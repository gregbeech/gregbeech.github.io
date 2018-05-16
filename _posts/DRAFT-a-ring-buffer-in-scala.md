---
layout: post
title: A ring buffer in Scala
date: 2018-05-12
tags: collections learning scala
author: gregbeech
comments: true
---



> Implement an immutable ring buffer using only immutable data structures. In other words, if your structure was `Ring[A]` then push would return a new `Ring[A]` with the new element. For more of a challenge, implement push as `def push[B >: A](b: B): Ring[B]`.
>
> Hint: think about the semantics of a circular buffer. What is its behaviour regarding elements going in and out? What other more common data structure does this remind you of?
>
> If you want to go deeper, implement the above structure using `List[A]`. Hint: think about the performance characteristics of singly linked lists, and how two of them might work together.






Our final listing:

```scala
class Queue[+A] private(in: List[A], out: List[A]) {
  def size: Int = in.size + out.size

  def enqueue[B >: A](b: B): Queue[B] = new Queue(b :: in, out)

  def dequeue: (A, Queue[A]) = dequeueOption match {
    case Some(v) => v
    case None => throw new NoSuchElementException()
  }

  @tailrec def dequeueOption: Option[(A, Queue[A])] = out match {
    case x :: xs => Some((x, new Queue(in, xs)))
    case Nil if in.nonEmpty => new Queue(Nil, in.reverse).dequeueOption
    case Nil => None
  }

  def toList: List[A] = out ::: in.reverse
}

object Queue {
  def apply[A](xs: A*): Queue[A] = new Queue(Nil, List(xs: _*))
}

class Ring[+A] private(val capacity: Int, val size: Int, queue: Queue[A]) {
  def push[B >: A](b: B): (Option[A], Ring[B]) =
    if (size == capacity) {
      val (e, q) = queue.dequeue
      (Some(e), new Ring(capacity, size + 1, q.enqueue(b)))
    } else (None, new Ring(capacity, size + 1, queue.enqueue(b)))

  def pop: (A, Ring[A]) = popOption match {
    case Some(x) => x
    case None => throw new NoSuchElementException()
  }

  def popOption: Option[(A, Ring[A])] = queue.dequeueOption.map {
    case (e, q) => (e, new Ring(capacity, size - 1, q))
  }

  def toList: List[A] = queue.toList
}

object Ring {
  def apply[A](capacity: Int, xs: A*): Ring[A] = new Ring(capacity, xs.size, Queue(xs: _*))
}
```