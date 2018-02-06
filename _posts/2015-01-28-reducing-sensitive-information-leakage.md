---
layout: post
title: Reducing sensitive information leakage
date: 2015-01-28
tags: security scala pii
author: gregbeech
comments: true
---

Most good developers take measures to protect sensitive information, and in particular personally identifiable information (PII), when building software. Some typical basic measures are putting user information in separate databases and restricting access to them, or storing credit card details with a specialist provider rather than in your own infrastructure.

However, even in a well designed system there are many channels through which information can leak. For example given the following class:

```scala
case class User(id: String, email: String, name: String)
```

It's all too easy to write something like the following:

```scala
logger.error(s"Failed to process request for $user")

// > Failed to process request for User(47d429adce, johndoe@example.org, John Doe)
```

And, whoops, you've accidentally dumped their email address and full name into your logs, which if you're doing things right are all collected and searchable in something like Graylog or Logstash. Even if you only keep logs for a relatively short period such as 30 days, this is still a fairly major leak.

It's pretty hard to prevent this even with careful developers and good code reviews because it's just so easy to leak sensitive information, and while it's obvious that a `User` class is going to contain that kind of thing, other classes may be rather less obvious.

A good way to solve this, inspired by [information flow theory](http://en.wikipedia.org/wiki/Information_flow_%28information_theory%29), is to mark the fields as being sensitive and then give them safe-by-default behaviour when dumped, e.g.

```scala
final case class Sensitive[A](value: A) {
  override def toString: String = "******"
}

object Sensitive {
  implicit def forAny[A](value: A): Sensitive[A] = Sensitive(value)
}

case class User(id: String, email: Sensitive[String], name: Sensitive[String])

logger.error(s"Failed to process request for $user")

// > Failed to process request for User(47d429adce, ******, ******)
```

Much better.

There are a couple of reasons you're better off using a type rather than, say, an `@sensitive` annotation. The most important one _is_ the safe-by-default behaviour because with a specialised type like this if the recipient doesn't know how to process it (e.g. third party logging libraries) then it'll print the masked value, unlike annotations which are ignored by recipients that don't understand them.

The other is that the sensitivity of a piece of data is an intrinsic part of the model. Much like an `Option[String]` declares that a string is optional and cannot be passed as a regular `String` argument directly, a `Sensitive[String]` also requires the developer to stop and think for a second before deciding whether it's appropriate to remove the sensitive marker. In an ideal world, this marker would be flowed all the way through to your application boundaries.

We can improve this further using the Scala idiom of creating wrapper classes for values that are likely to be passed around independently (e.g. instead of having the `email` property be a `String` we would make it an `Email`) which would make it a compile-time error to pass a name to a method expecting an email, and vice versa. By baking the sensitive marker into these we get a cleaner, more expressive model with better log output because we can see what information has been masked.

```scala
case class UserId(value: String) extends AnyVal
case class Email(value: Sensitive[String]) extends AnyVal
case class Name(value: Sensitive[String]) extends AnyVal
case class User(id: UserId, email: Email, name: Name)

logger.error(s"Failed to process request for $user")

// > Failed to process request for User(UserId(47d429adce), Email(******), Name(******))
```

This works pretty well within an application, but quite often you're going to want to send the sensitive information to other parties using some kind of open protocol such as HTTP or AMQP which doesn't support this kind of object model. Because you've got the sensitive type in your object model it's relatively easy to hook into frameworks such as [json4s](https://github.com/json4s/json4s) and provide custom serialization for these fields, giving you a number of options:

- Plain text - Unwrap the sensitive value when you serialize and wrap it when you deserialize, transmitting the value in plain text. This is useful when you're communicating directly with the intended recipient over a secure channel and so don't have to worry about things like interception, for example in a web API.

- Symmetric encryption - Encrypt the sensitive value when you serialize and decrypt it when you deserialize, transmitting the value as an encrypted string. This is useful when you're broadcasting the message to trusted recipients who can share a symmetric key but are concerned about things like messages being logged or routed to dead-letter queues, for example in a private message bus.

- Asymmetric encryption - There almost certainly _are_ use cases for asymmetric encryption at a field level in messages, but there are a number of ways to do this depending on the problem you're trying to solve, and you'd almost certainly want to use it in combination with message-level encryption and/or digital signatures. As such, I'm going to assume that if you're going this route you know enough about what you're doing and why.

I am not a lawyer so it's unclear to me whether symmetrically encrypting data on a message bus is sufficient for the Data Protection Act _et al._ rules on keeping personal data (as if any of the data does get logged then it is in theory decryptable, even if nobody except the most trusted operators would have the key). However, it's a pretty good start and a worthwhile endeavour given how simply it can be plugged in.

In any case -- it's trivial to start marking your data as sensitive, and trivial to process it when it is. It's not a panacea but it'll cure many of your problems with inadvertent data leakage, and allow you to take action based on the sensitivity of data in future. There's really no good reason not to do it.
