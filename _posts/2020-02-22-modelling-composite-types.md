---
layout: post
title: Modelling composite types
date: 2020-02-22
tags: [domain modelling, functional programming, object orientation]
author: gregbeech
comments: true
---

A composite type is one that can have different possible types of value, for example contact info might be either a phone number or an email address. Other common names for this---depending on programming language and context---are sum types, tagged unions, disjoint unions, discriminated unions, coproducts, or variant types (not the same as the old COM concept).

These are easy to model in functional languages that use algebraic type systems, because they can directly represent composite types. However, in object oriented languages there is no ideal way to model them. There is another approach which is neither algebraic nor object-oriented which might be the best of both worlds though.

To explore this, we'll model a contact info type which can be either a phone number or an email, show how it's used, and then evolve it to also add a website URL alternative.

## Algebraic modelling

For the algebraic type system I'm going to use F# as it has particularly clean syntax for domain modelling. The contact info can be modelled as a discriminated union where `|` indicates a choice between the type constructors, i.e. a `ContactInfo` is either a `Phone` containing a string, or an `Email` containing a string.

```fsharp
type ContactInfo =
    | Phone of string
    | Email of string
```

To use this we pattern match over the type. The following code defines a function called `contact` and extracts either the number or address string in the pattern match, then takes the appropriate action (let's assume that `call` and `message` are functions that somehow exist and know what to do).

```fsharp
let contact contactInfo =
    match contactInfo with
    | Phone number  -> call number
    | Email address -> message address
```

If you're not familiar with F# then this code might look strange because there are no types and no braces! F# uses spaces for function application so the first line declares a function named `contact` which takes an argument named `contactInfo`. It doesn't need any explicit types because it can infer from the pattern match branches that the argument must be of type `ContactInfo`.

To evolve the type and add a website, we just add another case. It doesn't matter that the contained type is a `Uri` rather than a `string` because the type constructors `Phone`, `Email` and `Website` are independent of each other and don't need to have any shared interface.

```fsharp
open System

type ContactInfo =
    | Phone of string
    | Email of string
    | Website of Uri
```

When we add this new `Website` type constructor we'll get a compiler error as the `match` is now not exhaustive, so we need to add a case to any matches throughout the codebase. That's just a matter of adding another line.

```fsharp
let contact contactInfo =
    match contactInfo with
    | Phone number  -> call number
    | Email address -> message address
    | Website url   -> browse url
```

That was pretty neat. Adding a different type didn't require any existing lines of code to be changed, and the compiler told us everywhere that would be affected. The downside is that this type can't be externally extended, i.e. only the author of the type can add a new variant, but that isn't an issue for business domains which are inherently closed.

Now let's see how we can model this concept in an object-oriented language.

## Object-oriented attempt 1: Tagging

The approach I see most often used for this situation in object-oriented languages is to add an enum tag to the class indicating the type of value. This is probably because corresponds to the way you'd store the data in a relational database (a column for the type and a column for the value) so it's easy to use with object-relational mappers.

```csharp
public enum ContactMethod {
    Phone,
    Email
}

public sealed class ContactInfo {
    public ContactInfo(ContactMethod method, string value) {
        this.Method = method;
        this.Value = value;
    }

    public ContactMethod Method { get; private set; }
    public string Value { get; private set; }
}
```

In use this looks broadly similar to, if somewhat more verbose than, the functional approach where the type is matched and then the value is used.

```csharp
public static void Contact(ContactInfo contactInfo) {
    switch (contactInfo.Method) {
        case ContactMethod.Phone:
            Call(contactInfo.Value);
            break;
        case ContactMethod.Email:
            Message(contactInfo.Value);
            break;
    }
}
```

However when we come to evolve it to add website with a `Uri` value we have a problem because the value is defined as a `string`. Generics don't help here because that would prevent us from doing things like putting multiple contact infos in a list if the type was different (or needing to use existential types in the list).

We'll have to settle for storing the value as a `string` and then converting it to a `Uri` when it's read with a different accessor.

```csharp
using System

public enum ContactMethod {
    Phone,
    Email,
    Website
}

public sealed class ContactInfo {
    public ContactInfo(ContactMethod method, string value) {
        this.Method = method;
        this.Value = value;
    }

    public ContactMethod Method { get; private set; }
    public string Value { get; private set; }

    public Uri ValueAsUri {
        get {
            // Will throw an exception if Value isn't a valid URI
            return Uri(this.Value);
        }
    }
}
```

In use this feels more unpleasant as we now have to remember to call the correct accessor based on the tag. This relationship between logical type and accessor isn't enforced by the type system so we've sacrificed some type safety, and the code is no longer exception-safe even though that isn't obvious from looking at it.

```csharp
public static void Contact(ContactInfo contactInfo) {
    switch (contactInfo.Method) {
        case ContactMethod.Phone:
            Call(contactInfo.Value);
            break;
        case ContactMethod.Email:
            Message(contactInfo.Value);
            break;
        case ContactMethod.Website:
            Browse(contactInfo.ValueAsUri);
            break;
    }
}
```

In general, this kind of tagged data approach is not very future-proof in object-oriented languages. We could just about get away with the evolving requirements here as the data is almost the same shape, but what if the requirement was to add a phone type (e.g. home, mobile, etc.) to the phone number? There's nowhere to store it.

Let's see if we can do better.

## Object-oriented attempt 2: Inheritance

For our second attempt we'll use the proper object-oriented approach of inheritance and subtype polymorphism. I've used an abstract base class here, but an interface could be used instead without changing any of the modelling discussion.

```csharp
public abstract class ContactInfo {
    public string Value { get; private set; }
}

public sealed class Phone : ContactInfo {
    public Phone(string value) {
        this.Value = value;
    }
}

public sealed class Email : ContactInfo {
    public Email(string value) {
        this.Value = value;
    }
}
```

Unfortunately, the above code makes one of the most common mistakes of object-oriented modelling which is exposing the object's data instead of its behaviour. We shouldn't be switching on the type of the class and reading the `Value` property, but should instead call a method on it and allow the object to respond correctly based on its runtime type.

Let's change the interface to hide the data and expose the desired behaviour instead. This now works nicely as we can call the `Contact()` method on any instance.

```csharp
public abstract class ContactInfo {
    public abstract void Contact();
}

public sealed class Phone : ContactInfo {
    private readonly string number;

    public Phone(string number) {
        this.number = number;
    }

    public override void Contact() {
        Call(this.number);
    }
}

public sealed class Email : ContactInfo {
    private readonly string address;

    public Email(string address) {
        this.address = address;
    }

    public override void Contact() {
        Message(this.address);
    }
}
```

We can also cleanly add a `Website` class with a `Uri` rather than `string` value because the type of the value isn't exposed in the interface, and much like the functional approach we are forced to implement the behaviour as it's part of the class contract. This is how object-oriented design is supposed to be done. It's unfortunate that many of the languages have standards (e.g. Java Beans) or features (e.g. auto-implemented properties) that encourage programmers to do the wrong thing by default.

```csharp
using System

// other code the same as before

public sealed class Website : ContactInfo {
    private readonly Uri url;

    public Website(Uri url) {
        this.url = url;
    }

    public override void Contact() {
        Browse(this.url);
    }
}
```

All good then? Not quite. Unfortunately, subtype polymorphism is only viable when you can actually modify the classes themselves when you need to add behaviours. It can also easily lead to very large classes that have high coupling and low cohesion as everything related to the class ends up in there (how many barely related methods do your `User` or `Order` or similar classes have, for example?).

Subtype polymorphism is a great approach for functionality that is intrinsic to the type, but for other things you might want to do with it (e.g. converting it to data transfer objects for rendering in APIs or UIs) another approach is necessary.

## Object-oriented attempt 3: Visitor pattern

We'll start off with subtype polymorphism again, but this time we will expose the data because the visitor pattern does dispatch based on type. Note, however, that there are no shared properties or behaviour and so `ContactInfo` becomes effectively a marker interface.

```csharp
public abstract class ContactInfo {}

public sealed class Phone : ContactInfo {
    public Phone(string number) {
        this.Number = number;
    }

    public string Number { get; private set; }
}

public sealed class Email : ContactInfo {
    public Email(string address) {
        this.Address = address;
    }

    public string Address { get; private set; }
}
```

Rather than having each specific visitor implement the boilerplate for the visitor pattern, we can implement a visitor base class and then allow specific visitors override the methods that handle the concrete types. This code uses C# 7.0's feature of aliasing variables after `as` checks so there is no need for an additional cast.

```csharp
using System;

public abstract class ContactInfoVisitor {
    public void Visit(ContactInfo contactInfo) {
        if (contactInfo is Phone phone) {
            Visit(phone)
        } else if (contactInfo is Email email) {
            Visit(email)
        } else {
            throw new NotSupportedException()
        }
    }

    protected abstract void Visit(Phone phone);
    protected abstract void Visit(Email email);
}

public sealed class ContactVisitor : ContactInfoVisitor {
    protected override void Visit(Phone phone) {
        Call(phone.Value)
    }

    protected override void Visit(Email email) {
        Message(email.Value)
    }
}
```

We can now evolve this to add the website. Unfortunately again we don't get any compiler errors when we add the `Website` class saying that it isn't handled, so we need to remember to update our visitor base class in lockstep. Fortunately with the abstract methods we will get errors in the derived visitors when we add the method to the base class, so there's _some_ safety there at least.

```csharp
using System

// other entity classes as before

public sealed class Website : ContactInfo {
    public Email(Uri url) {
        this.Url = url;
    }
    
    public Uri Url { get; private set; }
}

public abstract class ContactInfoVisitor {
    public void Visit(ContactInfo contactInfo) {
        if (contactInfo is Phone phone) {
            Visit(phone)
        } else if (contactInfo is Email email) {
            Visit(email)
        } else if (contactInfo is Website website) {
            Visit(website)
        } else {
            throw new NotImplementedException()
        }
    }

    protected abstract void Visit(Phone phone);
    protected abstract void Visit(Email email);
    protected abstract void Visit(Website website);
}
```

Finally we can use this to provide external extensibility to the class in a safe way.

```csharp
public sealed class ContactVisitor : ContactInfoVisitor {
    protected override void Visit(Phone phone) {
        Call(phone.Number)
    }
    
    protected override void Visit(Email email) {
        Message(email.Address)
    }
    
    protected override void Visit(Website website) {
        Browse(website.Url)
    }
}
```

Look back at the visitor pattern again though. We've exposed disparate properties on the entity classes, dispatched on their concrete types, and handled each case individually. It should be evident that the visitor pattern as used here is just a poor facsimile of the functional language's built-in discriminated union support, with a lot more boilerplate and a little less help from the compiler.

Unfortunately with traditional object-oriented languages we haven't found an ideal approach for modelling composite types.

## _Ad hoc_ interface implementation

This brings us neatly around to another form of modelling which is neither algebraic nor object-oriented. It's the approach used in Go's interfaces and Rust's trait objects, as shown below. Note that in Go you wouldn't tend to declare the interface along with the structures, but only when you need to make them implement a common behaviour.

```go
import "net/url"

// these types get defined up-front

type Phone struct {
        Number string
}

type Email struct {
        Address string
}

type Website struct {
        URL url.URL
}

// the interface and implementation can be defined later anywhere else

type ContactInfo interface {
        Contact()
}

func (p *Phone) Contact() {
        call(p.Number)
}

func (e *Email) Contact() {
        message(e.Address)
}

func (w *Website) Contact() {
        browse(w.URL)
}
```

This _ad hoc_ interface implementation for disjoint types is also supported in Python. That probably isn't too surprising as Python can't decide what type of language it wants to be, so it chucks a bit of every paradigm into the mix. It takes the approach of defining a 'base' method and registering additional methods as handlers, using metaprogramming rather than being a language intrinsic. This 'base' method is effectively the interface defintion.

```python
from dataclasses import dataclass
from functools import singledispatch

# these types get defined up-front

@dataclass
class Phone:
    number: str

@dataclass
class Email:
    address: str

@dataclass
class Website:
    url: str  # No URL type in Python :-(

# the implementation can be defined later anywhere else; no interface needed

@singledispatch
def contact(_contact_info: object):
    ...

@contact.register(Phone)
def __contact_phone(phone: Phone):
    call(phone.number)

@contact.register(Email)
def __contact_email(email: Email):
    message(email.address)

@contact.register(Website)
def __contact_website(website: Website):
    browse(website.url)
```

_Ad hoc_ interface implementation, or _ad hoc_ polymorphism as it's more commonly known, is a more powerful approach than traditional object-orientation's subtype polymorphism. (That's right sports fans, I actually said that there's a design decision in Go that isn't terrible. Just one though. Don't get excited.)

If you're into functional programming then you'll recognise this as being conceptually similar to typeclasses, but this post is already running long and I'd need to introduce yet another language that supports them to demonstrate, so I'm going to call it a day.
