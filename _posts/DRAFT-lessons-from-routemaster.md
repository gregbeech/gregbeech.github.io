---
layout: post
title: Lessons from Routemaster
date: 2018-05-30
tags: events kafka rest routemaster
author: gregbeech
comments: true
---

One of the more controversial aspects of Deliveroo's distributed system architecture over the last couple of years has been [Routemaster](https://github.com/deliveroo/routemaster), a homegrown event bus that allows CRUD notifications, encourages HATEOAS, and discourages payloads. There are a lot of people at Deliveroo who subscribe to the philosophy "Routemaster is bad" and are happy to end their train of thought there. I find this attitude strange because very few things are truly bad, and even when they are you can (and should) learn from them.

This post covers both Routemaster and the way we use it. I don't think there's much point in making a distinction because it's such a niche product that the way we use it _is_ effectively canonical.

## What is Routemaster?

You're probably not familiar with Routemaster unless you work at Deliveroo, and even then you might not be, so here's a very quick summary. Routemaster is a HTTP event bus backed by Redis. You publish events by posting JSON to an HTTP endpoint with the following fields:

- `type`: one of `create`, `update`, `delete` or `noop`
- `topic`: the pluralised entity name, e.g. `customers`, `orders`
- `url`: the callback URL to obtain the entity data
- `data` (optional, discouraged): the payload of the event

Consumers receive events by registering a callback URL and the topics they're interested in, and then events will be posted to that URL in batches as JSON. The service returns 2xx to indicate the events have been handled, or any other status to have them retried with backoff.

That's pretty much all there is to it. There's Basic authentication on the endpoints and a bunch of counters so you can monitor latency, failing subscribers, and so on. The whole thing clocks in at only 2500 lines of code; it's tiny.

## The Good

### Custom frontend

Authn, authz, validation

### No lost deletes

One of the main benefits of sending an event with just a type and a callback URL is that message ordering becomes largely a non-issue. It's essentially impossible to have a high-performance low-latency bus that guarantees in-order delivery, even if you can define what in-order means, which means that delete messages can overtake create messages.

With a traditional message bus this can lead to phantom entities. If the client sees the delete message and discards it because it doesn't have an entity with that identifier, then it may receive the create message and act on it. When using a message bus you need to be much more careful with deletes to ensure this doesn't happen, e.g. using soft deletion to mark entities that you haven't yet seen as already deleted.

With Routemaster however, even if the create message is received long after the delete, when the call is made to the URL it'll return `404 Not Found` or `410 Gone` so the client is at no risk of creating a phantom entity and can just ensure the entity is deleted.

### No partial updates

A common pattern with traditional message buses is to use partial updates, e.g. "restaurant 123 opened" which updates just a part of the state of that restaurant. However, when you combine this with out-or-order delivery it's possible to lose updates, e.g. if a restaurant closes by accident and then reopens immediately, the opened message might overtake the closed one and parts of the system think it's closed.

Message buses need care to mitigate this kind of thing. You might think of using versioning on the entity so that the closed message would be discarded as it has a higher version number, but it's not that simple as versioning only works within causal timelines; you wouldn't want a phone number changed message preventing an opened or closed message from being processed.

With Routemaster you just get a "restaurant 123 was updated" notification and then get the latest state so you can decide what to do based on that. There's no need to worry about ordering or causality.

### Content type negotiation for versioning

Gradual upgrade to subsequent versions

### Easy to fetch related data

Good in a monolith, but also a bad thing

### Nonrepudiation

all eggs in one basket, only the sending API controls access

### Selective sending (kind of)

only those authorised can see it

## The Bad

### Custom backend

The custom backend kind of made sense a couple of years ago because we weren't using Docker locally and all our infrastructure was provisioned manually, so if we'd used custom queuing infrastructure like SQS/SMS then it would have been a huge pain to run locally and deploy to multiple environments.

Unfortunately as we've grown the custom backend has become more painful to manage. The original developer is no long around, and although it's small it uses manual threading and complex Redis structures which make it tricky to work on. Then there's the fact that, really, nobody wants to.

It would make much more sense nowadays to use an off-the-shelf backend like SQS/SMS and let somebody else worry about running/scaling it.

### HTTP push for consumers

The motivations for having a push rather than pull interface for consumers were that most services had HTTP endpoints so the receive would be easy to implement, and we would be able to autoscale the consumers based on our existing mechanisms for scaling inbound HTTP traffic.

In reality the scaling didn't work because a message batch can only be acknowledged as a whole, so rather than processing the messages on receive they got stashed in a job engine like Sidekiq, the batch was acknowledged, and the messages were processed individually by worker nodes. This meant the nodes that needed scaling weren't the ones handling the receives!

Where it gets even more silly is that in non-Ruby services which don't have Sidekiq the messages tended to get stashed in a private SQS queue and then processed from there by workers so we ended up converting the push model into a pull model in an _ad hoc_ way per service.

### Poor entity design

e.g. order/items

### Producers must model state changes

What if only the consumer cares? Not everyone can work on every codebase. Purism versus practicality.

## The Ugly

### Using URLs as identifiers

We took the HATEOAS and [cool URIs don't change](https://www.w3.org/Provider/Style/URI) thing a bit too far and used the URL of an entity as its identifier, e.g. rider 123's identifier would be something like `https://deliveroo.com/api/riders/123`. Unfortunately, particularly when you start decomposing services, URLs _do_ change.

Also the links thing gets bad here -- links to other services means many places to update.

### Insufficient attention to caching

Adds load to database, API calls slow, also Ruby isn't good at handling concurrent requests and IO is synchronous

### Cache as datastore in client library

terrible idea; compounded by URL as identifier

## Other Things

### No replay

Not clear whether this is a con. Replay is hard because the data needs to be old enough and you need to handle all versions. Also need to merge multiple streams in a way that may violate DB invariants unless you're careful.

## Takeaways

- Good choice for inexperienced developers
- Needed better entity design and caching
- Should have used SQS/SMS as backend (automation?)
- Should not have had URL=ID and cache=datastore




