---
layout: post
title: Modelling errors in Scala
date: 2018-02-09
tags: guidelines scala
author: gregbeech
comments: true
---

With functions that can fail, people tend to think there are two possible options, success or failure. This is what's modelled by Scala's `Try[A]` and `Future[A]` types, as well as plain old `try`/`catch`. However things aren't quite as simple as they might first appear. Let's go down the rabbit hole.

As a straw man, here's a function for looking up a user by identifier from some external data store.

```scala
def get(id: UserId): Future[User]
```

The success mode for this function is pretty obvious, that the user was found and returned. There are plenty of different failure modes though, for example:

- No user with that identifier exists
- The function was unable to connect to the data store
- The data store itself raised an error

Handling these exceptions might look something like this:

```scala
repo.get(id).recover {
  case e: KeyNotFoundException => // the user doesn't exist
  case e: IOException          => // error communicating with data store
}
```

But do we really want to treat these two failure modes in the same manner? The `IOException` is _truly_ exceptional in that we expect the data store to be there and if it isn't then alerts and corrective action are likely to be needed, whereas a key not being found is an expected scenario that the application should handle, especially if you have an API where people can provide arbitrary identifiers.

Most functions that can fail have two different failure modes, expected failures and exceptional failures. You should only use exceptions for the exceptional failures. Expected failures should be part of the type signature. Let's improve things by putting that fact into the signature of the method with an `Option[A]` type indicating that the function can succeed but may not return a user.

```scala
def get(id: UserId): Future[Option[User]]
```

Our `get` method's signature now accurately reflects its behaviour, so let's apply this logic to a function that can return multiple users within a city. It's possible that a city might contain no users so putting that knowledge into the type signature could look something like this:

```scala
def findByCity(id: CityId): Future[Option[List[User]]]
```

The trouble is that here we've actually modelled the failure mode for no users in two different ways (where `Nil` is the empty list):

```scala
findByCity(id).map {
  case None      => // no users found
  case Some(Nil) => // no users found
  case Some(xs)  => // some users found
}
```

Of course we could combine the negative cases into `None | Some(Nil)` but there's no need for the option type here as a `List[A]` can already model nothing being found by being empty. We can simplify the method signature without losing any semantics thus:

```scala
def findByCity(id: CityId): Future[List[User]]
```

Now let's move onto a more interesting case of creating a user, which doesn't have any useful result to return, assuming the user's identifier is created in the application layer:

```scala
def create(user: User): Future[Done]
```

I tend to use the Akka convention of returning `akka.Done` as a marker for methods that exist only for their side effects rather than `Unit` because I think it's clearer, and with Akka HTTP, Akka Streams and [Alpakka](https://developer.lightbend.com/docs/alpakka/current/) most projects likely include it as a dependency; if not then defining your own `Done` marker is a one-liner.

The problem with this function signature is that creation can also fail for expected reasons such as the key already existing, but we're sending that down the exceptional path. We can't sensibly use an `Option[Done]` to indicate expected failures as we did for `get` because `None` would then mean that the function wasn't done which is semantically incorrect. Enter the `Either[A, B]` type:

```scala
sealed trait ErrorCode
case object DuplicateKey extends ErrorCode
// etc. for other error codes

def create(user: User): Future[Either[ErrorCode, Done]]
```

This signature now encodes the expected failure modes as an error code, which is declared as a `sealed trait` so we can benefit from exhaustiveness checking when handling it, and leaves the exceptional failure modes to the future's failure path.

Most methods that can fail will fall into one of these three categories, so it seems like this post should be complete. But there's one more interesting case that's worth looking at, and it takes us much deeper down the rabbit hole.

If you're using something like DynamoDB which has fixed IOPS (input/output operations per second) then if you're over the limit you'll find you get throttled when you try to make a call. While you _could_ argue this is an exceptional condition as ideally your autoscaler would have prevented it, it's definitely a thing that's expected and something the app could recover from (e.g. by retrying, using a cache, returning less data, etc.) so it _ought_ to be modelled as an expected error.

The obvious application of this to our `get` method would be:

```scala
sealed trait ErrorCode
case object Throttled extends ErrorCode
// etc. for other error codes

def get(id: UserId): Future[Either[ErrorCode, Option[User]]]
```

This signature accurately encodes what could happen in the function into the types. However, nesting types this deeply can start to get a bit inconvenient when handling the result. Let's say we subsequently want to look up the addresses for the user, we'd ideally want to write:

```scala
for {
  user      <- userRepo.get(id)
  addresses <- addressRepo.findByUser(user)
} yield (user, addresses)
```

But unfortunately this gives us a compiler error because methods like `map` and `flatMap` (which is what the `for` comprehension above desugars to) only unwrap one layer so when we unwrap our `Future[Either[ErrorCode, Option[User]]]` type we get a `Either[ErrorCode, Option[User]]` as indicated in the error message:

    error: type mismatch;
     found   : Either[ErrorCode, Option[User]]
     required: User
               addresses <- addressRepo.findByUser(user)

The solution to this is monad transformers. Scary name, but not a scary concept, honest! You can look at any of our 'wrapper' types as having a success branch and a failure branch:

- `Future[A]` can be either `Success[A]` (success) or `Failure[A]` (failure)
- `Either[A, B]` can be either `Right[B]` (success) or `Left[A]` (failure)
- `Option[A]` can be either `Some[A]` (success) or `None` (failure)

All monad transformers do is unwrap multiple layers on the success branch; [`EitherT`](https://typelevel.org/cats/datatypes/eithert.html) unwraps eithers, and [`OptionT`](https://typelevel.org/cats/datatypes/optiont.html) unwraps options. You can stack transformers so an `OptionT(EitherT)` would unwrap an either and then an option; the innermost value is unwrapped by the outermost transformer.

Wrapping the function calls in these transformers automatically unwraps the layers so code similar to the above will work. Sadly with our option nested inside the either the code ends up looking pretty ugly and we've lost the logic of what we're trying to achieve in a mess of wrappers and type coercions. Great for the compiler, not so great for humans.

```scala
type MyEitherT[B] = EitherT[Future, ErrorCode, B]

for {
  user      <- OptionT(EitherT(userRepo.get(id)): MyEitherT[Option[User]])
  addresses <- OptionT.liftF(EitherT.right(addressRepo.findByUser(user)): MyEitherT[List[Address]])
} yield (user, addresses)
```

This is because `OptionT` requires an argument with a single type parameter, but `EitherT` has three type parameters. As such we need to define a type alias (here `MyEitherT`) which fixes two of the type parameters leaving only one unbound. The logic can be cleaned up significantly by implementing `apply` and `right` for `MyEitherT`, at the expense of more boilerplate:

```scala
type MyEitherT[B] = EitherT[Future, ErrorCode, B]

object MyEitherT {
  def apply[B](f: Future[Either[ErrorCode, B]]): MyEitherT[B] = EitherT(f)
  def right[B](f: Future[B]): MyEitherT[B] = EitherT.right(f)
}

for {
  user      <- OptionT(MyEitherT(userRepo.get(id)))
  addresses <- OptionT.liftF(MyEitherT.right(addressRepo.findByUser(user)))
} yield (user, addresses)
```

You could even take it further by defining a custom transformer that combines `OptionT` and `EitherT` but the fact is you can't just directly stack the transformers without some additional glue code.

What if we change the signature of the `get` method to treat the user not being found as an error code rather than encoding it in an option?

```scala
sealed trait ErrorCode
case object NotFound extends ErrorCode
case object Throttled extends ErrorCode
// etc. for other error codes

def get(id: UserId): Future[Either[ErrorCode, User]]
```

This makes processing the results on the success path much easier as we no longer need to stack monad transformers and therefore don't need to deal with type aliases. The need to specify the `[ErrorCode]` type parameter to `EitherT.right` is unfortunate as it feels like the Scala compiler ought to be able to infer this, but the code is still pretty clear:

```scala
for {
  user      <- EitherT(userRepo.get(id))
  addresses <- EitherT.right[ErrorCode](addressRepo.findByUser(user))
} yield (user, addresses)
```

It might seem from this example that omitting the option type is a better approach, but sadly things aren't that clear cut.

If you _did_ want to handle the user not being found in specific way within the comprehension (e.g. maybe you have some way to register a user if they're missing) then having an option nested within the either would make this easier because you could choose to not unwrap the option, whereas when it's an error code you're forced to consider not only the `NotFound` error code but others such as `Throttled` within the comprehension.

In a library I'd err on the side of keeping the option nested inside the either as the type signature is more strictly correct and it's more flexible when processing the result, albeit at the expense of being more complex to process. However, if it's within an application then I'd do whichever made the calling code easier to write, which might vary on a case-by-case basis.
