---
layout: post
title: Feature flags
date: 2020-11-02
tags: [reliability, deployment]
author: gregbeech
comments: true
---

Introducing feature flags helps to separate release from deployment, and allow changes to be partially rolled out on a percentage basis and/or to target groups of users. It cannot completely separate these two things as some changes such as database migrations are all or nothing. However, it can significantly reduce the risk of deployments.

The trouble with feature flags is that they sound so simple: They're just an on/off switch, right? Engineers tend to underestimate how much complexity there is in implementing them well, so they'll either spend too little time choosing an off-the-shelf system and later find out it won't scale with the company, or spend hundreds of engineering hours building it themselves (and probably still find out it won't scale with the company).

We've just rolled out [LaunchDarkly](https://launchdarkly.com/) at [Zego](https://www.zego.com/) after evaluating a number of open-source and SaaS offerings. This post contains the criteria we used to select a provider so we can be confident they'll scale with us. It's probably not an exhaustive list, but it'll give you a starting point.

There are some table stakes requirements like multiple environments (production, staging, development, etc.), targeting groups using attributes, partial rollout of flags, archiving flags, and client libraries for all your backend and frontend languages. Pretty much every feature flagging system will support these. However, there are a many nonobvious requirements that are also essential. 

## Must haves

- **In-memory evaluation (performance, reliability)** - It's likely that requests will pass through a number of feature flag gates during execution; network calls to evaluate features increase latency as even a couple of milliseconds for each of a number of feature flags adds up, and reduces reliability as those calls may fail or be slow.
- **Second-level persistent cache (reliability, startup time)** - When applications start they need to load feature flags, and going to the source takes time. There must be a second-level persistent cache (e.g. Redis, DynamoDB) that applications can load initial configuration from which improves startup time, means apps can start even if the SaaS service is down, and in emergencies lets you edit settings manually.
- **Rollout stickiness (sanity)** - When flags have a partial rollout it's essential that when given the same parameters the decision is the same each time, because a request may pass through a gate multiple times, or a view may make multiple requests, and the decision needs to be consistent otherwise vexing bugs will occur.
- **Rapid updating of flags (incident management)** - When we want to turn things off because they have gone wrong, being able to change the configuration quickly is important. Flags should be updated within, say, 30 seconds either by polling or event-driven (less is better).
- **Explaining why a result was returned (debugging)** - As feature flags and target groups get more complex, which they will, being able to see why a result was returned for a user is essential. This is even better if it can be done *before* the flag setting is changed (e.g. a UI that lets you see what the result would be for a given input).
- **History of changed flags (compliance, debugging)** - It's useful to be able to see who changed which flags, and may be important for some security cases. Bonus points if there's a feed of changes, ability to see changes in a time window, or publishing changes to places like Datadog. Extra bonus points if comments can be added to changes.
- **Don't send server-side flags to clients (competitive advantage)** - Feature flags are used to gate new features, so broadcasting your feature flags to clients (i.e. web UI or mobile) can be used by competitors to predict what features you will launch and reduce your advantage; it must be possible to share some but not all flags with clients.
- **Single-Sign On (security)** - Incomplete offboarding of people who have left a company is one of the biggest security risks, so the management tools should have SSO for users to ensure they are offboarded automatically. Even if you're not going to use it initially to save costs (SSO tends to be Enterprise Plan $$$) you will need it as you grow.

## Should haves

- **Partial updates (network)** - Over time it's likely you'll get to get to hundreds or even thousands of feature flags. If updates are loaded from a single file, as some services do, then this can cause significant network usage especially from clients or when not centralised. Ideally updates should only update the things that have changed.
- **Good documentation (ease of use)** - Growing companies onboard people frequently and if the documentation is bad then people won't read it and they'll make mistakes. It's not essential as they can learn from examples, but it really helps.
- **Target groups (ease of use)** - It's possible to create properties to represent target groups, e.g. whether they are an employee, but it can make configuration easier if it's possible to create target groups of common properties, and be able to target them. Bonus points for being able to combine Boolean logic on conditions and groups.

## Nice to haves

- **Tracking of result distribution (debugging)** - Being able to see a breakdown of feature flag results can make it easier to ensure that your rollout percentages and target groups are doing what you expect. This can be done manually with Datadog or similar but it'd be nice to have built-in.
- **Scheduled flags (ease of use)** - Turn features on or off on a schedule rather than having to do it manually. This can help when marketing or other teams want to launch at a particular date and time, especially if you're targeting users in Australia and you don't want to be up at 3am.
- **Flag groups (ease of use)** - Sometimes feature flags are related and a number of them can be used to control rollout or behaviours of larger features. Ideally flags should be able to be grouped or tagged or have some other way to organise them and find related flags.
- **Open source clients (debugging, bug fixing)** - The clients will inevitably have some bugs and so it's useful for them to be open source which will allow us to fork and patch them if necessary. This isn't essential as hopefully we won't need to do it.

The other flagging system we evaluated which met the requirements was [Split](https://split.io) but we went with LaunchDarkly because it's a bit nicer to use, the documentation is much clearer, and it has a number of small and even more nonobvious features which weren't part of our evaluation criteria but which are nice to have. I'd be happy to use it though. Everything else came up a long way short.
