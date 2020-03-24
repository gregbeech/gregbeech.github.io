---
layout: post
title: Treat lifecycle hooks as events
date: 2020-03-22
tags: [rails, django, domain-driven design]
author: gregbeech
comments: true
---

I don't like lifecycle hooks on objects. I don't like Rails' ActiveRecord callbacks, I don't like Django's built-in persistence signals, and I'm quite sure I would not like the alternatives in other frameworks. They tend to get abused to the point where it's impossible to reason about what will happen when you save an object. Objects end up with recursive hooks that have to track whether they're currently being called, bulk changes which don't call them and violate invariants, and myriad special cases which explicitly bypass them for reasons nobody can quite remember.

The obvious solution is to ban the use of lifecycle hooks and model all side effects explicitly. This is a good solution, and it is the approach I would take if given free choice. However, these hooks are undeniably convenient and lots of people seem to like them. Let's have a look into them and see if there's a better way that gives many of the benefits but allows us to reason about what will happen on save.

## Rails callbacks vs Django signals

Rails has two 'hook' mechanisms which are ActiveRecord callbacks and ActiveSupport notifications. Callbacks are declared in the object's class definition, can take part in its database transactions, and are intended for behaviour intrinisic to the object. Notifications can be published from anywhere and subscribed to anywhere, run after the action has completed, and can be used to add out-of-band behaviour.

Django conflates these two concepts into signals, which can be subscribed to anywhere and can take part in an object's database transactions even if they're in a completely different module. This means that you cannot inspect an object's code to see what might happen when you save it, but have to grep the codebase for any signals that happen to have hooked into this process!

I think the Rails design is much cleaner. It encourages developers to separate behaviour that is intrinsic to the object from behaviour that isn't, whereas Django effectively encourages hooking into lifecycles and transactions of arbitrary objects. Unfortunately, in reality, people do tend to add Rails callbacks that perform actions only tangentially related to the object such as sending emails (and sadly, this is one of the examples of how they can be used in the official documentation).

In this post I'm going to write the examples using Python/Django as that's what we use at [Zego](https://www.zego.com), but it should be easy enough to port this approach to Rails or any other similar framework.

## The standard approach

Django uses 'apps' to segregate areas of functionality, so we'll create a `customers` app to hold the functionality specific to customer accounts, and a `Customer` model in it. Although it's not relevant to this article, the `id` is a UUID because [integer identifiers are bad]({% post_url 2019-12-10-all-about-identifiers %}).

```python
# ./customers/models.py

from django.db import models
import uuid


class Customer(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    email = models.CharField(max_length=100, unique=True)
```

Now if we want to take some additional actions such as sending an email when the customer is created, the standard approach would be to add a signal that subscribes to a lifecycle event and does it, e.g. this one which hooks into the `post_save` event.

```python
# ./customers/signals.py

from django.db.models.signals import post_save
from django.dispatch import receiver
from customers.models import Customer


@receiver(post_save, sender=Customer)
def send_welcome_email(sender, instance, **kwargs):
    if kwargs["created"]:
        # send email to the customer
```

We've already got a couple of problems here. Firstly, looking at the `Customer` class there's no hint that anything out of the ordinary is going to happen on save which reduces the maintainability of the codebase. Secondly, sending the email is by default done as part of the database transaction so if sending it fails the customer won't be created.

The second issue might not seem so bad until you start to think about the ways in which it could go wrong. From a business perspective, the email could send but then something happens such as the machine crashes and the transaction never commits so the customer never gets created. From a technical perspective, if the SMTP relay is slow to respond the transaction could be held open for seconds (or more!), causing scalability issues as database connections are scarce resources.

It can be improved by moving the actions out of the transaction by adding it to the post-commit hook rather than executing it immediately, as shown below. Even better, don't send the email in the post-commit hook but schedule a task using something like Celery to send it later which reduces latency and gives capability for retries. Of course, this means there is a small chance the task will never be schedules, but that's usually the lesser of the two evils.

```python
# ./customers/signals.py

from django.db import transaction
from django.db.models.signals import post_save
from django.dispatch import receiver
from customers.models import Customer


@receiver(post_save, sender=Customer)
def send_welcome_email(sender, instance, **kwargs):
    def do_send():
        # queue task to send email to the customer

    if kwargs["created"]:
        transaction.on_commit(do_send)
```

This, perhaps, isn't so bad. Nothing is interfering with the transaction of the `Customer` class any more, and everything is contained within the `customers` app so the scope of where you have to look for 'special' behaviour is constrained. Where things start really getting messy is when other apps start hooking into the same lifecycle signals, e.g.

```python
# ./marketing/signals.py

from django.db.models.signals import post_save
from django.dispatch import receiver


@receiver(post_save, sender="customers.Customer")
def update_email_marketing_system(sender, instance, **kwargs):
    # synchronously update some third-party systems
```

There's no direct reference to the Customer model here any more, as string names for models can be used to avoid cyclic loading dependencies, and in this naïve implementation any one of a number of third-party systems being down or slow could affect the ability to create customers or tie up database connections. Even worse is when these signals start _modifying_ the model, for example updating a marketing opt-out property, so even what will happen to the model's data on save starts becoming unpredictable.

None of the interactions between cross-app signals tend to get tested properly either, because the `customers` app tests will only tend to test what happens within that app, and the `marketing` app tests will only tend to test some very basic scenarios to do with its signal, so as multiple signals start to interact across apps, nothing tests how they affect each other.

## A better option

```python
from django.db import transaction
from django.db.models.signals import post_save
from django.dispatch import receiver, Signal
from customers.models import Customer


customer_created = Signal()
customer_updated = Signal()


@receiver(post_save, sender=Customer)
def __post_save_signals(sender, instance, **kwargs):
    def do_send():
        if kwargs["created"]:
            customer_created.send_robust(sender, instance=instance)
        else:
            customer_updated.send_robust(sender, instance=instance)

    transaction.on_commit(do_send)

```



## Only use after commit hooks

Lifecycle hooks should always be after the txn, and always asynchronous, because they are really domain events. Be aware that they won't always run and so like other async processes you need ways to ensure things are happening. But this makes intent hard to determine unless the intent literally is a CRUD event.

## Custom notifications and signals

Use Rails event notifications or Django custom signals for anything that isn't simply a CRUD event, to provide domain events rather than CRUD notifications.

## What about bulk create/update?

I would recommend not using these methods anyway, because they tend to have subtly different behaviour which can cause bugs.
