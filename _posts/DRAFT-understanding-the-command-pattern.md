---
layout: post
title: Understanding the Command Pattern
date: 2018-06-21
tags: engineering-101 go patterns
author: gregbeech
comments: true
---

A week or so ago I wrote about [why you shouldn't copy ActiveRecord](/2018/06/21/dont-copy-activerecord) and this is a follow-up post which covers another problem I'm seeing in some Go applications: An incorrect implementation of the command pattern for writing data. Once again, I'll explain why the approach is wrong, and demonstrate a better way of doing things.

First, let's see the approach I wouldn't recommend:

```go
struct CreateWidget {
        Id uuid
        CategoryId uuid
}

func (cmd *CreateWidget) Execute(db orm.DB) (Widget, error) {
        // implementation elided
}
```

The problem with this is exactly the same as implementing data access methods directly on your models: There isn't any abstraction between higher level functionality in the application and the data access layer. In fact, it's easy to see that these two approaches are homomorphic:

```go
struct Widget {
        Id uuid
        CategoryId uuid
}

func (cmd *Widget) Create(db orm.DB) error {
        // implementation elided
}
```

You can refer to the [previous article](/2018/06/21/dont-copy-activerecord#why-does-this-matter) for a full description of the drawbacks of this approach, but in a nutshell it leaks implementation details into higher layers, which adds complexity and means that tests for things like web handlers are going to be harder to write and much slower to run as they need to run against a real database.
















