---
layout: post
title: Akka HTTP client pooling and parallelism
date: 2018-04-08
tags: akka http parallelism
author: gregbeech
comments: true
---

Akka HTTP's client uses connection pooling, either implicitly when you use the `singleRequest` method, or explicitly when using `cachedHostConnectionPool` or `superPool`. The number of requests that can be made in parallel and how backpressure works is governed by the `max-connections` and `max-open-requests` settings, but these have some slightly surprising behaviour which isn't quite what the documentation suggests. This post demonstrates how these APIs work and discusses when to use each of them.

The configuration properties are documented as follows:

```properties
# The maximum number of parallel connections that a connection pool to a
# single host endpoint is allowed to establish. Must be greater than zero.
max-connections = 4

# The maximum number of open requests accepted into the pool across all
# materializations of any of its client flows.
# Protects against (accidentally) overloading a single pool with too many client flow materializations.
# Note that with N concurrent materializations the max number of open request in the pool
# will never exceed N * max-connections * pipelining-limit.
# Must be a power of 2 and > 0!
max-open-requests = 32
```

The `max-connections` definition looks straightforward but as we'll see it isn't quite correct. The documentation for `max-open-requests` is rather more confusing and I'm also fairly sure it's wrong. The tests I've done and the comments in the code itself show that the maximum number of open requests cannot exceed `max-connections * pipelining-limit` regardless of the number of materialised flows.

In this post I'm ignoring `pipelining-limit` and leaving it set to the default of `1` as that's what I expect the overwhelming majority of people to do, and because the post is already long enough without throwing more variables into the mix.

## Setup

To make the behaviour observable I wrote a tiny HTTP server which prints out the request details and sleeps for five seconds before responding. It returns `204 No Content` so we don't have to worry about reading the entity body (see the [large warning about response streams in the Akka HTTP docs](https://doc.akka.io/docs/akka-http/current/client-side/request-level.html)).

```scala
object Application {
  implicit val system: ActorSystem = ActorSystem("http-slow-server")
  implicit val mat: ActorMaterializer = ActorMaterializer()
  import system.dispatcher

  def main(args: Array[String]): Unit = {
    val route = extractUri { uri =>
      onSuccess(slowOp(uri)) {
        complete(StatusCodes.NoContent)
      }
    }

    val binding = Http().bindAndHandle(route, "0.0.0.0", 4000)
    println("Server online at http://0.0.0.0:4000/")
    StdIn.readLine()
    binding.flatMap(_.unbind()).onComplete(_ => system.terminate())
  }

  def slowOp(requestUri: Uri): Future[Unit] = Future {
    blocking {
      println(s"[${LocalDateTime.now}] --> ${requestUri.authority.host}")
      Thread.sleep(5000)
    }
  }
}
```

The server prints the host so we can see what happens when we vary this in the caller. To be able to test with different hosts locally I added a couple of entries to `/etc/hosts`:

    127.0.0.1   localhost1
    127.0.0.1   localhost2

## Http().singleRequest

This is the highest level API which makes it easy to send a request, and also the most intuitive in terms of its behaviour. The harness below sends a load of requests as fast as possible using the default settings for `max-connections` and `max-open-requests`.

```scala
object Application {
  implicit val system: ActorSystem = ActorSystem("http-pool-test")
  implicit val mat: ActorMaterializer = ActorMaterializer()
  import system.dispatcher

  def main(args: Array[String]): Unit =
    for (i <- 1 to 64) {
      val request = HttpRequest(uri = Uri("http://localhost:4000/"))
      Http().singleRequest(request).onComplete {
        case Success(_) => println(s"[${LocalDateTime.now}] $i succeeded")
        case Failure(e) => println(s"[${LocalDateTime.now}] $i failed: $e")
      }
    }
}
```

Requests 33-64 fail immediately with the error:

    [2018-04-07T13:12:19.952] 33 failed: akka.stream.BufferOverflowException:
        Exceeded configured max-open-requests value of [32].

Because `singleRequest` materialises a new flow for each request, once the limit of 32 is hit there's no option other than to fail. At first it might seem like this is a bad thing---it certainly did to me---but it actually makes a lot of sense. The final part of this post discusses why failure is the best option.

The remaining requests are grouped in sets of four (the default for `max-connections`) with approximately five seconds (the server sleep time) between each set; the pool runs them as fast as possible using the available connections. The responses are not quite in order because although the pool pulls the requests from upstream and dispatches them in order, it returns a response as soon as it is available.

    [2018-04-07T13:12:25.122] 1 succeeded
    [2018-04-07T13:12:25.124] 4 succeeded
    [2018-04-07T13:12:25.126] 2 succeeded
    [2018-04-07T13:12:25.127] 3 succeeded
    [2018-04-07T13:12:30.133] 5 succeeded
    [2018-04-07T13:12:30.135] 6 succeeded
    [2018-04-07T13:12:30.137] 7 succeeded
    [2018-04-07T13:12:30.139] 8 succeeded
    ...

Changing the following line allows us to run the harness alternating between two different hosts:

```scala
val request = HttpRequest(uri = Uri(s"http://localhost${i % 2 + 1}:4000/"))
```

This time all the requests are queued as we haven't overflowed the buffer. Each host will use its own connection pool so the buffer is 32 for `localhost1` and 32 for `localhost2`. The requests execute in sets of eight, four for each host, showing that when you use `singleRequest` the pooling for each host is completely independent.

    [2018-04-07T13:41:08.689] 7 succeeded
    [2018-04-07T13:41:08.689] 4 succeeded
    [2018-04-07T13:41:08.690] 5 succeeded
    [2018-04-07T13:41:08.691] 8 succeeded
    [2018-04-07T13:41:08.693] 1 succeeded
    [2018-04-07T13:41:08.693] 2 succeeded
    [2018-04-07T13:41:08.694] 6 succeeded
    [2018-04-07T13:41:08.695] 3 succeeded
    [2018-04-07T13:41:13.698] 10 succeeded
    [2018-04-07T13:41:13.698] 9 succeeded
    [2018-04-07T13:41:13.701] 11 succeeded
    [2018-04-07T13:41:13.701] 12 succeeded
    [2018-04-07T13:41:13.702] 13 succeeded
    [2018-04-07T13:41:13.702] 14 succeeded
    [2018-04-07T13:41:13.704] 15 succeeded
    [2018-04-07T13:41:13.704] 16 succeeded
    ...

The behaviour of `Http().singleRequest` isn't very surprising, but it may not be immediately obvious from the documentation that requests may be queued up to a certain limit so I felt it was worth demonstrating.

## Http().cachedHostConnectionPool

Rather more complex to use is `cachedHostConnectionPool` and its sibling `cachedHostConnectionPoolHttps` which behaves identically other than using TLS for the requests. These provide a flow which accepts a request and a state object and output a `Try[HttpResponse]` along with the state; the state is there to allow you to correlate the requests and responses as like `singleRequest` although the requests will be dispatched in order, the responses are returned when they are available. Again we'll send a number of requests as fast as possible.

```scala
object Application {
  implicit val system: ActorSystem = ActorSystem("http-pool-test")
  implicit val mat: ActorMaterializer = ActorMaterializer()

  val connection = Http().cachedHostConnectionPool[Int]("localhost", 4000)

  def main(args: Array[String]): Unit =
    Source(1 to 64)
      .map(i => (HttpRequest(uri = Uri("http://localhost:4000/")), i))
      .via(connection)
      .runWith(Sink.foreach {
        case (Success(_), i) => println(s"[${LocalDateTime.now}] $i succeeded")
        case (Failure(e), i) => println(s"[${LocalDateTime.now}] $i failed: $e")
      })
}
```

As we're only materialising a single flow we don't hit the max open requests limit and so none of the requests fail. They all execute in sets of four as the pool backpressures upstream.

    [2018-04-07T13:55:13.788] 1 succeeded
    [2018-04-07T13:55:13.791] 4 succeeded
    [2018-04-07T13:55:13.791] 2 succeeded
    [2018-04-07T13:55:13.791] 3 succeeded
    [2018-04-07T13:55:18.799] 5 succeeded
    [2018-04-07T13:55:18.800] 7 succeeded
    [2018-04-07T13:55:18.801] 6 succeeded
    [2018-04-07T13:55:18.803] 8 succeeded
    ...

Of course you could materialise a flow for each request and send them via the `connection` flow to hit the limit, which is for all intents and purposes what `singleRequest` does under the covers.

What happens if we _do_ materialise multiple flows with the same authority?

```scala
object Application {
  implicit val system: ActorSystem = ActorSystem("http-pool-test")
  implicit val mat: ActorMaterializer = ActorMaterializer()

  val connection1 = Http().cachedHostConnectionPool[Int]("localhost", 4000)
  val connection2 = Http().cachedHostConnectionPool[Int]("localhost", 4000)

  def main(args: Array[String]): Unit = {
    Source(1 to 32)
      .map(i => (HttpRequest(uri = Uri("http://localhost:4000/")), i))
      .via(connection1)
      .runWith(Sink.foreach {
        case (Success(_), i) => println(s"[${LocalDateTime.now}] $i succeeded")
        case (Failure(e), i) => println(s"[${LocalDateTime.now}] $i failed: $e")
      })
    Source(33 to 64)
      .map(i => (HttpRequest(uri = Uri("http://localhost:4000/")), i))
      .via(connection2)
      .runWith(Sink.foreach {
        case (Success(_), i) => println(s"[${LocalDateTime.now}] $i succeeded")
        case (Failure(e), i) => println(s"[${LocalDateTime.now}] $i failed: $e")
      })
  }
}
```

The requests still execute in sets of four so we can see they're using the same underlying connection pool even though we created completely separate connections. However rather than executing requests 1-32 that were queued first and then 33-64 the pool is 'fair' and pulls in two requests from each of the sources at a time.

    [2018-04-07T14:05:29.490] 1 succeeded
    [2018-04-07T14:05:29.490] 34 succeeded
    [2018-04-07T14:05:29.491] 2 succeeded
    [2018-04-07T14:05:29.491] 33 succeeded
    [2018-04-07T14:05:34.520] 3 succeeded
    [2018-04-07T14:05:34.522] 35 succeeded
    [2018-04-07T14:05:34.522] 36 succeeded
    [2018-04-07T14:05:34.523] 4 succeeded
    ...

One thing to note is that if you call `cachedHostConnectionPool` with different `ConnectionPoolSettings` then it will result in multiple pools for the same host. For example, if we change the setup of the second connection as follows:

```scala
  val connection2 = Http().cachedHostConnectionPool[Int]("localhost", 4000,
    ConnectionPoolSettings(system).withMaxConnections(2)
  )
```

We can see that the pools are no longer the same, and requests on `connection1` use the default four connections, with requests on `connection2` use the two connections it has been given:

    [2018-04-07T15:24:21.695] 34 succeeded
    [2018-04-07T15:24:21.695] 3 succeeded
    [2018-04-07T15:24:21.698] 33 succeeded
    [2018-04-07T15:24:21.698] 2 succeeded
    [2018-04-07T15:24:21.699] 1 succeeded
    [2018-04-07T15:24:21.699] 4 succeeded
    [2018-04-07T15:24:26.708] 35 succeeded
    [2018-04-07T15:24:26.708] 5 succeeded
    [2018-04-07T15:24:26.709] 36 succeeded
    [2018-04-07T15:24:26.709] 6 succeeded
    [2018-04-07T15:24:26.710] 7 succeeded
    [2018-04-07T15:24:26.710] 8 succeeded

I'm not sure this is entirely intuitive behaviour. I assume it's been done so that if/when people call the API multiple times rather than storing the pool reference then it does the right thing. However, it does seem a little obtuse that whether it creates a new pool depends on whether the settings match one created previously or not. I think an explicit setting such as `ReuseExisting` (default) or `AlwaysCreate` would have been a better API design.

Still, the ability to create multiple pools could be useful if you have different types of request to a single host, e.g. sending fast or high priority requests through one pool and slow or low priority requests through another. Just be careful to document that they mustn't have the same settings of they'll collapse into one pool!

## Http().superPool

Finally we come to `superPool` which is rather like `cachedHostConnectionPool` except it doesn't have an authority configured so you can send requests for any authority through it and it'll route them to the appropriate connection pool. It won't surprise you that using `superPool` with a single host behaves exactly the same as `cachedHostConnectionPool`, but the behaviour with multiple hosts might.

```scala
object Application {
  implicit val system: ActorSystem = ActorSystem("http-pool-test")
  implicit val mat: ActorMaterializer = ActorMaterializer()

  val connection = Http().superPool[Int]()

  def main(args: Array[String]): Unit =
    Source(1 to 64)
      .map(i => (HttpRequest(uri = Uri(s"http://localhost${i % 2 + 1}:4000/")), i))
      .via(connection)
      .runWith(Sink.foreach {
        case (Success(_), i) => println(s"[${LocalDateTime.now}] $i succeeded")
        case (Failure(e), i) => println(s"[${LocalDateTime.now}] $i failed: $e")
      })
}
```

I expected this to execute in sets of eight requests (four for each host) much like `singleRequest` with two hosts, as `max-connections` is documented as being the limit per host. However we see that the requests actually execute in sets of four:

    [2018-04-07T14:45:27.865] 1 succeeded
    [2018-04-07T14:45:27.868] 3 succeeded
    [2018-04-07T14:45:27.872] 2 succeeded
    [2018-04-07T14:45:27.873] 4 succeeded
    [2018-04-07T14:45:32.874] 5 succeeded
    [2018-04-07T14:45:32.881] 8 succeeded
    [2018-04-07T14:45:32.882] 7 succeeded
    [2018-04-07T14:45:32.882] 6 succeeded
    ...

It looks like the `max-connections` setting for `superPool` is actually applied at the pool level rather than at the host level. Digging into `superPool` through `superPoolImpl` and into `clientFlow` we can see clearly that this is actually how it's implemented, that the parallelism is applied before it actually hits any of the host-specific connection pools.

```scala
private def clientFlow[T](settings: ConnectionPoolSettings)(f: HttpRequest ⇒ (HttpRequest, PoolGateway))
  : Flow[(HttpRequest, T), (Try[HttpResponse], T), NotUsed] = {
  // a connection pool can never have more than pipeliningLimit * maxConnections requests in flight at any point
  val parallelism = settings.pipeliningLimit * settings.maxConnections
  Flow[(HttpRequest, T)].mapAsyncUnordered(parallelism) {
    // ...
  }
}
```

This _seems_ to be the intended behaviour, but it definitely isn't how I expected it to behave, and means that you can't use `superPool` as a stream-oriented version of `singleRequest`. If you do want to use a single flow that routes based on host with per-pool limits then you'll need to build that wrapper pool yourself.

## Controlling parallelism with mapAsync

I've seen a number of implementations attempt to control parallelism of HTTP requests using `mapAsync` or its cousin `mapAsyncUnordered` after the flow with the aim of controlling the pull through the pool, something like this:

```scala
object Application {
  implicit val system: ActorSystem = ActorSystem("http-pool-test")
  implicit val mat: ActorMaterializer = ActorMaterializer()
  import system.dispatcher

  val connection = Http().cachedHostConnectionPool[Int]("localhost", 4000)

  def main(args: Array[String]): Unit =
    Source(1 to 64)
      .map(i => (HttpRequest(uri = Uri("http://localhost:4000/")), i))
      .via(connection)
      .mapAsync(parallelism = 2)(asyncOp).runWith(Sink.foreach {
        case (Success(_), i) => println(s"[${LocalDateTime.now}] $i succeeded")
        case (Failure(e), i) => println(s"[${LocalDateTime.now}] $i failed: $e")
      })

  def asyncOp(result: (Try[HttpResponse], Int)): Future[(Try[HttpResponse], Int)] =
    Future {
      blocking {
        Thread.sleep(100) // simulate work
        result
      }
    }
}
```


In reality, `asyncOp` is likely where you'd map the response to something useful by deserialising the body, or at the very least discard the entity bytes. We don't need to do either of these things here as the server returns `204 No Content`, so the harness simulates work by sleeping.

Using a sleep significantly shorter than the request duration (which will be the case for the majority of scenarios, except if you're streaming very large entity bodies) we can see that even though the degree of parallelism is two there is no effect at all on the HTTP throughput, with requests still completing in sets of four every five seconds.

    [2018-04-08T13:02:38.517] 3 succeeded
    [2018-04-08T13:02:38.521] 2 succeeded
    [2018-04-08T13:02:38.531] 4 succeeded
    [2018-04-08T13:02:38.531] 1 succeeded
    [2018-04-08T13:02:43.526] 6 succeeded
    [2018-04-08T13:02:43.528] 5 succeeded
    [2018-04-08T13:02:43.543] 7 succeeded
    [2018-04-08T13:02:43.546] 8 succeeded
    ...

This is because the HTTP pool eagerly pulls in requests from upstream when it has spare capacity, and the `mapAsync` call doesn't provide any backpressure because although it has less parallelism it's much faster. If we change the delay within `mapAsync` to `sleep(5000)` it's a different story. The results are output in sets of two every five seconds.

    [2018-04-08T13:05:40.942] 1 succeeded
    [2018-04-08T13:05:40.945] 3 succeeded
    [2018-04-08T13:05:45.949] 4 succeeded
    [2018-04-08T13:05:45.950] 2 succeeded
    [2018-04-08T13:05:50.953] 5 succeeded
    [2018-04-08T13:05:50.954] 6 succeeded
    [2018-04-08T13:05:55.957] 8 succeeded
    [2018-04-08T13:05:55.958] 7 succeeded
    ...

However, looking at the server logs we can see that this still doesn't control the parallelism initially because the pool will saturate itself up to max connections before `mapAsync` starts applying backpressure.

    [2018-04-08T13:05:30.868] --> localhost
    [2018-04-08T13:05:30.868] --> localhost
    [2018-04-08T13:05:30.867] --> localhost
    [2018-04-08T13:05:30.867] --> localhost
    [2018-04-08T13:05:35.940] --> localhost
    [2018-04-08T13:05:35.942] --> localhost
    [2018-04-08T13:05:40.950] --> localhost
    [2018-04-08T13:05:40.950] --> localhost
    ...

The only practical way to control request parallelism within a connection pool is to set `max-connections` for the pool. You may still need to pay attention to the parallelism of `mapAsync` though as if it's too low then that may cause the pool to backpressure and not reach the limit.

## Which client API should I use?

The three different approaches, `singleRequest`, `cachedHostConnectionPool` and `superPool`, all have different behaviour and there are different places in which you'd want to use them.

`singleRequest` is probably the most appropriate for near-real-time services such as APIs that are calling other services to get data to fulfil a request. These likely have fairly tight latency requirements so you don't want to queue requests for long if the outbound connection pool is full. Having a small amount of buffering between max connections and max open requests to handle small bursts but then failing with `BufferOverflowException` on larger ones is likely to be the desirable behaviour.

The reason failing is a good thing is that any other behaviour is probably worse. To try and avoid failing it could open more and more connections to the host, but this could either overload the host or saturate the network and mean that none of the requests return successfully. Alternatively it could buffer the requests indefinitely but then the latency of the service would keep increasing and by the time it responds the original requester may have stopped listening. By failing and translating the buffer overflow to `503 Service Unavailable` the service can indicate it is temporarily overloaded and provide application-level backpressure.

However, if you want more control over what happens when the buffer gets full then then using `cachedHostConnectionPool` with `Source.queue` allows you to set the overflow behaviour. For example, if you know that clients often call your service with a very short timeout then it might make sense to drop the older queued requests and allow the newer ones through when the pool gets full to increase the chance of completing a request where a client is still listening for the response.

A more obvious use for `cachedHostConnectionPool` is places where there isn't as much time pressure to respond to incoming data, for example handling asynchronous messages or streaming data from one location to another. Here you want to process requests as fast as possible without dropping or rejecting any, and the backpressure from the pool is exactly what's needed.

`superPool` is a more interesting beast. As the max connections limit applies at the whole pool level but it allows requests to multiple hosts it's hard to see any obvious use for it because it isn't to prevent overloading a single host with requests. A couple of hypothetical scenarios are where you're using multiple hostnames for the same service and want to avoid overloading it, or when you want to limit the outbound traffic from your service, but these aren't things I've come across frequently. Let me know if I'm missing something.
