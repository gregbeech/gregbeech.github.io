---
layout: post
title: Language choice
date: 2018-07-30
tags: languages scala ruby java c# go
author: gregbeech
comments: true
---

Choosing programming languages can be an emotive subject. All programmers have languages preferences,

## Constraining Factors

* **Compatibility** - e.g. FFI,
* **Startup Time** - e.g. lambdas
* **Concurrency** - e.g. scatter/gather


## Semi-Free Factors


* **Tooling** - e.g. existing constraints
* **Ecosystem** - e.g. libs for complex stuff
* **Performance** - e.g. realtime checks, sidecars


## Free Factors

* **Expressivity** - The breadth of ideas that can be communicated or represented in the language. More expressive languages typically let you create and compose more powerful abstractions, making it easier to manage intrinsic complexity.
* **Simplicity** - easier to learn, but
* **Type Safety** -
* **Compile Time** -



-------




## Expressivity

As a rough heuristic, you want a language with better tools to manage complexity when you have more intrinsic complexity to manage. As an even more rough heuristic you can approximate intrinsic complexity by looking at the proportion of code handling input/output (e.g. API endpoints, serialization, data access) relative to the amount of code implementing business logic, with a higher proportion of business logic being more intrinsically complex. A compiler is possibly the ultimate example of a program with limited IO and a lot of internal complexity; a CRUD web service probably pretty much at the other end.

Scala gives you tools to manage very high amounts of intrinsic complexity within a program such as sum types, monads/applicatives, pattern matching, implicits, clustering, etc. but the cost is that it's a complex language and thus if you use it for intrinsically simple things then you get a lot of unnecessary extrinsic complexity. So it's a very good fit for something like Identity which needs to handle a lot of intrinsic complexity from a few endpoints, but would be a less good fit for a CRUD service with little business logic, unless your team generally works in Scala and is thus familiar with it.

I'll rate a few languages I'm familiar with on a number of factors. These factors will not be equally weighted to you; which ones matter most depends on many things including your company and the developers you have.

* **Expressivity** - The breadth of ideas that can be communicated or represented in the language. More expressive languages typically let you create and compose more powerful abstractions, making it easier to manage intrinsic complexity.
* **Simplicity** -
* **Tooling** -
* **Ecosystem** -
* **Type Safety** -
* **Performance** -
* **Concurrency** -
* **Compile Time** -
* **Startup Time** -


## Ruby

    Expressivity ██████████████████████████████ 5/5
      Simplicity ████████████████████████ 4/5
         Tooling ████████████ 2/5
       Ecosystem ████████████████████████ 4/5
     Type Safety ██████ 1/5
     Performance ██████ 1/5
     Concurrency ██████ 1/5
    Compile Time ██████████████████████████████ 5/5
    Startup Time ██████████████████ 3/5

Great for building things fast, but not so good if you want them to execute fast.

## Go

    Expressivity ██████ 1/5
      Simplicity ████████████████████████ 4/5
         Tooling ████████████████████████ 4/5
       Ecosystem ████████████ 2/5
     Type Safety ██████████████████ 3/5
     Performance ████████████████████████ 4/5
     Concurrency ██████████████████ 3/5
    Compile Time ██████████████████████████████ 5/5
    Startup Time ██████████████████████████████ 5/5

Basically no expressive power. Easy to use as a result but loses a point for a bunch of design flaws such as nil interfaces. Type safety OK but no ADTs and errors are weakly typed. Performance is good but GC is not tuneable. Concurrency is possible but not composable so often not used in practice. Good startup time as generates native code.

Good when simplicity, tooling, and compile/startup time matter the most, e.g. places like Google that have a lot of new engineers and millions of lines of code.

## Scala

    Expressivity ██████████████████████████████ 5/5
      Simplicity ██████ 1/5
         Tooling ████████████ 2/5
       Ecosystem ████████████████████████ 4/5
     Type Safety ██████████████████████████████ 5/5
     Performance ████████████████████████ 4/5
     Concurrency ██████████████████████████████ 5/5
    Compile Time ██████ 1/5
    Startup Time ██████ 1/5

Pretty much the opposite of Go; good when you have a lot of complexity to manage and type safety, performance and concurrency are important.



## Java

    Expressivity ██████████████████ 3/5
      Simplicity ██████████████████ 3/5
         Tooling ████████████████████████ 4/5
       Ecosystem ██████████████████████████████ 5/5
     Type Safety ████████████████████████ 4/5
     Performance ████████████████████████ 4/5
     Concurrency ██████████████████ 3/5
    Compile Time ██████████████████ 3/5
    Startup Time ██████ 1/5

Verbose, no HK types, no async/await or comprehensions, does have ADTs (enums) and Optional but often not used.

Decent all-round choice. Good for pretty much everything, particularly if running in AWS.

## C\#

    Expressivity ████████████████████████ 4/5
      Simplicity ██████████████████ 3/5
         Tooling ████████████████████████ 4/5
       Ecosystem ██████████████████ 3/5
     Type Safety ████████████████████████ 4/5
     Performance ████████████████████████ 4/5
     Concurrency ██████████████████████████████ 5/5
    Compile Time ██████████████████ 3/5
    Startup Time ██████ 1/5

Expressiveness has Linq, iterators, async/await, data classes, unsafe, rudimentary pattern matching.

Like Java but better; probably the best general purpose language. Main downside is .NET Framework for many people.



## Choosing


