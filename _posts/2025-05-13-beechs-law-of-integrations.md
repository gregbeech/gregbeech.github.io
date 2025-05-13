---
layout: post
title: Beech's Law of Integrations
date: 2025-05-13
tags: [planning, software engineering, integrations]
author: gregbeech
comments: true
---

I've spent a lot of the last two-plus decades integrating systems, whether that was the goal of the project itself, or just a necessary part of a larger project. Integrations always take longer than you think, even when you take into account [Hofstadter's Law](https://en.wikipedia.org/wiki/Hofstadter%27s_law). However, in this time I've observed the amount of additional time they take is surprisingly predictable, leading to Beech's Law:

> Any integration will take as long as your worst possible estimate, multiplied by three.

Estimates are largely nonsense anyway, but specifically for integrations you haven't fully considered the impact of the documentation being outdated or wrong, asking questions, waiting for answers, first-time authentication, data mapping being incorrect, mandatory fields missing, fields having invalid data types or values, errors not working as you expect, retries, idempotency, downtime, rate limiting, monitoring, metrics, and so on. These will require myriad production fixes of both code and data, extending the expected timeline by, oh, about three times.

Integration estimates---even the worst case ones---tend to be based on writing the code and assuming it'll all work basically fine. It won't.

You've all been there. You look at the specs, give a hand-waving estimate of two or three days, maybe four worst case, and two weeks later you're still dealing with those last few edge cases that still just don't quite work. A month estimate? See you in a quarter.

This isn't necessarily all working time, it's _elapsed_ time, so you may not be spending all of your days dedicated to the integration. However, it'll keep coming up with issues that are typically high priority and interrupting whatever else you're trying to get done until that three-times-worst-estimate period is over. Have enough integrations on the go, and all you've got is interruptions.

We didn't talk about updates yet either did we? About that... I've got a law you might want to consider.


