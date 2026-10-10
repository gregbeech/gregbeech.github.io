---
layout: post
title: The production gap
date: 2026-10-10
tags: [ai, software engineering]
author: gregbeech
comments: true
---

Our new web crawler started life as something our CEO vibe coded with Claude. He's a former product manager, so he knows more about engineering than most CEOs, but he isn't an engineer. What he did have was the problem: we didn't have enough listing coverage, and he was determined to find a way to fix it.

Most engineers would bristle at that, and plenty of CTOs would take it personally. I don't. A CEO's job is to own the company's biggest problems, and this was him owning it in the most direct way available to him. It also worked: the approach he proved out is the one we built on.

But he was curious about something, and asked what the gap actually is between a proof of concept and a production-grade solution. I wrote a quick answer in Slack, and this is the longer version. It's mostly about one deceptively simple question: how fast should a crawler be allowed to go?

In my last post, I argued that engineers increasingly own the things no single change reveals. This is what that looks like in practice.

## The Proof of Concept

The proof of concept had its share of rough edges. Every adapter parsed HTML with regular expressions, which anyone who's read [that Stack Overflow answer](https://stackoverflow.com/questions/1732348/regex-match-open-tags-except-xhtml-self-contained-tags/1732454#1732454) will appreciate. But that's the kind of gap an engineer spots straight away. The one I want to talk about is one most people never think about at all.

Every request a crawler makes costs the site something. The web server burns CPU rendering the page, the database burns CPU, memory and IO fetching the data, and everything burns network moving it around. Push any of those towards their limits and the site slows down or falls over.

We care about that for two reasons. It harms the estate agent's business, and it gets us blocked. The second is a problem; the first is a line we won't cross. [Jitty](https://jitty.com/)'s success depends on helping estate agents, so a crawler that slowed their sites down would be undermining the very thing we're trying to do.

The obvious fix is a per-site rate limit. Say one request every couple of seconds, which is gentle enough that no reasonable site will notice. Job done.

That's proof-of-concept grade. It's also where most crawlers stop.

## Multitenancy

Many estate agents don't run their own website. They use a platform, and some platforms include multitenant hosting: many agents' sites served from the same web and database servers. Some platforms host several hundred tenants.

So a polite one request every couple of seconds per site becomes a hundred or more requests per second to one company's servers. That's no longer polite. It's getting uncomfortably close to a denial-of-service attack, and it's exactly the harm we said we wouldn't do.

The fix is to work out which sites share an origin, and rate limit at that level as well as per site. Nobody publishes that, so we have to infer it. DNS records (A, AAAA, CNAME and PTR) give strong signals, and TLS certificate fingerprints and serial numbers fill in a lot of the gaps. Put together, they let us say with reasonable confidence that these hundreds of domains are really one set of servers. If PTR records and certificate serials mean nothing to you, that's rather the point.

So that's the pages sorted. Done? Not even close.

## Media

Every listing has a gallery, and every image is another request. Where those images come from changes how you should treat them, and there are four common cases.

1. Served from the same origin as the site. Image requests are still requests, so they count against the origin's limit. Lumping them in with pages works, but it means one site's photo backlog slows down another site's page crawls. Images are generally cheaper to serve than rendered pages, so ideally they get their own, higher limit on the same origin.
2. Served through a CDN with a read-through cache. The CDN serves what it has, and only goes back to the origin on a cache miss. That's how Jitty's own images work. Treating these like same-origin media is safe, but the better approach is to track cache misses and limit those separately from total requests, because only the misses actually cost the origin anything. And on estate agency sites, the misses are most of the traffic: cache hit ratios are typically only 30 to 50%, so the majority of requests go straight through to the origin anyway. You only know that if you're measuring it.
3. Served from an image service. These resize and convert images on the fly, often for a huge number of sites at once. They sit somewhere between a CDN and an object store: built for far more traffic than a single site's server, but with real work behind each uncached request, so we give them limits somewhere between the two.
4. Served from an object store like S3. These can take far more traffic, but not unlimited traffic, and the limits are per bucket. Many sites share the same object store, so if you rate limit by host alone, you throttle everyone together and can't get through the crawl. You need to extract the bucket from the URL and key the limit on both.

Even extracting the bucket is fiddlier than it sounds. S3's newer syntax puts the bucket name in the hostname, but the older style with the bucket in the path still works, so the same bucket can arrive in two shapes. And that's one case of a wider problem: every key you rate limit on has to be canonicalised first. `jitty.com.` with a trailing dot is the same host as `jitty.com`. The same IPv4 or IPv6 address can be written several different ways: `2001:db8::1` and `2001:0db8:0:0:0:0:0:1` are the same address. Miss any of these and one origin quietly becomes two, each with its own limit, and you're sending double what you think you are.

OK, so that's media. Surely we're done now? Nope.

## Not All Requests Are Equal

A search results page is expensive to serve. A single listing is cheaper. An image is cheaper still. A flat requests-per-second limit treats them all the same, which means you're either too aggressive with searches or too timid with everything else.

The usual answer is a token bucket. Tokens drip into a bucket at a fixed rate, say two per second, and each request has to take out tokens equal to its cost before it can go. Cost a search page at 4, a listing at 2 and an image at 1, for example, and the same bucket allows one search every couple of seconds, one listing a second, two images a second, or any mix of them.

We actually use a modified version of GCRA, the generic cell rate algorithm. It gives the same behaviour as a token bucket, but needs only a single timestamp per key: the earliest time the next request is allowed. That makes it cheap to implement atomically in Postgres, with one row update per booking, which matters when many workers across many machines share the same limits.

Our modification adds a bounded slack. A worker books a timeslot, and it has to make its request within that slot. If it misses, it loses the slot and has to book again. Without that, a slow or stalled thread could hold a booking indefinitely, and the schedule would stop reflecting what's really being sent.

It also prevents a subtler problem: a thundering herd. If lots of threads book slots but don't use them straight away, they can all end up firing at once. Averaged over a minute the rate looks fine, but the peak hits the site as a burst, which is exactly what the limit was meant to prevent. Forcing each request into its own slot means the minimum gap between requests is never breached, even for a moment. We call this floor integrity: the limit is a floor on how closely requests can be spaced, not just a target for the average.

## Backing Off

All of those origins and limits are guesses. Educated guesses, backed by evidence, but still guesses. Sometimes the guess is wrong. A site might be having a bad day, or sharing its servers with something we can't see.

So the crawler has to listen. A 429 (too many requests), 503 (service unavailable) or a run of 500s means back off, or stop entirely, across the site, the origin, or both, and respect any `Retry-After` header.

Better still is not getting there at all: rising response latency is usually the first sign of a server running out of resources, so we watch for it and slow down before the errors start. By the time a site is returning errors, we've already done some harm, and the goal is to do none.

## Where You're Allowed to Go

So far this has all been about how hard to hit other people's servers. There's also the question of which servers you should be hitting at all.

A crawler fetches untrusted pages, then follows the links and image URLs in them. Nothing stops a page pointing at an address inside our own network, or at the cloud metadata service that hands out credentials. Fetch that blindly and the crawler becomes a way into our own infrastructure. It's called server-side request forgery, and it's a well-trodden path for attackers.

One obvious defence is to block private address ranges. The less obvious part is how many of them there are. Our list runs to more than thirty, and some are genuinely subtle. Here's a small part of it:

```ruby
IPAddr.new("100.64.0.0/10"),   # carrier-grade NAT
IPAddr.new("::ffff:0:0/96"),   # IPv4-mapped IPv6 (e.g. ::ffff:127.0.0.1)
# Well-known NAT64 (RFC 6052). Globally reachable, but embeds an arbitrary
# IPv4 (64:ff9b::a00:1 == 10.0.0.1), so on a NAT64 network it can translate
# to internal space.
IPAddr.new("64:ff9b::/96"),
IPAddr.new("2002::/16"),       # 6to4 (embeds IPv4; deprecated)
```

Several IPv6 ranges embed an IPv4 address inside them, so an address that looks public can quietly translate to one that isn't. And the list is only as good as the canonicalisation in front of it. `127.000.001.001` is written partly in octal, but plenty of parsers will read it as `127.0.1.1`, a loopback address that sails straight past a naive check.

Then there's timing. If you check that a hostname resolves to a safe address, then look it up again when you actually fetch, the answer can change in between. That's DNS rebinding, and the fix is address pinning: resolve once, check that address, and connect to exactly that address.

None of this is rate limiting, but it's the same kind of problem: invisible in a proof of concept, and essential the moment real, untrusted content flows through the system.

## The GVL Problem

The slotted approach is sound on paper. In Ruby, it turns out to be a royal pain.

Ruby has a global VM lock, the GVL, which means only one thread in a process runs Ruby code at a time. Threads give it up while they wait on IO, but they have to get it back to carry on. When a thread's timeslot arrives and another thread is busy, say parsing a large HTML page, it can't acquire the lock in time.

It isn't only Ruby code. libvips, the library we use to resize and convert images, releases the GVL for some operations but holds it for others, like reading pixels back into Ruby, for their whole duration. Because that's native code, Ruby's timeslice doesn't apply either: the thread can't be interrupted until the operation finishes. Either way, the waiting thread misses its slot, rebooks, and quite possibly misses the next one too. The rate limiter is working perfectly; the threads just can't keep their appointments.

This is the part that surprises people outside engineering. The idea is right, the algorithm is right, and the code does what it says. It still doesn't work, because of how the language it's written in runs on real machines. A correct design is where the engineering starts, not where it ends.

There are ways to fight it. Page fetches and image downloads have very different profiles, as many sites render pages slowly while images come back quickly, so we can run them on separate workers rather than letting them compete for the same lock. We can also tune how long a booking's timeslot lasts, trading precision for tolerance. And we've tuned Ruby's own thread timeslice: how long a thread can run before it's made to hand the lock over, so a waiting thread gets its turn sooner.

The real fix would be Ractors, Ruby's newer model for running code in parallel, which aren't bound by a single lock. But Rails relies on too much shared global state to run inside them yet, though there's active work underway to change that. So I'll be honest: it's not yet clear whether this approach is viable in Ruby at all, and that's still an open piece of engineering work.

## Seeing It Work

None of this is any use if you can't tell whether it's working. A crawler that's quietly hammering one origin looks exactly like a crawler that's behaving, right up until someone emails to complain.

So there are metrics for everything: request rates and response codes per site and origin, latencies, and throughput. There's anomaly detection on top, so we get alerted when something drifts rather than when it breaks. The rate limiter has its own metrics too, which is how we can see the GVL problem at all: the rebooking rate shows exactly how often threads are missing their slots.

And some questions can't be answered with metrics at all, because the cardinality is too high. Which of thousands of sites slowed down after a particular change? For those, we ship the detail to a columnar analytics store, where we can slice it however we need.

## The Gap

So that's the gap. And it isn't even all of the fetching, just part of it. I haven't touched on automatically redacting the keys that sites embed in their pages, like maps keys, of which there are dozens of varieties, or stripping out personal data. Let alone robots.txt, retries, scheduling, storage, or any of the other parts of a production crawler.

The proof of concept answered the question that mattered most at the time: can this approach work at all? It could, and without it we might still be arguing about whether to try. That's real value, and it came from someone owning a problem rather than waiting for engineering to get round to it.

Production engineering answers a different question: what happens when it works, at scale, to everyone else? Most of the gap is invisible from the outside, because when it's done well, nothing happens. Nobody's site falls over, nobody blocks you, and nobody emails to complain. That's the job.
