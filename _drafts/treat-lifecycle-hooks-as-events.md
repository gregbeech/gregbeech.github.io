---
layout: post
title: Treat lifecycle hooks as events
date: 2020-02-16
tags: [rails, django, domain-driven design]
author: gregbeech
comments: true
published: false
---

Lifecycle hooks should always be after the txn, and always asynchronous.
