---
layout: post
title: Lessons from Routemaster
date: 2018-06-13
tags: eventbus messagebus routemaster
author: gregbeech
comments: true
---

One of the more controversial aspects of Deliveroo's distributed system architecture over the last couple of years has been [Routemaster](https://github.com/deliveroo/routemaster), a homegrown event bus that allows CRUD notifications, encourages HATEOAS, and discourages payloads. We're in the process of replacing Routemaster with Kafka, so it's a good time for a retrospective in the timeless good/bad/ugly format.

This post covers Routemaster, the way we use it, and a whole bunch of history. I don't think there's much point in trying to make a distinction between the product itself and its usage at Deliveroo because as far as I'm aware we're the only people who actually use it, so it's much of a muchness.

## What is Routemaster?

You're probably not familiar with Routemaster unless you work at Deliveroo, and even then you might not be, so here's a very quick summary. Routemaster is a HTTP event bus backed by Redis. You publish events by posting JSON to an HTTP endpoint with the following fields:

- `type`: one of `create`, `update`, `delete` or `noop`
- `topic`: the pluralised entity name, e.g. `customers`, `orders`
- `url`: the callback URL to obtain the entity data
- `data` (optional, discouraged): the payload of the event

Consumers receive events by registering a callback URL and the topics they're interested in, and then events will be posted to that URL in batches as JSON. The service returns 2xx to indicate the events have been handled, or any other status to have them retried with backoff.

The format of the entity data should be [HAL](http://stateless.co/hal_specification.html). If the `data` element is provided it should be the same format the URL would have returned; its use is discouraged except for [value objects](https://en.wikipedia.org/wiki/Value_object) (our use case was rider locations).

That's pretty much all there is to it. There's Basic authentication on the endpoints and a bunch of counters so you can monitor latency, failing subscribers, and so on. The whole thing clocks in at only 2500 lines of code; it's tiny.

## The Good

### Custom frontend

Routemaster has a small HTTP/JSON API that allows publishers to manage topics and subscribe to events, as well as publish events. The API handles authentication and authorisation, as well as basic validation of things like events being valid. One of the most important validations it performs is that a topic is owned by a single publisher and no other publishers can write to it which prevents inadvertent topic pollution.

This basic API has worked well as it's very easy to understand and trivial to implement a client in any language. We're actually doing much the same thing for publishing to Kafka, to provide additional access control and ensure that only schema-valid messages are published.

### No lost deletes

One of the main benefits of sending an event with just a type and a callback URL is that message ordering becomes a non-issue. Total ordering in a distributed system is essentially impossible to define, and even partial ordering is unreliable unless you use things like [vector](https://en.wikipedia.org/wiki/Vector_clock) or [atomic](https://www.wired.com/2012/11/google-spanner-time/) clocks. You can use database timestamps in a single-master relational system, but as we increasingly use storage like Aurora and DynamoDB this isn't something you can rely on. This means you can end up in the situation where delete messages overtake create messages.

With a message bus this can lead to phantom entities. If the client sees the delete message and discards it because it doesn't have an entity with that identifier, it may subsequently receive the create message and act on it. When using a message bus you need to be much more careful with deletes to ensure this doesn't happen, e.g. using soft deletion to mark entities that you haven't yet seen as already deleted, or holding back the delete message until you've either seen a corresponding create.

With Routemaster's event-based approach, even if the create message is received long after the delete, when the call is made to the URL it'll return `404 Not Found` or `410 Gone` so the client is at no risk of creating a phantom entity and can just ensure the entity is deleted. Routemaster's `type` field is arguably unnecessary; you could treat every event as "something happened" and then base your action purely on the response from the API and whether you already have the data.

### No partial updates

A common pattern with message buses is to use partial updates, e.g. "restaurant 123 opened" which updates just a part of the state of that restaurant. However, when you combine this with out-of-order delivery it's possible to lose updates, e.g. if a restaurant closes by accident and then reopens immediately, the opened message might overtake the closed one and parts of the system think it's closed.

Message buses need care to mitigate this kind of thing. You might think of using versioning on the entity so that the closed message would be discarded as the opened one has a higher version number, but it's not that simple as versioning only works within causal timelines; you wouldn't want a menu changed message preventing an opened or closed message from being processed just because it happened to insert itself in the middle of the sequence.

With Routemaster you can only model notifications on complete entities, so you would get a "restaurant 123 was updated" notification and then get the latest state so you can decide what to do based on that and the last state you knew about. There's no need to worry about ordering or causality.

### Content type negotiation for versioning

It's a fact of life that requirements change with time, and message formats will need to change too as fields get added and removed. You can make a message bus more resilient to this by using something like protobuf instead of JSON which helps guarantee both forwards and backwards compatibility from a schema point of view, but it can't ensure logical compatibility.

If an app needs the value of a particular field and it got removed then protobuf will still see the message as schema-valid as all fields are optional, but the app will cease to function correctly. As such, removing fields from messages can be a slow and error-prone process with lots of manual checking with teams that they no longer need it, and actually removing it is a 'big bang' change which will break any app that was missed.

With Routemaster as the data is retrieved via a callback rather than sent in a payload, you can use content-type negotiation for versioning so apps can switch over gradually to the new version. You can monitor who is still using the old version easily, and even send warnings to the clients using the `Warning` HTTP header to tell them they need to upgrade (we never actually added logging of warning headers to the client library, but it was in the backlog).

## The Bad

### Custom backend

The custom backend kind of made sense a couple of years ago because we had fairly low message volumes, weren't using Docker locally, were running in Heroku, and all our infrastructure was provisioned manually. If we'd used off-the-shelf queuing infrastructure like SNS/SQS then it would have been a huge pain to run locally and difficult to deploy reliably to multiple environments.

The backend has been extremely reliable; I'm not sure of the exact figure but it's had something like 99.995% uptime since it was launched and only very occasional alerts which were normally related to misbehaving subscribers.

However, once we moved to infrastructure-as-code there just wasn't a good reason to keep using a custom messaging backend given there are so many off-the-shelf options. We should probably have moved to an SNS/SQS backend and let somebody else worry about running/scaling it.

### HTTP push for consumers

The motivations for having a push rather than pull interface for consumers were that most services had HTTP endpoints so the receive would be easy to implement, and we would be able to autoscale the consumers based on our existing mechanisms for scaling inbound HTTP traffic.

In reality the scaling didn't work because a message batch can only be acknowledged as a whole, so rather than processing the messages on receive they got stashed in a job engine like Sidekiq, the batch was acknowledged, and the messages were processed individually by worker nodes. This meant the nodes that needed scaling weren't the ones handling the receives!

Where it gets even more silly is that in non-Ruby services which don't have Sidekiq the messages tended to get stashed in a private SQS queue and then processed from there by workers so we ended up converting the push model into a pull model in an _ad hoc_ way per service.

### Poor entity design

When we started implementing the callback APIs for Routemaster we tried to implement a façade over the somewhat suboptimal domain model that had emerged through years of fast-paced development. For example, using synthetic entities to try and keep fields with similar lifetimes and change frequencies grouped, and only adding fields when there was a genuine need for them on the basis that it's easier to add fields than remove them.

Unfortunately in a growing company with fast-paced development you can't effectively police everything so the callback API model ended up just about as bad as the underlying one. For example, orders ended up with a status field which changed frequently and so meant the order call had to be cheap. Unfortunately people who needed the order often needed the items and that meant multiple calls as adding the items to the order would have made the call expensive.

Many people blame Routemaster for the chatty callback APIs and that it often needs many calls to reconstitute an entity's state. However, they're blaming the wrong thing: The real culprit here is people's lack of skill in domain modelling. I wish more people would read Eric Evans' [Domain-Driven Design](https://www.amazon.co.uk/Domain-Driven-Design-Tackling-Complexity-Software/dp/0321125215) and/or Vaughn Verne's [Implementing Domain-Driven Design](https://www.amazon.co.uk/Implementing-Domain-Driven-Design-Vaughn-Vernon/dp/0321834577).

However, message buses are more forgiving of poor entity design because you only generate the message once rather than having to handle callbacks, so it doesn't matter as much if producing the message is more expensive.

### Fetch model in synchronous languages

Ruby cannot handle lots of requests at once so you end up spending a lot of time blocking.

### Producers must model state changes

One of the obvious implications of Routemaster's callback design only giving you the latest state is that you don't see any of the intermediate states, and if they change quickly then you may miss them. For an example, an order might go from placed to paid to accepted quickly and consumers may miss the paid status.

For most consumers that isn't a problem, but for some it is. Now, if you follow pure DDD principles then the right thing to do is model the state changes themselves as entities and so each state change is individually addressable. However, if the producer doesn't care about transient states then it pushes a consumer requirement into a producer application, and if they're maintained by different teams this creates a conflict of interest.

Message buses are far superior here because each individual state change is pushed onto the bus and therefore consumers can produce a synthetic model of those state changes without the consumer having to worry about it.

## The Ugly

### Using URLs as identifiers

We took the HATEOAS and [cool URIs don't change](https://www.w3.org/Provider/Style/URI) thing a bit too far and used the URL of an entity as its identifier, e.g. rider 123's identifier would be something like `https://deliveroo.com/api/riders/123`. Unfortunately, particularly when you start decomposing services, URLs _do_ change.

Also the links thing gets bad here -- links to other services means many places to update.

### Insufficient attention to caching

Adds load to database, API calls slow, also Ruby isn't good at handling concurrent requests and IO is synchronous

### Cache as datastore in client library

terrible idea; compounded by URL as identifier

## The Unknown

### No replay

Not clear whether this is a con. Replay is hard because the data needs to be old enough and you need to handle all versions. Also need to merge multiple streams in a way that may violate DB invariants unless you're careful.

## Takeaways

- Good choice for inexperienced developers
- Needed better entity design and caching
- Should have used SQS/SMS as backend (automation?)
- Should not have had URL=ID and cache=datastore
- Kafka will solve some problems and create others; no silver bullet






