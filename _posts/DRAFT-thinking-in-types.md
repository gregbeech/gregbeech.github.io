---
layout: post
title: Thinking in types
date: 2018-05-22
tags: collections learning scala
author: gregbeech
comments: true
---

Scala isn't a particularly easy language to learn, and if you're coming from dynamically typed languages like Ruby or Python then it's a huge mental shift because Scala is _very_ strongly typed. Idiomatic Scala programming uses the type system to represent assumptions, and so that means you have to pretty much invert the way you write code compared to dynamic languages: You model your assumptions with types and then fill in the blanks.

I suggested the following exercise for people to get to grips with Scala's generics and the concept of immutability, so let's work it though and see how we 'follow the types' to an implementation.

> Implement an immutable ring buffer using only immutable data structures. In other words, if your structure was `Ring[A]` then push would return a new `Ring[A]` with the new element. For more of a challenge, implement push as `def push[B >: A](b: B): Ring[B]`.
>
> Hint: think about the semantics of a circular buffer. What is its behaviour regarding elements going in and out? What other more common data structure does this remind you of?
>
> If you want to go deeper, implement the above structure using `List[A]`. Hint: think about the performance characteristics of singly linked lists, and how two of them might work together.

Let's start with our ring buffer. Because it's going to be immutable, values will only come out of it so we can make the type argument covariant. In other words, a `Ring[Giraffe]` can safely be stored in a variable of type `Ring[Animal]`.

```scala
class Ring[+A]
```

As the ring is immutable the `push` method is going to need to return a new instance with the new element. It would also be nice if we could access any element that was displaced because the buffer was full; as there may not be any displaced element we should model this as an `Option`.

The `B >: A` syntax is a lower type bound which requires that `B` is a 'bigger' type than `A`. `Animal` is a bigger type than `Giraffe` because there are more types that fit into it. This means we could push an `Animal` into a `Ring[Giraffe]` and get a `Ring[Animal]` returned which is safe because everything already in there must be 'smaller' than the new type<sup>1</sup>.

```scala
class Ring[+A] {
  def push[B >: A](b: B): (Option[A], Ring[B])
}
```

Popping an element needs to return both the element itself and a new ring without it.

```scala
class Ring[+A] {
  def push[B >: A](b: B): (Option[A], Ring[B])
  def pop: (A, Ring[A])
  def popOption: Option[(A, Ring[A])]
}
```

```scala
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


---

[1] The [lower type bound documentation](https://docs.scala-lang.org/tour/lower-type-bounds.html) describes this as a supertype relationship but that's not correct, as a `Ring[List[Giraffe]]` is assignable to `Ring[List[Animal]]` even though there is no supertype/subtype relationship between `List[Giraffe]` and `List[Animal]`