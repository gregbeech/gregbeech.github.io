---
layout: post
title: Reliable background jobs
date: 2023-12-05
tags: [reliability, design patterns]
author: gregbeech
comments: true
---

Background jobs, or tasks if you prefer, are an everyday part of software development. These might be periodic jobs running on a schedule, or triggered jobs running in response to an event such as an entity being created or updated. For the most part you want these jobs to be reliable. That is you want them to actually run, and run to completion. Unfortunately, my experience is most engineers assume this will just happen and are surprised when it doesn't. Getting jobs to be reliable is harder than you might initially think.

Broadly speaking, there are a number of places where a job might fail to run to run at all, or fail to run to completion:

1. It might not be queued to run
2. It might be lost when execution starts
3. It might be interrupted when running
4. It might not be rescheduled after interruption
5. It might not be able to resume after interruption

These might be more or less of an issue you need to deal with depending on which libraries you're using. For example if you're using Akka with Projections, then (1), (2) and (4) are handled out of the box, and (3) and (5) _tend_ to be straightforward to deal with because of the way you're guided to write code. On the other hand, if you're using Rails/Sidekiq or Django/Celery then all of these are issues you'll have to explicitly think about.

The rationale for these differences is down to the philosophy of the underlying libraries. Akka assumes its users will write idempotent code, so uses at-least-once reliability. Celery---quite reasonably, in my experience---assumes a lower level of skill or knowledge so has at-most-once reliability by default, but does allow at-least-once if you know what you're doing. Sidekiq is somewhere in the middle and assumes your jobs will be idempotent, but won't run them reliably unless you pay for the Pro version.

I'll illustrate the remainder of the article with Rails/Sidekiq or Django/Celery, but once you know what to look for it'll be easy enough to apply the knowledge to any other libraries you happen to be using.

## Queueing jobs

If you look at most Rails or Django apps they tend to use callbacks or signals to enqueue jobs after transactions have committed, for example:

```ruby
class Article < ApplicationRecord
  after_commit do |article|
    UpdateSearchIndexJob.perform_async(article.id)
  end
end
```

The rationale for after commit is that the record won't actually be available to the job until the transaction has committed, so this avoids a potential race condition if you do it before commit where the job starts before the transaction commits. Unfortunately, there are a couple of different ways this can fail to queue the job.

Firstly, the callback may never actually be run as the application could crash or be 'rudely' shut down (e.g. SIGKILL) between when the transaction commits and when the callback is executed. Secondly, even if the callback is executed, there may be a network issue which prevents the job being queued. Neither of these are common, but they do happen; from what I've seen over many years you'll typically lose somewhere between 1 in 10k and 1 in 100k jobs under 'normal' conditions.

One of the ways you can mitigate this is to change `after_commit` to `after_save` which means the job is queued _inside_ the database transaction. Now the transaction will only commit if the job is successfully enqueued, so you can guarantee the job will be enqueued. This does mean your job retry logic needs to become more complex because it now has to handle the race condition of potentially starting before the entity exists, and it also needs to handle the fact the transaction may not commit so the entity will never exist!

```ruby
class Article < ApplicationRecord
  after_save do |article|
    UpdateSearchIndexJob.perform_async(article.id)
  end
end
```

The unfortunate downside of using `after_save` is it extends the transaction lifetime, and in the worst way by including IO calls which may have unpredictable durations. If you've ever had to scale anything using a relational database, you know how important it is to keep transactions as short as possible, so while this works it isn't an appealing option. A more scalable alternative is to give your code additional structure and use an application service to save the entity rather than just calling `save!` directly.

```ruby
class ArticleService
  def save!(article)
    article.id ||= SecureRandom.uuid
    article.validate!
    UpdateSearchIndexJob.perform_async(article.id)
    article.save!(validate: false)
  end
end
```

This code explicitly validates the entity before doing anything so we know it's _likely_ to save successfully, then enqueues the job before the database transaction even begins. As a minor optimisation, saving can skip validation. Another potential optimisation is to delay the job start time, e.g. by using `perform_in(1.second, article.id)`, to make it more likely the transaction has committed by the time it runs. However, be aware that even with NTP running clock slip is a thing, so you should never _rely_ on the times of different servers being in sync.

An additional bit of fun for non-Pro Sidekiq users is none of the above code is actually reliable because the `perform_*` methods are all fire-and-forget so don't wait to see if the job was actually enqueued. There's no way to solve this without paying for the Pro version. Don't use Sidekiq for any real systems unless you're prepared to pay for Pro.

## Executing jobs

There are a couple of ways jobs can be executed by job servers, in principle. The un


(just the scheduler, e.g. RPOPLPUSH)

## Interrupting jobs

(crashes, shutdowns)

## Rescheduling jobs

(configuration of job)

## Resumable jobs

(idempotence)


