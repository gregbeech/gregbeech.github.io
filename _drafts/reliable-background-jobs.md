---
layout: post
title: Reliable background jobs
date: 2023-12-05
tags: [reliability, design patterns]
author: gregbeech
comments: true
---

Background jobs, or tasks if you prefer, are an everyday part of software development. These might be periodic jobs running on a schedule, or triggered jobs running in response to an event such as an entity being created or updated. For the most part you want these jobs to be reliable; that is you want them to actually run, and run to completion. Unfortunately, my experience is most engineers assume this will magically happen and are surprised when it doesn't. Getting jobs to be reliable takes some knowledge and care.

Broadly speaking, there are a number of places where a job might fail to run to run at all, or fail to run to completion:

1. It might not be queued to run
2. It might be lost when starting the job
3. It might be interrupted when running
4. It might not be rescheduled after interruption
5. It might not be able to resume after interruption

These might be more or less of an issue you need to deal with depending on which libraries you're using. For example if you're using Akka with Projections then (1), (2) and (4) are handled out of the box, and (3) and (5) _tend_ to be straightforward to deal with because of the way you're guided to write code. On the other hand, if you're using Rails/Sidekiq or Django/Celery then all of these are issues you'll have to explicitly think about.

I'll illustrate the remainder of the article using Rails and Sidekiq. I'll be using Sidekiq directly rather than ActiveJob just for the sake of clarity, but all the same reasoning applies if you use the ActiveJob wrapper, as it does for any other languages and libraries you happen to be using.

## Queueing jobs

If you look at most Rails or Django apps they tend to use callbacks or signals to enqueue jobs after transactions have committed, for example:

```ruby
class Article < ApplicationRecord
  after_commit do |article|
    UpdateSearchIndexJob.perform_async(article.id)
  end
end
```

The rationale for after commit is that the record won't be available to the job until the transaction has committed, so this avoids the potential race condition if you do it before commit where the job starts and tries to process a record that isn't yet available. Unfortunately, there are a couple of different ways this can fail to queue the job.

Firstly, the callback may never be run as the application could crash or be 'rudely' shut down between when the transaction commits and when the callback is executed. Secondly, even if the callback is executed, there may be a network issue which prevents the job being queued. Neither of these are common, but they do happen; from what I've seen over many years you'll typically lose one job in every 10--100k under normal conditions, or far more in some incident conditions.

One of the ways you can mitigate this is to change `after_commit` to `after_save` which means the job is queued _inside_ the database transaction. Now the transaction will only commit if the job is successfully enqueued. This does mean your job retry logic needs to become more complex because it has to handle the race condition of starting before the entity exists, and it also needs to handle the fact the transaction may not commit so the entity will never exist!

```ruby
class Article < ApplicationRecord
  after_save do |article|
    UpdateSearchIndexJob.perform_async(article.id)
  end
end
```

The unfortunate downside of using `after_save` is it extends the transaction lifetime, and in the worst way by including IO calls which may have unpredictable durations. If you've ever had to scale anything using a relational database, you know how important it is to keep transactions as short as possible, so while this works it isn't an appealing option. A more scalable alternative is to give your code additional structure and use a [domain service](https://ddd-practitioners.com/home/glossary/domain-service/) to save the entity rather than just calling `save!` directly.

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

Note that this pattern necessitates using identifiers you can assign client-side, like UUIDs, rather than using database-allocated identifiers like auto-incrementing integers. But [you shouldn't be using integer identifiers anyway](/2019/12/10/all-about-identifiers/) so if this is a problem in your application, fix it first.

A bit of fun for non-Pro Sidekiq users is none of the above code is actually reliable because the `perform_*` methods are all fire-and-forget so won't error even if the job isn't enqueued. There's no way to solve this without paying for the Pro version. Don't use Sidekiq for any real systems unless you're prepared to pay for Pro.

## Starting jobs

The most basic way a job server can start a job is, when ready, it simply pops the job description off the queue and starts it. Unfortunately this means if the server crashes or is rudely shut down, the jobs will be lost because there's no persistent record of them anywhere.

By default both Sidekiq and Celery use this unreliable at-most-once approach to execution, where the job will be started either zero times or one time.

A more reliable approach is to keep the job description in the queue until is has completed successfully. Exactly how this works will depend on the queue backend. For example if you're using a real queueing system this might mean not acknowledging the message until the job has completed, or if you're using Redis it might mean moving the job from a pending to in-progress list. But the principle is the same; the job description [stays until the job's done](https://www.youtube.com/watch?v=CzdPOkUUBKk).

That means you get at-least-once behaviour in job execution, where the job is always started at least once, but may be started many more times than that.

In Celery you can adopt at-least-once behaviour easily enough by setting `acks_late=True`. In Sidekiq, as you've probably guessed, you can adopt this behaviour by paying for the Pro version. Don't use Sidekiq for any real systems unless you're prepared to pay for Pro.

## Interrupting jobs

Continuing the article theme, lets say you've added the ability for users to subscribe to topics so they can be notified of new articles. One approach to this would be to run a daily batch-style job that loops over every user and evaluates their subscription.

```ruby
class SubscriptionNotificationJob
  include Sidekiq::Job

  def perform
    User.find_each do |user|
      SubscriptionService.new(user).notify_new_articles!
    end
  end
end
```

This job is potentially long-running if there are a lot of users, and the longer it runs for the greater the chance there is of being interrupted by a crash. If the server crashes part way through the job, not all of the users will receive their notifications. Not the end of the world in this case, but for jobs you actually need to finish this could be a major issue.

There's an even bigger problem with this job being long-running though, which is that if you need to restart the application---for example, to deploy it---then the job will attempt to block this by continuing to run. Most job servers, including Sidekiq, will give jobs a grace period of up to 30s to shut down and will then rudely kill them. If you write long running jobs then you're virtually _asking_ for them to be interrupted!

One solution to this is to write long-running jobs as a series of short-running jobs, for example below. This doesn't protect you from crashes (although it will help, as we'll see later) but it does protect you from self-inflicted rude shutdowns.

```ruby
class SubscriptionNotificationJob
  include Sidekiq::Job

  BATCH_SIZE = 100

  def perform(previous_id = nil)
    users = fetch_users(previous_id)
    users.each do |user|
      SubscriptionService.new(user).notify_new_articles!
    end
    SubscriptionNotificationJob.perform_async(users.last.id) if users.size == BATCH_SIZE
  end

  private

  def fetch_users(previous_id)
    users = User.order(:id).limit(BATCH_SIZE)
    users = users.where("id > ?", previous_id) if previous_id
    users.to_a
  end
end
```

Although this is better, it isn't the best approach as it's still a batch-style job, which is a pain in the ass from an operational perspective. Batch jobs are typically run overnight when compute resource demands are at their lowest, which means they aren't running during the day when you make changes, so they typically also _break_ overnight which isn't fun if you're on call. A better approach is to try and keep your jobs event driven so they happen in near-real-time, which tends to keep them implicitly short-running.

## Rescheduling jobs

(configuration of job)

## Resumable jobs

(idempotence)


