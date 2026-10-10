---
layout: post
title: What are engineers for now?
date: 2026-10-10
tags: [ai, software engineering]
author: gregbeech
comments: true
---

Six weeks ago, Rich, who looks after growth for us, made his first real commit to our codebase. Recently he made his hundredth. That ranges from SEO, our main growth driver, to new UI features, and it isn't trivial stuff: plenty of it involves database changes and background jobs. The work is well thought through and high quality. If I didn't know better, I'd assume it came from a strong mid-level engineer, maybe even a senior.

He can't code. At all.

The piece that impressed me most started with someone else. Millie, who brings our partnerships and industry expertise, had been using Claude to produce homebuyer reports, pulling together land registry records, planning applications, flood risk, sales history and more into something people will actually pay for. Rich built the feature to sell them, including the changes our Stripe integration needed to take payment. Millie can't code either. For now she still produces each report by hand with Claude; that part isn't codified yet.

So two people who can't code came up with an idea, built it, and shipped a revenue-generating feature, with no engineering involvement beyond a few review comments. I think that's incredible.

Neither of them can do deep refactoring, and they don't know much about performance or software engineering principles. But as Rich put it in [his own post](https://www.linkedin.com/feed/update/urn:li:activity:7513922056082669568/) about the experience: "Not ship vibe-coded slop, but ship ship." It's real, meaningful work that until very recently would have needed an engineer. I'm fairly sure that's a good thing. Working out exactly why, and what it means, is a bit harder. It feels like a revolution, but I'm not sure it really is.

## This Isn't New

Non-engineers building software isn't new. Businesses have run on spreadsheets for decades, and plenty of those spreadsheets had enough VBA in them to count as software by any reasonable definition. More recently, tools like Zapier let people wire systems together without writing code at all. In the early days of Deliveroo, a lot of our operations ran on Zapier, because there weren't enough engineers to build what the operations teams needed.

This stuff created enormous value. It also lived entirely outside engineering: no version control, no review, no tests, and usually no monitoring, so when it broke, the people running it often didn't know.

More worryingly, in my experience it's where most reportable data breaches come from. Not from engineering, but from a mail merge that CC'd everyone, or a file of personal data dropped into a public S3 bucket. Engineering is where people tend to worry about breaches most, and I suspect that's exactly why they're rarer there: it's the part of the business that gets the scrutiny.

## What Is New

What's different now is where the work lands. His changes go into the real codebase, through the same pull requests, the same CI, and the same AI review as everyone else's. AI isn't creating shadow engineering. If anything, it's dragging it into the light.

It also unlocks a category of work that has always struggled to get done: the small features and fixes that never make it onto a roadmap because they're too minor to compete with bigger priorities. SEO improvements are a perfect example. Individually they're small, collectively they're valuable, and they're permanently stuck behind whatever engineering is working on this quarter. Now the person who cares most about them can just do them.

He's refreshingly honest that a good chunk of the code didn't take much effort. By his own account, his role was mostly being someone with the will and the headspace to move it forward. That's exactly the point: the code was never the hard part. The work just never got prioritised.

## The Gate

There is one difference in how his work is treated. Engineers can merge their own pull requests once the automated reviews are happy, but his need a final sign-off from an engineer. He counts those approvals among the guardrails that make this work, and he's right. But on an engineering team as tiny as ours, every sign-off is also an interruption.

It's tempting to think that gate is about code quality, but it isn't, really. The automated review is the same either way. The gate is about who can own the outcome. When an engineer gets something wrong, they fix it, and they're on the on-call rota. When a non-engineer gets something wrong, an engineer fixes it, and it's still the engineer on the on-call rota.

That asymmetry matters, and it matters more when the on-call rota is tiny. Nobody's being careless, but it's hard to weigh a risk you don't even know exists, and harder still when someone else will be the one paying for it.

## Whoever Merges Carries the Pager

We already have a rule that captures the principle. If you merge out of hours, you put yourself on call for the night. Whoever merges carries the pager.

So the useful question isn't whether the review agent is good enough. It's whether he could carry the pager for his own changes.

The bar for that is lower than it sounds. Deploy isn't release, so everything we ship sits behind a feature flag, and the first response to most incidents is switching that flag off. Anyone can do that. Our CI is fast enough that we roll forward rather than back, and with agents that can see logs, metrics and exceptions, a non-engineer can get a long way towards diagnosing and fixing a problem too. I'd still want the flag to be the answer at 3am, but turning it off and looking properly in the morning is often the right call for anyone.

## Changes You Can't Switch Off

That also shows where the risk really lives: in the changes a flag can't contain. Migrations. Anything that writes or transforms data. Batch jobs that run whether a flag is on or not. Performance problems, like a precompute job that quietly hammers the database. These are often irreversible, and they're exactly the system-level things a non-engineer can't see.

So rather than a blanket gate, the principle becomes: human sign-off for changes you can't switch off. Anything fully behind a flag could merge on the same terms as an engineer's work. Anything irreversible needs an engineer, whoever wrote it.

It's the same reasoning that lets us [run without a staging environment](https://www.gregbeech.com/2024/12/22/exit-staging-left/). It's not that there's no risk; it's that specific practices for the genuinely dangerous changes beat a checkpoint on everything.

## Earning It

We're not there yet on this repository. It's older and isn't as well set up for agents as our newer repositories, and it doesn't have a proper code review skill, so for now the gate stays.

Interestingly, he thinks that kind of setup is mostly unnecessary, and he's partly right. The review agents do a good job without a skill. But most of what engineers have flagged in his pull requests wasn't wrong so much as wrong for us: adding hooks to the site template because one component needed them, or adding a dedicated Sidekiq queue so one job could jump ahead of the others. A generic reviewer can't know those things. A review skill could.

What he can't see is everything else. The CI pipeline, the preflight checks, the feature flags and release practices: all of it was built by engineers, and from where he sits, it's invisible. The guardrails feel unnecessary precisely because they're working.

The way to remove it is the same way the rest of our agent setup grew: scar tissue. Every time an engineer catches something in one of his pull requests that the review agent missed, it goes into the review skill. Over time, human sign-off turns into a measurement of what the agent still doesn't know. When engineers stop finding anything over a decent run of pull requests, there's evidence the gate can go, rather than just a feeling.

I'll be honest: even then, it makes me a bit nervous. That's probably healthy. Spreadsheets didn't go wrong because non-engineers built them. They went wrong because nobody was checking the things their authors couldn't see.

## Where the Line Ends Up

In [my last post](https://www.gregbeech.com/2026/10/08/ai-driven-development/) I argued that writing code is the easy bit between the hard bits. He has the hard bits for his domain. He understands SEO far better than any of our engineers, and as he points out, that business context makes him a better fit than an engineer for some pull requests. What he was missing was the easy bit, and agents have filled that in.

So the line between engineering and everything else hasn't disappeared. It's moved. Engineers increasingly own the things that don't show up in any single change: performance, architecture, reliability, and the guardrails that let everyone else work safely. That's uncomfortable news for junior engineers, who are now competing not just with agents but with domain experts who can ship. And as his own existential crisis about it shows, it's not only engineers who are wondering what their job looks like in a year.

It moves the bottleneck, too. He makes the point himself that building was never really the hard part; building the right thing was. When anyone can ship, it's easy to build faster than you can learn from users. I've argued before that you should [just build it, but not ship it](https://www.gregbeech.com/2025/05/16/just-build-it-but-dont-ship-it/), and that's truer now than ever. Building is cheap enough for anyone; the discipline is being brutally honest about what deserves to reach users.

I think it's a good thing. And the rule for getting there applies to everyone, engineer or not: you can merge without sign-off when you can carry the pager for what you've merged.
