---
layout: post
title: Go's Glass Ceiling
date: 2018-05-25
tags: career languages go
author: gregbeech
comments: true
---

Go is becoming increasingly popular and I find it troubling. It's taken me quite a while to work out why that is, and quite a few drafts to try and express it in a way that gets my point across in what I hope is a fair and balanced way. This is not a "Go is bad" post. That's been done to death and I don't want to rehash it. I also have no intention of denigrating people who like Go; doing so would be self-defeating given it's them this post is really aimed at. This is a post about reaching your potential.

## Go's design goals

To discuss Go we need to understand the environment that it was designed for. In the Go FAQ there's a fairly long document that describes the [design goals of the language](https://talks.golang.org/2012/splash.article) but this quote from one of the author's talks really elucidates the most important consideration:

> The key point here is our programmers are Googlers, they’re not researchers. They’re typically, fairly young, fresh out of school, probably learned Java, maybe learned C or C++, probably learned Python. They’re not capable of understanding a brilliant language but we want to use them to build good software. So, the language that we give them has to be easy for them to understand and easy to adopt. --- [_Rob Pike_](https://channel9.msdn.com/Events/Lang-NEXT/Lang-NEXT-2014/From-Parallel-to-Concurrent)

This shows us the target audience for the language, but although young and inexperienced engineers is the obvious point it's not the whole story. Google hires thousands of engineers straight out of college every year and, as is common in this industry, they don't tend to stay around for long before moving to another company.

Short tenure combined with the necessity to hire thousands of engineers means that software needs to be written in a basic way that people can understand and change without having to spend time improving their skills or knowledge. You can't assume that the people who originally wrote the software will be around to help the next intake work on it, or pass on the skills they learned while doing so.

It isn't really worth investing in people because you know they won't be around for a long time, and they'll quite possibly be going to a competitor when they leave. Instead you want to get the most out of them _now_ without worrying about their future development.

Given this context, it seems reasonable to hypothesise that the key design goal of Go is not only to make it easy for inexperienced programmers to get to grips with it, but also to constrain what they can do with the language in order to ensure that software stays written in a basic manner. Can we find evidence to support this?

## Go's omissions

Go is often criticised for lacking many features of modern languages such as data structures, generics, exceptions, pattern matching, enumerations, immutability, macros, and so on.

Although Go doesn't have user-definable generics, it does have some built-in ones: map, slice (list), array and channel (thread-safe queue). The question I find most interesting is why they don't have any of the higher-order functions you'd normally expect to find such as `Filter` or `Map` or `Fold`. Although syntax doesn't exist to define these functions, they could have been provided and special-cased just like the built-in generic types.

You can't write them yourself either, as without user-definable generics they would have to operate on the `interface {}` type and thus sacrifice type safety, which isn't something you tend to want in statically typed languages. Rob Pike has actually got [an example library of this](https://github.com/robpike/filter) but dismisses it with the following comment:

> I haven't had occasion to use it once. Instead, I just use "for" loops. You shouldn't use it either.

Even if you're prepared to believe that there is no implementation of generics that's suitable for Go because they're either [too complex, too bloated, or too slow](https://research.swtch.com/generic), the omission of higher-order functions on generics looks to be a decision rather than something that just wasn't thought of.

Error handling also receives a lot of criticism for the repetitive nature of checking whether an error object is returned. I also [prefer not to use exceptions]({% post_url 2018-02-09-modelling-errors-in-scala %}), but arguing about return codes vs exceptions rather misses the point. There are much better options that could be implemented without significant changes to the language.

Go only has three return patterns by convention (`result`, `result, error` or `error`) so the compiler could easily implement some syntactic sugar. You could take inspiration from Rust and introduce an early return operator `?` so a statement like `result := Foo().?` would expand to:

```go
result, err := Foo()
if err != nil {
        return _, err
}
```

Alternatively you could take inspiration from F# or Elixir and introduce a pipeline operator `|>` so a statement like `result, err := Foo() |> Bar()` would expand to:

```go
res0, err0 := Foo()
if err0 != nil {
        return _, err0
}

result, err := Bar(res0)
```

These wouldn't need any significant changes to the core language, would barely slow compilation due to the very simple heuristics needed, wouldn't inflate the binary size at all, and would work with all existing code. Why hasn't something like this been implemented?

There's a theme here.

We could go on to look at other omitted features, but they all follow the same pattern. Any feature that allows meaningful abstraction is omitted so that the _mechanics_ of how the code works must be spelled out in full. This means that even the most inexperienced of programmers can follow how the code works, but at the cost of much repetition.

> (The C approach.) Leave them [generics] out. This slows programmers. But it adds no complexity to the language. --- [_Russ Cox_](https://research.swtch.com/generic)

The evidence appears to support the hypothesis that Go is deliberately constrained to ensure software can only be written in a basic manner with the mechanics firmly on display.

Does it matter if we have to build software in a more basic way though? Isn't it a good thing if anybody can just pick software up, read it, follow the code, and work on it? Well, yes and no.

It matters because the complex features in more powerful languages allow you to build _abstractions_.

## Why abstraction matters

Rather than just explain, I'll demonstrate with something that Go ought to be good at given its positioning as a language for building microservices: A parallel scatter/gather. This isn't a contrived example; it's the kind of thing that's extremely common in distributed architectures, for example collecting user data from one service and order data from another in order to present an account page.

Imagine we have three functions `fetchUser`, `fetchOrders` and `renderPage` that return types `User`, `[]Order` and `Page` respectively. `fetchUser` and `fetchOrders` perform IO (e.g. a HTTP GET) and thus may be slow and may fail (e.g. network error) but are independent and so can be called in parallel. `renderPage` is fast but needs the results from `fetchUser` and `fetchOrders`.

In Go, assuming we want to keep type safety, and handle errors properly by passing them up the call stack rather than just logging and ignoring them, modelling this is going to look something like:

```go
var wg sync.WaitGroup
wg.Add(2)

chanU := make(chan User, 1)
chanO := make(chan []Order, 1)
errors := make(chan error, 1)
finished := make(chan bool, 1)

go func() {
        if res, err := fetchUser(); err == nil {
                chanU<- res
        } else {
                errors<- err
        }
        wg.Done()
}()

go func() {
        if res, err := fetchOrders(); err == nil {
                chanO<- res
        } else {
                errors<- err
        }
        wg.Done()
}()

go func() {
        wg.Wait()
        close(finished)
}()

var user User
var orders []Order
for {
        select {
        case u := <-chanU:
                user = u
        case o := <-chanO:
                orders = o
        case <-finished:
                return renderPage(user, orders)
        case err := <-errors:
                return _, err
        }
}
```

There's a lot of code here, but there's nothing complex. Once you know that `chan` is just a thread-safe queue and `select` is a special form of switch that matches whichever channel has something available first you can probably work out what's happening even if you've never seen Go before.

Now let's see the same thing modelled in a higher level language, Scala:

```scala
Apply[Future].map2(fetchUser, fetchOrders)(renderPage)
```

You might not be able to understand this code just by looking at it. This code uses many abstractions including higher-kinded generic types, immutable types, sum types, implicits, typeclasses, higher-order functions, currying and method values. The code is much shorter, but conceptually there's much more going on here.

However, once you _do_ understand some of the underlying concepts, it's much more obvious what's going on because you only have to scan one line, and it's much more obviously _correct_ because there aren't any mechanics to get wrong.

This is the power of abstraction. This just shows a single example in isolation, but when you start building larger programs it starts to matter more. By building abstractions and composing them the program stays manageable _overall_ because you can keep the number of concepts you have to reason about at any point relatively small, which [matters to humans](https://en.wikipedia.org/wiki/The_Magical_Number_Seven,_Plus_or_Minus_Two). The fewer or worse your abstractions, the more state you have to maintain to understand the overall flow of the code.

So how can you learn to write code at a higher level of abstraction?

## How programmers learn

I've been writing software for over two decades, and professionally for seventeen years as an engineer, as a lead, and as a manager. I've worked with hundreds of people, so I've seen how a broad section of industry programmers learn. The answer shouldn't surprise you: they learn on the job.

I'll tell you my story.

Twenty years ago I'd done a lot of programming in Visual Basic 6 and was fairly happy with it as a language. The lack of true object-orientation bothered me a bit (you couldn't inherit from other classes, only interfaces) but it was fine; I just dealt with it. The lack of generics and concurrency? I'd never heard of either of them.

Then I discovered C# and it was mindblowing! There weren't any generics yet but there was true object orientation and threading. With actual threads and mutexes and volatiles and mutable collections (this was still the old days). I read and I experimented, and I started to understand all these concepts I'd never even heard of before.

Generics came along and---wow---we didn't need to copy/paste collection templates for type-safe code any more. They were just built into the language. The next year came generic variance, iterators and then Linq which let you filter or transform collections without needing to write for loops, and chain all the methods together to express your _intent_ more clearly.

Eventually I got to the point where I found C#'s type system frustrating because it just couldn't express many of the things I wanted to. Later, when I started using Scala on a daily basis I'd finally understand higher-kinded types and typeclasses and unlock a new set of abstractions I could use to solve problems.

As my interest in languages increased I spent my spare time learning others. Scheme, Haskell and Rust are among some of the more interesting, but I've studied just about every popular language and other far more esoteric ones. I've never got good at any of them though, because like many developers I'm pragmatic and struggle to get too invested in something I can't use in my day job.

Of course, that's just my story, and it differs for everybody [depending on your philosophy](https://josephg.com/blog/3-tribes/). However, the important point is that everybody learns by doing and there are very few people who understand programming concepts well unless they've used them repeatedly in their day job. That's because programming is difficult. It takes a lot of work to be able to understand these concepts, and a lot of practice to be able to apply them to build nontrivial abstractions.

Let me repeat that: Programming is difficult.

## Go's comfort blanket

Rewind back to 2001 and imagine that instead of C#, Go was the hot new language on the block.

It would have been similarly mindblowing to my younger self. Better object-orientation than Visual Basic 6. Concurrency! Generic lists and maps! What more could I have wanted? It would have taken everything I knew and then added a whole bunch of things I didn't.

It would have had everything I needed.

But it wouldn't have had any of the things I didn't know I needed. It wouldn't have had generics. It wouldn't have had higher-order functions. It wouldn't have had typeclasses. It wouldn't have had pattern matching. It wouldn't have had metaprogramming. It wouldn't have had macros. It wouldn't have had any of the tools that I now take for granted to build abstractions.

And here's the rub. Go's documentation, in its justification of why the language omits so many features, does its best to explain that [they are too difficult or complex for you](https://golang.org/doc/faq). In fact, the FAQ includes the words "difficult" or "complex" sixteen times and "simple" or "simplifies" twenty:

> Programming had become too difficult and the choice of languages was partly to blame.


> Generics are convenient but they come at a cost in complexity in the type system.


> Concurrency and multi-threaded programming have a reputation for difficulty.


> Your favorite feature may be missing because [...] it would make the fundamental system model too difficult.

It's comforting to believe it.

You're getting along perfectly fine in your day job. You can do everything you need to do with Go. Sure, it may be clunky and repetitive but as the documentation says, that's better than having to learn anything _difficult_. And concepts like "monads" and "applicatives" can't be expressed in Go anyway so there's no practical point to learning them. Plus they have scary names. Best to leave all that difficult stuff to those silly type astronauts who want to make life hard for themselves with their category theory nonsense.

It's pretty easy for most programmers to convince themselves of this. Paul Graham [wrote about the phenomenon](http://www.paulgraham.com/avg.html) all the way back in 2001, using a hypothetical language called Blub for illustration:

> As long as our hypothetical Blub programmer is looking down the power continuum, he knows he's looking down. Languages less powerful than Blub are obviously less powerful, because they're missing some feature he's used to. But when our hypothetical Blub programmer looks in the other direction, up the power continuum, he doesn't realize he's looking up. What he sees are merely weird languages. He probably considers them about equivalent in power to Blub, but with all this other hairy stuff thrown in as well. Blub is good enough for him, because he thinks in Blub.

But here's the thing. Those of us who have invested huge amounts of time and effort into learning higher level languages that have these complicated features generally prefer to use them over languages like Go. We have the capability to work in pretty much any language we want, and we choose higher level ones like Scala or Ruby or Rust instead of basic ones like Go.

Do you really think it's just because we want to make life hard for ourselves, or could there be something deeper than that? Could it be that learning these languages and concepts makes you a better programmer, and lets you build software in a way that's _ultimately_ simpler by creating high level abstractions and composing them?

If you're happy with Go, you'll probably never know the answer. And, more tragically, you'll probably never want to.

_That_ is what troubles me.

An entire generation robbed of the chance to reach their potential.
