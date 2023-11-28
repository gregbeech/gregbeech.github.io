---
layout: post
title: Strengthen your types
date: 2021-06-28
tags: [languages, types, scala]
author: gregbeech
comments: true
---

"Static typing" and "strong typing" are frequently conflated, as for many people a statically typed language implies that programs written with it must also be strongly typed. That's notionally true as the variables themselves have types, not just the values, but I'd argue that most statically typed programs are actually fairly weakly typed.

That’s a bold claim, so I’ll spend the next few minutes justifying it.

To begin, we need to examine what we mean by strong and weak typing, and where better to start than JavaScript? Here are some vexing expressions taken from the infamous [wat talk](https://www.destroyallsoftware.com/talks/wat) which produce clearly nonsensical results:

```javascript
[] + []  // ""
[] + {}  // "[object Object]"
{} + []  // 0
{} + {}  // NaN
```

You can read the [detailed explanation of what’s happening](https://medium.com/dailyjs/the-why-behind-the-wat-an-explanation-of-javascripts-weird-type-system-83b92879a8db) if you like, but it comes down to JavaScript’s surprising implicit type conversions at runtime. To demonstrate that this is a consequence of weak typing rather than dynamic typing we can contrast the results with another dynamically typed language, Python, which doesn’t coerce types at runtime. Here the results are either sensible or the runtime raises a TypeError:

```python
[] + []  # []
[] + {}  # TypeError: can only concatenate list (not "dict") to list
{} + []  # TypeError: unsupported operand type(s) for +: 'dict' and 'list'
{} + {}  # TypeError: unsupported operand type(s) for +: 'dict' and 'dict'
```

Wikipedia says [there is no precise definition of what constitutes weak or strong typing](https://en.wikipedia.org/wiki/Strong_and_weak_typing) but hopefully those examples are sufficient to convince you that one of its definitions is a good baseline for considering a language weakly typed:

> A weakly typed language has looser typing rules and may produce unpredictable or even erroneous results

Assuming we can broadly agree on that definition, let’s get back to the business of showing that most statically typed programs are also weakly typed. Quite fantastically, we don’t need anything more complex than Hello World’s `greet` function to do so! Here’s what that might look like in Scala 3:

```scala
def greet(name: String): String = "Hello " + name + "!"
```

This is Scala so it’s statically typed, and at first glance it appears strongly typed because the parameter type is declared to be a `String`, the return type is also declared to be a `String`, and it clearly does return a `String`. We know the `+` operator will always be `String` concatenation in this context, so the function works as you’d expect:

```scala
greet("Alice")  // "Hello Alice!"
```

However, we can still call this function in ways that produce unpredictable or erroneous results. These might not be as unpredictable or erroneous as some of the JavaScript expressions — we’re not going to get `NaN`, for example— but they definitely aren’t the results we would like.

```scala
greet("  Alice  ")  // "Hello   Alice  !"
greet("")           // "Hello !"
greet(null)         // "Hello null!"
```

As such, it appears we need to modify our definition of weakly typed. It’s not just whether the language itself is weakly typed, but whether the program written in the language is weakly typed.

> A weakly typed **program** has looser typing rules and may produce unpredictable or even erroneous results

Here we demonstrably have a program with sufficiently loose typing rules that unpredictable or erroneous results are produced. Ergo, this program is weakly typed.

There are two key weaknesses in the parameter type.

Firstly it’s not really constraining the parameter type to be a `String` because `null` is not a `String` and passing `null` is permitted. By default in Scala 3 the `String` type actually means `String | Null`. However, by supplying the `-Yexplicit-nulls` compiler option we can strengthen the `String` type to mean exactly `String` so the final line of code won’t compile:

```scala
greet(null)  // [E007] Type Mismatch Error: Found: Null, Required: String
```

Secondly we’re not constraining the contents of the string to be valid, so we can pass in things like the empty string, or strings with leading or trailing whitespace. This problem could be solved without changing the types by adding branching logic to the greet function; from what I’ve seen over the last twenty years or so, this is the approach most people would use to solve it in most languages:

```scala
def greet(name: String): String =
  val trimmed = name.trim
  if trimmed != null && trimmed.nonEmpty then
    "Hello " + trimmed + "!"
  else
    ""

greet("Alice")      // "Hello Alice!"
greet("  Alice  ")  // "Hello Alice!"
greet("")           // ""
```

This looks better. Unfortunately we’ve moved the problem of unpredictable or erroneous results to the return type because the function’s type of `String` implies it will always return a greeting, but the empty string isn’t a valid greeting.

You might argue I’m picking nits here, but when it comes to using this function there’s nothing to indicate to the caller they may need to deal with this case so there’s a fair chance no greeting being displayed will be raised as a bug somewhere down the line, and it’ll be nontrivial to work out that it was an empty string that somehow got into the system causing it. Half a day gone.

We can fix this by strengthening the return type to an `Option[String]` which tells the caller that `greet` may not be able to construct a greeting if the input is invalid, i.e. it is a [partial function](https://wiki.haskell.org/Partial_functions) rather than a total function. Now when the function is used, the caller explicitly has to handle the failure case and decide what to do. Half a day back.

```scala
def greet(name: String): Option[String] =
  val trimmed = name.trim
  if trimmed != null && trimmed.nonEmpty then
    Some("Hello " + trimmed + "!")
  else
    None
    
greet("Alice")      // Some("Hello Alice!")
greet("  Alice  ")  // Some("Hello Alice!")
greet("")           // None
```

This function now arguably meets our definition of strongly typed, because whatever you pass into it, the result is predictable and it is hard to subsequently make erroneous use of it. So, we’re done, right?

No. Unfortunately not.

This function might now be hard to misuse, but to make it that way we’ve broken the single responsibility principle. It has the dual responsibilities of understanding what makes a name valid, and also formatting a greeting. This might not seem like too much of a problem, but over time it means other functions dealing with names will have to reimplement the same logic, might do it slightly differently, and in a long-lived codebase you’ll end up with numerous different implementations of the same basic concept and won’t know which is correct (if any).

The reason it’s having to break the single responsibility principle is because the types are _still_ too weak. So let’s strengthen them again and instead of name being a `String` introduce a proper `FirstName` type and move the validation into its smart constructor `fromString` to ensure that only valid instances can be constructed; this approach is sometimes called “making illegal states unrepresentable”:

```scala
object types:
  opaque type FirstName = String
  
  object FirstName:
    def fromString(name: String): Option[FirstName] =
      val trimmed = name.trim
      if trimmed != null && trimmed.nonEmpty then
        Some(trimmed)
      else
        None
      
import types.*

def greet(name: FirstName): String = "Hello " + name.toString + "!"

FirstName.fromString("Alice").map(greet)      // Some("Hello Alice!")
FirstName.fromString("  Alice  ").map(greet)  // Some("Hello Alice!")
FirstName.fromString("").map(greet)           // None
```

The above code might benefit from a little explanation. The `opaque type` line defines `FirstName` as being a `String` but because it’s `opaque` that fact isn’t known outside the container `types`, so if you try to call `greet("Alice")` then you’ll get a compilation error that `FirstName` was expected but `String` was found. However, inside the `types` object the equivalence of `FirstName` and `String` can be used to return a `String` as a `FirstName` after validation.

Here `FirstName.fromString` has the single responsibility of understanding what makes a first name valid, and `greet` has the single responsibility of formatting the greeting. Note that `greet` can go back to returning a `String` rather than an `Option[String]` because the input must always be valid, so it’s a total function rather than a partial function. We could go further than this and return a `NonEmptyString` or even a `Greeting` (and we should!) but I think you get the idea by now so that is left as an exercise for the reader.

These improvements might not appear to be much of a benefit in this little sample of code, but when additional functions need a first name they can reuse the same type, and won’t need to implement any argument validation, or negative tests for invalid input. The functions will have less branching which makes them easier to reason about, and the code will likely have fewer bugs as a consequence.

There are myriad other benefits to strengthening your types. The obvious one is that it makes the code more self-documenting which is a major benefit for readability and maintainability, especially in long-lived codebases where the original authors may no longer be around, or may be busy with other things.

It also helps to prevent trivial mistakes in code. If you had a method expecting a last name or an email address then if the types are all `String` you can pass one where another is expected and the compiler can’t help you. When you use distinct `FirstName`, `LastName`, and `Email` types then it’s not possible to mix them up.

A less obvious benefit is that it helps to enforce good architectural practices. If all your business logic deals with strong types rather than strings or integers then it forces validation of input up to the boundary layers where it should be, not merely by convention, but by necessity because you cannot call lower layers of code without doing so!

Returning to the claim that most statically typed programs are pretty weakly typed, I don’t have proof but I’ll take a bet that majority of the code written by the majority of people reading this looks much more like the initial version of the function with its weak `String` parameter and `String` result types than the final version with its strong types. That’s fine; I’m in that majority.

But there’s always time to make amends.

Any time you find yourself needing to validate arguments, give a function multiple responsibilities, or make a function partial rather than total, consider whether you can strengthen your types to remove those problems.

---

_[Originally posted on the Zego Product Engineering blog](https://zego.engineering/strengthen-your-types-7ed3e4cc4e9f)_
