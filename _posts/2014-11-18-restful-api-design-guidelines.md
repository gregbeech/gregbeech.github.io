---
layout: post
title: RESTful API design guidelines
date: 2015-01-28
tags: rest http guidelines
author: gregbeech
comments: true
---

We spend a lot of time designing RESTful APIs and discussing different patterns and paradigms. Contrary to popular opinion designing RESTful APIs is actually pretty difficult, so I thought I'd share some of the decisions we've made. You might not agree with everything, but I've included some discussion around the points so you can at least see why we think it's the right thing to do.

## Resource orientation

I'm going to start with this because it's the most important section. It includes details that are covered in more depth in the rest of the post, so if there's anything you're not sure about don't worry; it'll be covered later.

One of the key features of RESTful APIs is that they are resource-oriented. That is, you deal with resources rather than RPC-style requests and responses. The basic rules are:

- URLs are nouns identifying resources
- Verbs indicate the actions that are taken on the resource
- URLs accept and return payloads of the type of resource they identify

This last point is critical. You should not have `XxxRequest` and `XxxResponse` entities in REST as these are RPC concepts; you should only deal in entities.

As an example, here's the outline of a simple bookmarks API:

- `POST /my/bookmarks` creates a bookmark and takes a `Bookmark` resource in the entity-body. If it returns an entity-body it must return a complete `Bookmark` resource.
- `GET /my/bookmarks` gets a list of `Bookmark` resources.
- `GET /my/bookmarks/:id` gets an individual `Bookmark` resource.
- `PATCH /my/bookmarks/:id` updates a bookmark and takes a `Bookmark` resource in then entity-body. If it returns an entity-body it must return a complete `Bookmark` resource.
- `DELETE /my/bookmarks/:id` deletes a bookmark and returns no entity-body.

Note that the only resource in the entire API is a `Bookmark`, and this is the only thing found in any entity-body. The exception to this is in error cases (i.e. status codes >= 400) where it is more appropriate to return an `Error` resource in the body, if any body is returned.

Typically some of the fields on a bookmark will be read-only (set by the server) for example the resource identifier and creation date, so these would not be sent by the client on creation. Often other fields which may be set on creation will be read-only after the resource is created; in the example above it might not be valid to change the bookmark type after creation.

When writing code to implement this, it can be tricky to use a single class to handle these three cases, so it might be appropriate to define three _internal_ representations which map to a single Bookmark resource externally:

- `class NewBookmark` represents a bookmark being created
- `class Bookmark` represents a full, created, bookmark
- `class BookmarkUpdates` represents updates to a bookmark

However, this is an implementation detail and from the point of view of the API there is one single resource type, `Bookmark`.

## Verbs

The HTTP verbs always seem to cause some confusion, so for the sake of avoidance of doubt the most common usages for the most common verbs are:

* `GET` gets a resource
* `POST` appends an item to a list resource
* `PUT` (to a non-existent path) creates a new resource at that path
* `PUT` (to an existing path) completely replaces the resource at that path
* `PATCH` updates the resource at the path
* `DELETE` deletes the resource at the path

Unless there's a good reason not to, `POST`, `PUT` and `PATCH` should return the created or updated resource in the response to ensure that clients don't have to `GET` it immediately afterwards to see the results. We'll look at these verbs in more depth later when we consider creating and updating resources.

It's all too easy to abuse the `POST` verb and use it for purposes other than appending to a list. While this is _occasionally_ valid, more often than not it means you haven't put enough thought into your resource design and you should consider whether there's a cleaner and more resource-oriented way to achieve what you're trying to do.

## URLs

If URLs refer to list resources then they should be pluralised, e.g. `/books` is a list of books and then `/books/9780297859406` is a book with a specific ISBN. If they refer to a singleton resource then they should be singular, for example `/users/123/accountcredit` is the only account credit resource for user 123.

When URLs are hierarchical then they should make semantic sense, and each path segment should be a sub-resource of the resource identified by the preceding path. In the account credit case above, the account credit resource is a sub-resource of the user 123, who is themselves a sub-resource of the complete list of users.

With user-specific URLs we also have a convention which is that `/my` can be used as a synonym for `/users/{currentId}` so that rather than having to use `/users/123/accountcredit` clients can just use `/my/accountcredit` which makes things a little easier for them.

## Parameter locations

Should a parameter be in the path or the query? Consider an endpoint that gets a user's credit cards; possible URLs might be:

```
/creditcards?userId=123
/users/123/creditcards
```

My rule is that `GET` requests should work without query parameters, as if the parameter is required then it is necessarily part of the resource identifier. In this case we wouldn't want `GET /creditcards` to work because listing all credit cards in the system is something of a security risk, so the user identifier should be in the path as the resource is a specific user's credit cards.

Conversely, an endpoint which could list books and optionally filter them by category should have the category identifier as a query parameter because you'd expect both to work, i.e.

```
GET /books                  // gets all the books
GET /books?categoryId=123   // gets all the books in category 123
```

Sometimes it can be difficult to work out whether a filter should be a parameter or a sub-resource. One example of this is in our library where you can archive books you don't want to see again, this could be represented as either of the following:

```
/users/123/library?status=Archived
/users/123/library/archive
```

Both of these are valid but we chose the latter because archived books should normally not be returned, so it makes sense to move the concept of archived status away from the main library endpoint. In addition the query parameter could be confusing because it would have to have a default of `Unarchived` to ensure that archived books are not returned, whereas the usual default for filter parameters is unspecified.

## Lists

There are a number of different ways of representing lists. The most basic is an array, i.e.

```json
[
  { "isbn": "9780297859406" },
  { "isbn": "9781447252566" }
]
```

This is the most lightweight approach in terms of bytes on the wire, but has a major disadvantage that you cannot associate any metadata with the list itself such as whether there are more pages of results. As such, for lists we return an object with an `items` field, meaning you can insert metadata related to the list, e.g.

```json
{
  "lastPage": false,
  "items": [
    { "isbn": "9780297859406" },
    { "isbn": "9781447252566" }
  ]
}
```

We try to avoid heterogenous lists (ones that contain multiple types of resource) as these are harder for clients to work with, but sometimes it's unavoidable such as when returning search suggestions which could be a book, an author, etc. In this case we use a discriminator field `type` so that clients can differentiate between the resource types:

```json
{
  "items": [
    { "type": "Book", "isbn": "9780297859406" },
    { "type": "Author", "id": "1726" }
  ]
}
```

All lists are pageable using `offset` and `count` parameters, where `offset` is the zero-based index at which to start returning results, and `count` is the maximum number of results to return. We prefer not to return the total number of results available (e.g. to allow things like "Page 1 of 23" in the client) because it makes queries harder to optimise and this kind of paged design is somewhat old-fashioned meaning clients have little need for it. Instead we return a `nextPage` flag which indicates whether there are more results.

It's generally a good idea to have a default page size and a maximum page size to avoid the situation where you return thousands of results because either somebody forgot to specify a page size or they decided that getting thousands of results at a time was sensible. Whatever these limits are I suggest you make them consistent across all API endpoints to avoid confusion, except in the rare occasion where there's a good reason to have them deviate.

## Creating resources

The most common approach to creating an resource is to `POST` the resource body to the list that it's part of; it's rare that something which can be created isn't part of a list. The response is generally `201 Created` with a `Location` header indicating where the new resource was created, and the created resource in the response body. For example, the request to create a bookmark for a user might be something like:

```
POST /users/123/bookmarks
// headers elided for clarity

{
  "isbn": "9780297859406",
  "cfi": "epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/1:0)"
}
```

With a response like:

```
HTTP/1.1 201 Created
Location: https://api.blinkboxbooks.com/users/123/bookmarks/37462
// other headers elided for clarity

{
  "id": "37462",
  "isbn": "9780297859406",
  "cfi": "epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/1:0)"
}
```

Sometimes resource creation can be more complex than this though; one situation is when the list is heterogeneous. A recent example we had was an admin API for crediting or debiting an account, where one option would have been to send the credit or debit with a type discriminator to the list endpoint, e.g.

```
POST /users/123/accountcredit
// headers elided for clarity

{
  "type": "debit",
  "amount": { "currency": "GBP", "value": 4.99 }
}
```

This would be completely valid as a design. However, as for this particular endpoint it's really important that you create the right type of resource (as the effects on a user's balance need to be taken pretty seriously) we decided to separate out the endpoints into separate `/credits` and `/debits` endpoints, making the request like this:

```
POST /users/123/accountcredit/debits
// headers elided for clarity

{
  "amount": { "currency": "GBP", "value": 4.99 }
}
```

Another more complex situation is where resource creation takes a long time. An example of this is in our storage service where the resource is a file such as an image or epub, which is uploaded to a number of cloud storage providers. In this case if the service cannot complete the upload synchronously it should return `202 Accepted` and give the caller a means of checking when the action has been completed; the `Location` header would be a good way of doing this if applicable.

Occasionally it might be appropriate for a client to specify the URL that it wants the resource created at, in which case you should use `PUT` to the individual resource URL rather than `POST` to the list URL. It's _incredibly_ rare that you'd want a client to be able to specify the identifier of a resource so I'd normally advise against doing it. However, this is a valid approach if you have a situation where it makes sense, for example if you're building a Dropbox-like service where the client should be able to specify the path and name of the file.

## Updating resources

This is something many people get wrong, so I'll reiterate the semantics of the verbs used for updating resources:

* `PUT` (to an existing path) completely replaces the resource at that path
* `PATCH` updates the resource at the path

In other words, if you're updating the resource then you almost certainly should be using `PATCH` rather than `PUT` if you want to be semantically correct. However, there are a couple of reasons why you might not want to be. Firstly, even though `PATCH` was fully defined nearly five years ago, support for it in proxies and CDNs is still a little patchy (see what I did there?) whereas `PUT` is universally supported, so if you're concerned about compatibility at all costs then `PUT` might be safer. Secondly, numerous web frameworks still don't support `PATCH` which could make it impossible to develop unless you're willing to move to a more modern framework.

Because it's rare to have both `PUT` and `PATCH` verbs supported on the same endpoint it probably doesn't matter which one you use as long as you're consistent about it and you understand why you're doing it. We use `PATCH` because we only support HTTPS which means we don't need to worry about the behaviour of arbitrary internet proxies.

The next question is what should your `PATCH` body contain? You might have seen [RFC 6902][1] which describes an operation-based approach to updating resources, with a body something like this:

```json
[
  { "op": "test", "path": "/a/b/c", "value": "foo" },
  { "op": "remove", "path": "/a/b/c" },
  { "op": "add", "path": "/a/b/c", "value": ["foo", "bar"] },
  { "op": "replace", "path": "/a/b/c", "value": 42 },
  { "op": "move", "from": "/a/b/c", "path": "/a/b/d" },
  { "op": "copy", "from": "/a/b/d", "path": "/a/b/e" }
]
```

This approach is, in my opinion, overly-complex nonsense.

The `test` operation is redundant because HTTP already defines a way to perform optimistic concurrency control at an resource level with the `If-Match` or `If-Unmodified-Since` directives. You'd be much better off using those because trying to do concurrency control at a sub-resource level is likely to lead to logically inconsistent data.

The others are also redundant when faced with optimistic concurrency control because there's no need to specify operations to change parts of an resource: Just define what you want the new value to be and set it to that. The `add` operation for appending to lists within the resource might seem valid at first, but if your list is sufficiently large that you can't reasonably send the complete new list in the resource body then you've probably got your resource modelling wrong and this should be a sub-resource with its own `POST` operation to append to it.

So if you shouldn't do that, what should you do? Just keep it simple! Set the values you want to change to what you want them to be in the body. If you want a value removed, set it to `null`. For example, to change the `cfi` of the bookmark that we created earlier just send a body with a new one:

```
PATCH /users/123/bookmarks/37462
// headers elided for clarity

{
  "cfi": "epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/2/1:0)"
}
```

## Status codes

These are common status codes that we return for API requests, grouped by verb.

If authentication and authorisation is required then there are two more that could apply to any of the verbs, which are commonly confused:

- `401 Unauthorized` means that the server either doesn't know who you are or doesn't believe that you are who you claim to be. It must include a `WWW-Authenticate` header indicating how you can obtain/refresh/etc. the credentials to access the service. Re-authenticating may fix the situation
- `403 Forbidden` means that the server knows who you are and believes you do not have permission to perform the action you were trying to do. Re-authenticating will not fix the situation.

### GET

- `200 OK` - the request was successful
- `400 Bad Request` - the request was invalid (e.g. invalid parameters)
- `404 Not Found` - the resource does not exist
- `410 Gone` - the resource used to exist but doesn't any more and will not exist again; in general prefer `404 Not Found` to this code, but it may be useful in very specific cases

### POST, or PUT (to non-existent path for resource creation)

- `201 Created` - the resource has been created; the response must include a Location header
- `202 Accepted` - the resource will be created but hasn't been yet; the request should include a Location header
- `400 Bad Request` - the request was invalid (e.g. invalid body)
- `409 Conflict` - the resource already exists

You might find the `409 Conflict` code a bit unusual for resource creation as it's most commonly associated with conflicted updates. However, we found that trying to create sub-resources that already exist is such a common situation that it was worthy of its own status code; it's arguable that a situation where a sub-resource already exists is a symptom of the list resource being stale, and it is this that generates the conflict. I'm prepared to admit this _might_ be a minor abuse, but it's one we're generally happy with.

One thing I'll also mention is that it's not valid to return `404 Not Found` to a `POST` request unless you specifically mean that the list endpoint does not exist, which you probably don't. A common mistake I see here is when people are adding a pre-existing resource (e.g. a book) to another list (e.g. a wishlist) that people return `404 Not Found` to indicate that the referenced book does not exist; here you should return `400 Bad Request` instead.

### PUT (to an existing path for complete resource replacement)

- `200 OK` - the resource has been replaced and the server is returning the complete resource in the body
- `202 Accepted` - the resource will be replaced but it hasn't been yet
- `204 No Content` - the resource has been replaced and the server is not returning anything in the body
- `400 Bad Request` - the request was invalid (e.g. invalid body)
- `404 Not Found` - the resource does not exist
- `409 Conflict` - a conflicting modification has been made to the resource
- `410 Gone` - the resource used to exist but doesn't any more and will not exist again; in general prefer `404 Not Found` to this code, but it may be useful in very specific cases

### PATCH

- `200 OK` - the resource has been updated and the server is returning the complete resource in the body
- `202 Accepted` - the resource will be updated but it hasn't been yet
- `204 No Content` - the resource has been updated and the server is not returning anything in the body
- `400 Bad Request` - the request was invalid (e.g. invalid body)
- `404 Not Found` - the resource does not exist
- `409 Conflict` - a conflicting modification has been made to the resource
- `410 Gone` - the resource used to exist but doesn't any more and will not exist again; in general prefer `404 Not Found` to this code, but it may be useful in very specific cases

### DELETE

- `202 Accepted` - the resource will be deleted but it hasn't been yet
- `204 No Content` - the resource has been deleted and the server is not returning anything in the body
- `404 Not Found` - the resource did not exist; only use this if it matters that the resource did not exist, otherwise prefer `204 No Content` as the net result is that the resource does not exist which is what was desired
- `410 Gone` - the resource used to exist but doesn't any more and will not exist again; in general prefer either `204 No Content` or `404 Not Found` to this code, but it may be useful in very specific cases

## Error responses

Most of the time status codes are sufficient to work out what went wrong in an API call, but sometimes you need to return an additional sub-status code to differentiate between errors with the same HTTP status.

Another factor to consider with errors is that sometimes when debugging things you just want to paste a URL into a browser and see what the response is. If it's an error then it's a pain to inspect the status code as you need to open the developer console rather than just seeing it in the browser window.

Consequently, for all errors we return a JSON body with a status code and a helpful developer message such as:

```json
{
  "code": "InvalidParameter",
  "developerMessage": "The 'count' parameter must be greater than zero."
}
```

The `code` field is by default the description of the status code such as `BadRequest` or `NotFound`, although when a more specific error code is appropriate it can be substituted, as shown in the example above.

We use the name `developerMessage` for the text to make it clear that this is only for development and must not be relied on in client code -- pattern matching on error strings is not a good practice! The distinctive name also makes it easy to scan the codebase for clients who _are_ using the field so that their developers can be reeducated.

## Data types

### Dates

There's always some debate about date formats in JSON. We use two different ones depending on whether the date means a specific point in time (e.g. the date/time a user purchased a book) or a non-specific day (e.g. the day a book was published).

For specific datetimes we use `yyyy-MM-dd'T'HH:mm:ss'Z'`, e.g. `2014-11-21T09:23:46Z` which is _always_ UTC to avoid any confusion with time zones. For non-specific dates we use `yyyy-MM-dd`, e.g. `2014-11-21`.

One reason we don't use the specific datetime format for non-specific days is that it can result in incorrect display due to time zone corrections. For example, if you return `2014-11-21T00:00:00Z` then in BST it can be automatically converted to `2014-11-20T23:00:00+0100` by client libraries and accidentally display the previous day when the time portion is removed.

### Money

How to represent money is also often controversial. The usual source of this debate is that people distrust floating point numbers in JSON because they know Javascript only supports binary floating point rather than decimal floating point, and thus believe it is safer to return an integer number of pence rather than the number of pounds.

The downside of this is that when you need to display the money it needs to be divided by a scale factor to convert it into the display unit, and this unit can vary by currency. This is inconvenient for services consuming the API, and means clients are required to perform financial calculations to display it which is generally undesirable.

The JSON specification doesn't actually define the binary representation of numbers; it's simply a number so it's up to clients to interpret it appropriately. As such, because we always interpret non-integer numbers in JSON as decimals for safety, we made the decision to use the primary currency unit and have floating point numbers in the representation, e.g. £13.37 would be:

```json
{ "currency": "GBP", "value": 13.37 }
```

You don't have to include the currency code if you're sure you'll only ever accept one currency. If you suspect you might use other currencies in future then it doesn't hurt to put it in there for forwards-compatibility.

## Versioning

I left this until the end because it's probably the most controversial subject in the whole post and I didn't want you to stop reading if you disagreed with it.

There are three common ways to version APIs:

1. In the path, e.g. `/v2/books`
2. In the query, e.g. `/books?version=2`
3. In the media type, e.g. `Accept: application/vnd.blinkbox.books.v2+json`

The first approach isn't semantically correct. URLs in REST are supposed to uniquely identify resources (the books themselves) rather than representations (how they appear on the wire), but this approach identifies the representation rather than the resource. This can clearly be seen because if you change a single book resource it would change the response from `/vN/books` for all `N`, meaning you have a many-to-one mapping of URLs to a resource.

The same is true for the second approach, as according to [RFC 3986][2] § 3.4:

> The query component contains non-hierarchical data that, along with data in the path component (Section 3.3), serves to identify a resource within the scope of the URI's scheme and naming authority (if any).

In other words, your query is part of the resource identifier so having a `version` parameter means you're identifying a different resource, when you're only intending to return a different representation.

The third approach is semantically correct. You have a resource identified by the URL and return a different representation based on the standard HTTP content type negotiation mechanism. Therefore, you should always use this approach, right?

Well, it's not quite as simple as that unfortunately.

RESTful API design is _hard_ which means you're going to get things wrong, and that quite likely includes your resource modelling and thus your URL space. Another thing is that requirements change over time and what was once right may be unsuitable for the future. If your resource modelling is sufficiently wrong or obsolete then it may be infeasible to reuse the same URL space for the new resource model, necessitating an approach like #1 with either a slug in the path or even a different subdomain to entirely separate the APIs.

We used approach #1 to change the URL space of our v2 API (on which this post is based) because we made a lot of mistakes in the v1 API, for a number of reasons such as developing under severe time pressure and having a team relatively new to REST. It's nothing to be ashamed of; it's just a fact of life. We're hoping the v2 API has a cleaner URL space so we can version that using approach #3, but who knows what the future will hold.

Don't forget if you're using approach #3 that you'll need to add a `Vary: Accept` header to the response body for cache correctness.



[1]: https://tools.ietf.org/html/rfc6902 "JavaScript Object Notation (JSON) Patch"
[2]: https://tools.ietf.org/html/rfc3986 "Uniform Resource Identifier (URI): Generic Syntax"