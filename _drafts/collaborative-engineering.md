---
layout: post
title: Collaborative engineering
date: 2019-12-12
tags: [team health, software quality, deliberate engineering]
author: gregbeech
comments: true
published: false
---

Building a new software product or feature involves numerous disciplines, both from within and outside engineering. The speed of delivery, quality, and fitness for purpose depends on collaboration and good interactions between and within those disciplines. Let me tell you a story about one of the most collaborative, and consequently most successful, projects I have ever been a part of.

This isn't the post I was originally intending to write. I was going to write about the myriad uncollaborative and inconsiderate interactions I have seen over the years, and the devastating consequences of them. However, it is impossible to do so without reflecting badly on the people involved and hard to anonymise them sufficiently without losing the impact of the stories.

Perhaps focussing on the positive is better anyway. After all, that's the kind of environment most people prefer to work in.

## Inception

In a young but fast-growing food delivery company the monitoring of in-flight orders for problems is primitive. Agents scan the entire list of orders looking for problems such as no rider assigned or the order already being late, and attempt to resolve them using manual assignments, phoning restaurants, etc. This approach worked fine when there were few in-flight orders. However, as order volumes grow an increasing number of problems are missed until it is too late and the customer's experience is adversely affected.

Customer satisfaction being a key metric for the business because it reduces refunds and drives retention, a team is reassigned from their previous workstream to urgently look into improving the monitoring tools. The team consists of a researcher/designer, a product manager, a lead engineer, and three mid-level engineers.

The brief from management is to improve the monitoring tools, but there is no mandate for how this should be done. The team has complete agency to approach this problem in the way they see fit, including coming up with the metrics to measure progress towards the high-level goal.

## Research

The team brainstorms and realises they do not know what the actual problems are that need solving. The entire team gets involved with research including interviewing agents, shadowing the in-house agents, shadowing call-center agents, and even doing first line support shifts. They realise there are two linked problems:

1. In order monitoring---the target problem---a lot of time is spent scanning lists of orders for problems using heuristics, but effectiveness varies significantly based on the agent's tenure, intuition, and conscientiousness.
2. In call handling---a hitherto unrelated problem---agents spend a lot of time trying to work out what has actually happened to an order while the customer waits on the phone, increasing call duration and queuing times.

The engineering team works closely with the operations teams to develop a mutual understanding of the problems, and form relationships with the domain experts. This makes them less dependent on the product manager to resolve uncertainties during the development process, and helps to ensure that everybody involved is aligned.

## Proposition

The team presents their findings back to management and the operations team leads. They propose building a rule engine to implement the heuristics used by agents and surface a list of problems, so human time is spent on resolving them rather than finding them. Call handling is acknowledged as something that could benefit from this work, but the group decides that it will not be tackled initially as pre-empting problems that lead to calls is more important.

Rollout plans are discussed, and the decision made with the operations leads is to use a couple of the best agents to trial the new tool with a basic set of rules, give feedback on how to improve it, and get directional metrics as to whether it reduces the number of missed problems.

Even though nearly a month has passed since the team was given the brief, management has not pushed them into starting development prematurely and allowed them time to understand the problems. Key people from the business are in the room when decisions are being made, and will be actively involved in product feedback and measurement.

## Design

The team starts technical planning, including which rules should be included and any interactions between them, and how issues should be distributed between multiple users. This is done together on whiteboards and in documents as rule interactions and UX design have a significant effect on the technical requirements, and technical complexity may affect the product and design decisions.

In parallel the engineers build a prototype to determine whether it will be possible to use Ruby (the company's primary language) for the solution. Something like Akka Cluster would be more suitable as it will be consuming thousands of events per second and running stateful calculations, but only one team member is familar with Akka, and nobody has production experience running it clustered, so this is a trade-off to ship faster and more predictably.

The team recognises that product, design and engineering decisions all affect each other, and work together to find good compromises between them. Based on their technical abilities, the company's tech stack, and the product being of unproven long-term value, the engineers choose an approach which is not ideal but which will allow them to ship quickly and predictably and iterate. This is [deliberate engineering]({% post_url 2019-11-07-deliberate-engineering %}).

## etc.

> prototype, iterate, improve perf



> map and contention

map became a contentious point as PM did not believe in it but team did, quick prototype using MapBox to get a feel for value, PM realised the value, later convert to Google Maps




