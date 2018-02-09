---
layout: post
title: Whither monorail
tags: scala
author: gregbeech
comments: true
---

Deliveroo's codebase started life as a Rails monolith, and until about a year ago that was what we worked on. Monoliths are a great way to bootstrap a company because they let you move _fast_, and much as I kinda loathe Rails it's really pretty good for getting stuff out the door.

But then you run into problems. The general purpose models and richly modelled relationships between them which allowed you to move so fast because fuck the Law of Demeter are _too_ general purpose and you're having to load 47 columns just to get the couple of attributes you care about which ain't great for performance.

You don't have any options when it comes to concurrency really. Sidekiq is about it in practical terms. Yeah I know you _can_ do it. Kind of. But when it comes to things like modelling, say, riders as singletons so that you can stream location events through them at high speed without the load/store overhead that then it's going to be much easier to implement with an actor model.

What's more, the solution has around half a million lines of tests and because they're all integration tests due to Rails' inability to abstract, well, anything, they take a while to run. Around three hours nowadays.

So you start doing what everyone else is doing and start breaking things out into services.


