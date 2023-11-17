---
layout: post
title: Ten simple rules for future-proof monoliths
date: 2023-10-12
tags: [monoliths, rails, django, ruby, python, ddd]
author: gregbeech
comments: true
---

A fair bit of my last two decades has been spent building in monoliths, followed shortly after by leading the effort to re-platform away from those same monoliths. That might make you think I don’t like monoliths, but the far more mundane reality is the practices used to build them meant they tended to reach a state where they could no longer be reasonably maintained or evolved, and it’s usually more efficient to rebuild externally and migrate than to rebuild in-place.

However, rebuilding—at least as a single big effort—is _The Thing You Never Want To Do_ because all the time you’re doing it your product stagnates and your competitive advantage slips away. What you really want to do is build your monolith well, or at least well enough that you can continue to maintain and evolve it indefinitely, while still catering for the possibility you may want to replace parts of it later.

If you follow these ten rules, ranked roughly from most to least important, then you should find your monolith serves you well for many years to come. None of them will cost you much time in the short term, but each of them will save you huge amounts of time in the future. 

That said, if you’re building a monolith it’s pretty likely you’re working at a startup. I’ve spent the last seventeen years working in high growth startups and I’m all too aware even a bit more time in the short term might be too much more time. So treat these more like guidelines than actual rules, and give them more weight for your core functionality than peripheral or experimental features.

I’ll be illustrating the points with specific reference to Rails and Django because they’re the monolithic frameworks I know well and have used for years, but they apply to any monolithic application, even if it's not "Rails-like".

## 1. Have fast build/test/deploy cycles

Monoliths seem to tend towards a painful state where setting up the application and its dependencies takes hours, running the tests locally takes an eternity, some of the tests won't run locally unless you spend another day or two finding the right incantations to get _those_ native dependencies to play nice, and then even though you've split your tests out into numerous parallel jobs in CI it still takes twenty minutes to check a pull request and another half hour or so to deploy.

Your cycle time to deploy even a small change goes to an hour plus, and you get nervous deploying because issues will be slow to fix, and rolling back can be risky or even impossible if you've made incompatible database changes. Say goodbye to productivity, and hello to everybody wanting to write things outside the monolith, even if only to get away from the horrendously slow cycle times.

More than anything else, slow tests, build and deploys will kill your monolith because they lead to nobody _wanting_ to work on it any more, and once that battle is lost, you've lost the war.

The biggest culprit by far tends to be the use of database entities in tests, so even web or controller tests need to have data set up, queried, and torn down. For tens of test suites this might not seem like a huge deal, but once you've got hundreds or even thousands of suites, it can be the difference between sixty seconds and sixty minutes for a full test run. Avoid hitting the database in tests unless you're specifically testing database interactions, or in a very limited set of full system tests.

As a heuristic, I'd suggest any time your builds or deploys get above two or three minutes, you should spend some time making them faster. Don't wait until they get to twenty or ten or even five minutes before you act, because by then you're already on the fated path.

## 2. Validate data rigorously

This might seem a surprising rule to have so high up, but there's a good reason for it. Bad data causes myriad problems because systems don't work as expected when supposed invariants are violated, for example when you've got users with invalid or unconfirmed email addresses, multiple users with the same phone number, or orders that were placed eight years in the future.

These problems usually have to be investigated by engineers on a case-by-case basis to find and fix the root cause, and then go back and fix up the data itself. If the data is from a source you can query this might just take engineering time. Unfortunately, it's often impossible to fix the data without either manual work or user intervention.

If you only apply _one_ rule from this list, make it this one. At least if you've got good data you can easily migrate it to the new services you had to build because you neglected your cycle times. (This isn't a hypothetical concern; rebuilt systems tend to have more rigorous data validation and I've seen poor data block migrations by many months.)

Rails makes adding validation to your models straightforward, and will run validations by default on the usual `create`, `update` and `save` methods, although it does have other methods which bypass validation which isn't great because it's easy for people new to Rails to use them without realising. Django really drops the ball though, because completely counter to any reasonable expectation it doesn't run validations when you save a model unless you explicitly override `save` to call `clean`. Which you should.

As a backstop for validations being accidentally not run, I'd recommend defining your tables as tightly as possible too with relevant non-null, unique, and length constraints. This helps to catch cases where your model validation isn't tight enough or has been bypassed.

## 3. Model the real world

If you've worked with me in the past then you know this is where I'm going to start talking about Domain-Driven Design. DDD is a _huge_ topic and far too much to cover here. If you aren't familiar with it then do yourself---and everyone else---a favour and learn more about it.

One of the biggest problems in monoliths tends to be the addition of inappropriate properties to entities, so the `User` entity ends up holding tangentially related data like `balance` and `last_login_at`. This creates a high degree of coupling between different subsystems (in this case, users, finance, and authentication) which makes them hard to work on independently or extract into separate services.

Even if you're not too worried about that, wide rows can lead to performance problems. I've seen this particularly in Postgres if one or two columns are updated frequently as rows are copied on write just to update that one column which leads to a lot of dead rows, which can lead to excessive vacuuming.

If you follow DDD principles you'll always be asking yourself questions like "what is the real-world entity this data belongs to?" so you won't put inappropriate data on entities, and they'll stay smaller, more focused, and easier to work with.




DDD - model the real world - small models, duplicate/denormalise where needed;

practical considerations around postgres


 don’t reference models cross ‘module’. 

Who is authoritative for the data?

Entities vs value objects, e.g. address is a value object, should be immutable


 Also lets you move functionality ‘out’ without a huge refactor.

Better for performance, don't accumulate 'junk' rows. Wide rows cause garbage. e.g. balance on User. 

Reduces locking issues or concurrent update issues (we'll talk about this later)

Consider CQRS patterns; your query patterns may not match your data model.



## 4. Encapsulate functions on entities

more important for writes than reads [related to don’t use signals/hooks]. Also lets you move functionality ‘out’ without a huge refactor. Scopes are kind of okay but don’t chain them.

Don't use signals/hooks (worse in Django as cross-app transaction hooks are ‘hidden’)

This helps with fast builds as you can mock/stub services without needing data access.

## 5. Don't use pessimistic concurrency

If you're not sure what pessimistic and optimistic concurrency are, in a nutshell pessimistic means you lock an entity for update at the time you read it so you can guarantee nobody else will change it until you're ready to, and optimistic means entities are versioned on write so when you try and change it you check the version to ensure it hasn't been updated in the meantime; if it has you retry your process with the new version.

Pessimistic concurrency seems easier to reason about on the surface because you know only one process can be trying to change an entity at a time. However, it doesn't scale beyond even fairly moderate loads due to lock contention, can cause high resource consumption, and can even lead to deadlocks in extreme cases. These issues are _not_ easy to reason about. As such, I would strongly recommend you do not use pessimistic concurrency except for very specific situations.

Arguably the best form of concurrency is optimistic, although it does make code harder to write as you need to cater for the eventuality the entity has been modified in the meantime and make your process retriable. However, in some cases, this might be overkill and you _may_ be able to get away with (gasp!) no concurrency control, a.k.a Last Write Wins (LWW).

Rails defaults to no concurrency control, and for many entities this is going to be okay as it implements change tracking and only writes modified columns, so LWW may not cause problematic data loss, particularly for entities that are unlikely to have competing processes modifying the same columns. For all entities where correctness is important though, use `ActiveRecord::Locking::Optimistic` and avoid `lock!`.

Django is rather more problematic as it doesn't have change tracking so by default writes all columns, meaning even process that update different columns can overwrite each other (yes, you can specify which columns to update explicitly, but nobody actually does that) so it's hard to recommend using LWW with Django. In addition, Django also only supports pessimistic concurrency (`select_for_update`) out of the box so you'll need to implement optimistic locking manually or use one of the third-party packages. Not exactly 'pit of success' territory,


## 6. Use UUID identifiers

I've already [written a lot about identifiers](/2019/12/10/all-about-identifiers/) so you should go and read that because there's too much to discuss in this one point. However, the if you only take one thing from it, let that be not to use integer identifiers. They can't be generated on the client-side, make it hard to scale, hard to extract functionality, leak business information, and they're a precursor to at least two serious security problems.

Do not use integer identifiers.

v4 UUIDs are a good choice which have no noticeable performance penalty in Postgres. Other database engines may vary in this regard, but it's probably premature to be worrying about performance anyway.

Both Rails and Django get this wrong out of the box and will default to integer primary keys. Ugh. In Rails you can [configure model generation](https://world.hey.com/ian.bradbury/how-to-configure-ruby-on-rails-and-postgres-to-use-uuids-for-primary-keys-669279d6) so it defaults to using UUIDs as primary keys, so if you set that up all your models will do the right thing by default. In Django you can create a base model with a field `id = models.UUIDField(primary_key=True, ...)`.

If you've already got this wrong and started with integer primary keys, it's pretty much impossible to get rid of them from existing entities. Do the next best thing and add a UUID surrogate key, then use that instead of the integer everywhere except foreign key relations.

## 7. Ensure background jobs are reliable

, e.g. outbox pattern is one option, or defer the job before the write (easy with uuids) and handle non-writes in the job. 

While we're on this theme...

 (<10s), interruptible, and idempotent (retriable). And respond to signals to shut down gracefully. Remember the Redis thing. Consider workflow engine like Temporal.io

 As a side note this applies to sending events. Ensure they're sent reliably, typically from a job.

## 8. Avoid batch jobs

Still on this theme...

; use events unless you actually need batch semantics. They don’t scale, they overtake each other, and they tend to fail when you’re asleep. Can cause IO spikes/self-DoS.

## 9. Keep dependencies up to date

I was debating putting this one higher as monoliths tend to have a _lot_ of dependencies, which often have inter-dependencies between them, i.e. multiple higher-level libraries referencing different versions of the same lower-level library. The consequence of this is dependencies can be tricky to update and sometimes you have to pin them to avoid conflicts. Unfortunately those pins tend to be forgotten about and over time you can end up with numerous libraries which are multiple major versions out-of-date and would take a huge effort to update, so they just stay pinned.

The deeper you get into this hole, the harder it is to dig yourself out of it, with the consequences of accumulating security issues, running into old library bugs, and not being able to use new functionality.

My recommendation is to have separate requirements and lock files, not to pin any versions of libraries in the requirements file except when absolutely necessary, and use something like Dependabot to automatically open pull requests to update versions on a weekly basis. If you do pin dependency versions, treat upgrading them and removing the pin as a high priority task.

For Ruby this all works by default as having separate `Gemfile` and `Gemfile.lock` is the standard approach. In Python, however, it's common to use a single `requirements.txt` for both purposes; I'd suggest instead you use `requirements.in` as the requirements file, and then use `pip-compile` to generate `requirements.txt` as a lock file.

## 10. Stay on top of errors

; use a tool like Sentry and keep it at inbox zero. If there are errors you don’t intend to fix, turn them into warnings and set some threshold alerts on them.

## Bonus tips:

1. Use a code formatter to keep arguments about style to a minimum
2. Write detailed PR descriptions, and use it as the description for squashed commits. Helps with code forensics. Don't rely on links back to Jira tickets or whatever.
3. Don’t use Redis as a primary data store; only as a cache. It’s not great for reliability, memory tends to accumulate, and it gets expensive.
