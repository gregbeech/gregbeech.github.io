---
layout: post
title: Rejection handling
date: 2018-08-12
tags: scala akka http
author: gregbeech
comments: true
---




When we started building our OAuth server, completing with errors looked something like this:

```scala
parameter('response_type) {
  case "authorization_code" => // ...
  case _ =>
    val params = Uri.Query(
      "error" -> "unsupported_response_type",
      "error_description" -> "The query parameter 'response_type' was invalid")
    val location = redirectUri.withQuery(params)
    redirect(location, StatusCodes.TemporaryRedirect)
}
```

Now it looks more like this:



