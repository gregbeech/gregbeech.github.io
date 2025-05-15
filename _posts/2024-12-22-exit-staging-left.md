---
layout: post
title: Exit staging left
date: 2024-12-22
tags: [software engineering, deployment, testing, velocity]
author: gregbeech
comments: true
---

It's received wisdom in the startup world that you need to have a staging environment to test things out before going to production. In some cases, maybe even multiple staging environments with different names like preproduction or demo or QA, with different rules about how mature code has to be to go on there. However, I don't believe staging environments are worth the time, effort, and cost to keep running, so let's talk about why you should just deploy straight to production.

Building and maintaining staging environments takes time, whether it's setting up and maintaining the infrastructure, seeding and managing test data, or resetting the environment when it inevitably gets so much cruft on there it diverges too far from production. If you've got your infrastructure all configured in Terraform or whatever and automated reset scripts this might not be a huge amount of time, but it's still _time_.

Waiting for staging environments takes much more time. The amount of time I've spent over the years waiting for deploys to staging of code I already know works fine, and then running cursory checks "just to be sure" because "that's the process we follow" is shocking. Even if it's only ten minutes per PR that could be half an hour to an hour per day, and it's hard to use that time productively because you're distracted by the pending context switch back to check the deploy and get the PR merged for real.

Given a finite amount of time, staging environments are not the best place to spend it. There's nothing you can do on staging that can't be done better in either development, where you've got all your tools handy, or in production with real data and real users.

Testing code can be done well in a development environment. This is hopefully not shocking news, but you can write tests that test your code, which will give you--and others--more confidence it works as you expect, and let you evolve it safely in future. You can test _ad hoc_ in development, e.g. for UI changes where tests are hard to write and insufficient for ensuring things feel right. You can run the tests in CI to stop things deploying if you accidentally broke stuff.

Of course pre-production testing won't cover everything and that's why you need to spend more time on release practices. Deploy is not release. Use [feature flags](https://www.gregbeech.com/2020/11/02/feature-flags/), rollout groups, gradual rollout, A/B testing or MVT, etc. as needed to make sure your deployed changes are rolled out safely and have the effect you want. If you're not spending time on staging environments, you'll have more time and more motivation to get this right.

The argument that always comes up at this point is what about infrastructure changes? How can you be confident doing things like database upgrades or k8s upgrades or any of those scary things in production if you haven't done them in staging? Let me ask you a different question: How can you be confident doing it even if you have done it in staging, given staging is always different? You'd do things like create or upgrade read replicas first, or run on multiple production clusters so if one goes down you're still up. And guess what? If you're not spending time on maintaining staging, you'll have more time and motivation to do this too.

OK but what about integrations environments for customers? You're probably starting to get the idea now, but run them in your production environment too. You've hopefully already got ways of separating out metrics etc. so you don't count your own team in them, so just do that better and separate out integrations metrics too. If your mechanism for separating these things out is bad then by not having a staging environment you'll have more time and motivation to do this better. If you're worried about integrations interfering with real customers, you'll spend more time on isolation, rate limiting, etc.

Performance testing is usually the next argument. I usually find this to be whataboutism because (a) most companies don't actually _do_ performance testing, and (b) you can't do it on staging anyway unless it's identical to production--albeit with fewer replicas and so on--which it isn't because that's too expensive. Anyway, if you really do performance testing then you could possibly do it on production where you've already got a production-like dataset, using the capabilities you set up for infrastructure & integrations environments to separate infra & metrics. But maybe not, in which case I'd say fair enough spin up a performance environment for that as and when you need it. But that's not really staging.

We could go on but what I'm trying to get you thinking about is for every reason you could give to need a staging environment, there's usually another answer which lets you level up either your development or production environments instead. You know, the ones that actually matter. Before just defaulting to a staging environment, at least ask yourself whether you really need it, and what you could do better with the time you save by not having one.

I'll end by noting this isn't just a hypothetical post. We've built [Jitty](https://jitty.com/) for the last year without a staging environment simply by using good development and release practices. You can do it too.
