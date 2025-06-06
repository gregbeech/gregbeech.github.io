---
layout: post
title: The monolith rules, introduction
date: 2025-06-06
tags: [monoliths, rails, django, ruby, python]
author: gregbeech
comments: true
---

Over the last couple of decades I've spent a lot of time building monoliths, followed shortly after by leading the effort to move away from those monoliths. That might lead you to believe I don’t like monoliths, but I do: The monolith rules! Sadly the reality is the practices used to build the monoliths meant they tended to reach a state where they could no longer be reasonably maintained or evolved, and it's often safer and more efficient to rebuild externally and migrate than to rebuild in-place.

Rebuilding—--at least as a single big effort—--is _The Thing You Should Never Do_ for myriad reasons, the biggest of which is all the time you’re doing it your product stagnates and your competitive advantage slips away, possibly to nothing. I've had to make the decision to rebuild once at a billion dollar company, and it wasn't one I took lightly, but it really seemed to be the only option to let the company progress. Was it the right decision? I'll never know for sure, but the company made it to profitability off the back of the new platform, so it at least appears to have been _right enough_.

However, I should never have been in the position where I had to make that decision, and you don't want to be in that position either. You never will if you build your monolith well, or at least well enough that you can continue to maintain and evolve it indefinitely, while catering for the possibility you may want to replace or extract parts of it later. 

So what do I mean by “well enough”? It’s not as straightforward as it sounds, which is why I’m turning this into a series of posts about rules for monoliths. Yes, the title has a clever double meaning. I’ll publish them roughly in order of importance, though honestly it'll mostly depend on what I feel like writing next.

Follow these rules and you'll find your monolith serves you well for many years to come. Maybe for the lifetime of your company. None of them will cost you much time in the short term, but each of them will save you huge amounts of time in the future. 

That said, if you’re building a monolith it’s pretty likely you’re working at a startup. I’ve spent most of my career working in high growth startups and I’m all too aware even a bit more time in the short term might be too much more time. So treat these more like guidelines than actual rules, and give them more weight for your core functionality than peripheral or experimental features.

I’ll be illustrating the points with specific reference to Rails and Django because they’re the monolithic frameworks I know well and have used for years, but they apply to any monolithic application, even if it's not exactly _Rails-like_ or _Django-like_.

Check back soon for the first rule. I think it'll surprise you.
