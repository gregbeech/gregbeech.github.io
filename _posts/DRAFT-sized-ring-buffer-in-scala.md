---
layout: post
title: Sized ring buffer in Scala
date: 2018-05-25
tags: collections learning scala
author: gregbeech
comments: true
---

Some people in the office are learning Scala so a while back I set them a challenge of implementing an immutable ring buffer. It's not too hard, but can we go one better and i

```scala
import scala.collection.immutable.Queue

class Ring[+A] private(val capacity: Int, val size: Int, queue: Queue[A]) {
  def push[B >: A](b: B): (Option[A], Ring[B]) =
    if (size < capacity) (None, new Ring(capacity, size + 1, queue.enqueue(b)))
    else (Some(queue.head), new Ring(capacity, size, queue.tail.enqueue(b)))

  def pop: (A, Ring[A]) = popOption.getOrElse(throw new NoSuchElementException())

  def popOption: Option[(A, Ring[A])] = queue.dequeueOption.map {
    case (h, t) => (h, new Ring(capacity, size - 1, t))
  }
}

object Ring {
  def empty[A](capacity: Int): Ring[A] = new Ring(capacity, 0, Queue.empty)
}
```

This is fine, but it has some issues:

- `push` returns an option which needs matching
- `pop` can throw
- `popOption` is annoying to use because of the option wrapper

Can we go one better?

```scala
import shapeless.{_0, Nat, Succ}
import shapeless.ops.nat.{LT, Pred}

import scala.collection.immutable.Queue

class Ring[+A, C <: Nat, S <: Nat] private(queue: Queue[A]) {
  def push[B >: A](b: B)(implicit ev: LT[S, C]): Ring[B, C, Succ[S]] =
    new Ring(queue.enqueue(b))

  def pushPop[B >: A](b: B)(implicit ev: S =:= C): (A, Ring[B, C, S]) =
    (queue.head, new Ring(queue.tail.enqueue(b)))

  def pop(implicit ev: Pred[S]): (A, Ring[A, C, ev.Out]) =
    (queue.head, new Ring(queue.tail))
}

object Ring {
  def empty[A, C <: Nat] = new Ring[A, C, _0](Queue.empty)
}
```

- Can only `push` if there is capacity else must use `pushPop`
- Can only `pop` if non-empty
