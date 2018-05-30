---
layout: post
title: Sized ring buffer in Scala
date: 2018-05-30
tags: collections learning scala
author: gregbeech
comments: true
---


## Stronger interface definition

All of the problems in the ring's interface occur because we need to cater for the differing behaviour based on size or capacity. If we could assert that operations such as `pop` are only possible when the ring is non-empty then we could make a much stronger interface that would fail at compile time if you attempted to perform illegal operations.

Using [shapeless](https://github.com/milessabin/shapeless), we can. The `Nat` type represents a type that is a natural number, so we can encode them into the ring type which will let us make other assertions about what's possible on it.

```scala
class Ring[+A, C <: Nat, S <: Nat](implicit cap: LT[_0, C])
```

This encodes the capacity and size as type parameters, with an implicit constraint that `_0` (the singleton type of the integer zero) must be less than `C`. The class definition isn't quite complete because it should also have `ls: LTEq[_0, S], hs: LTEq[S, C]` constraints to prove 0 <= S <= C. I'll come back to this as we go through.



Now onto our push method. We can use the `LT` type to encode our assertion that an element can only be pushed if the size is less than the capacity, and the `Succ` type to encode that the size is increased by one (i.e. it is the successor of the previous size):

```scala
def push[B >: A](b: B)(implicit ev: LT[S, C]): Ring[B, C, Succ[S]] = ???
```

If the capacity is equal to the size then we know we need to pop an element when a new one is pushed, but the size will stay the same. The `=:=` constraint can be used to encode this assertion. I've named the method `pushPop` partly because Scala can't resolve overloads based solely on differing implicit types, and partly due to [nostalgia](https://en.wikipedia.org/wiki/Push_Pop).

```scala
def pushPop[B >: A](b: B)(implicit ev: S =:= C): (A, Ring[B, C, S]) = ???
```

And finally we can only pop when there is at least one element. This could be encoded using the `LT` class again to ensure that the size is greater than zero, but as we also want to assert that the final size is one less than the current size the `Pred` (predecessor, or one less) class is a better choice.

```scala
def pop(implicit ev: Pred[S]): (A, Ring[A, C, ev.Out]) = ???
```

Once the types are defined the implementation is far less complex than the previous attempt because the types are doing most of the work for us.

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
  def empty[A, C <: Nat](implicit c: LT[_0, C]) = new Ring[A, C, _0](Queue.empty)
}
```

Now we can only use the collection in ways that are statically verifiable as safe:

```scala
val r0 = Ring.empty[String, _2]
val (v0, r1) = r0.pop // this line will not compile
```

> Error: could not find implicit value for parameter ev: shapeless.ops.nat.Pred[shapeless._0]

```scala
val r0 = Ring.empty[String, _2]
val r1 = r0.push("1")
val r2 = r1.push("2")
val r3 = r2.push("3") // this line will not compile
```

> Error: could not find implicit value for parameter ev: shapeless.ops.nat.LT[shapeless.Succ[shapeless.Succ[shapeless._0]],shapeless.nat._2]

OK, they're not the nicest error messages in the world, but they're still better than runtime errors.


but it turns out that this makes the implementation painful. because given `LT[S, C]` the types in shapeless cannot automatically prove that `LTEq[Succ[S], C]]` even though logically that must hold. Also when `S =:= C` the `LT[_0, S]` and `LT[_0, C]` are ambiguous.



These could be `erased` types in Scala 3.
