---
layout: post
title: Why algebraic type systems win
date: 2020-02-13
tags: [software engineering]
author: gregbeech
comments: true
---

We'll model a simple business type first using a functional language with an algebraic type system, and subsequently with an object-oriented language. What we'll do is model a contact info type which can be either a phone number or an email, see how we'd use it, and then evolve it to also add a website.

# What are algebraic type systems?

(TODO)

# F#

For the functional language I'm going to use F# as it has particularly clean syntax for domain modelling. Our contact info can be modelled as follows where the `|` indicates a choice between one of the two types, i.e. a `ContactInfo` is either a `Phone` containing a string, or an `Email` containing a string.

```fsharp
type ContactInfo =
    | Phone of string
    | Email of string
```

To use this we pattern match over the type. This defines a function called `contact` and extracts either the number or address in the pattern match, then takes the appropriate action (let's assume that `call` and `message` somehow exist and know what to do).

```fsharp
let contact contactInfo =
    match contactInfo with
    | Phone number  -> call number
    | Email address -> message address
```

To evolve the type and add website, we just add another case. It doesn't matter that the contained type is a `Uri` rather than a `string` because there isn't any shared interface between the types.

```fsharp
open System

type ContactInfo =
    | Phone of string
    | Email of string
    | Website of Uri
```

When we add this we'll get a compiler error as the `match` is now non-exhaustive, so we need to complete the usage. That's just a matter of adding another line.

```fsharp
let contact contactInfo =
    match contactInfo with
    | Phone number  -> call number
    | Email address -> message address
    | Website url   -> browse url
```

That was pretty neat. Now let's see how we can do this in an object-oriented language.

# C# attempt 1: Tagging

The approach that most closely emulates the functional style is to tag the data with an enum, e.g.

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

In use this looks broadly similar too, if somewhat more verbose.

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

However when we come to evolve it to add website with a `Uri` value we have a problem because the value is defined as a `string`. We'll have to settle for storing the value as a string and then converting it to a `Uri` when it's read with a different accessor.

```csharp
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
            // will throw an exception if value isn't a valid URI
            return Uri.Parse(this.Value);
        }
    }
}
```

In use this starts to feel a bit more unpleasant as we now have to remember to call the correct accessor based on the tag, and because the tag doesn't enforce the type of data stored we've sacrificed some type safety and our code is no longer exception-safe.

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

Let's see if we can do better.

# C# alternative 2: Object orientation

Rather than using a tag, we'll use subtype polymorphism to be able to see what type of data it is.

```csharp
public abstract class ContactInfo {
    public abstract string Value { get; private set; }
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

However, we've made the most common mistake of object-oriented modelling which is exposing the object's data instead of behaviour. We don't want to switch on the type of the class, we want the class to respond correctly, so let's change the interface to hide the data and have behaviour instead. This now works nicely as we can call the `Contact()` method on any instance.

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

We can also cleanly add the website class, and much like the functional approach we are forced to implement the behaviour too as it's part of the class contract. This is how object-oriented design is supposed to work.

```csharp
using System.Uri

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

Unfortunately, this only works when you can actually modify the classes themselves. It can also easily lead to very large classes that have low cohesion. And for things at a level 'above' (e.g. rendering UI) you don't want to add that to the model. What else can we do?

# C# alternative 3: Visitor

We start off with the same basic subtype polymorphism, and we'll deliberately go back to making the 'mistake' of exposing the data.

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

However, to make the behaviour extensible outside the class, we'll need to dispatch based on type. Because we _won't_ get a compiler error if we don't cover all cases as this isn't an algebraic type system, the safe way to do this is to define a visitor base class once, and then override the methods for specific cases:

```csharp
public abstract class ContactInfoVisitor {
    public void Visit(ContactInfo contactInfo) {
        if (contactInfo is Phone phone) {
            Visit(phone)
        } else if (contactInfo is Email email) {
            Visit(email)
        }
    }

    protected virtual void Visit(Phone phone) {}
    protected virtual void Visit(Email email) {}
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

We can now evolve this to add the website. Unfortunately again we don't get any compiler errors when we add the `Website` class so we just need to remember to update our visitor base class in lockstep.

```csharp
using System.Uri

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
        }
    }

    protected virtual void Visit(Phone phone) {}
    protected virtual void Visit(Email email) {}
    protected virtual void Visit(Website website) {}
}
```

Finally we can use this to provide external extensibility to the class in a safe way from clients.

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

However, it should be fairly easy to see that with the visitor pattern we've really just implemented a poor facsimile of the algebraic type system, with a lot more boilerplate and less help from the compiler.

# Where algebraic types fail

Open domains, which is where the OO implementation shines, and where algebraic type systems need typeclasses. But that's rare in business domains, which are typically closed.
