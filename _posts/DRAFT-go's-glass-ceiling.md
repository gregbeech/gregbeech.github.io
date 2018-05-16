---
layout: post
title: Go's Glass Ceiling
date: 2018-05-16
tags: languages go
author: gregbeech
comments: true
---

Go is becoming increasingly popular, including within Deliveroo, and I find it quite troubling. It's taken me quite a while to work out why that is, and quite a few drafts to try and express it in a way that gets my point across. This is not a "Go is bad" post. That's been done to death and I don't want to rehash it. I also have no intention of disparaging people who like Go; doing so would be self-defeating given it's them this post is _really_ aimed at.

## Go's design goals

To discuss Go we need to understand the environment for which it was designed. In the Go FAQ there's a fairly long document that describes the [design goals of the language](https://talks.golang.org/2012/splash.article) but this quote from one of the author's talks really elucidates the most important consideration:

> The key point here is our programmers are Googlers, they’re not researchers. They’re typically, fairly young, fresh out of school, probably learned Java, maybe learned C or C++, probably learned Python. They’re not capable of understanding a brilliant language but we want to use them to build good software. So, the language that we give them has to be easy for them to understand and easy to adopt. --- [_Rob Pike_](https://channel9.msdn.com/Events/Lang-NEXT/Lang-NEXT-2014/From-Parallel-to-Concurrent)

This shows us the target audience for the language, but it's not the whole story. The other thing we need to consider is the average tenure of engineers at Google. I haven't been able to find a tenure specifically for engineers, but in 2013 around when Go was introduced the average tenure for Google employees was [just 1.1 years](https://www.geekwire.com/2013/amazon-google-employees-ranked-least-loyal/). Even if we hypothesise that engineers perhaps stay longer than other types of employee, it's still likely only a couple of years tenure on average.

Why does tenure matter? Well, if the average tenure of employees is long then you can assume they'll be around help future hires work on and understand existing software and any complex concepts that it uses, which levels them up. That means it's worth investing in people for the long term, training them, and ensuring that their skills are continuously improving so they can use them to write better software and pass the skills on. It's a virtuous cycle.

However, if tenure is short, then the opposite is true. You can't assume they'll be around to help people understand existing software or pass on their skills. Software needs to be written in a more basic way that people can understand without needing to level up, and it isn't really worth investing in people because not only will they not be around, but they'll quite possibly be at a competitor. Instead you want to get the most out of them _now_ without worrying about their future development.

A key design goal of Go, therefore, is not only to make it easy for inexperienced programmers to get to grips with it, but also to constrain what they can do with the language in order to ensure that the software stays written in a basic manner.

## Go's omissions

Go is often criticised for lacking many features of modern languages such as data structures, user-definable generics, exceptions, immutability, enumerations, macros, and so on. Rather than examine all of them, let's just have a look at generics and error handling and see what we can learn.

The omission of user-definable generics is a good place to start. There's a fairly long document that outlines the [summary of Go generics discussions](https://docs.google.com/document/d/1vrAy9gMpMoS3uaVphB32uVXX4pi-HnNjkMEgyAHX4N4) but the evidence points to one main reason that generics haven't been added:

> 1. (The C approach.) Leave them out. This slows programmers. But it adds no complexity to the language. --- [_Russ Cox_](https://research.swtch.com/generic)

Go does have a few generic types built into the language: Arrays, maps, slices and channels are all generic types. However, these generic types don't have any of the higher-order functions you'd expect to find such as `Filter` or `Map` or `Fold`.

You could write them yourself, of course, but without generics they would have to operate on the `interface {}` type and thus sacrifice type safety, which isn't something you tend to want in a statically typed languages. Rob Pike has actually got [an example library of these functions](https://github.com/robpike/filter) but dismisses it with the following comment:

> I haven't had occasion to use it once. Instead, I just use "for" loops. You shouldn't use it either.

The omission of higher-order functions was clearly a decision rather than something that just wasn't thought of. It's clear that the language designers do not want to facilitate the style of programming that generics allow. They'd rather programmers stuck to basic data structures like maps and lists, and use for loops than higher-order functions.

Let's move onto error handling, which also receives a lot of criticism in Go for the repetitive nature of checking whether an error object is returned. I also [prefer not to use exceptions](/2018/02/09/modelling-errors-in-scala/), but arguing about return codes vs exceptions rather misses the point. There are much better options that could be implemented without significant changes to the language.

For example, rather than the convention of returning a 2-tuple of `(result, error)` the standard library could include a `result[success]error` generic type with success/error cases. However, this would arguably necessitate sum types (aka enumerations) and exhaustiveness checking on switch statements. The various discussions around enumerations in Go seem to take the stance that they would add unnecessary complication to the language and constants are "good enough".

But even without introducing a generic result type the compiler could include syntactic sugar based on some very simple heuristics. You could take inspiration from Rust and introduce an early return operator `?` so a statement like `result := Foo().?` would expand to:

```go
result, err := Foo()
if err != nil {
        return err
}
```

Alternatively you could take inspiration from F# or Elixir and introduce a pipeline operator `|>` so a statement like `result, err := Foo() |> Bar()` would expand to:

```go
res0, err0 := Foo()
if err0 != nil {
        return err0
}

result, err := Bar(res0)
```

These wouldn't need any significant changes to the core language and would work with most existing code. However, it makes the language slightly less explicit and slightly more complicated; if higher-order functions are off the menu then so is this kind of syntactic sugar. And---of course---you can't add them yourself unlike Rust or Elixir because Go doesn't have a macro system.

We could go on to look at other omitted features, but they all follow the same pattern. Any feature that allows meaningful abstraction is omitted so that the _mechanics_ of how the code works must be spelled out in full, and the tools to provide that abstraction are either limited to Go itself (e.g. generics) or omitted entirely (e.g. macros). This means that even the most inexperienced of programmers can follow the code, but at the cost of much repetition.

## How programmers learn

Why am I so troubled by the rise of Go then?

We need to go back twenty years to when I was Go's target audience. Back then I'd done a load of programming in Visual Basic 6 and was fairly happy with it. The lack of true object-orientation bothered me a bit (you couldn't inherit from other classes, only interfaces) but it was fine; I just dealt with it. The lack of generics and concurrency? I'd never heard of either of them.

I then discovered C# and Java and it was mindblowing! There still weren't any generics but there was true object orientation and threading. With actual threads and mutexes and volatiles and mutable collections of course; this was still the old days. I read and I experimented, and I started to understand all these concepts I'd never even heard of before. It was amazing.

Generics came along and---wow---we didn't need to copy/paste collection templates for type-safe code any more. They were just built into the language. And later came generic variance, iterators and a whole bunch of other features that introduced me to new concepts.

Then came the big one. Language Integrated Query, or Linq for short. I didn't know where this stuff came from, but suddenly it was possible to filter or change collections without needing to write for loops. We could also write our own providers and build Linq-to-anything. So I did. At work, in my spare, time, basically any chance I got.

My curiousity was insatiable. While researching where all this Linq stuff came from I stumbled upon other languages like Haskell and Scheme and Scala and OCaml and all these other languages that had features and approaches that I simply didn't know existed. Didn't even know _could_ exist. I started learning them all! I just couldn't get enough of them. And I realised I could apply many of the concepts I learned from these languages to C# in my day job, so I did, and I taught the people around me too.

That continues to this day. I've programmed professionally in numerous languages, but learned many more in my spare time. By learning I don't necessarily mean I've written a huge amount of code in them, but it'll include things like reading the language spec, books about how to write them well, how the runtime works, what the ethos of the community is, and so on. Every single language I look at I can see at least some of the lineage, and I take some new ideas and approaches that I can apply in other scenarios.

It means that I can drop into pretty much any language and use it at a very high level with relative ease because so few concepts or idioms are new to me any more. It's made me a _much_ better programmer than I would otherwise have been.

But let's rewind again and imagine that instead of C# I'd picked up Go. It would have been similarly mindblowing to my young self. Better object-orientation than Visual Basic 6. Concurrency! Generic arrays and maps! What more could I have wanted? It would have taken everything I knew and then added a whole bunch of things I didn't.

But it would never have added generics. It would never have added higher-order functions. What it offers is on a plate and the language is so locked down that you can't really explore anything else. Even if you stumble upon these concepts in your spare time they take a lot of time and effort to learn. You can do your work just fine without them, so is it really worth the effort?

## Go's comfort blanket

And here's the rub. Go's documentation, in its justification of why the language omits so many features, does its best to explain that [they are too difficult or complex for you](https://golang.org/doc/faq). In fact, the FAQ includes the words "difficult" or "complex" sixteen times and "simple" or "simplifies" twenty:

> Your favorite feature may be missing because [...] it would make the fundamental system model too difficult.


> Generics are convenient but they come at a cost in complexity in the type system.



> Concurrency and multi-threaded programming have a reputation for difficulty.



> When a coroutine blocks, such as by calling a blocking system call, the run-time automatically moves other coroutines [...] so they won't be blocked. The programmer sees none of this, which is the point.

You're getting along perfectly fine in your day job. You can do everything you need to do with Go. Sure, it may be a bit clunky and repetitive at times but as the documentation says, that's better than having to learn anything _difficult_. And all these concepts you came across, you can't express them in Go anyway so there's no practical point to learning them. Plus words like "monad" and "applicative" are scary. Best just to leave all that difficult stuff to those silly type astronauts who want to make life hard for themselves.

It's pretty easy for most programmers to convince themselves of this. Paul Graham [wrote about the phenomenon](http://www.paulgraham.com/avg.html) all the way back in 2001.

So here's the thing. Those of us who have invested huge amounts of time and effort into learning higher level languages that have these complicated features generally prefer to use them over languages like Go. We have the capability to work in pretty much any language we want, and we choose higher level ones like Scala or (if you want a systems language) Rust instead of basic ones like Go.

Do you really think it's just because we want to make life hard for ourselves, or could there be something deeper than that? Could it be that learning these languages makes you a better programmer, and allows you to use better tools to write better software in a better way?

## What you're missing?

We haven't touched on what many people seem to believe is Go's killer feature yet: goroutines. However, goroutines are one of the worst concurrency abstractions that have ever been invented.



```go
var wg sync.WaitGroup
wg.Add(2)

c1 := make(chan A)
c2 := make(chan B)
errors := make(chan error, 1)
finished := make(chan bool, 1)

go func() {
        if res, err := A(); err != nil {
                c1 <- res
        } else {
                errors <- err
        }
        wg.Done()
}()

go func() {
        if res, err := B(); err != nil {
                c2 <- res
        } else {
                errors <- err
        }
        wg.Done()
}()

go func() {
        wg.Wait()
        close(finished)
}()

var a A
var b B
select {
case a1 := <- c1
        a = a1
case a2 := <- c2
        a = a2
case <- finished:
        return C(a, b)
case err := <- errors:
        return nil, err
}
```

Scala does this differently. It has generics. It has sum types. It has pattern matching. It has compiler syntactic sugar. It's a much more complex language than Go. It takes longer to learn. However, these three features combined do mean that you can write the equivalent of the above code like this:

```scala
for {
  List(a, b) <- Future.sequence(List(A(), B()))
} yield C(a, b)
```

If you're happy with Go, you'll never know the answer. And, more tragically, you'll probably never want to.

_That_ is what troubles me.
