---
layout: post
title: Deliberate engineering
date: 2019-11-07
tags: [team health, software quality, deliberate engineering]
author: gregbeech
comments: true
---

When building a software project with a given scope there are three main constraints you can trade off: good, fast, and cheap. This is commonly known as the project management triangle. Focusing on one will have an effect on the others. For example, trying to do things cheap will adversely affect good and fast.

Cheap in this context uses salary as a proxy for the skill and experience levels of engineers. Don’t take it too literally as you may be paying over the odds for engineers, so cheap really means projects that are staffed by engineers lacking in skill and/or experience. It could also mean projects that are under-resourced, but that problem is much more obvious so we won't talk about it here.

The thing many people don't seem to realise is that you don't have a free choice with these constraints. Much like the CAP theorem only allows you to trade off between consistency and availability because network partitions are beyond your control, with software projects you can only really trade off between good and fast because cheap is largely defined by your company's hiring policy.

Some companies have such a poor hiring policy that they are unable to choose either good or fast because there simply is not the skill and experience available. Companies like this tend to have a lot of engineers who have been at the company less than two years; most of the rest have been at the company for over a decade and are just waiting for retirement. Their interviews are _ad hoc_ with no rubric and no hiring bar. This is, sadly, a large number of companies.

At the other end of the scale there are the companies who have relatively small but highly skilled teams who can choose both fast and good. These companies have a high proportion of senior engineers, including some that are well known in the industry, and low staff turnover rates. They have multi-stage interviews with standardised rubrics and a very high hiring bar. If you don’t know whether you work at one of these companies, then you probably don’t.

The remainder are somewhere in between. They have a relatively bottom-heavy pyramid of seniority with lots of junior/mid-level engineers and a much smaller number of seniors. They have structured interviews, but the rubrics may be absent or lacking and interviewers may not be calibrated, so the hiring bar is inconsistent. This group includes most startups and young companies.

This last group of companies is the most interesting. They have the choice between fast and good, but struggle to do both because the people who could do this are too thinly spread.

The trouble is, they often can’t do either fast or good.

## Why fast fails

Every company wants to deliver new features fast, because features are thought to be what drives sales, conversion, etc. and so getting them out in front of customers is the most important thing. When the pressure is on to go fast, people want to look and feel like they're going fast.

The majority of engineers appear to believe the fallacy that any activity other than writing code isn’t “real work” and is just ceremony that slows them down. This means when they want to feel like they're going fast they'll forgo--or merely pay lip service to--gathering requirements, writing design documents, doing research, and building proof-of-concepts to test and measure. Instead they jump straight into the code and start building.

They don't even realise that they're trading off good. They're getting peer review on the code and fixing up the issues pointed out there, they have good test coverage, and they may even be extracting reusable components. They feel like they're moving fast, and they feel like they're doing good quality work. In the first month or two it can be hard to tell a successful project from a doomed one.

Building software is a bit like building a house. We all know roughly what shape a house is, that it's built of bricks, and that it has windows and doors. If you were to start laying down bricks and putting in windows then fairly quickly you'll have something that starts to resemble a house. You might even convice yourself you'll be finished soon.

Then the rain comes and because you didn't build foundations one of the walls starts to subside and crack, and you need to spend time propping it up and repairing it. Then you realise you forgot to hook up the gas or water so you have to dig up the floor. Then you find out you've got two kitchens but no bathroom. Then you find out that the client wanted a chalet, not a house.

By forgoing the requirements and blueprints and foundations the house starts to take shape quickly, but finishing it off takes far longer than originally planned because it keeps needing to be re-engineered. The end result isn't quite what anybody wanted, and it keeps trying to fall over because it has no foundations.

I've lost count of the number of software projects I've seen run this way.

For any nontrivial software project, the faster you think you're starting, the slower you'll end up finishing. If you finish at all. As the estimates and timelines start to stretch and the priorities of the company evolve, the probability of projects getting cancelled increases significantly. The alternative is that hard deadlines get set and the project gets delivered, but is unreliable and unmaintainable, and consumes months of time after launch to support and re-engineer it.

You go fast to go slow.

## Go slow to go fast

If you want to go fast then you have to understand how to go fast, and as you've probably deduced by now, that means starting slowly.

Define the problem statement, the goals, and the non-goals so you can scope the project more tightly. Work out the minimal set of features you can cohesively deliver, which shortcuts make sense, and what tradeoffs you’re prepared to make in non-functional requirements like reliability, cost, or performance. Design the architecture and data model in a document and get feedback from people with experience in the domain and/or the technologies, to resolve potential problems before you've coded them.

These activities don't need to take long. For a relatively straightforward feature or service in a well understood domain using boring technologies you should be able to get the docs written and peer reviewed in a couple of days.

That's not to say you should timebox it to a couple of days though. For a new service I worked on recently, research, design and prototyping took a few weeks. It was a good job we did it though, because many of our initial hypotheses were invalidated in ways that wouldn't have become apparent until after it was live. It's much quicker to correct mistakes on (virtual) paper than it is in code.

Once you’ve done the preparation, you can deliver deliberately and fast. On any nontrivial project, starting slowly will mean you deliver faster than if you just dive in and start writing code.

This doesn't necessarily mean you'll end up with good software. If fast is the main priority, as it might be for features of uncertain long-term value, then you will make some design decisions that are not objectively good. For example using a data store with a high hosting cost to reduce implementation time, or omitting reliability features like retries or circuit breakers because downtime is an acceptable risk. What's important is that you considered these decisions, made them deliberately, and you know the future cost of making the software good, should that prove necessary.

On the flip side if your priority leans towards good, as it might for features that form the core of the business and which you know will need to be evolved over years, then deliberate engineering helps you to ensure that you meet your goals, and also gives you the best chance of delivering it fast.

---

In the next post in this series we'll take a look at why many teams use the "feels fast" approach instead of a deliberate approach, and why deliberate engineering is often mistaken for over-engineering.
