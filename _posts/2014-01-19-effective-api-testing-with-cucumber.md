---
layout: post
title: Effective API testing with Cucumber
date: 2014-01-19
tags: cucumber gherkin testing
author: gregbeech
comments: true
---

At [blinkbox books](http://www.blinkboxbooks.com) we're making extensive use of Cucumber to capture business requirements and ensure that the code fulfils them. If you're getting started with Cucumber, a lot of the good practices for writing Gherkin specifications and effectively automating them is captured by [The Cucumber Book](https://pragprog.com/book/hwcuc/the-cucumber-book) which is, like most of the Pragmatic Bookshelf, a very good book indeed.

However, in the chapter where they discuss testing REST APIs they completely dropped the ball. It's at odds with the rest of the book, and frankly most of the recommendations make no sense at all; you should not be testing your APIs in the way they describe.

Let's take an example scenario from chapter 12, "Testing a REST Web Service", to see the suggested approach:

```gherkin
Scenario: List fruit
  Given the system knows about the following fruit:
    | name       | color  |
    | banana     | yellow |
    | strawberry | red    |
  When the client requests GET /fruits
  Then the response should be JSON:
    """
    [
      {"name": "banana", "color": "yellow"},
      {"name": "strawberry", "color": "red"}
    ]
    """
```

You'll note that this is significantly different from a normal Gherkin specification because it includes significant technical detail such as the HTTP verb `GET`, the URL `/fruits` and an entire JSON object for the response. It's also incredibly tightly coupled to the implementation.

This completely goes against the advice given in the rest of the books, for example at the start of chapter 5 it says:

> When you're writing Cucumber features, make readability your main goal. Otherwise, a reader can easily feel like they're reading a computer program rather than a specification document, which is something we want you to try to avoid at all costs. After all, if your features aren't easy to read, you might as well just be writing your tests in plain old Ruby code.

Good advice indeed. The level of technical detail in the above scenario would be appropriate in a lower level testing framework such as RSpec, which is intended to be used to test specific implementation details, but feels wholly out of place in a Gherkin specification.

The above scenario also falls foul of a number of the points in chapter 6, "When Cucumbers Go Bad", namely:

- Incidental Details: The details such as the specific HTTP verb used and, in particular, the URL of the resource itself, feel like incidental details. It's not clear why any stakeholder would need to know these details.
- Imperative Steps: The step to `GET /fruits` is clearly failing to create its own domain language, instead deferring to the specifics of the underlying HTTP protocol. The recommendation to raise the level of abstraction and write steps in a declarative style is completely ignored.
- Brittle Features: The JSON document implies an implicit ordering, but is this based on the order the data was inserted into the system? Or alphabetical based on name? It's not clear. Given the JSON matching semantics aren't specified it seems that this test could be brittle when an unrelated change causes a different sort order to be returned. It might even be a flickering scenario, where sometimes the sort order is correct, but sometimes not.
- Duplication: At the moment there doesn't look like any duplication, but once you start creating lots of tests for fruits there will be many, many JSON documents littered throughout the Gherkin specifications. Want to add a new attribute to the JSON? Time to go back and change them all...

There's an attempt at an explanation for why the authors have entirely ignored everything about the approach they espoused in the first eleven chapters:

> Joe asks: I Thought Scenarios Should Avoid Technical Terms Like JSON
>
> It's always important to make a scenario readable by a stakeholder. However, for a REST interface, the stakeholder is going to be another programmer writing a client for the REST interface. In such cases, it's fine to expose technical details.

But this is based on a false premise.

In this simple scenario there aren't much in the way of requirements, but in the real world you're likely to have some other constraints such as the fact that you can't make smoothies from fruits that aren't in stock, so you probably need a way to return only available fruits. You might also need to know how many fruits are available -- but for watermelons or pineapples which are large and require pre-preparation in the form of peeling and chopping it may be weight rather than count. And some fruits such as oranges may be pre-squeezed, so those quantities might be measured in volume.

You presumably also need recipes to suggest which fruits go together, and some sort of price list for pre-selected combinations and ad-hoc blends, and perhaps even the available sizes of cups, and so on, and so on. In other words, there's likely to be a moderately complex logical data and operation model hiding behind even this throwaway scenario.

Is the client programmer the stakeholder for that?

I sure as hell hope not.

Unless you're a really small company with a few developers hacking out code to try and get it off the ground -- in which case you're probably not using Cucumber because you don't have the time -- then you probably have product managers who define the vision for the future and specify how these things should work (albeit usually with input from the development and test team). The product team own the requirements, and thus _they_ are the stakeholders for the API, and the Gherkin specifications need to be written with _them_ in mind.

Are all of your product managers familiar with the details of HTTP and JSON? The difference between `PUT` and `PATCH`? The difference between `200 OK` and `202 Accepted`? Of couse not. Heck, even most developers are embarrassingly unaware of many of the commonly used parts of HTTP.

So if you're writing Gherkin for REST APIs -- or, indeed, any APIs -- then you need to write it using the same approach as you would with any other Gherkin. Just pretend chapter 12 doesn't exist.

You might think I'm unfairly picking on a single book here, but the fact is that The Cucumber Book is the _de facto_ book for learning Cucumber and when they have got something so hideously wrong it means that the wrong approach is going to get widely propagated. We even tried their approach at our company before realising that with more complex APIs it led to a huge amount of repetition and brittle scenarios, and was utterly useless for describing the actual behaviour of the API to anybody, including other developers.

So, let's have a go at writing the scenario to be more readable and less brittle:

```gherkin
Scenario: List fruit
  Given the system knows about the following fruit:
    | name       | color  |
    | banana     | yellow |
    | strawberry | red    |
  When the client requests a list of fruit
  Then the response is a list containing two fruits
  And one fruit has the following attributes:
    | attribute | type   | value  |
    | name      | String | banana |
    | color     | String | yellow |
  And one fruit has the following attributes:
    | attribute | type   | value      |
    | name      | String | strawberry |
    | color     | String | red        |
```

The first step is fine, so I've left that as is, but after that things start to diverge. The steps use product language instead of specific technical details, and although the last two steps might look quite technical they are a representation of a logical data model and thus I believe are fine in a product-oriented document. They use the vague preposition 'one' rather than 'the first' and 'the second' as I'm assuming order isn't important here; if it is then it would be an easy change to make.

Note that this specification does not even make mention of HTTP or JSON, so could easily be mapped to other kinds of API or different implementations without having to rewrite the product requirements.

We'll go through the changed steps one at a time, along with corresponding implementation, starting with the following (all the code to support this post is available [on GitHub](https://github.com/gregbeech/cukes_rest)):

```gherkin
  When the client requests a list of fruit
```

This step now states exactly what the client is doing in product language, thus creating its own domain specific language. The implementation is fairly trivial, assuming that we have an `get` helper method defined somewhere (e.g. `rack-test`) and creates the mapping between the product requirement and HTTP.

```ruby
When(/^the client requests a list of (.*?)s?$/) do |type|
  get("/#{type.pluralize.downcase.tr(' ', '-')}")
end
```

Rather than hard-coding "fruit" the step is parameterised so that it can be used for lists of other things, making automation of future scenarios faster. I brought in the `pluralize` method from ActiveSupport so we can say "fruit" rather than "fruits" in the Gherkin file, which is more grammatically correct.

The step assumes a strong API convention that lists are at the root with a name corresponding to their type, so for example a if the step said "cup sizes" instead of "fruits" then the requested URL would be `/cup-sizes`. As we will see going forward, having strong conventions makes creating your tests easier, and ultimately allows you to derive your exact API design from the product requirements.

The next step describes what the expected response is at a high level, and it is very easy for a person reviewing the test to see that it would be the logical outcome of the first two steps.

```gherkin
  Then the response is a list containing two fruits
```

Although this is a short step, it tells us a lot about the structure of the response: it's a list, it has two items in it, and each item should look like a fruit. The automation for this is actually a little complex, if we take the time to make it reusable, with the step definition looking something like this:

```ruby
Then(/^the response is a list containing (#{CAPTURE_INT}) (.*?)s?$/) do |count, type|
  data = MultiJson.load(last_response.body)
  validate_list(data, of: type, count: count)
end
```

Both the count and the type of item are parameterised in the step definition to make it reusable, and to allow proper English grammar (where numbers up to ten are spelled rather than written as numerals) there's a handy transform function defined.

In general I'm not a massive fan of transforms as unless they are very specific they can activate in unexpected places and give you some really baffling behaviour until you work out that a rogue transform is the issue, but this one is the exception I make to that rule:

```ruby
CAPTURE_INT = Transform(/^(?:-?\d+|zero|one|two|three|four|five|six|seven|eight|nine|ten)$/) do |v|
  %w(zero one two three four five six seven eight nine ten).index(v) || v.to_i
end
```

Clearly we also need a `validate_list` function to implement the step logic:

```ruby
def validate_list(data, of: nil, count: nil)
  expect(data).to be_a_kind_of(Array)
  expect(data.count).to eq(count) unless count.nil?
  unless of.nil?
    validate_item = "validate_#{of.singularize.downcase.tr(' ', '_')}".to_sym
    data.each { |item| send(validate_item, item) }
  end
end

def validate_fruit(data)
  expect(data["name"]).to be_a_kind_of(String)
  expect(data["name"]).to_not be_empty
  expect(data["color"]).to be_a_kind_of(String)
  expect(data["color"]).to match(/^(green|purple|red|yellow)$/i)
end
```

This method does the basic checks that the data returned is an array and has the expected number of items, and then checks that each item in the array has the expected structure by dispatching to a method name derived from the Gherkin step text. By writing the code in this way, we can check for lists of other types of item simply by adding a `validate_item_type` method.

It might seem like there's a lot of hidden logic in this step, but the code does _exactly_ what the step definition says -- checks for a list containing two fruits -- and anything with less validation around what a list is or what a fruit structure looks like would not fulfil that requirement.

The final steps perform additional validation on the contents of the list, beyond just checking the structure:

```gherkin
  And one fruit has the following attributes:
    | attribute | type   | value  |
    | name      | String | banana |
    | color     | String | yellow |
```

The automation for the step converts the specified table into a hash, and this is another good reason for having the type in the table, so that the conversion can be done accurately as by default everything in Gherkin is a string. It then searches the array for matching items and checks the count.

```ruby
Then(/(#{CAPTURE_INT}) (?:.*?) ha(?:s|ve) the following attributes:$/) do |count, table|
  expected_item = table.hashes.each_with_object({}) do |row, hash|
    name, value, type = row["attribute"], row["value"], row["type"]
    hash[name.tr(" ", "_").camelize(:lower)] = value.to_type(type.constantize)
  end
  data = MultiJson.load(last_response.body)
  matched_items = data.select { |item| item == expected_item }
  expect(matched_items.count).to eq(count)
end
```

I've just done some very basic exact matching of attributes here, but in all likelihood you'd want to do something more complex and match values that has the specified attributes even if they had extra ones. This also parses the response body again, which is a little inefficient, though in practice it makes little difference.

Note that again this makes use of conventions by calling `camelize` on the name field, because it assumes the JSON will be camel cased. As a result, the Gherkin can be cleaner for attribute names with multiple words, e.g. a JSON attribute `inStock` can be written "`in stock`" in the test, further decoupling requirements from implementation.

The `to_type` method is a non-standard addition, and uses some slightly dirty hacks to allow things like `Boolean` and `Enum` to be specified as types in the Gherkin even though they don't exist in Ruby. I wouldn't do them in production code, but in test code I think it's fine.

```ruby
module Boolean; end
class TrueClass; include Boolean; end
class FalseClass; include Boolean; end

module Enum; end
class String; include Enum; end

class String
  def to_type(type)
    # cannot use 'case type' which checks for instances of a type rather than type equality
    if type == Boolean then self =~ /true/i
    elsif type == Date then Date.parse(self)
    elsif type == DateTime then DateTime.parse(self)
    elsif type == Enum then self.upcase.tr(" ", "_")
    elsif type == Float then self.to_f
    elsif type == Integer then self.to_i
    else self
    end
  end
end
```

And with that, we have a completed API test that is totally decoupled from the technology used to implement the API and therefore can be written first to specify what the behaviour should be. It was quite a lot of work, and some of the step definitions were more complex than needed just for it, but that will pay off in the future.

Let's test that theory by specifying and designing a new cup sizes API in a similar manner.

```gherkin
Scenario: List cup sizes
  Given the system knows about the following cup sizes:
    | name    | fluid ounces |
    | Regular | 12           |
    | Large   | 16           |
  When the client requests a list of cup sizes
  Then the response is a list containing two cup sizes
  And one cup sizes has the following attributes:
    | attribute    | type    | value   |
    | name         | String  | Regular |
    | fluid ounces | Integer | 12      |
  And one cup sizes has the following attributes:
    | attribute    | type    | value |
    | name         | String  | Large |
    | fluid ounces | Integer | 16    |
```

We'd need to implement a new `Given` step but I'll skip the implementation of that in this post because the setup steps have been out of scope so far.

The `When` step is already automated as the parameterised step will match it, and based on the convention we've used it means that then API endpoint must be at `/cup-sizes`.

The first `Then` step will be matched by the existing definition, but it will fail because it's expecting a `validate_cup_size` method to be available. It isn't, but we know how to define it because we've got our specification for what a cup size should be. The remaining `Then` steps are already automated as the existing code to match attributes will work just fine.

```ruby
def validate_cup_size(data)
  expect(data["name"]).to be_a_kind_of(String)
  expect(data["name"]).to_not be_empty
  expect(data["fluidOunces"]).to be_a_kind_of(Integer)
  expect(data["fluidOunces"]).to be >= 0
end
```

So, although the first scenario was slow and a bit complex to write, the second one only required six additional lines of basic code to get it fully working. The conventions used by the tests also defined what our API must look like, otherwise they will fail, which helps to ensure a consistent design even when multiple developers are working on it.

This is really only a flavour of where you can go with convention-oriented API tests using product language rather than technical details to describe the behaviour, and deriving the technical details from that, as Cucumber should be! It's the approach we're taking at [blinkbox books](https://www.blinkboxbooks.com/), and we're developing some libraries that should help you to do a similar thing more easily which we'll hopefully have out in the wild in early 2014.

Let me know what you think, or even better [come and help us out](http://jobs.blinkbox.com)!
