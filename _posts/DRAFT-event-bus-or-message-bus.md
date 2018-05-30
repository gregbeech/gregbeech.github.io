---
layout: post
title: Event bus or message bus
date: 2018-05-30
tags: career languages go
author: gregbeech
comments: true
---




- Custom publishing frontend (good with bad api)
- Custom backend (bad, should use SMS/SQS)

Pros

- Nonrepudiation
- Selective sending (kinda)
- No lost updates/deletes problem
- Easy to 'spider' to fetch related data
- Content type negotiation for versioning

Cons

- Run your own infra isn't great; most people didn't want to know it
- Producer must model state changes

Issues we had

- Use of URLs as identifiers (URLs do change)
- Poor entity design (e.g. order/items)
- Poor attention to caching
- Receiving via HTTP doesn't work for scaling (not processed inline)




