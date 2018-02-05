---
layout: post
title: Optimising session key storage in Redis
date: 2016-10-07
tags: deliveroo performance redis
author: gregbeech
---

Tracking authenticated user sessions can be implemented in Redis using `setex` with some serialised JSON. It works pretty well until you have to cope with millions, or even tens of millions of sessions where the memory usage and performance can suffer. By using Redis data structures more effectively we can achieve a 70% reduction in memory usage, at the cost of both code and conceptual complexity. Is it worth it?

[Read the full post on the Deliveroo Engineering blog](https://deliveroo.engineering/2016/10/07/optimising-session-key-storage.html)
{:.lead}

