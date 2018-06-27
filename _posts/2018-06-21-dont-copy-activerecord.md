---
layout: post
title: Don't copy ActiveRecord
date: 2018-06-21
tags: engineering-101 go repositories ruby
author: gregbeech
comments: true
---

When I looked through some of Deliveroo's non-Ruby applications, I saw that a number of them were trying to copy the ActiveRecord approach and defining data access methods on the models themselves. This is not a good approach in statically typed languages. I'll explain why, and demonstrate the approach you should be using. It's no secret that I think [Go is a dangerously bad language](/2018/05/25/gos-glass-ceiling), but I'll use it here to demonstrate as the majority of the applications I've seen with this problem are written in it.

## Pure vs impure methods

Let's start off with a bit of theory. If you know the difference between pure and impure methods then feel free to skip this section, but I'm sure there are more than a few people out there who don't.

A pure method is one whose outputs only depend on its inputs. For example, the following method is pure because given, say, `3` and `6` the output will always be `9`:

```go
package math

func Sum(a int, b int) int {
        return a + b
}
```

However, the following method is impure as the result may be different each time it is called. It might create a widget, it might return a key violation error if the widget already exists, or it might return an unexpected error if it can't connect to the database or the network times out:

```go
package models

func (w *Widget) Create() error {
        db.Insert(w)
}
```

It's fairly easy to identify impure methods because they're the ones that connect to any external resources such as databases, file systems or web services. If the method return type contains an `error` then it's probably impure.

## Testing impure methods

Testing pure methods is easy because you can provide different inputs and check that they give the right output:

```go
func TestSum(t *testing.T) {
        if Sum(3, 6) != 9 {
                t.Error("Expected 9")
        }
}
```

Testing impure methods is harder because you typically need to set things up to test the success path, for example inserting data in the database before calling the method so that foreign key relationships are satisfied, and you need to clean up afterwards, for example by wrapping the test in a transaction and rolling it back at the end:

```go
func TestCreateSuccess(t *testing.T) {
        defer db.Rollback()

        c := &Category{Id: uuid.NewV4(), Name: "Test"}
        if err := c.Create(); err != nil {
                t.Errorf("Test setup failed: %v", err)
        }

        w := &Widget{Id: uuid.NewV4(), CategoryId: c.Id}
        if err = w.Create(); err != nil {
                t.Errorf("Failed with error %v", err)
        }
}
```

Testing failure conditions is harder still because doing things like stopping the database to test connection failures, or emulating behaviours such as exceeding provisioned throughput, are at best impractical and at worst impossible.

Impure methods that talk to an external resource such as a database are also orders of magnitude slower than those that run in-memory, meaning your test pack will be slower.

## Why does this matter?

Testing data access methods directly against the database is a good thing because you want to know that they actually work. However, tests for higher layers such as web handlers (which are broadly equivalent to controllers in many other languages) shouldn't need to talk to the database.

All that matters from the web handler's point of view is that when it calls `Create` that the method doesn't return an error. It shouldn't care what the `Create` method is doing behing the scenes because that's an _implementation detail_ unrelated to the handler's behaviour. However, because the method is a concrete implementation on the `Widget` struct you have to actually set up the database with the referenced category for the creation to succeed.

The tests for the handler are going to be slow and complex because they need to get the database into the right state before they can run, then create the entity in the database, and then clean up, even though the handler's logic doesn't need to know or care about the database!

This is only for a really simple entity with one relation. Imagine something as complex as an order where you need to set up the customer, restaurant, menu, etc. just to be able to test order creation in a handler. It gets really complex and really, really slow. You only need to look at the test pack on our original monolithic Rails application for proof.

When using a real database you also cannot easily test how your handler behaves under specific error conditions. For example, if the error is that you've exceeded your provisioned throughput on the database then you should return `503 Service Unavailable` rather than `500 Internal Server Error`, but how are you going to set up that test condition? You can't, so it's probably just left untested or, worse, not even thought about.

The problem here all stems from depending on a specific version of the `Create` method which is hardcoded to talk to the database. As a rule, **never depend on a concrete implementation of an impure method**.

## What should I do instead?

A much better approach, which is the norm for statically typed languages, is to use the repository pattern. Instead of defining data access methods on the model, define a repository interface and a concrete implementation of it that talks to the database, e.g.

```go
type WidgetRepository interface {
        Create(w *Widget) error
}

type DBWidgetRepository struct {
        db orm.DB
}

func (repo *DBWidgetRepository) Create(w *Widget) error {
        return repo.db.Insert(w)
}
```

Now in your handler you can take a dependency on the interface `WidgetRepository` and instead of needing to set up the database you can pass in a fake implementation. There are a variety of mocking frameworks you can use, but for many cases like this you could use a [null object](https://en.wikipedia.org/wiki/Null_object_pattern), e.g.

```go
type NullWidgetRepository struct {}

func (repo *NullWidgetRepository) Create(w *Widget) error {}
```

Null objects have the drawback that you can't assert they were called or set any expectations on the arguments, so if you need to do this then use a mocking framework. However, mocks tend to complicate tests so I generally avoid them where possible.

If you do want standard repository behaviour in your tests, such as being able to look up an entity after inserting it, then interfaces allow you to use in-memory repositories which speed the tests up dramatically, as well as reducing complexity because they don't need test data set up to prevent key violations. I often write in-memory versions of repositories which are tested using the exact same tests as the real ones to ensure they have the same observable behaviour.

## Why is it OK in Rails then?

Honestly, it isn't. One of the main reasons that large Rails applications tend to have slow test packs is that the tests from the controllers down interact with the database, creating data, creating entities, rolling transactions back, etc. A significant portion of that time is usually just database access. Unfortunately in Rails you don't have much other choice because [DHH says so](http://david.heinemeierhansson.com/2014/tdd-is-dead-long-live-testing.html). But that doesn't mean it's OK.

## What about related entities?

A question somebody asked when I posted this internally was how you'd handle related entities, e.g. in Rails if you wanted to get a restaurant with its menus, and include the items in the menus, you could write something like this which would materialise the entire relationship tree and combine all the identifiers into three queries for efficiency.

```ruby
restaurant = Restaurant.includes(menus: :items).find(restaurant_id)
```

How would you model that with repositories? Would you have a bunch of extra options on the `Find` method such as `includeMenus bool` and `includeMenuItems bool`, or would you have methods like `FindWithMenus` and `FindWithMenusAndItems` that would duplicate code?

Neither.

It's a great question, but it's a symptom of looking at the world through Rails-coloured glasses where relationships are always modelled as intrinsic to an entity. To answer it we need to fall back on domain-driven design principles.

In this case I'd think about the `Restaurant` entity and whether it could reasonably exist without a menu. It could because, perhaps, it's setting up as a company and may not have a menu yet. Thus, does a restaurant entity need to know anything about menus? No.

How about the `Menu` entity; does it need to know about restaurants? Again, I don't think so. The menu for chains is basically the same at every one of their restaurants, and so a menu could reasonably exist without knowing which specific restaurant it is going to be used at. It could even be shared between multiple restaurants. It may need to know about the parent company, but not the individual restaurant.

Therefore, the `Restaurant` and `Menu` entities should not have direct references to each other, and based on the single responsibility principle (each class should have only one reason to change) the `RestaurantRepository` should not know about menus, and the `MenuRepository` should not know about restaurants.

Instead, you probably want to look at something along the lines of a `RestaurantMenuRepository` which is the single point that combines the two concepts and can answer questions about them. This might have methods like `MenuForRestaurant` or `MenusForRestaurants`. In other words, you make two queries explicitly, one for restaurants and one for menus. This is more code than using ActiveRecord as you have to do the merging of results yourself. But it turns out this approach has advantages.

In the early days of Deliveroo menus were modelled as being related to a specific restaurant and there were direct links between the models which were used throughout the code. We had to change it so that menus for chains could be shared between restaurants, and this meant hardcoded relationships needed to be remodelled throughout the codebase. By abstracting the way the relationship is modelled you can make this kind of change more easily, and with less risk.

This is one of the reasons that the Rails "just link everything to everything" approach is flawed because it doesn't make you think about the design of your domain, what your aggregate roots are, and what your relationships really mean.

As for `MenuItem` it seems reasonable to say that they are part of a `Menu` aggregate root, and in that case they should only be manipulated via a `Menu` entity. If there is a case for retrieving a menu without the items, then having an option to either return or not return the items on the repository method that gets the menu would make sense[^1].

Another thing to consider is future extraction to services. It’s fairly likely that as companies grow, the initial monolith will be decomposed and menus and restaurants will probably not be in the same service. With `Restaurant.includes(:menus)`, and references to `Restaurant#menus` all over the codebase, moving menus out is a large task requiring a lot of refactoring and a lot of changes to tests, especially if they do database setup to get things working.

If everything is behind a repository interface then you can write a new implementation that talks to a web service and then change which implementation you load. No changes to any other code or tests required. You can even use a third implementation to control the switch over; it implements the repository interface, and based on a feature flag it calls one of the two concrete implementations. Still no changes to any other code required.


[^1]: In reality the modelling of menus is vastly more complex than I've made it sound. Although chain restaurants do share menus between restaurants, they're rarely identical for each of them so you need to be able to handle variation. Menus also change over time so they need versioning, as do prices which need care because the current menu needs to show the new price but order history needs to show the price at the time. There are further complexities like restaurants who have different menus for different times of the day, and the problem that items may become unavailable. That's not to mention things like item modifiers (e.g. that you want onions on your burger) and for very complex menus that modifiers may themselves have modifiers, and that those may be single choice, multiple choice, mandatory or optional, and may affect the price of the item. All of this detail is entirely irrelevant to the main point, but I thought it was a nice illustration of how things that look quite simple on the surface can be incredibly complex and nuanced underneath.









