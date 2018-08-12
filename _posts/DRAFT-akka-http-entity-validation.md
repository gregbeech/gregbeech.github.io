---
layout: post
title: Akka HTTP entity validation
date: 2018-08-12
tags: scala akka http
author: gregbeech
comments: true
---

TODO: Intro

To give us a context in which to discuss validation, here's a basic order API adapted from the [Akka HTTP docs](https://doc.akka.io/docs/akka-http/current/common/json-support.html):

```scala
import akka.http.scaladsl.server.Directives
import akka.http.scaladsl.marshallers.sprayjson.SprayJsonSupport
import spray.json._

case class Item(sku: String, count: Int)
case class Order(items: List[Item])

trait OrderJsonSupport extends SprayJsonSupport with DefaultJsonProtocol {
  implicit val itemFormat: JsonFormat[Item] = jsonFormat2(Item)
  implicit val orderFormat: RootJsonFormat[Order] = jsonFormat1(Order)
}

class OrderApi extends Directives with OrderJsonSupport {
  val route =
    post {
      entity(as[Order]) { order =>
        complete(s"Ordered $order")
      }
    }
}
```

This example already introduces _structural_ validation rules as if the entity isn't valid JSON, or if any of the required attributes are missing or of the wrong type, then the request will be rejected with a `MalformedRequestContentRejection`.

The next type of validation would be _introspective_ rules which are based solely on the state of the order model to determine whether it could possibly be valid. In this case the rules would be that `items` list must be non-empty, the `sku` for each item must be non-empty, and the `count` for each item must be positive.

The most complex type of validation is _state-based_ rules which need to query the state of the system to be able to determine whether the order is actually valid. This likely includes rules such as the `sku` references a real item and there are at least `count` of them in stock.

With structural validation you don't get much of a choice where it's implemented; it's always at the edge in your routes (or controllers or handlers in other languages and frameworks). State-based validation is typically done in service classes that have access to databases, APIs, and other places they need to get the state from.

However, introspective validation seems less obvious. It's often implemented in controllers mixed with structural validation as "request validation", or in services mixed with state-based validation as "business logic validation". Sometimes both in the same project. But neither are really correct. It's a different type of validation and, as it depends solely on the state of the model, the object-oriented place to implement it is as an instance method on the model.

Rather than invent a validation framework from scratch I'm going to build on top of [Cats Validation](https://typelevel.org/cats/datatypes/validated.html). This defines a `Validated[+E, +A]` type with cases `Valid[A]` and `Invalid[E]`. The `ValidatedNel` type is an alias for `Validated[NonEmptyList[E], A]` so it can collect multiple validation failures in the `Invalid` case.

```scala
import cats.data._

abstract class ValidationFailure(val message: String)

type ValidationResult[A] = ValidatedNel[ValidationFailure, A]

trait Validatable[A] {
  def validate: ValidationResult[A]
}
```

Using those we can define the introspective validation for our order model. I'm not entirely sold on the Cats approach of defining a different validation object for each type of validation error, but I'll implement it that way to keep things consistent with their documentation.

```scala
import cats.implicits._

case object ItemsIsEmpty extends ValidationFailure("Items is empty")
case object SkuIsEmpty extends ValidationFailure("SKU is empty")
case object CountIsInvalid extends ValidationFailure("Count must be positive")

case class Item(sku: String, count: Int) extends Validatable[Item] {
  def validate: ValidationResult[Item] = (
    validateSku,
    validateCount
  ).mapN(Item)

  private def validateSku: ValidationResult[String] =
    if (sku.length > 0) sku.validNel else SkuIsEmpty.invalidNel
  private def validateCount: ValidationResult[Int] =
    if (count > 0) count.validNel else CountIsInvalid.invalidNel
}

case class Order(items: List[Item]) extends Validatable[Order] {
  def validate: ValidationResult[Order] = validateItems.map(Order)

  private def validateItems: ValidationResult[List[Item]] =
    items.traverse(_.validate)
}
```

Integrating this validation into the routes is easy enough, but it adds a significant amount of noise to the routes, and the boilerplate for handling the `Invalid` case is going to be the same everywhere an entity needs to be validated.

```scala
class OrderApi extends Directives with OrderJsonSupport {
  val route =
    post {
      entity(as[Order]) { unvalidatedOrder =>
        unvalidatedOrder.validate match {
          case Valid(order) =>
            complete(s"Ordered $order")
          case Invalid(failures) =>
            reject(ValidationRejection(failures.toList.map(_.message).mkString(", ")))
        }
      }
    }
}
```

If something is noisy and repeated then it's a pretty good hint that it could be factored out.

**TODO: It could be put in the service class, but that leads to test duplication (checking the service for validation too) or even more boilerplate (if the service can return more than just validation failures)**

We only care about valid orders inside the `entity` directive, so we can declare that in the type system:

```scala
import cats.data.Validated.Valid

class OrderApi extends Directives with OrderJsonSupport {
  val route =
    post {
      entity(as[Valid[Order]]) { order =>
        complete(s"Ordered $order")
      }
    }
}
```

Unfortunately if you try and compile this you'll get an error saying that Akka HTTP doesn't know how to unmarshal a `Valid[Order]`. What's needed is a new unmarshaller that lifts a regular unmarshaller into the validation context.

```scala
import akka.http.scaladsl.unmarshalling.FromRequestUnmarshaller
import cats.data.Validated.{Invalid, Valid}

implicit def validatedEntityUnmarshaller[A <: Validatable[A]](
  implicit um: FromRequestUnmarshaller[A]): FromRequestUnmarshaller[Valid[A]] =
  um.flatMap { _ => _ => entity =>
    entity.validate match {
      case v @ Valid(_) =>
        Future.successful(v)
      case Invalid(failures) =>
          val message = failures.toList.map(_.message).mkString(", ")
          Future.failed(new IllegalArgumentException(message))
    }
  }
```

It matters that the failure is an `IllegalArgumentException` as Akka HTTP's `entity` directive interprets that as an invalid value within the payload, as opposed to a malformed payload, so causes a `ValidationRejection` rather than a `MalformedRequestContentRejection`.

Inside the entity directive you'll now have a `Valid[Order]` instance rather than an `Order` instance. You could unwrap it if you want, but we tend to pass it 'as is' to service classes so it's encoded in the type system that you should only pass it orders that have been validated.

```scala
trait OrderCreator {
  def create(order: Valid[Order]): Future[Order]
}
```
