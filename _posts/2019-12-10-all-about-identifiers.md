---
layout: post
title: All about identifiers
date: 2019-12-10
tags: [identifiers, system design, gdpr]
author: gregbeech
comments: true
---

Identifiers aren't usually considered very interesting. Indeed, popular frameworks such as Django or Hibernate find them so uninteresting that they ship with the default of auto-incrementing integers so users don't need to be concerned with them. Unfortunately using sequential identifiers is a bad idea, and if you don't think about your identifiers up front then fixing things later can be very time consuming. Here's most of what you need to know about identifiers.

## Don't use sequential integers

Before we get into anything else, let me convince you that you should not use sequential integers as your primary identifier, whether 32-bit or 64-bit. There are three main problems with sequential integers.

Firstly, they make life difficult if you want to generate them in multiple places such as a different service if an entity is being migrated, or in different shards, because the sequences will overlap with each other. If you're using 64-bit integers this issue can often be mitigated by partitioning the keyspace, but this kind of partitioning can be manual and error-prone, leading to accidental overlaps. If you're using 32-bit integers then you're out of luck unless your rate of growth is really very small.

Secondly, sequential integers can impact application security because they facilitate enumeration and thus make [insecure direct object reference (IDOR)](https://www.owasp.org/index.php/Testing_for_Insecure_Direct_Object_References_(OTG-AUTHZ-004)) attacks easier to mount, and the consequences of insufficient access control more severe. No matter how dilligent you are, mistakes will be made in access control. While this is to some extent security by obscurity, it's still a valuable part of defence in depth.

Lastly, they leak business information which could be valuable to competitors, who can derive things like how many orders/day you're doing from sequential order numbers. The workaround of partitioning the keyspace can make this leak even worse because if your partitions relate to business units or markets then competitors can obtain a more detailed breakdown. Trust me, your competitors _will_ do this.

Instead I'd recommend using randomly generated identifiers with effectively zero probability of collision such as [v4 UUIDs](https://en.wikipedia.org/wiki/Universally_unique_identifier#Version_4_(random)). However, note that while most mainstram v4 UUID generation algorithms are cryptographically secure and thus the UUIDs are unguessable under any circumstances, this is not required by the specification. UUIDs are required to be _unique_ but not _unguessable_. As such, if the identifiers must be unguessable then it may be safest to use a cryptographically random generator directly.

Another option you might want to consider is [k-sortable](https://en.wikipedia.org/wiki/Partial_sorting) identifiers which are essentially a random string prefixed with a specially formatted timestamp so that the identifiers are roughly sortable by time both lexicographically and in binary. However, again beware that this leaks information as the timestamps could be extracted by interested third parties.

Before ending this section, a word on performance. These larger random identifiers work well in many data stores, but for some such as SQL Server which uses clustered primary keys they can cause major problems from effects like page splits. In this case you may want to create the table with an auto-incrementing integer primary key which is a [surrogate](https://en.wikipedia.org/wiki/Surrogate_key) and only used _within_ the application but never exposed to any other application or party. This isn't necessary in Postgres; using a UUID rather than a 64-bit integer key has a negligible effect on performance.

## Identifiers can be personal data

When we think of personal data we tend to think of things like name or email. However, any identifier for a person that is accessible to that person or any third party (whether it's in a user interface, URL, API body, cookie, JWT, etc.) should also be considered personal data. On learning this many people are dismissive, but consider that it falls into the same category as identifiers like passport or driving license number.

If you operate in Europe and are thus required to be compliant with the GDPR then you need to be able to _delete_ any accessible identifier if the person files a [deletion request](https://ico.org.uk/for-organisations/guide-to-data-protection/guide-to-the-general-data-protection-regulation-gdpr/individual-rights/right-to-erasure/) (aka "the right to erasure" or "the right to be forgotten").

In theory if you implement 'true' deletion where all of the data related to that person is actually deleted then there should be no problem having the same identifier for both internal and external use.

However, it is common practice particularly with relational databases to implement [pseudonymisation](https://en.wikipedia.org/wiki/Pseudonymization) and replace any personal data with anonymised data, because unpicking the foreign key relationships to allow true deletion is impractical. In this case the accessible identifier must also be anonymised; this is clearly not possible if it is the primary key or used in foreign key relationships.

As such, for people you often need at least _two_ identifiers: One that is used only for internal purposes, and one that is exposed to the person. The internal identifier should be used as the key for all internal storage but never exposed in any UI, URL, JWT, etc. which is where the external identifier should be used. 

The reason for at least two rather than exactly two is that if you integrate with any third parties then you should provide a different identifier to each of those third parties, or even to different accounts with the same third party if applicable. This is part of defence in depth as it means the third party cannot identify people they don't have access to, and it makes it harder for them to correlate information. In fact, individually translating the identifier of _any_ resource for third parties is generally good practice.

## Cross-system compatibility

Identifiers are one of the few things in systems that tend to stay stable, unlike languages and storage or data warehousing technologies, so we want identifiers to work with any future technology choices we may make. In addition, if they are sent to third parties then they may be processed using a completely different set of technologies of which we are unaware. To ensure the highest level of compatibility there are a number of considerations.

The most important consideration is not to create identifiers that differ only by case. Some data stores such as DynamoDB are case sensitive, others such as Postgres have selectable collations which control case sensitivity, and others such as Elasticsearch are _sometimes_ case sensitive depending on both index and query. Having identifiers that differ only by case makes it more likely that they will collide or be conflated, causing hard-to-find bugs that potentially have security or privacy implications.

If the identifiers will not differ by case then it also makes sense to define a canonical case so they can always be compared lexically as well as logically. For example `42A23DAB-67AD-4AD7-B7A9-3DAFF34F6C02` and `42a23dab-67ad-4ad7-b7a9-3daff34f6c02` are _logically_ the same UUID but are lexically unequal. If identifiers are always represented in a particular case (I prefer lowercase) then systems can convert identifiers to the canonical case and then it doesn't matter if they use logical or lexical comparison.

On the subject of case, we don't want to deal with anomalies like the [Turkish I problem](http://www.i18nguy.com/unicode/turkish-i18n.html) so restrict identifiers to ASCII characters. As identifiers may end up being used in URLs, headers, cookies, etc. it's also best to stay away from any character that might have special meaning in those places. A safe character set to stick to is `0-9`, `a-z`, `-` and `_`.

## Labelling

One of the issues with identifiers is trying to work out what they refer to if you don't have the context, and this gets worse in distributed systems or with data warehousing. A neat solution to this is to include labels in the identifiers.

Stripe uses a fairly basic prefix approach with their API keys (which are really just a form of identifier) using a `pk_` prefix for publishable keys, `sk_` prefix for secret keys, and then a `live_` or `test_` environment slug. For example, a live publishable key looks like `pk_live_8hTOJDTo...`.

Amazon uses a much more complex approach with [Amazon Resource Names (ARNs)](https://docs.aws.amazon.com/general/latest/gr/aws-arns-and-namespaces.html) which have a structured format including details of where the resource is and which account it belongs to, e.g. `arn:partition:service:region:account-id:resource-id`.

These two examples also show a different approach to identifier uniqueness scope. In Stripe the resource identifier is globally unique, whereas in AWS it is only necessarily unique within the scope of the partition, service, region and account because the complete identifier is always used.

At Deliveroo we chose an approach somewhere in between these two, using the format `drn:partition:market:resource-name:resource-id` which gave us future flexibility to partition the system, a market because all resources are strongly market-affine, and a globally unique resource identifier that can be used standalone in the many existing URLs without ambiguity (as those URLs typically already identify both the market and resource name).

We decided not to include an environment component as it added a generation and validation burden with little practical benefit because environments are strongly separated using other mechanisms. The market is deliberately abstracted from the shards in which that market resides to allow shards to be rearranged as markets grow. 

Labelling identifiers makes them much more useful, but be careful not to paint yourself into a corner by encoding aspects of your business that might change in future.

## Summary

Identifiers are more complex to get right than you might think. Here's a summary of the recommendations in this post which should help:

- **Never** use sequential integer identifiers
- **Usually** use v4 UUID identifiers
- **Always** represent identifiers in lowercase
- **Consider** labelling identifiers with their meaning
- **Remember** that identifiers can be personal data

As always with software development, "never" doesn't mean never and "always" doesn't mean always. You'll find that many of these recommendations are broken in the wild, and often for good reason. However, this is a good base set of guidelines to start from, and you should think carefully before deviating.
