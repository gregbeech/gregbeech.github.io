---
layout: post
title: The problem with ETags in RESTful APIs
date: 2015-04-04
tags: http caching concurrency
author: gregbeech
comments: true
---

Consider a collection of two addresses. #1 was updated at 11:20 and #2 was updated at 11:45. The last modified date of the collection can be the latest time that any individual address was modified. To make notation simpler I'll just include the time for the last modified date, and the etag will be the time as they're often derived from timestamps (you could hash the state or any other mechanism too; it won't alter this discussion).

These are the ways you could fetch the addresses, with the expected `Last-Modified` or `ETag` headers:

```
GET /addresses   -> Last-Modified: 11:45, ETag: "1145"
GET /addresses/1 -> Last-Modified: 11:20, ETag: "1120"
GET /addresses/2 -> Last-Modified: 11:45, ETag: "1145"
```

No surprises there. But now let's try some updates using `If-Match` or `If-Unmodified-Since` conditional request headers which facilitate optimistic concurrency, particularly useful in the modern world where state is heavily cached and users often have multiple devices. Assume we retrieved the list of addresses using `GET /addresses` and now want to update them.

Using modification dates everything works as we'd expect:

```
PATCH /addresses/1, If-Unmodified-Since: 11:45 -> 200 OK
PATCH /addresses/2, If-Unmodified-Since: 11:45 -> 200 OK
```

In either case the address has not been modified since we retrieved it so the condition is true. However if we use etags for the condition the results are a bit more surprising:

```
PATCH /addresses/1, If-Match: "1145" -> 412 Precondition Failed
PATCH /addresses/2, If-Match: "1145" -> 200 OK
```

Because etags use an equality comparison function rather than a range-based comparison like modification dates, the etag `"1145"` for address #1 does not match the expected `"1120"`, and so the address cannot be updated.

Let's try a different approach. What if we made the etag the same for _all_ address resources, so they'd all have the etag of the latest modified address?

```
GET /addresses   -> Last-Modified: 11:45, ETag: "1145"
GET /addresses/1 -> Last-Modified: 11:45, ETag: "1145"
GET /addresses/2 -> Last-Modified: 11:45, ETag: "1145"
```

That initially seems like a good solution as now it seems like both our `PATCH` requests above should just work. But the results might surprise you:

```
PATCH /addresses/1, If-Match: "1145" -> 200 OK
PATCH /addresses/2, If-Match: "1145" -> 412 Precondition Failed
```

Unfortunately now we've linked our resources to each other, so if we make an update to address #1 at 11:50 then the etag for all of the address resources will change to `"1150"` meaning that the second `PATCH` will fail because the previously 'known' etag for that resource has changed underneath us, even though the resource itself hasn't actually changed!

Bugger.

So why do we run into this mess? Does this mean etags are fundamentally broken? No, it's because our RESTful API isn't _really_ RESTful.

In true REST you cannot return lists of resources (i.e. you cannot return a list of addresses) you can only return a list of _links_ to addresses because the resource state must be retrievable from exactly one location. To fetch a list of addresses you'd have to make a request to the `/addresses` endpoint to get the links, and then to each of the individual links it returned (`/addresses/1`, `/addresses/2`) to get the state -- in other words true REST has the N+1 selects 'antipattern' codified into it.

Under this situation etags work fine because you only have one canonical location for the resource state and thus the etag for the address list changes only when addresses are added or removed but not when an address itself changes, so the etags are independent rather than co-dependent. However, we don't tend to do things this way because N+1 requests isn't great for performance, and the compromises we make for performance break the assumptions that etags are based on.

However, you'll notice that even when you break these assumptions, the range comparisons afforded by modification dates still work as you'd intuitively expect. There's a _bit_ of trickery on the client-side who has to know that it's valid to cascade a modification date from a collection to an individual resource, which is strictly a violation of the HTTP rules, but it's one that feels logical and reasonable.

You could most likely do some trickery with etags on the client-side too, by shuffling etags between resources (e.g. taking the response etag from an address update and applying to the collection) but I can't easily come up with a set of rules for doing this that would make sense in all cases, and I suspect that attempting to do this would lead to a significant number of hard-to-find bugs. Just use modification dates.

## Appendix

If you really want to be sure that modification dates will work, here's a fairly exhaustive set of scenarios using them. The starting point for each scenario is that you got a list of addresses. Each scenario is independent -- i.e. they all start from this starting point -- but multiple calls in each scenario are considered to be in sequence.

The one case you may notice where things aren't quite right is in the case where another client has deleted and address and then you get `412 Precondition Failed` when trying to add an address because the collection has changed, even though there can't possibly be a conflict between those two actions. It's not the end of the world. If it really bothers you, go and play with [CRDTs](https://en.wikipedia.org/wiki/Conflict-free_replicated_data_type).

### If nothing has changed

"I want to get the latest addresses"

    GET /addresses, If-Modified-Since: 11:45 -> 304 Not Modified

"I want to get a particular address"

    GET /addresses/1, If-Modified-Since: 11:45 -> 304 Not Modified
    GET /addresses/2, If-Modified-Since: 11:45 -> 304 Not Modified

"I want to add an address"

    POST /addresses, If-Unmodified-Since: 11:45 -> 201 Created

"I want to update my addresses"

    PATCH /addresses/1, If-Unmodified-Since: 11:45 -> 200 OK
    PATCH /addresses/2, If-Unmodified-Since: 11:45 -> 200 OK

"I want to delete my addresses"

    DELETE /addresses/1, If-Unmodified-Since: 11:45 -> 200 OK
    DELETE /addresses/2, If-Unmodified-Since: 11:45 -> 200 OK

### If another client added an address

"I want to get the latest addresses"

    GET /addresses, If-Modified-Since: 11:45 -> 200 OK

"I want to get a particular address"

    GET /addresses/1, If-Modified-Since: 11:45 -> 304 Not Modified
    GET /addresses/2, If-Modified-Since: 11:45 -> 304 Not Modified

"I want to add an address"

    POST /addresses, If-Unmodified-Since: 11:45 -> 412 Precondition Failed

"I want to update my addresses"

    PATCH /addresses/1, If-Unmodified-Since: 11:45 -> 200 OK
    PATCH /addresses/2, If-Unmodified-Since: 11:45 -> 200 OK

"I want to delete my addresses"

    DELETE /addresses/1, If-Unmodified-Since: 11:45 -> 200 OK
    DELETE /addresses/2, If-Unmodified-Since: 11:45 -> 200 OK

### If another client updated address #1

"I want to get the latest addresses"

    GET /addresses, If-Modified-Since: 11:45 -> 200 OK

"I want to get a particular address"

    GET /addresses/1, If-Modified-Since: 11:45 -> 200 OK
    GET /addresses/2, If-Modified-Since: 11:45 -> 304 Not Modified

"I want to add an address"

    POST /addresses, If-Unmodified-Since: 11:45 -> 412 Precondition Failed

"I want to update my addresses"

    PATCH /addresses/1, If-Unmodified-Since: 11:45 -> 412 Precondition Failed
    PATCH /addresses/2, If-Unmodified-Since: 11:45 -> 200 OK

"I want to delete my addresses"

    DELETE /addresses/1, If-Unmodified-Since: 11:45 -> 412 Precondition Failed
    DELETE /addresses/2, If-Unmodified-Since: 11:45 -> 200 OK

### If another client deleted address #1

"I want to get the latest addresses"

    GET /addresses, If-Modified-Since: 11:45 -> 200 OK

"I want to get a particular address"

    GET /addresses/1, If-Modified-Since: 11:45 -> 410 Gone
    GET /addresses/2, If-Modified-Since: 11:45 -> 304 Not Modified

"I want to add an address"

    POST /addresses, If-Unmodified-Since: 11:45 -> 412 Precondition Failed

"I want to update my addresses"

    PATCH /addresses/1, If-Unmodified-Since: 11:45 -> 410 Gone
    PATCH /addresses/2, If-Unmodified-Since: 11:45 -> 200 OK

"I want to delete my addresses"

    DELETE /addresses/1, If-Unmodified-Since: 11:45 -> 410 Gone
    DELETE /addresses/2, If-Unmodified-Since: 11:45 -> 200 OK