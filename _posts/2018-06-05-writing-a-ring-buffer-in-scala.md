---
layout: post
title: Writing a ring buffer in Scala
date: 2018-06-05
tags: learning scala scala-101 types
author: gregbeech
comments: true
---

People coming from dynamic languages like Ruby or primitive languages like Go tend to miss the point of Scala. They tend to think in terms of mutability and often aren't familiar with data structures beyond lists and hashes, with types and side effects being seen as fairly unimportant considerations. To try and illustrate the different way you need to think when writing Scala I'm going to write a ring buffer, as I've seen a few people around the office implementing them as a learning exercise.

It'll be quite different to what you'd write in most mainstream languages.

Scala developers prefer immutable types to mutable ones because knowing they can't change makes them much easier to reason about, particularly once concurrency gets involved. People new to Scala tend to worry unduly about the performance of immutable data structures; you can actually write very efficient immutable collections if you make them [persistent](https://en.wikipedia.org/wiki/Persistent_data_structure) so that's the approach we'll take.

To further illustrate how to write idiomatic Scala I'm going to structure this article the way I tend to write code, which is types first. This is an alien concept to people used to dynamic languages or languages with only basic type systems, but in languages with powerful type systems it makes sense: You encode your knowledge of how the program should work as types as far as possible, and then you fill in the blanks.

## Specification

Before we write any code at all, we should write a specification. It's much quicker and easier to discuss and iterate on a specification than code. It's amazing how many programmers miss this step out, but you shouldn't. Writing at least a small specification will make things faster overall.

You could write these requirements out as tests, and I would if this was for a real project, but it takes up quite a bit of space and it's not really the point of this post so I won't here.

1. The ring can hold elements of any type.
2. The capacity must be greater than zero, and is fixed when the ring is created.
3. The size may vary between zero (empty) and the capacity (full).
4. When an element is pushed to a non-full ring the new element is added to the end and the size is increased by one.
5. When an element is pushed to a full ring the oldest element is discarded, the new element is added to the end, and the size is unchanged.
6. When an element is popped from a non-empty ring the oldest element is removed and returned, and the size is decreased by one.
7. If an attempt is made to pop an element from an empty ring the program should crash.

Although these requirements are short and easy to read, they're also comprehensive and detail what each operation should do to things like the size of the buffer. I referred back to these quite a number of times when writing both the interface and the implementation.

## Interface

The first requirement can be implemented with a type parameter. Because we know the ring buffer is going to be immutable, values will only come out of it and therefore we should be able to make the parameter covariant with an `+` annotation. As a first-order approximation, if values only come out (e.g. return values) then the type parameter can be covariant, and if they only go in (e.g. method parameters) it can be contravariant[^1].

Making the ring covariant with regards to `A` means that if we have a `Ring[Giraffe]` then we can assign it to a variable of type `Ring[Animal]`, or pass it to a method where a `Ring[Animal]` is required. Variance makes generic types more convenient and flexible for users, so is worth thinking about.

```scala
class Ring[+A]
```

As soon as we start modelling `capacity` and `size` we run into a bit of trouble. Scala doesn't have refinement types built-in (we can't say that capacity is an integer greater than zero) and there's no way to model the relationship between the two numbers  in the type system (that `capacity` must always be `<= size`) so we'll have to settle for modelling them as plain old integers.

Although we may end up making these `val`, we'll start with `def` because it gives us more flexibility in the implementation. It doesn't affect the interface because Scala implements the [uniform access principle](https://en.wikipedia.org/wiki/Uniform_access_principle) so a parameterless `def` is the same as a `val` from the caller's point of view.

```scala
def capacity: Int = ???
def size: Int = ???
```

Things start getting more complex when we look at the push method. Because the ring is immutable it can't modify any state, so the method needs to return a new ring that has the pushed element added. Your first intuition might be to define the push method like this:

```scala
def push(a: A): Ring[A] = ???
```

Unfortunately that leads to a compiler error because we declared the type parameter `A` covariant but we're trying to use the type in an input position as a method parameter:

> Error: covariant type A occurs in contravariant position in type A of value a
>
>   def push(a: A): Ring[A] = ???

To resolve this we could remove the variance annotation, but there is a better way. Because we're returning a new ring, we can change the type of it from the push method! Think about it this way: If you have a `Ring[Giraffe]` and you try to push an `Animal` then because all giraffes are animals it would be safe to return a `Ring[Animal]`.

As such, we can use a new type parameter `B` constrained to be a supertype[^2] of `A`, which makes the push method more flexible and allows the type parameter to stay covariant:

```scala
def push[B >: A](b: B): Ring[B] = ???
```

That's a decent definition, but it doesn't fully encode what might happen; we know that an element might be discarded if the ring is full. The user of the ring may want to know which element got discarded so we can return that from the method as well, wrapped in an option to indicate that there might be no discard.

```scala
def push[B >: A](b: B): (Option[A], Ring[B]) = ???
```

Next the pop method, which needs to return a 2-tuple of the popped element and the new ring with that element removed. This method will throw a `NoSuchElementException` if the ring is empty and ideally this should be encoded into the type signature, but that isn't the idiom in the built-in Scala collections so we'll copy them and have an 'invisible' exception.

```scala
def pop: (A, Ring[A]) = ???
```

Finally, a more convenient pop method which only pops if the collection is non-empty so users don't need to check the size of the collection before calling it. Here we could wrap just the value in an option, but as there's no need to change the ring if the pop doesn't happen it's more accurate to encode the whole thing as an option.

```scala
def popOption: Option[(A, Ring[A])] = ???
```

With that, our minimal interface for the ring buffer is complete:

```scala
class Ring[+A] {
  def capacity: Int = ???
  def size: Int = ???
  def push[B >: A](b: B): (Option[A], Ring[B]) = ???
  def pop: (A, Ring[A]) = ???
  def popOption: Option[(A, Ring[A])] = ???
}
```

## Implementation

If you look at the requirements for the ring, the elements are ordered and they are handled in a first-in first-out (FIFO) manner. This should remind you of a queue, and indeed we can treat a ring as a bounded queue where enqueueing an element may also cause an element to be dequeued.

I've chosen to make the ring a case class so we get equality for free. This will expose the queue in the class's interface, but I don't care too much as it _is_ a specialised type of queue and that abstraction doesn't need to be hidden. Plus, as the queue is immutable, it can be safely exposed without worrying anybody might modify it.

The size being explicit might surprise you given queues already have a size method we could pass through to. However, the size method on immutable queues is O(N) because they actually count all the elements when you query the size, but it's important to the runtime complexity of the ring class that querying the size is O(1).

```scala
import scala.collection.immutable.Queue

case class Ring[+A](capacity: Int, size: Int, queue: Queue[A])
```

The push method is pretty much a transliteration of the English language requirements. Here you can see why it's important that size is O(1) otherwise pushing an element would be an O(N) operation. The code can be made to look a bit cleaner using queue's `head` and `tail` methods rather than `dequeue` but it makes the performance rather harder to reason about so I've done it this way.

```scala
def push[B >: A](b: B): (Option[A], Ring[B]) =
  if (size < capacity) (None, Ring(capacity, size + 1, queue.enqueue(b)))
  else queue.dequeue match {
    case (h, t) => (Some(h), Ring(capacity, size, t.enqueue(b)))
  }
```

The pop method is easiest implemented in terms of the optional version. If you are after the maximum performance this isn't the best approach as it requires the allocation of an additional option instance which is immediately discarded, but it's an 'obviously correct' implementation which for most programs is better than a marginally faster but more complex one.

```scala
def pop: (A, Ring[A]) = popOption.getOrElse(throw new NoSuchElementException)
```

Finally `popOption`, which can be implemented in terms of the equivalent `dequeueOption` method on the queue. One of Scala's little warts is that lambdas with tuple arguments need to use `case` to destructure them. That's going to be fixed in Scala 3, but for now we'll just have to live with it.

```scala
def popOption: Option[(A, Ring[A])] = queue.dequeueOption.map {
  case (h, t) => (h, Ring(capacity, size - 1, t))
}
```

Here's the final code listing, with the constructor made private as it's easy to make mistakes using it which violate the invariants of the class, and instead a couple of factory methods in the companion object to construct empty rings or rings with initial elements.

```scala
import scala.collection.immutable.Queue

case class Ring[+A] private (capacity: Int, size: Int, queue: Queue[A]) {
  def push[B >: A](b: B): (Option[A], Ring[B]) =
    if (size < capacity) (None, Ring(capacity, size + 1, queue.enqueue(b)))
    else queue.dequeue match {
      case (h, t) => (Some(h), Ring(capacity, size, t.enqueue(b)))
    }

  def pop: (A, Ring[A]) = popOption.getOrElse(throw new NoSuchElementException)

  def popOption: Option[(A, Ring[A])] = queue.dequeueOption.map {
    case (h, t) => (h, Ring(capacity, size - 1, t))
  }
}

object Ring {
  def empty[A](capacity: Int): Ring[A] = Ring(capacity, 0, Queue.empty)

  def apply[A](capacity: Int)(xs: A*): Ring[A] = {
    val elems = if (xs.size <= capacity) xs else xs.takeRight(capacity)
    Ring(capacity, elems.size, Queue(elems: _*))
  }
}
```

I chose to use multiple parameter lists for `apply` because otherwise a ring which is initialised with integer elements is confusing as the capacity blends into the elements:

```scala
val ring = Ring(4, 3, 2, 1) // single parameter list; which is the capacity?

val ring = Ring(4)(3, 2, 1) // multiple parameter lists; capacity is clear
```

## Performance

I said this would be an efficient implementation, and it is. All of the operations have amortized O(1) performance in both time and space. However, it can be tricky to understand why this is. First, we need to understand the implementation of immutable queues.

The trick to an efficient immutable queue is using a pair of singly-linked lists, one as an input buffer, and one as an output buffer.

    in:   []
    out:  []

As elements are enqueued a new node is prepended to the input buffer which is an O(1) operation because it just requires a couple of pointer changes. Enqueuing `1`, `2`, `3` then `4` would cause the buffers to look like this:

    in:   [4]->[3]->[2]->[1]->[]
    out:  []

If we now want to pop an element it would be inefficient to take the last element of the input buffer as that's an O(N) operation for a single element. Instead the input buffer is reversed and stored as the output buffer, which is an O(N) operation:

    in:   []
    out:  [1]->[2]->[3]->[4]->[]

It's now possible to pop up to four elements from the output buffer as O(1) operations because popping the head off a singly linked list is O(1).

As such, for N elements enqueued and dequeued there are 2N O(1) operations and 1 O(N) operation. Here the O(N) reverse operation is equivalent to N O(1) operations so overall enqueue/dequeue is equivalent to 3N O(1) operations for N elements, or 3 O(1) operations per element. As constant factors (i.e. the 3) aren't considered in big-O notation this means the operations are _amortized_ O(1). Amortized means that not every operation will be O(1), but that the overall performance works out that way.

As our ring is implemented entirely in terms of enqueuing and dequeueing elements with no loops, this analysis must therefore apply to our ring so we can see that its operations are also amortized O(1).

## Summary

This post walks through the process of building a ring buffer in Scala, but the actual class itself isn't the important thing. What I want to show is the process for developing in very strongly typed languages, which differs significantly from dynamic languages where the approach tends to be evolutionary, or less strongly typed languages where the types don't play as big a part:

1. Define your requirements
2. Model your requirements as types
3. Fill in the implementation

Even though Scala is statically typed, as we've seen the type system usually can't encode all the information in your requirements, and it doesn't encode information about runtime performance. This means you still need tests to make sure the class obeys the specification, and you still need to analyse and measure the performance to ensure it's sufficient. Where exactly in the process you do these things doesn't matter too much (to me, anyway) as long as you do them.



[^1]: For a much more thorough treatment of covariance and contravariance, read [Eric Lippert's eleven-part series](https://blogs.msdn.microsoft.com/ericlippert/2007/10/16/covariance-and-contravariance-in-c-part-one/) on the subject. It's written with C# in mind but everything is applicable to Scala too. It's much more complicated than you might think. Even then, that's only dealing with the _natural_ variance of the parameter; in certain advanced cases you may want to override the compiler's checks by using the `@uncheckedVariance` annotation.

[^2]: It's not strictly correct to say supertype here, as the `>:` constraint actually imposes that the type is 'bigger' without necessarily implying an inheritance relationship. For example, `Animal` is a bigger type than `Giraffe` because there are more types that fit within it and there is an obvious subtyping relationship, but `List[Animal]` is a bigger type than `List[Giraffe]` because they are assignment-compatible even though there is no subtyping relationship. Most of the time this distinction isn't important.
