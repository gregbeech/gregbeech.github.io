---
layout: post
title: Twelve-factor configuration for Scala
date: 2018-04-20
tags: 12factor configuration scala
author: gregbeech
comments: true
---

The [twelve-factor methodology](https://12factor.net/) is a pretty solid approach to deploying applications that can run locally and in multiple cloud environments, as well as being able to scale out on demand. We've used this approach at Deliveroo since time immemorial (about three years ago), at least in part because with Rails it Just Works<sup>TM</sup>. With our more recent use of Scala and the ubiquitous [Typesafe Config library](https://github.com/lightbend/config) it's actually rather harder. After many attempts I finally found an approach I'm happy with.

If you're not familiar with the twelve-factor approach to configuration then you can [read about it on their site](https://12factor.net/config), but to summarise they key points:

- Store environment-specific configuration in environment variables
- Do not have named groups of variables such as "staging" or "production"

The reason for not having groups of variables is best explained by the twelve factor site itself:

> This method does not scale cleanly: as more deploys of the app are created, new environment names are necessary, such as staging or qa. As the project grows further, developers may add their own special environments like joes-staging, resulting in a combinatorial explosion of config which makes managing deploys of the app very brittle.

The recommended approach for handling different environments in the Typesafe Config library seems to be to create a variety of configuration files such as `application.staging.conf` and `application.production.conf`, and then use a JVM `-D` setting to tell it which configuration file to load. There are also [more complex approaches](https://www.stubbornjava.com/posts/environment-aware-configuration-with-typesafe-config) to load the right environment-specific file.

However, environment-specific files clearly violate the second twelve-factor guideline. And while guidelines are just that---guidelines---from experience I can tell you that this is one worth sticking to because at the very least you're likely to have four environments (dev, CI, staging, prod) and even those are a PITA to keep the config files in sync for. Once you introduce multiple staging environments, preproduction, etc. it becomes a nightmare.

Let's get our twelve-factor on.

First of all, the Typesafe Config library will do substitution of environment variables out of the box, so it's trivial to map them to your configuration file:

```hocon
myservice.dynamodb {
  region = ${AWS_REGION}
  host = ${DYNAMODB_HOST}
  port = ${DYNAMODB_PORT}
}
```

If you run your application with this in `application.conf` it's going to blow up because of the unresolved substitutions. To provide some values that work for the development environment out of the box (because there's nothing more evil than repositories that you can't just clone and run) we need a `.env` file which is the standard way of providing defaults.

```dotenv
AWS_REGION=local
DYNAMODB_HOST=localhost
DYNAMODB_PORT=8000
```

Of course that's still going to blow up because there's nothing linking the two together. There are three different places we need to tackle this: SBT, IntelliJ and Docker.

For SBT I use the [`sbt-dotenv`](https://github.com/mefellows/sbt-dotenv) plugin. Add the following to `project/plugins.sbt` (with the most recent version number) and it'll configure the environment for all your SBT builds. Just don't look at the plugin code to see the nasty things it's doing underneath the covers.

```scala
addSbtPlugin("au.com.onegeek" %% "sbt-dotenv" % "1.2.88")
```

For IntelliJ there are a couple of options.

The easy option is to install the "Env File" plugin and then go to the _Run > Edit Configurations..._ menu and under _Defaults_ modify Application and ScalaTest so that the EnvFile tab points to the `.env` file. As the file is hidden you may need to use `⌘`+`⇧`+`.` (on a Mac) to show it. Note that this only changes the defaults for the current project.

The other option is to follow the [instructions for running/debugging using SBT shell](https://www.jetbrains.com/help/idea/run-debug-and-test-scala.html). This is more complex to set up and will affect the way you need to use IntelliJ (adversely, in my opinion) so is only recommended if you want to make life hard for yourself or you're an SBT shell zealot.

When it comes to Docker, the best approach is to use `docker-compose` which has support for `.env` files. Use `env_file` to load the basic settings and then `environment` to tweak it.

```yaml
services:
  dynamodb:
    image: cnadiminti/dynamodb-local:latest
    ports:
      - 8000:8000
  app:
    build: .
    env_file: .env
    environment:
      - DYNAMODB_HOST=dynamodb
    links:
      - dynamodb
```

This file shows how the approach of using environment-specific parameter groups would already have started to fall apart because even in development there are some variations, with `DYNAMODB_HOST` being `localhost` when the app is running in the host OS or `dynamodb` when running under Docker Compose.

You could level the criticism here that you need three different approaches to load the configuration. It's a reasonable criticism. But for both SBT and Docker they're both 'set and forget' so you do them once and it's sorted for everybody. The IntelliJ plugin is slightly more irritating as it doesn't just pick up the `.env` file in the project root automatically, but even then you only need to set the defaults once per project and then you can forget about it.

The counterpoint to this criticism is that by using plugins for development/testing it makes it impossible to leak development configuration into production. Even if you copy the `.env` file into the production container the code has no mechanism to load it because once the app is compiled and deployed to production it doesn't run under SBT or IntelliJ or Docker Compose. For me, this safety outweighs any concerns about mild inconvenience; leaking dev settings into production can be a huge security risk.

One thing to be aware of is that in CI you might find an unwanted interaction between the plugins. We use CircleCI 2.0 which runs the containers using `docker-compose` and then we run the tests with `sbt test` so both are trying to configure the environment. Unfortunately the SBT plugin reloads the `.env` file over the top of any existing configuration so the `DYNAMODB_HOST` variable that Docker Compose set to `dynamodb` gets trashed and set back to `localhost` meaning the app can't find its database.

My workaround for this was to disable the `sbt-dotenv` plugin when running under CircleCI. You'll need to disable it individually for each project if you have a multi-module build.

```scala
// disable dotenv plugin in CircleCI as docker-compose loads the environment
lazy val disabledPlugins = {
  val isCircleCI = Option(System.getenv("CIRCLECI")).getOrElse("").nonEmpty
  if (isCircleCI) Seq(SbtDotenv) else Seq.empty
}

lazy val app = (project in file(".")).
  disablePlugins(disabledPlugins: _*).
  // etc.
```

Finally, I like my configuration to be strongly typed and validated at app startup. It's better to have the app crash on startup if any of the configuration is invalid so the release can roll back, rather than letting it start handling traffic and finding you haven't told it where the database is.

[PureConfig](https://github.com/pureconfig/pureconfig) is the nicest library I've found for mapping configuration to case classes. It's used something like this:

```scala
case class DynamoDBConfig(region: String, host: String, port: Int)

case class AppConfig(dynamoDB: DynamoDBConfig)

object AppConfig {
  implicit def productHint[A]: ProductHint[A] = ProductHint[A](
    ConfigFieldMapping(CamelCase, KebabCase).withOverrides(
      "dynamoDB" -> "dynamodb"
    ))

  lazy val config: AppConfig =
    ConfigFactory.load.getConfig("myservice").to[AppConfig] match {
      case Right(appConfig) => appConfig
      case Left(failures) => throw new ConfigReaderException[AppConfig](failures)
    }
}
```

Note that here I've had to use a hint to tell it that I want `dynamoDB` read from a section called `dynamodb` rather than the default mapping of `dynamo-db`. You'll also need to do this with things like `s3` which it otherwise thinks should be in a section called `s-3` and that's just silly.

So there we go. A single configuration file with settings stored in the environment, no chance of leaking development configuration into production, and validated configuration on startup. What more could you want?
