---
layout: post
title: The production gap
date: 2026-10-24
tags: [ai, software engineering]
author: gregbeech
comments: true
---

The new web crawler at [Jitty](https://jitty.com/) started life as something our CEO vibe coded with Claude. He's a former product manager, so he knows more about engineering than most CEOs, but he isn't an engineer. What he did have was the problem: we didn't have enough listing coverage, and he was determined to find a way to fix it.

Most engineers would bristle at that, and plenty would take it personally. I don't. A CEO's job is to own the company's biggest problems, and this was him owning it in the way that made most sense to him. It worked out too, because the approach he prototyped is the one we built on.

One of the things he asked, which many non-engineers struggle to understand, is what the gap is between a proof of concept and a production-grade solution. Why can't you just take the PoC and stick it in production? I wrote a quick answer in Slack, and this is the longer version. I'm going to focus on one seemingly tiny detail, which is how fast a crawler should be allowed to go.

In [my last post](/2026/10/22/the-line-has-moved/), I argued that engineers increasingly own the things that don't show up in any single change, like performance, architecture, and reliability. This is what that looks like in practice.

## Everything has a cost

Every request a crawler makes costs the site something. The web server burns CPU rendering the page, the database burns CPU, memory and IO fetching the data, and everything burns network moving it around. Push any of those towards their limits and the site slows down or falls over.

We care about that for two reasons. It harms the estate agent's business, and it gets us blocked. The second is a problem; the first is a line we won't cross. Jitty's success depends on helping estate agents, so a crawler that slowed their sites down would be undermining the very thing we're trying to do.

The obvious fix is a per-site rate limit. Say one request every couple of seconds, which is gentle enough that no reasonable site will notice. It can be implemented in just a few lines of code. Job done.

That's proof-of-concept grade engineering, and it's deeply, hopelessly insufficient.

## Multitenancy

Many estate agents don't build or run their own website. They use a platform, and the majority of platforms include multitenant hosting: many agents' sites served from the same web and database servers. Some platforms host several hundred tenants.

A polite one request every couple of seconds per site becomes a hundred or more requests per second to one company's servers. That's uncomfortably close to a denial-of-service attack, and exactly the harm we don't want to do.

The fix is to work out which sites share an origin, and rate limit at that level as well as per site. Nobody publishes that, so we have to infer it. DNS records (A, AAAA, CNAME and PTR) give strong signals, TLS certificate fingerprints and serial numbers provide corroborating evidence, and header probing can help to fill in the gaps. Put together, they let us say with reasonable confidence that these hundreds of domains are really one set of servers.

If origins, PTR records and certificate serials mean nothing to you, that's rather the point of this post. Engineering is a domain too.

## Some requests are more equal than others

A search results page is expensive to serve. A single listing is cheaper. An image is cheaper still. A flat requests-per-second limit treats them all the same, which means you're either too aggressive with searches or too timid with everything else.

The usual answer is a leaky bucket. Each request adds its cost to the bucket, the bucket drains at a fixed rate, say two units per second, and a request can only go once there's room for it. Cost a search page at four, a listing at two and an image at one, for example, and the same bucket allows one search every couple of seconds, one listing a second, two images a second, or any mix of them.

We actually use a modified version of GCRA, the generic cell rate algorithm. It gives the same behaviour as a leaky bucket, but needs only a single timestamp per key: the time the next request is due. That makes it cheap to implement atomically in Postgres, with one row update per booking, which matters when many processes across many machines share the same limits.

Our modification adds bounded slack. A thread books a timeslot, and it has to make its request within that slot. If it misses, it loses the slot and has to book again. Without that, a slow or stalled thread could hold a booking indefinitely, and the schedule would stop reflecting what's really being sent.

It also prevents a more subtle problem. If lots of threads book slots but don't use them straight away, they can all end up firing at once. Averaged over a minute the rate looks fine, but the peak hits the site as a burst, which is exactly what the limit was there to stop. Forcing each request into its own slot means it can only drift from its schedule by the width of the slot, so requests can't bunch up. We call this floor integrity: the limit is a floor on how closely requests can be spaced, not just a target for the average.

Sites can ask for a slower rate with a `Crawl-delay` in `robots.txt`, but it was never formally standardised, so it's unclear whether it means the gap between the start of each request or the gap between one request finishing and the next starting. GCRA schedules when requests start, and has no idea when they'll finish, so we chose that meaning for purely practical reasons.

## Media requests aren't equal either

Every listing has a gallery, and every image is another request. Where those images come from changes how you should treat them, and there are four main cases.

1. Served from the same origin as the site. These requests count against the origin's limit alongside the pages, using an appropriate cost.
2. Served from a CDN with a read-through cache. The CDN serves what it has, and only goes back to the origin on a cache miss. Treating these like same-origin media is safe, but the better approach is to track cache misses and limit those separately from total requests, because only the misses actually cost the origin anything.
3. Served from an object store like S3. These can take far more traffic, but not unlimited. S3 scales its limits per key prefix, which you can't see from outside, but the bucket is a good proxy. Many sites share the same object store, so if you rate limit by host alone, you throttle everyone together and can't get through the crawl. You need to key the limit on the bucket as well.
4. Served from an image service. These resize and convert images on the fly, often for a huge number of sites at once. They can act either like a CDN or an object store, and it may vary by customer, or even by the image itself, not just by the service. Fortunately we can detect which case we're in pretty reliably, and limit it accordingly.

As object stores can absorb short bursts we let them burst up to capacity like a token bucket, where everything else keeps a steady rate like a leaky bucket. GCRA supports either with no modifications.

## What's in a name?

Keying on an object store's bucket sounds simple, but even extracting it from the URL is fiddly. S3's newer syntax puts the bucket name in the hostname, but the older style with the bucket in the path still works, and both come with regional variants, so the same bucket can arrive in several shapes. Other object stores have similar quirks.

That's one case of a wider problem: every key you rate limit on has to be canonicalised first, because the same host can be written in many different ways. Hostnames are case-insensitive, so `Jitty.com` and `jitty.com` are the same. A trailing dot makes a name fully qualified, but `jitty.com.` is still `jitty.com`. Internationalised domain names have to be converted to punycode, so `tŷ.example` and `xn--t-foa.example` end up as one key. Ports get dropped, because `jitty.com:443` is still the same machine.

IP addresses aren't straightforward either, because they have several valid forms. `8.8.8.8` is also `134744072`, and `2001:db8::1` and `2001:0db8:0:0:0:0:0:1` are the same address. Miss any of these and one origin quietly becomes two or more, each with its own limit, and you're sending traffic at a higher rate than you think you are.

## Hey, back off!

All of those origins and limits are educated guesses, and sometimes they're wrong. A site might be having a bad day, or sharing its servers with something we can't see.

So the crawler has to listen. A 429 (too many requests), 503 (service unavailable) or a run of 500s means back off, or stop entirely, across the site, the origin, or both, and respect any `Retry-After` header.

Better still is not getting there at all: rising response latency is usually the first sign of a server running out of resources, so we watch for it and slow down before the errors start. By the time a site is returning errors, we've already done some harm, and the goal is to do none.

## The problem with theory and practice

The slotted booking from earlier is sound on paper. In Ruby, it turns out to be a royal pain.

Ruby has a global VM lock, the GVL, which means only one thread in a process runs Ruby code at a time. Threads give it up while they wait on IO, but they have to get it back to carry on. When a thread's timeslot arrives and another thread is busy, say parsing a large HTML page, it can't acquire the lock in time.

It isn't only Ruby code. libvips, the library we use to resize and convert images, releases the GVL for some operations but holds it for the whole duration of others, like reading pixels back into Ruby. Because that's native code, Ruby's timeslice doesn't apply either: the thread can't be interrupted until the operation finishes. Either way, the waiting thread misses its slot, rebooks, and quite possibly misses the next one too. The rate limiter is working perfectly; the threads just can't keep their appointments.

This is the part that surprises people outside engineering. The design is sound and the code does what it says, but it still doesn't work, because of how Ruby runs on real machines. A correct design is where the engineering starts, not where it ends.

There are ways to fight it. Page crawls and image downloads hog the lock in different ways, one parsing HTML and the other processing images, so we can run them in separate processes, each with its own GVL, rather than letting them compete for the same one. We can also tune how long a booking's timeslot lasts, trading precision for tolerance. We've tuned Ruby's own thread timeslice, which is how long a thread can run before it's made to hand the lock over, so a waiting thread gets its turn sooner.

The obvious next step is more processes with fewer threads in each, but our crawl processes also run Chromium and some pretrained transformer models, so each one has a fair chunk of CPU and memory allocated, which makes processes expensive compared to the threads inside them. Moving those out to allow lots of small, single-threaded crawl processes is a bigger architectural shuffle.

The real fix would be Ractors, Ruby's newer model for running code in parallel, which aren't bound by a single lock. But Rails relies on too much shared global state to run inside them yet, though there's active work underway to change that.

Honestly, it's not yet clear whether the current booking slot approach is viable in Ruby at all, and that's still an open piece of engineering work.

## Seeing it work

None of this is any use if you can't tell whether it's working. A crawler that's quietly hammering one origin looks exactly like a crawler that's behaving, right up until someone emails to complain.

So there are metrics for everything: request rates and response codes per site and origin, latencies, and throughput. There's anomaly detection on top, so we get alerted when something drifts rather than when it breaks. The rate limiter has its own metrics too, which is how we can see the GVL problem at all. The rebooking rate shows exactly how often threads are missing their slots. It should be a couple of percent at most, and it's about an order of magnitude higher than that.

Some questions can't be answered with metrics at all, because the cardinality is too high. Which of thousands of sites slowed down after a particular change? To answer that, the records need to be shipped to some kind of columnar analytics store where they can be sliced however we need.

## Who do you trust?

So far this has all been about how hard to hit other people's servers. Before finishing, a brief aside on which servers you should be hitting at all.

A crawler fetches untrusted pages, then follows the links and image URLs in them. Nothing stops a page pointing at an address inside our own network, or at the cloud metadata service that hands out credentials. Fetch that blindly and the crawler becomes a way into our own infrastructure. This is server-side request forgery (SSRF), and it's a well-trodden path for attackers.

The obvious defence is to block private address ranges, but there are more of them than you'd think. Our list runs to more than thirty, and some are genuinely subtle. Here's part of it:

```ruby
IPAddr.new("100.64.0.0/10"),   # carrier-grade NAT
IPAddr.new("::ffff:0:0/96"),   # IPv4-mapped IPv6 (e.g. ::ffff:127.0.0.1)
# Well-known NAT64 (RFC 6052). Globally reachable, but embeds an arbitrary
# IPv4 (64:ff9b::a00:1 == 10.0.0.1), so on a NAT64 network it can translate
# to internal space.
IPAddr.new("64:ff9b::/96"),
IPAddr.new("2002::/16"),       # 6to4 (embeds IPv4; deprecated)
```

Several IPv6 ranges embed an IPv4 address inside them, so an address that looks public can quietly translate to one that isn't. And the list is only as good as the canonicalisation in front of it. `0177.0.0.1` is `127.0.0.1` written partly in octal. A naive check reads it as `177.0.0.1`, a public address, but the system resolver reads it as loopback, so it sails straight through.

Then there's timing. If you check that a hostname resolves to a safe address, then look it up again when you actually fetch, the answer can change in between. That's DNS rebinding, and the fix is address pinning: resolve once, check that address, and connect to exactly that address.

None of this is rate limiting, but it's the same kind of problem because it's invisible in a proof of concept, and essential the moment real, untrusted content flows through the system.

## The production gap

So that's the gap, and it's only part of fetching. I haven't touched on automatically redacting the API keys that sites embed in their pages, like Google Maps keys, of which there are dozens of varieties, or stripping out personal data. Let alone the rest of robots.txt, retries, scheduling, storage, or any of the other parts of a production crawler.

The proof of concept answered the question that mattered most at the time, whether the approach could work at all. It could, and without it we might still be arguing about whether to try. That's real value, and it came from someone owning a problem and getting agents to build a solution, rather than waiting for engineering to get round to it.

The production crawler was written by agents too, every line of it, and they did a bunch of the research as well. When I wanted to know whether TLS certificates could tell us which hosts share servers, an agent dug through real-world patterns and came back with the answer, that it was good corroborating evidence but not reliable enough to place a host on its own.

What it was never going to do was ask that question in the first place. Knowing that shared hosting turns politeness into a denial of service, that a crawler is an SSRF vector, that a certificate might count as evidence at all: that's the engineering. The agents made the answers cheap, but the questions still had to come from somewhere.

From the outside, the production system looks just like the proof of concept. Crawls run, and listings arrive. The work that makes it safe to do at scale doesn't show, so the gap is hard to see from outside engineering. Both were built with the same tools, and what separates them is the engineering. It's an essential discipline, and will be for a long time yet.
