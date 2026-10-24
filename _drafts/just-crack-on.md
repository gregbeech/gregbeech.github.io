---
layout: post
title: Just crack on
date: 2026-10-24
tags: [AI, Teams, Agile]
author: gregbeech
---

I've written a few posts about methodologies in the past, about keeping things light and fast. At Jitty, we're taking these ideas to the extreme. We don't have standups, sprints, estimates, a roadmap, or a backlog. We don't don't wait on human code reviews, and we don't have a staging environment. For the most part, we don't even have tickets.

What we do have is a small, very senior team that knows what the company is trying to achieve, and is given space to get on with it.

I should say up front that this is a description, not a prescription. It's how one tiny company works right now, and I'm not sure how far it generalises. But I've worked in small engineering teams of around ten, and I've worked in large engineering teams of hundreds, and I've never seen one move even close to this fast.

In the last four weeks, two engineers and our [growth person](/2026/10/22/the-line-has-moved/) shipped over eight hundred pull requests to production, anywhere from a few lines to well over a thousand. (Our third engineer joined last week, so barely registers yet.). I know, I know, pull requests are a poor proxy for value, but they're a bit like BMI in that they're useless for judging any one person, but give you a reasonable guide in aggregate.

## What's left

Here's everything in the calendar.

On Monday, Wednesday and Friday mornings there's "Jit Tea". It's optional and has no agenda. Sometimes it's about work, often it isn't. We're remote, and it's how we stay people to each other rather than avatars on pull requests.

Once a week there's "JIT Planning", partly because it's just-in-time, and partly because we like terrible puns. That sounds grander than it is: we go through what matters most to the company right now, and the handful of projects we're running. A project is little more than a title and the metrics we want to move, or hold. "Get more listings" is a project. How we get them is largely up to whoever's working on it.

Once a month there's a retro, a feature impact review, and a company update on funding and numbers. Twice a month there's an Ideas Critty. Plus 1:1s, as you'd expect.

That's it.

The retro is the one I'd keep if I had to bin everything else. Day-to-day coordination works fine without ceremony, because you can see the problem in front of you. But some problems only show up over weeks: a habit that's quietly costing you, or friction nobody mentions because no single instance is worth raising. You need a forum where you stop and look at them, and where people can be honest about what's working and what isn't. If they are, it's the most valuable meeting in the calendar. Ironically, it's also the one most Agile teams either skip or go through the motions of.

Look at what the rest are for. Tea time and 1:1s are for people. Planning and ideas crits are for direction: what matters, and what's worth doing. Impact reviews, like retros, are for learning, in their case whether what we shipped actually did anything. The company update is context.

None of them are for coordination. Nobody stands up and says what they did yesterday. Nobody drags a ticket across a board. There's no meeting whose purpose is finding out what everyone else is doing.

## Where coordination went

That's not because coordination doesn't happen. It just doesn't wait for a meeting.

When two of us need to agree something, we talk about it, in Slack or on a quick call, at the point it needs agreeing. Why wait for a ceremony when you can just do it? Slack is async, so there's no expectation of an immediate reply, and if you're blocked on one workstream you switch to another. With several agents on the go there's always another one to switch to, so waiting on someone costs almost nothing.

The longer-lived stuff lives in the repository. In [AI-driven development](https://www.gregbeech.com/2026/10/08/ai-driven-development/) I described work orders: design docs covering why a piece of work exists, what's there today, the decisions made, and the plan. We read each other's, and link between them. Architecture docs and guides sit alongside them, with `AGENTS.md` as the map. If you want to know what someone's working on and why, it's written down, versioned, and next to the code it describes. That's a better status update than any standup ever gave me, and nobody had to sit through it.

## Where direction comes from

Company priorities ultimately come from our CEO, and most of the large-scale work follows them. There's no roadmap, for reasons [I've written about before](https://www.gregbeech.com/2023/12/01/no-more-roadmaps/). Instead there's a rolling six-week window that's re-evaluated every week, so priorities can move as fast as we learn.

But a surprising amount of what gets built isn't on anyone's list. We used to call small bits of side work "sorbet tickets": palate cleansers between bigger pieces of work, like fixing something that annoyed you or making an improvement nobody had prioritised. With agents they've grown into sorbet features, because bigger things now fit in the gaps. A basic ML labelling and training system I built for extracting information from listing descriptions and images, like reading EPCs, started life as side work. Sorbet that turned into a main course.

The obvious risk is that everyone works on what's interesting rather than what matters. The filter is simple enough: if something's large and it isn't serving one of the current projects, it's not the right thing. If you're not sure, take it to an ideas crit. And because projects are framed as metrics rather than features, there's plenty of room inside them for people to find their own way to move the number, which is where most of the interesting work ends up anyway.

## Size

None of this is new. Small, senior teams have always been able to work like this. The hard part has always been staying small.

I've watched size kill speed more than once. At Deliveroo the engineering team was about fifteen people early on, and I'm convinced velocity dropped as we grew to around eighty. At three hundred it was higher, sure, but twenty times higher? Not by a long shot. At Zego, engineering grew to something like three hundred, with all the roles big organisations accumulate, and was then cut back through rounds of redundancies to around fifty, keeping only engineers, engineering managers, designers and product. We delivered more, and at higher quality.

It's why I [don't like hiring](https://www.gregbeech.com/2023/10/12/dont-hire/). Every person adds communication overhead, and most of the roles big teams add, like delivery managers, agile coaches and dedicated QA, exist to manage the overhead the earlier hires created. If you need someone to manage delivery, that's what engineering managers are for. Anything that slows you down is out.

What's changed is that AI makes staying small much easier. We have three engineers, all staff or principal level in the real sense rather than the title-inflation sense, each running several agents in parallel. Rich in growth ships to production, [as I wrote about recently](https://www.gregbeech.com/2026/10/22/the-line-has-moved/). Our CEO prototypes ideas himself. The group building the product is effectively five people, and it produces what I'd once have expected from twenty or thirty.

That changes who we hire. We do need more people. There were two of us earlier this year and there are three now, and I think we could genuinely use up to about eight engineers if we had the money and could find the right people. But they'd all need to be at the same level as the team we have. I honestly don't know whether there's a place for junior or mid-level engineers at a company like ours in the near future, or even most seniors. That's not a comfortable thing to write, and I don't have a good answer for what it means for the industry. But it's an honest description of where we are.

## Where it breaks

It'll break. I just don't know where.

So far it hasn't creaked, but that's because we're tiny. Communication channels grow much faster than headcount, and at some point people will start treading on each other's toes. We've got some natural protection in that the system is split into three large services, the web crawler being one of them, so as long as people know which areas others are working in it should hold for a while.

We've talked internally about keeping the whole company under fifty people, and plenty of those would be in roles that don't build anything: finance, a chief of staff, and everyone else it takes to support a growing business. I'm confident this way of working holds at twenty people. At fifty, I don't know.

What I'm fairly sure of is that the answer won't be bolting standups and sprints back on. If coordination becomes a problem, I'd rather push more of it into the repository and split along service boundaries, and keep the meetings for people, direction and learning.

## Not a methodology

So does this count as a methodology? I don't think so. There's nothing here anyone could get certified in. It's mostly a list of things we chose not to do, and a few habits that filled the space.

We hire very few, very good people. We make sure they know what matters and how it's measured. We write things down where the work happens, talk when we need to, and keep meetings for the things that can't be done any other way.

Then we let them crack on.
