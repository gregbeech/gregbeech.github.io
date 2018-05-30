---
layout: post
title: Lessons from Routemaster
date: 2018-05-30
tags: events kafka rest routemaster
author: gregbeech
comments: true
---

One of the more controversial aspects of Deliveroo's distributed system architecture over the last couple of years has been [Routemaster](https://github.com/deliveroo/routemaster), a homegrown event bus that allows CRUD notifications, encourages HATEOAS, and discourages payloads. There are a lot of people at Deliveroo who subscribe to the philosophy "Routemaster is bad" and are happy to end their train of thought there. That's a silly attitude, because very few things are truly bad, and even when they are you can (and should) learn from them.

## What is Routemaster?

You're probably not familiar with Routemaster unless you work at Deliveroo, and even then you might not be, so here's a very quick summary. Routemaster is a HTTP event bus backed by Redis. You publish events by posting JSON to an HTTP endpoint with the following fields:

- `type`: one of `create`, `update`, `delete` or `noop`
- `topic`: the pluralised entity name, e.g. `customers`, `orders`
- `url`: the callback URL with data about the event
- `data` (optional, discouraged): the payload of the event

Consumers receive events by registering a callback URL and the topics they're interested in, and then events will be posted to that URL in batches as JSON. The service returns 2xx to indicate the events have been handled, or any other status to have them retried with backoff.

That's pretty much all there is to it. There's Basic authentication on the endpoints and a bunch of counters so you can monitor latency, failing subscribers, and so on. The whole thing clocks in at only 2500 lines of code; it's tiny.

## The Good

### No lost deletes

One of the main benefits of sending an event with just a type and a callback URL is that message ordering becomes largely a non-issue. It's essentially impossible to have a high-performance low-latency bus that guarantees in-order delivery, even if you can define what in-order means, which means that delete messages can overtake create messages.

With a traditional message bus this can lead to phantom entities. If the client sees the delete message and discards it because it doesn't have an entity with that identifier, then it may receive the create message and act on it. When using a message bus you need to be much more careful with deletes to ensure this doesn't happen, e.g. using soft deletion to mark entities that you haven't yet seen as already deleted.

With Routemaster however, even if the create message is received long after the delete, when the call is made to the URL it'll return `404 Not Found` or `410 Gone` so the client is at no risk of creating a phantom entity and can just ensure the entity is deleted.

### No partial updates

A common pattern with traditional message buses is to use partial updates, e.g. "restaurant 123 opened" which updates just a part of the state of that restaurant. However, when you combine this with out-or-order delivery it's possible to lose updates, e.g. if a restaurant closes by accident and then reopens immediately, the opened message might overtake the closed one and the restaurant ends up closed.

Message buses need care to mitigate this kind of thing. You might think of using versioning on the entity so that the closed message would be discarded as it has a higher version number, but it's not that simple as versioning only works within causal timelines; you wouldn't want a phone number changed message preventing an opened or closed message from being processed.

With Routemaster you just get a "restaurant 123 was updated" notification and then get the latest state so you can decide what to do based on that. There's no need to worry about ordering or causality.

### Nonrepudiation

all eggs in one basket, only the sending API controls access

### Selective sending (kind of)

only those authorised can see it







- Custom publishing frontend (good with bad api)
- Custom backend (bad, should use SMS/SQS)

Pros

- Easy to 'spider' to fetch related data
- Content type negotiation for versioning

Cons

- Run your own infra isn't great; most people didn't want to know it
- Producer must model state changes
- Delete with ID and 404

Things people think are cons

- No replay (versioning, not from zero, multiple streams)

Issues we had

- Use of URLs as identifiers (URLs do change)
- Poor entity design (e.g. order/items)
- Poor attention to caching
- Receiving via HTTP doesn't work for scaling (not processed inline)
- Bad patterns encouraged by client library (cache as data store)

## Takeaways

- Good choice for inexperienced developers
- Should have used SQS/SMS as backend (automation?)
- Should not have had URL=ID and cache=datastore




