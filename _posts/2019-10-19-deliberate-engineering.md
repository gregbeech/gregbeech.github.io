---
layout: post
title: Deliberate engineering
date: 2019-10-19
tags: [deliberate engineering, project management]
author: gregbeech
comments: true
---

When building a software project with a given scope there are purported to be three main constraints you can trade off: good, fast, and cheap. This is commonly known as the project management triangle. Focusing on one will have an effect on the others. For example, trying to do things cheap will adversely affect good and fast.

Cheap in this context uses salary as a proxy for the skill and experience levels of engineers. But don’t take it too literally as you may be paying high salaries for sub-par engineers, so cheap really means projects that are staffed by engineers lacking in skill and/or experience. It could also mean projects that are under-staffed in number of engineers, but the problem there is much more obvious so we won't talk about it here.

The thing that a lot of people don't seem to realise is that you don't have a free choice between these constraints. Much like the CAP theorem only allows you to trade off between consistency and availability because network partitions are beyond your control, in software projects you can only really trade off between good and fast because cheap is already defined by your company's hiring policy.

Some companies have such a poor hiring policy that they are unable to choose either good or fast because there simply is not the skill and experience available. Companies like this tend to have a lot of engineers who have been at the company less than two years, and a lot who have been at the company for over a decade who are just waiting for retirement, with little in between. Their interviews are _ad hoc_ with no rubric and no hiring bar. They almost certainly use Java or C#. This is, sadly, a large number of companies.

At the other end of the scale there are the companies who have relatively small but highly skilled teams who can choose both fast and good. These companies have a high proportion of senior engineers, including a number of world class engineers that you follow on Twitter, and low staff turnover rates. They have multi-stage interviews with standardised rubrics and a very high hiring bar. They likely use a non-mainstream language like OCaml or Haskell. If you don’t know whether you work at one of these companies, then you probably don’t.

The remainder are somewhere in between. They have a relatively bottom-heavy pyramid of seniority with lots of junior/mid-level engineers and a much smaller number of seniors. They have structured interviews, but the rubrics may be absent or lacking and interviewers may not be calibrated, so the hiring bar is inconsistent. They're probably using one or more mainstream languages. If you care enough to be reading this post, there's a pretty good chance you work at a company like this.

This last group of companies is the most interesting. They have the choice between fast and good, but cannot do both because the people who could do this are too thinly spread.

The trouble is, they often can’t do either fast or good.

## Why fast fails

In pretty much every company the pressure is to deliver new features fast, because features are thought to be what drives sales, conversion, etc. and so getting them out in front of customers is the most important thing. When the pressure is on to go fast, people want to look and feel like they're going fast.

The majority of engineers appear to believe the fallacy that any activity other than writing code isn’t “real work” and is just unnecessary ceremony that slows them down. This means that when they want to feel like they're going fast they'll forgo--or just pay lip service to--writing specifications or design documents, doing research, and building proof-of-concepts to test and measure. Instead they jump straight into the code and start building.

They don't even realise that they're trading off good. They're getting peer review on the code and fixing up the issues pointed out there, they have good test coverage, and they may even be extracting reusable components. They feel like they're moving fast, and they feel like they're doing good quality work. In the first month or two it can be hard to tell a successful project from a doomed one.

Building software is a bit like building a house. We all know roughly what shape a house is, and that it's built of bricks, and that it has windows and doors. If you were to start laying down bricks and putting in windows then fairly quickly you'll have something that starts to resemble a house. You might even convice yourself you'll be finished soon.

Then the rain comes and because you didn't build foundations one of the walls starts to subside and crack, and you need to spend time propping it up and repairing it. Then you realise you forgot to hook up the gas or water so you have to dig up the floor. Then you find out you've got three kitchens but no bathroom. Then you find out that the client wanted a bungalow, not a house.

By forgoing the requirements and blueprints and foundations the house starts to take shape quickly, but finishing it off takes far longer than originally planned because it keeps needing to be re-engineered. The end result isn't quite what anybody wanted, and it keeps trying to fall over because it has no foundations.

Sound familiar?

For any nontrivial software project, the faster you think you're starting, the slower you'll end up finishing. If you finish at all. As the estimates and timelines start to stretch and the priorities of the company evolve, the probability of projects getting cancelled increases significantly. The alternative is that hard deadlines get set and the project gets delivered, but is unreliable and unmaintainable, and consumes months of time after launch to support and re-engineer it.

You go fast to go slow.

## Go slow to go fast

If you want to go fast then you have to be deliberate about being fast, and you have to understand how to go fast.

To go fast you need to start slowly. Defining the problem statement, the goals, and the non-goals so you can scope the project more tightly. Working out the minimal set of features you can cohesively deliver, which shortcuts make sense, and what tradeoffs you’re prepared to make in non-functional requirements like reliability, cost, or performance. Designing the architecture and data model in a document and getting feedback from people with experience in the domain and/or the technologies, to resolve potential problems before you've coded them.

These activities don't need to take long. For a relatively straightforward feature or service in a well understood domain using boring technologies you could get the docs written and peer reviewed in a day or two.

That's not to say you should timebox it to a day or two though. For one of the services I worked on recently, research and prototyping took a few weeks. It was a good job we did it though, because many of our initial hypotheses were invalidated and so if we'd have just started building we'd have had to either spend months trying to re-engineer the solution or cancel the project entirely. It's much quicker to correct mistakes on (virtual) paper than it is in code.

Once you’ve done that, you can deliver deliberately and fast. On any nontrivial project, starting slowly will end up being faster than diving in and writing code.

This doesn't necessarily mean you'll end up with good software. If fast is the only priority, as it might be for features of uncertain long-term value, then you will make some design decisions that are not good. For example using a data store with a high hosting cost to reduce implementation time, or omitting reliability features like retries or circuit breakers. What's important is that you considered these decisions, made them deliberately, and you know the future cost of making the software good, should that prove necessary.

On the flip side if your priority is towards writing good software, as it might be for features that form the core of the business and which you know will need to be evolved over years, then this approach does give you the highest chance of writing it fast.

## Fitter, happier, more productive

<< WIP >>

The way I've seen many teams work where the PM dictates requirements, designers dictate UX, developers decide on technical requirements, and EMs just talk about career paths and reviews are low performing and unhappy. These are the teams that tend to use the "feels fast" approach.

Starting a new project gives them a brief natural high while it seems to be working for the first month or two, because code is getting shipped and they're are seeing the first glimpse of new features. When it starts to break down and the schedules start to slip, and it raises alerts every day, it needs two engineers assigned to it for the next six months to support it... people don't worry. They think that's just how software projects are.

Deliberate engineering needs a major mental shift, and requires all disciplines to work together more closely and care about decisions that they may have previously seen as being somebody else's remit. For example, engineers need to care more about the product requirements, and product managers need to make decisions about non-functional requirements.

The rewards are worth it though. Teams are more cohesive, higher performing, much happier, and the speed and quality of output will surprise everybody. Trust me, I've worked in those teams, and they are the best times of my career.
