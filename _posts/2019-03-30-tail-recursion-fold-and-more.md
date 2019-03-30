---
layout: post
title: Tail recursion, fold, and more
date: 2019-03-30
tags: fp scala scala-101
author: gregbeech
comments: true
---

People new to functional languages often struggle a bit with the concept of recursion, and in particular tail recursion. In this post we'll look at both recursive and tail recursive functions using the substitution model to show their effect on the stack. We'll also walk through deriving `fold`, `map`, and other functions from first principles because it fairly naturally follows on from this.

To start with let's write a recursive function to sum a list:

```scala
def sum(list: List[Int]): Int = list match {
 case Nil => 0
 case x :: xs => x + sum(xs)
}
```

Like most recursive functions we have two cases. The base case of an empty list (`Nil`) has a sum of zero, and when this case is reached the function stops recursing. The inductive case breaks the problem down into two smaller problems by defining the sum as the first element plus the sum of the rest of the elements, so each time this case is hit it will recurse by calling itself.

This function works fine for small lists, but unfortunately once we start trying it with larger lists it overflows the stack and errors.

```scala
sum(List.range(1, 1000))   // 499500
sum(List.range(1, 10000))  // java.lang.StackOverflowError
```

To see why this is we can substitute some real values and examine how the function executes. For a four element list the steps would be as follows:

    sum([1, 2, 3, 4])
    1 + sum([2, 3, 4])
    1 + 2 + sum([3, 4])
    1 + 2 + 3 + sum([4])
    1 + 2 + 3 + 4 + sum([])
    1 + 2 + 3 + 4 + 0
    1 + 2 + 3 + 4
    1 + 2 + 7
    1 + 9
    10

Each time the function executes it stores the current value of `x` in its stack frame, and then runs `sum` on the rest of the list in a new stack frame. This gives rise to the distinctive triangle shape as the stack grows with the list length, and then unwinds to compute the results. For longer lists more stack frames are allocated and so with a long enough list the stack will overflow. The default stack on the 64-bit JVM is only 1MB so a few thousand frames will typically do it.

Let's look at an alternative way of writing the function, which accumulates the result as it recurses using a helper function. Here `loop` is the recursive function, and `sum` is a wrapper to keep the desired method signature that just starts the first loop iteration.

```scala
def sum(list: List[Int]): Int = {
  def loop(acc: Int, rest: List[Int]): Int = rest match {
    case Nil => acc
    case x :: xs => loop(acc + x, xs)
  }
  loop(0, list)
}
```

Using the substitution approach again, we can see that this has a different execution profile because there is no operation after the call to `loop`; each function in the stack just returns the value from the recursive call. This pattern of having the recursive call as the last operation the function performs is known as tail recursion.

    sum([1, 2, 3, 4])
      loop(0, [1, 2, 3, 4])
        loop(1, [2, 3, 4])
          loop(3, [3, 4])
            loop(6, [4])
              loop(10, [])
            10
          10
        10
      10
    10

The reason tail recursive functions are important is that due to there being nothing to do after the recursive call, rather than adding a new stack frame for the recursive call the compiler can _replace_ the current stack frame for that call. This is known as tail-call optimisation, and means the stack usage actually looks like this:

    sum([1, 2, 3, 4])
      loop(0, [1, 2, 3, 4])
      loop(1, [2, 3, 4])
      loop(3, [3, 4])
      loop(6, [4])
      loop(10, [])
      10
    10

The stack depth is now constant regardless of the list length, so the function succeeds for any list:

```scala
sum(List.range(1, 1000))   // 499500
sum(List.range(1, 10000))  // 49995000
```

One thing we should also do is add the `@tailrec` annotation to the `loop` function. This is a compiler instruction which tells the compiler that it must perform tail-call optimisation on the function, or fail if it cannot. The Scala compiler will perform tail-call optimisation where possible anyway, so the annotation is more a safety check for the programmer.

```scala
def sum(list: List[Int]): Int = {
  @tailrec def loop(acc: Int, rest: List[Int]): Int = rest match {
    case Nil => acc
    case x :: xs => loop(acc + x, xs)
  }
  loop(0, list)
}
```

There are loads of other functions we can write using a similar tail recursive approach. For example, here's a function to find the maximum value in a list:

```scala
def max(list: List[Int]): Int = {
  @tailrec def loop(acc: Int, rest: List[Int]): Int = rest match {
    case Nil => acc
    case x :: xs => loop(acc max x, xs)
  }
  loop(0, list)
}
```

This looks very similar to `sum` though. In fact the only difference is what we do to the numbers to accumulate them, so as good programmers we should factor that out into a higher-order function, which we call `fold`. To make it more general purpose we also factor out the seed value that the accumulator starts with. Note that the function `f` is in a second parameter list to help with Scala's flow-based type inference.

```scala
def fold(list: List[Int], seed: Int)(f: (Int, Int) => Int): Int = {
  @tailrec def loop(acc: Int, rest: List[Int]): Int = rest match {
    case Nil => acc
    case x :: xs => loop(f(acc, x), xs)
  }
  loop(seed, list)
}

def sum(list: List[Int]): Int = fold(list, 0)(_ + _)
def max(list: List[Int]): Int = fold(list, 0)(_ max _)
```

This is great for list of integers, but it can be generalised further to work on any kind of list, and to return a value that might be a different type to what's contained in the list by introducing some generic types.

```scala
def fold[A, B](list: List[A], seed: B)(f: (B, A) => B): B = {
  @tailrec def loop(acc: B, rest: List[A]): B = rest match {
    case Nil => acc
    case x :: xs => loop(f(acc, x), xs)
  }
  loop(seed, list)
}
```

Using this more generalised definition we can get some interesting results, e.g. starting with an empty list and appending to it we can get the list out again, possibly with changes. (NB: Don't use `:+` with `List[A]` in Scala because it's very inefficient; this is a theoretical implementation rather than one optimised for performance.)

```scala
fold(List(1, 2, 3, 4), List.empty[Int])((xs, x) => xs :+ x)      // List(1, 2, 3, 4)
fold(List(1, 2, 3, 4), List.empty[Int])((xs, x) => xs :+ x + 1)  // List(2, 3, 4, 5)
fold(List(1, 2, 3, 4), List.empty[Int])((xs, x) => xs :+ x * x)  // List(1, 4, 9, 16)
```

Once again these look remarkably similar with only the transformation applied to `x` differing, so we can capture this pattern in another higher-order function, commonly known as `map`. It turns out `map` is just a specialised form of `fold`.

```scala
def map[A, B](list: List[A])(f: A => B): List[B] =
  fold(list, List.empty[B])(_ :+ f(_))
```

In fact most list functions can be written as a specialised form of fold. You wouldn't want to write them quite like this as the `:+` and `++` operators have O(N) performance on lists, and functions like `contains` or `find` ought to short-circuit. However, it's interesting to see that `fold` is really the base abstraction for many more common operations.

```scala
def contains[A](list: List[A])(f: A => Boolean): Boolean =
  fold(list, false)(_ || f(_))

def find[A](list: List[A])(f: A => Boolean): Option[A] =
  fold(list, Option.empty[A]) {
    case (None, a) if f(a) => Some(a)
    case (acc, _) => acc
  }

def flatMap[A, B](list: List[A])(f: A => List[B]): List[B] =
  fold(list, List.empty[B])(_ ++ f(_))

def length[A](list: List[A]): Int =
  fold(list, 0)((n, _) => n + 1)

def reverse[A](list: List[A]): List[A] =
  fold(list, List.empty[A])((xs, x) => x :: xs)

def take[A](list: List[A], n: Int): List[A] =
  fold(list, List.empty[A])((xs, x) => if (length(xs) < n) xs :+ x else xs)
```

Even these functions can be generalised further to operate on any effect `F[A]` rather than just `List[A]` which is where libraries like [cats](https://typelevel.org/cats/) come in. But we're already veering way off topic so let's call it a wrap.
