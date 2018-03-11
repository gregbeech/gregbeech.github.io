---
layout: post
title: Java is the new C++
date: 2013-05-14
tags: java languages rants scala
author: gregbeech
comments: true
---

Back in the early 1990s Java was conceived as an alternative to C++ which would be portable, garbage collected, and easier to learn, but still retaining a C-like syntax to make programmers feel more comfortable migrating to it. There are a variety of reasons why Java became so popular on launch, marketing not being the least of them, and now it's one of the most popular languages in the world. Perhaps _the_ most popular, depending on which statistics you believe.

When Java was released in 1996 it was primarily competing against C++ as the language to build things in and, yes, for building many types of software, Java was a much better language than C++. It still is. The trouble is, the game has moved on, and C++ isn't the main competition any more.

It's the best part of 20 years since Java was launched, and time has left the language behind. For example, can you think of another modern language that doesn't have lambda expressions and proper closures? And yeah, I know they're supposed to be coming in Java 8, but they've been supposed to be coming for years. And even then Java 8's release data has slipped back to 2014 (at least), which just encourages derogatory comparison with C++0x... er, I mean C++11.

What's even worse is that Java developers know that it's a clumsy, outdated language. When you point out the incredibly verbose syntax, the pain of checked exceptions (which has to go down as one of _the_ most stupid language features in history), the incomprehensibility of `T[]` not being assignment compatible with `Iterable<T>`, and the fact that it's impossible to transform a collection of something into a collection of something else without either writing five lines of `for`-loop or importing a third party library and writing five lines of anonymous inner class, they'll still defend it as being "good enough".

It isn't. Not by a long shot.

Anybody defending Java as a "good enough" language is generally doing so from a position of knowing _only_ Java and not wanting to have to learn anything else. This only further reinforces my opinion that if anybody describes themselves as an "X developer" you can replace "X" with "average" and have a reasonable probability of being correct. This applies for pretty much any value of X by the way; not just Java. If you don't care about the language you use every day then it's hard to believe you're going to care much about what you produce with it.

The last stand of the Java developer when trying to defend the language is that at least it's easy to learn. But that isn't true either. What they mean is that because Java has so little expressive power that there isn't much in the way of language features to learn, which _is_ true, but Java still goes out of its way to make the few concepts it can express appear complex.

Let's start with primitives such as `int` and `byte` which aren't objects, and their counterparts `Integer` and `Byte` which are. Because Java isn't really an object-oriented language, if you want to have an integer that is an object you have to convert your `int` to `Integer`; this is necessary if you want to put it in a collection because they can only store objects. If somebody is learning the language, is now a good point to start explaining the difference between reference and value types? Probably not. Especially as most developers _still_ think that value types live on the stack and reference types live on the heap -- and that it matters -- and thus will try and explain it in those terms.

This might not seem so bad, as nowadays Java will auto-box your `int` to an `Integer` if you try to add it to a collection. But if you try and call a method on it, e.g. `(3).toString()`, then it won't auto-box it and you'll get a compiler error, so we're now in an inconsistent world where primitives are sometimes treated like objects and other times not. And while it's easy to convert `int` to `Integer`, you're back to a `for` loop if you want to convert `int[]` to `Integer[]`.

Now we're onto the subject of arrays, although generally you find the number of elements in a Java collection using the `size()` method, the array type - not being a real object and thus not supporting methods - has a `length` field instead. Strings aren't sure whether they're an array or a collection of characters, so they hedge their bets and use a `length()` method.

That isn't the biggest array WTF in Java though, because that's waiting for you when you try to pass an array of `T` to a method that's expecting an `Iterable<T>` and you get a compiler error complaining that they're incompatible types. I'm sorry, but in what world is an array _not_ iterable? Yeah, I know it's because arrays are special types that aren't really objects and don't really exist, but that's no excuse - it's the same in .NET but at least Microsoft put a load of hacks in their VM to make scenarios that _ought_ to work _actually_ work.

What's more ridiculous is that there _are_ some hacks in Java to make arrays appear more like their real-object collection cousins. For example, the "smart" `for` loop (yeah, that does seem to be its real name) can iterate over both `T[]` and `Iterable<T>` even though neither are assignment compatible nor share any common interface.

Sticking with the array theme, in Java it's possible to check whether a variable contains an array of integers at runtime by writing `myVar instanceof Integer[]`. However, if you want to check whether it contains a list of integers then you're shit out of luck, because writing `myVar instanceof List<Integer>` will just see the compiler come back with an error that it's an illegal type for `instanceof`. You actually can only check that it's a list of _something_ by writing `myVar instanceof List<?>` because generic type information is erased at compile time and so doesn't exist at runtime. You might not think this is such a big deal, but it causes significant complexity in some libraries; want to explain [how to deserialize JSON to a generic type](http://wiki.fasterxml.com/JacksonPolymorphicDeserialization#A5.1_Missing_type_information_on_Serialization) to a beginner?

We've barely covered primitive types and basic collections and already we're up to paragraphs on the needless complexities inherent in Java. We haven't even got onto the different types of variance. Ah, yes, variance. Java offers two types of generic variance which I'm going to call "broken" variance and "where's that book again?" variance.

"Broken" variance is demonstrated by arrays, where their covariance and mutability can lead to some surprising errors at runtime that can't be caught by the type system:

```java
Animal[] animals = new Giraffe[10];
animals[0] = new Turtle(); // BOOM!
```

This is broken because [it should always be legal to put a Turtle into an array of animals](http://blogs.msdn.com/b/ericlippert/archive/2007/10/17/covariance-and-contravariance-in-c-part-two-array-covariance.aspx).

Not much more to say on that one.

"Where's that book again?" variance is demonstrated by pretty much all other variance in Java, where it's so unintuitive you can really only figure out why things aren't doing what you expect, and how to fix it, by going back to the reference manual. For example, you'd expect a generic iterator to be covariant as types only come 'out', and therefore that you'd be able to treat a `List<String>` as an `Iterable<Object>`, but:

```java
Iterable<Object> items = new ArrayList<String>(); // error: incompatible types
```

If you want to get this to compile then you have to change the declaration of the iterable to indicate its variance:

```java
Iterable<? extends Object> items = new ArrayList<String>();
```

You probably didn't need the book to work out how to fix that one, but you might for this. How do you declare a method to get the maximum item from a sequence, which works if the items implement the `Comparable<T>` interface anywhere in their inheritance chain (i.e. it could be implemented on their base class)?

Don't peek...

Did you get it?

```java
public static <T extends Comparable<? super T>> T max(Iterable<? extends T> items) {
    // ...
}
```

I'm not even kidding, that's lifted straight out of Joshua Bloch's "Effective Java" (a great book, incidentally) as an example of the right way to do things. It's so complex that it has actually broken the Markdown code block parser in Sublime Text, and I've had to remove it temporarily to be able to continue typing!

Let's see the C# versions of these examples with the same variance:

```csharp
IEnumerable<object> items = new List<string>();

public static T Max<T>(IEnumerable<T> items) where T : IComparable<T> {
    // ...
}
```

These just work in C# because variance is defined on the interfaces themselves, and so anywhere the interfaces are used they automatically 'do the right thing'. Given you _use_ interfaces a lot more frequently than you _declare_ them, having variance defined on declaration makes a lot more sense than on usage, and is far easier because you only need to consider one interface at a time rather than the composition of all the interfaces together.

So let's sum up where we are: Primitives that aren't objects, except when they are. Arrays that aren't iterable, but language constructs that can treat them as such. Types that exist at compile time but not at runtime. Two types of variance, one of which is broken, and the other which requires you to think about covariance and contravariance every time you use it.

A language that's easy to learn? I can't think of any modern language that's more needlessly complex.

I feel like I've barely scratched the surface here, but actually that's most of what Java as a language has to offer. I guess I could also go into the fact that checked exceptions are one of the most broken language features ever conceived, but you know that already and you're probably sick of writing shit like:

```java
Cipher cipher;
try {
    cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
} catch (NoSuchAlgorithmException e) {
    throw new RuntimeException("AES/CBC is documented as always existing.", e);
} catch (NoSuchPaddingException e) {
    throw new RuntimeException("PKCS5Padding is documented as always existing", e);
}
```

I sure as hell am.

But let's not dwell on Java's shortcomings in isolation any longer. Let's take a look at what people really mean when they say other languages are harder to learn: They can do more. I'll take a simple example that I needed to do this week, which was prepend a single zero-byte to an array. In Java your code is going to look something like this:

```java
byte[] temp = new byte[bytes.length + 1];
System.arraycopy(bytes, 0, temp, 1, temp.length);
bytes = temp;
```

Whereas in Scala, an increasingly popular JVM language, it's going to look more like this:

```scala
bytes +:= 0
```

Yeah, I'm not kidding. Those code fragments are equivalent.

I know what you're thinking though. The Scala code looks more cryptic. But much like `a += b` expands to `a = a + b` in Java, `a +:= b` expands to `a = a.+:(b)` in Scala, where the part before the `=` is the method name (`+:` is a legal method name in Scala). All you have to remember is a universal expansion rule, which is arguably simpler than the localised expansion rule in Java. And you don't need to refer to the documentation to see which order the parameters for the `arraycopy` method come in, or make an off-by-one error by carelessly using the wrong array length (did you spot that?).

You're probably thinking that's a contrived example, so let's take another one - produce the running total of an array of numbers, which is the kind of thing you might want to do for a receipt or on a summary screen. In Java you're looking at something like this (with no deliberate errors this time, I promise):

```java
int[] runningTotals = new int[numbers.length];
int currentTotal = 0;
for (int i = 0; i < numbers.length; i++) {
    currentTotal += numbers[i];
    runningTotals[i] = currentTotal;
}
```

Whereas in Scala it's rather simpler:

```scala
val runningTotals = numbers.scanLeft(0)(_ + _)
```

But again, it's _cryptic_, right? Well, no, not really. Once you're able to recognise common Scala idioms and functions you can read this in your head as "Scan the array from the left, start with zero, and make each new value by adding the original value to the accumulated value.", which is probably just about how you'd describe the solution in English. It certainly reads better than "Create a new array of the same length, start with zero for the current total and the index into the array, while the index into the array is less than the array length, add the value at the current index to the current total and store that in the running totals at the current index, then increment the index into the array.".

I know you're still not convinced yet, so let's try a different tack. Every Java developer is familiar with the verbosity that came from dealing with resources that need to be closed after use in Java before version 7:

```java
BufferedReader reader = new BufferedReader(new FileReader(path));
try {
    // ...
} finally {
    reader.close();
}
```

They were all pretty happy when a little bit of syntactic sugar was eventually introduced in Java 7 which let them achieve the same result with fewer lines of code. Well, I assume they were happy anyway.

```java
try (BufferedReader reader = new BufferedReader(new FileReader(path))) {
    // ...
}
```

In other languages, you don't need to wait fifteen years for the language designers to get their asses in gear, you can just add the feature yourself. Here's the same try-with-resources concept expressed in Scala, which is duck-typed to work on anything with a `close` method; no need to add an `AutoCloseable` interface here:

```scala
// we can't call it 'try' as that's a keyword, so we'll go with 'using' in homage to C#
def using[R, T <: { def close(): Unit }](resource: T)(func: T => R): R =
  try { func(resource) }
  finally { resource.close() }
```

It can now be used in much the same way as the Java one, and looks reasonably like a built-in language construct:

```scala
using (new BufferedReader(new FileReader(path))) { reader =>
  // ...
}
```

Plus the really cool thing with this version is that say you want to return something from within the `using` block, because this is an an expression rather than a statement, you can just assign the result directly. This is something I've _often_ wanted to do when writing C# over the past decade or so:

```scala
val firstLine = using (new BufferedReader(new FileReader(path))) { reader =>
  reader.readLine()
}
```

What's the big deal though? Java 7 has this language feature built in now so you're not gaining anything with Scala, right? Well, because the Scala approach is not dependent on a specific language feature you can apply it to scenarios other than just closing resources; for example you could create `borrow` helper that borrows resources from a pool and returns them to it at the end, or a `cached` helper where you check a cache for the resource and, if it isn't found, run the block to get it and then add it to the cache. In fact, you can add a helper like this for _any_ situation where you have 'before' and/or 'after' actions. And believe me, this is barely scratching the surface of what you can do with higher order functions.

OK, one last one. Say you want to create a basic immutable 'property holder' class style in Java, which is a fairly common requirement, you're going to need to write something like this:

```java
class Person {
    private final String name;
    private final int age;

    public Person(String name, int age) {
        this.name = name;
        this.age = age;
    }

    public String getName() {
        return this.name;
    }

    public int getAge() {
        return this.age;
    }
}
```

And the same in Scala?

```scala
case class Person(name: String, age: Integer)
```

Well, actually, the Scala version doesn't have quite the same functionality... The compiler will also generate a `toString` method which pretty-prints the values, and compliant `equals` and `hashCode` methods. So it's a significantly more functional class in _quite_ a lot less code. And if you want mutability, just prefix the argument names with `var` and it'll generate the setters too.

You can't even say the Scala version is cryptic this time, either.

If you're still reading and you've managed to hold off being offended for long enough to actually consider some of the points I've made, you're probably starting to thing that maybe, just _maybe_, Java isn't the language you want to spend the next God-knows-how-many years coding in. Pretty much the same position that hordes of C++ developers found themselves in all the way back in 1996.

The problem was that not much from C++ was salvageable when they moved to Java. Sure, all the language-agnostic skills such as functional decomposition, object-oriented design and the like were pretty transferable, but knowledge of all the class libraries and frameworks: gone. If you've spent a lot of effort learning all the Java libraries and frameworks and build systems and so on, you don't want to be in the same boat as those C++ guys and get reset back to scratch.

The thing is, you don't have to be.

Virtually everything I've picked on in this article has been problems with Java the _language_, not Java the _platform_. Java as a platform has a lot going for it. The virtual machine is stable, fast and widely supported. The packaging and deployment system makes a fair amount of sense. The frameworks and class libraries are extensive. What if you could retain _all_ your knowledge of _all_ of these things, and just switch to a [language](http://clojure.org/) [that](http://groovy.codehaus.org/) [made](http://www.scala-lang.org/) [them](http://jruby.org/) [more](http://www.jython.org/) [pleasant](https://developer.mozilla.org/en/docs/Rhino) to use?

That'd be pretty cool.

But which language to choose?

Well, that's the billion dollar question.

As you may have guessed from the code samples above, my best guess is Scala. It's object-oriented and strongly typed, unlike most other popular JVM languages, which will make Java developers feel right at home. In fact, it's pretty easy to write Java-like code in Scala, just with fewer lines. The syntax is kind of C-like if you squint. Well, it's got curly braces. And you can put semi-colons in there if you really want. And although it favours a functional and immutable style, you can mix and match imperative and mutable code as appropriate without feeling like you're being scolded for it.

You're still stuck with generic type erasure and some of the weird side effects that come with it. Nothing can fix that mistake other than an updated bytecode format, and hell isn't freezing over any time soon. But hey, nothing's perfect, and Scala still looks pretty compelling.

However, there are a few things standing in its way.

The first, and probably the most significant, is you've got to read [a book](http://www.amazon.co.uk/Programming-In-Scala-2nd-Edition/dp/0981531644) to learn it because some of the syntax and idioms are fairly non-obvious until you know them. And as Steve Yegge frequently points out, most developers are happy to read about frameworks until the cows come home, but ask them to read a book about a new language and they'll look at you with the same kind of horror as if you'd just asked them to cut off their own arm.

I've always found this an odd stance to take. When you're working in an industry where there are so many languages used, how can you _not_ be curious about what they have to offer and why other people might be using them? Even with languages I wouldn't claim to have any knowledge of, I've still probably read a book about them and/or played around with them for a couple of days just to get a bit of a flavour.

That's OK though. You've read this far, so you're probably not most developers. Go pick up a copy of that book from somewhere (if you're a Safari Books Online subscriber it's available to you right now) and spend a few weeks working through it. I guarantee you'll start looking at Java in a whole different way, and -- even if nothing else -- you'll finally understand that [Blub paradox](http://www.paulgraham.com/avg.html) article.

The second hurdle is the potential impedance mismatch between Scala and the Java-oriented libraries. Although it's easy to consume Java libraries from Scala, there are quite a number of libraries that assume your code will adhere to certain conventions, and may not function correctly - or at all - if it doesn't.

Perhaps the most common one is the 'Java bean' convention which requires a parameterless constructor, and all fields to be mutable with accessors named according to a `getX` and `setX` convention. Idiomatic Scala code will use immutable objects with a parameterised constructor, and the accessor method naming convention is `x` (getter) and `x_=` (setter), which is clearly significantly different, and means that frameworks like Spring, and serialisation libraries like Jackson are probably going to have issues.

Quite how much of a problem this impedance mismatch will cause I don't know. But it's definitely non-zero, and it could be significant, depending on how much you read into the [infamous email leaked from Yammer](https://gist.github.com/anonymous/1406238). It may be significant enough that it's actually more appropriate to use different frameworks and build systems like Play and SBT which are designed to be more Scala-friendly, reducing the previously hypothesised benefit of platform knowledge transferring directly.

The final hurdle will be the difficulty of getting Scala accepted - or even investigated - as an implementation language by companies due to FUD. That previously mentioned email seeded a lot of it and and I'm not convinced that the [official response](http://eng.yammer.com/scala-at-yammer/), which attempted to rectify the situation by explaining that all languages are crap and Scala was the least crap for some key systems, did much to help. Many companies will simply write Scala off as 'too experimental', 'too complex', 'too different', 'too slow', 'too risky', or any combination of the above.

This will probably be the hardest hurdle of all to overcome, because this decision is typically made by people who haven't done any development in years (if ever) and are unlikely to be swayed away from 'safe' technologies just because it might make the developers more productive. All languages are Turing complete, so how much difference can it make? Why would we move away from trusty Java?

Good question.

And I'm not sure I have a good answer.

Java is an outdated language, but that doesn't mean you can't build great systems with it. Most people consider C++ to be pretty outdated for systems building (that was the starting point for this post, if you can remember back that far) but Facebook use it extensively and it doesn't seem to have held them back too much. And there are some great frameworks that provide a lot of functionality and just use Java as the glue, so when there isn't a lot of actual code it might not be worth the effort to try and wedge some other language in there.

However a lot of Java code seems to make extensive use of frameworks to try and compensate for the language deficiencies, and these frameworks often _cause_ you to write even more complex and/or boilerplate code just to support the framework, meaning your useful code (i.e. the stuff that solves actual business problems) is lost in a mire of support code. Pretty much any framework that has a lot of `Factory`, `Manager` or `Provider` classes, or that requires hundreds of lines of XML configuration, is going to be in this category.

Take an honest look at your current codebase and see what proportion of it is real business code, and what proportion is either framework support code/configuration or dumb data transfer objects with no real behaviour of their own. If the ratio's not so good, you might be better off using a more modern language.
