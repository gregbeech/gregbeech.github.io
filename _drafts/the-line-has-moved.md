---
layout: post
title: The line has moved
date: 2026-10-13
tags: [ai, software engineering]
author: gregbeech
comments: true
---

A few weeks ago, Rich, who looks after growth for us, made his first real commit to our codebase. He's now well past his hundredth. That ranges from SEO, our main growth driver, to new UI features and performance improvements, and it isn't trivial stuff: some of these changes involve database migrations and background jobs. The work is well thought through and high quality. If I didn't know better, I'd assume the analysis and implementation came from an experienced engineer.

He can't code. At all.

Millie, our partnerships manager, came up with the idea of using AI to produce homebuyer reports, pulling together myriad data sources including land registry records, planning applications, flood risk, sales history and more. Rich built a feature to allow people to buy them, including the changes our Stripe integration needed to take payment. People are buying them.

So two people who can't code took an idea all the way to a revenue-generating feature, and engineering's only involvement was a few minor review comments. As Rich put it in [his own post](https://www.linkedin.com/feed/update/urn:li:activity:7513922056082669568/) about the experience: "Not ship vibe-coded slop, but ship ship." It's real, meaningful work that until very recently would have needed an engineer.

This is very cool. It feels like a revolution, and in one way it is: this is production software, serving paying customers. But non-engineers building software isn't new, so it's worth looking at what's actually changed, and what it means for engineers.

## Out of the shadows

Businesses have run on spreadsheets for decades, and plenty of those spreadsheets had enough VBA in them to count as software by any reasonable definition. More recently, tools like Zapier let people wire systems together without writing code at all. In the early days of Deliveroo, a lot of our operations ran on Zapier, because there weren't enough engineers to build what the operations teams needed.

This kind of software creates enormous value. It also lives entirely outside engineering: no version control, no review, no tests, and usually no monitoring, so when it goes wrong, the people running it often don't know. In many big companies that's deliberate, because otherwise The Process is invoked, and the half hour spreadsheet job gets Prioritised and put on a Roadmap, and won't happen for six to twelve months, if ever.

So engineering turns a blind eye and pretends the Zapier and spreadsheets don't exist because they've already got enough work, and the business just kind of ignores engineering because they're too slow anyway, and everybody is happy.

Until something leaks, anyway. In my experience, it's this kind of software that most reportable data breaches come from. Not from engineering, but from a file containing personal data dropped into a public S3 bucket, or a mail merge that CC'd everyone instead of BCC'd. Engineering is where people tend to worry about breaches most, and I suspect that's exactly why they're rarer there: it's the part of the business that gets the scrutiny.

What's different now is where the work lands. Rich's changes go into the real codebase, through the same pull requests, the same CI, and the same agentic review as everyone else's. Rather than creating more shadow engineering, AI is dragging it into the light.

It also unlocks a category of work that has always struggled to get done: the small features and fixes that never make it onto a roadmap because they're too minor to compete with bigger priorities. SEO improvements are a perfect example. Individually they're small, collectively they're valuable, and they're permanently stuck behind whatever engineering is working on this quarter. Now the person who cares most about them can just do them.

Rich is refreshingly honest that a good chunk of the code didn't take much effort. By his own account, his role was mostly being someone with the will and the headspace to move it forward. That's exactly the point: the work just never got prioritised.

So the software isn't new, but the scrutiny is. And once it's in the light, it raises a question Zapier never did: who gets to merge?

## Whoever merges carries the pager

Right now, there's one difference in how Rich's work is treated. Engineers can merge their own pull requests once the automated reviews are happy, but his need a final sign-off from an engineer. He counts those approvals among the guardrails that make this work, and he's right. But on an engineering team as small as ours, every sign-off is also an interruption.

It's tempting to think that gate is about code quality, but it isn't, really. The automated review is the same either way. The gate is about who owns the outcome. When an engineer gets something wrong, they fix it, and they're on the on-call rota. When a non-engineer gets something wrong, an engineer fixes it, and it's still the engineer on the on-call rota. Nobody's being careless, but it's hard to weigh a risk you don't even know exists, and harder still when someone else will be the one paying for it.

We already have a rule that captures the principle. If you merge out of hours, you put yourself on call for the night. Whoever merges carries the pager. So the useful question isn't whether the review agent is good enough. It's whether Rich could carry the pager for his own changes.

The bar for that is lower than it sounds. Deploy isn't release, so everything we ship sits behind a feature flag, and the first response to most incidents is switching that flag off. Anyone can do that. Our CI is fast enough that we usually roll forward rather than back, and with agents that can see logs, metrics and exceptions, a non-engineer can get a long way towards diagnosing and fixing a problem too. I'd still want the flag to be the answer at 3am, but turning it off and looking properly in the morning is often the right call for anyone.

## Changes you can't switch off

Flags also show where the risk really lives: in the changes a flag can't contain. Migrations. Anything that writes or transforms data. Batch jobs that run whether a flag is on or not. Performance problems, like a precompute job that quietly hammers the database. These are often irreversible, and they're exactly the system-level things a non-engineer can't see.

So rather than a blanket gate, the principle becomes: human sign-off for changes you can't switch off. Anything fully behind a flag could merge on the same terms as an engineer's work. Anything irreversible needs an engineer, whoever wrote it. It's the same reasoning that lets us [run without a staging environment](https://www.gregbeech.com/2024/12/22/exit-staging-left/). It's not that there's no risk; it's that specific practices for the genuinely dangerous changes beat a checkpoint on everything.

We're not there yet on our main repository. It's older, isn't as well set up for agents as our newer ones, and doesn't have a proper code review skill, so for now the gate stays.

Interestingly, Rich thinks that kind of setup is mostly unnecessary, and he's partly right. The review agents do a good job without a skill. But most of what engineers have flagged in his pull requests wasn't wrong so much as wrong for us: adding hooks to the site template because one component needed them, or adding a dedicated job queue so his job could jump ahead of the others. A generic reviewer can't know those things. A review skill could.

The way to remove the gate is the same way the rest of our agent setup grew: scar tissue. Every time an engineer catches something in one of his pull requests that the review agent missed, it goes into the review skill. Over time, human sign-off turns into a measurement of what the agent still doesn't know. When engineers stop finding anything over a decent run of pull requests, there's evidence the gate can go, rather than just a feeling.

Even then, it makes me a bit nervous. That's probably healthy. Zapier workflows didn't go wrong because non-engineers built them. They went wrong because nobody was checking the things their authors couldn't see.

## Engineering is a domain too

In [my last post](https://www.gregbeech.com/2026/10/08/ai-driven-development/) I argued that writing code is the easy bit between the hard bits. Rich has the hard bits for his domain. He understands SEO far better than any of our engineers, and as he points out, that business context makes him a better fit than an engineer for some pull requests. What he was missing was the easy bit, and agents have filled that in.

What agents can't fill in is everything that makes his changes safe to ship. The comprehensive testing strategy, the CI pipeline, the preflight checks, the feature flags and release practices, the instinct that a new precompute job is going to hurt the database: all of it comes from engineers, and from where he sits, it's invisible. It's also why the models seem to need so little setup: they're working inside guardrails somebody already built.

Those are the hard bits of engineering. Engineers need to be domain experts too, and their domain is engineering. Not knowing a language or a framework, but knowing how systems behave under load, how data outlives the code that wrote it, how changes fail and how to make them fail safely, and how to build the environment that lets everyone else ship without breaking things. That's what Rich is borrowing every time he merges.

For a long time you could have a perfectly good career by showing up and writing code, because the code was scarce. It isn't any more. An agent can write it, and a domain expert with an agent can write it with better business context than you have. If what you bring is turning tickets into pull requests, you're competing with both, and you're the one with less context. Writing code is no longer a differentiator; it's table stakes.

That's particularly uncomfortable for junior engineers, because the traditional route to engineering expertise was years of writing code and getting it wrong. That route still exists, but it has to be walked much more deliberately: reading the incident reviews, asking why the guardrails exist, and working out why the review comment said "not like that, not here" rather than just fixing it.

## Redrawing the line

So the line between engineering and everything else hasn't disappeared. It's moved. Domain experts increasingly own the changes in their domain. Engineers increasingly own the things that don't show up in any single change: performance, architecture, reliability, and the guardrails that let everyone else work safely. And as Rich admits, he's been having something of an existential crisis about it too: it's not only engineers who are wondering what their job looks like in a year.

It moves the bottleneck, too. Rich makes the point himself: "Building stuff was never really the main issue. Building the right stuff was." When anyone can ship, it's easy to build faster than you can learn from users. I've argued before that you should [just build it, but not ship it](https://www.gregbeech.com/2025/05/16/just-build-it-but-dont-ship-it/), and that's truer now than ever. Building is cheap enough for anyone; the discipline is being brutally honest about what deserves to reach users.

None of that is a reason to stop people building, just a reason to be deliberate about who can merge what. The rule applies to everyone, engineer or not: you can merge without sign-off when you can carry the pager for what you've merged. What engineers are for now is making that a bar other people can actually clear.
