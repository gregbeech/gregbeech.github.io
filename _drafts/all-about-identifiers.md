---
layout: post
title: All about identifiers
date: 2019-12-10
tags: [identifiers, distributed systems, gdpr]
author: gregbeech
comments: true
---

Most people don't think very much about identifiers. Indeed, popular frameworks such as Django or Hibernate encourage you not to think very much at all and use the default of an auto-incrementing integer. Unfortunately using sequential identifiers is a bad idea, and if you don't think about your identifiers up front then it can take a lot of time to fix things later. Here's most of what you need to know about identifiers.

## Don't use integers

Before we get into anything else, let me convince you that you should not use sequential integer identifiers as your primary identifier. There are three main problems with integers.

Firstly, they make life difficult if you want to generate them in multiple places such as a different service if an entity is being migrated, or in different shards, because the sequences will overlap with each other. If you're using 64-bit integers this issue can often be mitigated by partitioning the keyspace, but this kind of partitioning can be complex and error-prone, leading to accidental overlaps. If you're using 32-bit integers then you're out of luck unless your rate of growth is really very small.

Secondly, sequential integers can impact application security because they facilitate enumeration and thus make [insecure direct object reference (IDOR)](https://www.owasp.org/index.php/Testing_for_Insecure_Direct_Object_References_(OTG-AUTHZ-004)) attacks easier to mount, and the consequences much more severe if you do not have the appropriate access control in place. No matter how dilligent you are, mistakes will be made in access control. While this is to some extent security by obscurity, it's still a valuable part of defence in depth.

Lastly, they leak business information which could be highly valuable to competitors, who can derive things like how many orders/day you're doing from sequential order numbers. The workaround of partitioning the keyspace can make this leak even worse because if your partitions relate to business units or markets then competitors can obtain a more detailed breakdown. Trust me, your competitors _will_ do this.

Instead I'd recomment using randomly generated identifiers with effectively zero probability of collision such as v4 UUIDs. However, note that while most mainstram v4 UUID generation algorithms are cryptographically secure and thus the UUIDs are unguessable under any circumstances, this is not required by the specification. UUIDs are required to be _unique_ but not _unguessable_. As such, if the identifiers must be unguessable then it may be safest to use a cryptographically random generator directly.

Another option you might want to consider is [k-sortable](https://en.wikipedia.org/wiki/Partial_sorting) identifiers which is essentially an identifier prefixed with a specially formatted timestamp so that the identifiers are roughly sortable by time both lexicographically and in binary format. However, again beware that this leaks information as the timestamps could be extracted by interested third parties.

Before ending this section, a word on performance. These larger random identifiers work well in many data stores, but for some such as SQL Server which uses clustered primary keys they can cause major problems from effects like page splits. In this case you may want to create the table with an auto-incrementing integer primary key which is a [surrogate](https://en.wikipedia.org/wiki/Surrogate_key) and only used _within_ the application but never exposed to any other application or party. This isn't necessary in Postgres; using a UUID rather than a 64-bit integer key has a negligible effect on performance.

## Identifiers can be personal data

When we think of personal data we tend to think of things like name or email. However, any identifier for a person that is accessible to that person or any third party (whether it's in a user interface, URL, API body, cookie, JWT, etc.) should also be considered personal data. On hearing this many people are dismissive, but consider that it falls into the same category as identifiers like passport or driving license number.

If you operate in Europe and are thus required to be compliant with the GDPR then this means you need to be able to _delete_ any accessible identifier if the person files a [deletion request](https://ico.org.uk/for-organisations/guide-to-data-protection/guide-to-the-general-data-protection-regulation-gdpr/individual-rights/right-to-erasure/) (aka "the right to erasure" or "the right to be forgotten").

In theory if you implement 'true' deletion where all of the data related to that person is actually deleted then there should be no problem with using the same identifier for both internal and external use.

However, it is common practice particularly with relational databases to implement [pseudonymisation](https://en.wikipedia.org/wiki/Pseudonymization) and replace any personal data with anonymised data, because unpicking the foreign key relationships to allow true deletion is impractical. In this case the accessible identifier must also be anonymised; this is clearly not possible if it is the primary key or used in foreign key relationships.

As such, for people you typically need at least _two_ identifiers: One that is used only for internal purposes, and one that is exposed to the person. The internal key should be used as the key for all internal storage but never exposed in any UI, URL, JWT, etc. which is where the external key should be used. 

The reason for at least two rather than exactly two is that if you deal with any third parties (e.g. integrations) then you should provide a different identifier to each of those third parties, or even to different accounts with the same third party if applicable. This is part of defence in depth as it means the third party cannot identify people they don't have access to. It also makes it harder for them to correlate people's information. In fact, translating identifiers for _any_ resource for third parties is generally good practice.

## Labelling 

It’s a good idea to label the identifiers so that you can tell what they are. ARNs as example, Stripe as another. A good idea to include a market or region etc. if the data can be geographically distributed (helps with sharding and privacy law compliance). 

## Cross-system compatibility

Use all lowercase identifiers but treat them as case insensitive for compatibility across all kinds of data store and collation. Identifiers that differ only by case are a potential security risk and can cause hard to find bugs.

## Short identifiers

Be wary of truncating/hashing to make short identifiers as you only need sqrt(n in flight) to have a 50% chance of collision. Sequential generation is better here (with block allocation for better speed/reliability). 

