---
layout: post
title: Things I believe about software engineering
date: 2020-01-27
tags: [software engineering]
author: gregbeech
comments: true
published: false
---

A collection of thoughts.




## Code

All code is technical debt because it never does what you will want it to in the future, needs ongoing maintenance and upgrades, and will be full of bugs. You should only write code when you are left with no other options.

Good static type systems are better than dynamic type systems. However, bad static type systems are worse. Any type system that does not differentiate between the presence or absence of a value is bad.

All functions should accept a single argument and return a single value. Compilers should deal with converting `(a, b) -> c` into `a -> b -> c` automatically. Multiple parameter lists are a barely acceptable substitute.

Subtype polymorphism is a poor alternative to _ad hoc_ polymorphism. Typeclasses are probably a poor alternative to something else that I either haven't heard of yet or hasn't been invented yet.

Large-scale mutability makes programs impossible to reason about. This applies doubly if it has any form of concurrency or parallelism. Mutability is just about acceptable if contained within a single, short, function.

Side effects make programs impossible to reason about. This applies an order of magnitude more if they are triggered by lifecycle hooks on mutable objects. Effects should be explicit, and ideally modelled using pure functions. This does not include logging.

Go is a bad language, and if you like it you are a bad person.

## System design

Domain-driven design is the only sensible way to approach business software. The thirty or so hours it takes to read the books is a right of passage you have to go through. Vomiting over the Enterprise Java code samples is optional, but recommended.

Conway's law is a law, not a guideline. This means teams must be structured based on the subdomain they work on, and by implication managers who do not understand at least the basics of domain-driven design cannot sensibly structure teams.

Amdahl's law also applies to development teams. Companies who ignore domain-driven design and/or Conway's law will find their development speed plateaus or even reduces. Because they don't understand why, they'll try and hire their way out of it.

If you have multiple services sharing the same database then they are not multiple services, they're a distributed monolith. Congratulations, you now have all the development speed of a distributed system, with all the reliability of a monolith.



## Processes and tools

Jira is inevitable, and isn't really that bad, so just accept it. This rule does not apply if it has been defiled by overzealous product managers to the point where new issues have 28 required fields and boards have 17 columns.

Confluence on the other hand is bad, and should only be used if you want to ensure any information there is at least two years out of date, and that updating it is always somebody else's responsibility.

Agile processes are mostly cargo-culted by people who use a capital "A" when writing agile. Unless you actually get benefits from estimation, standups, reviews, retros, etc. you should can them. If you don't get benefit from planning, you should can your product instead.






