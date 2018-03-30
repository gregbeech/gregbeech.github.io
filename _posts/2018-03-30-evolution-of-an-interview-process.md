---
layout: post
title: Evolution of an interview process
date: 2018-03-30
tags: deliveroo interviews
author: gregbeech
comments: true
---

When I interviewed for Deliveroo a little over three years ago it was a tiny company so the 'process' was just a series of chats with a senior engineer, the CTO, and the CEO. All held in coffee shops because the single-room office had no free space. This approach is typical for early stage startups, and it actually seems to work reasonably well because we managed to hire some great engineers, many of whom still work at Deliveroo. But it's not really a scalable way to grow a team.

## The monolithic era

Our first attempt at a 'proper' technical interview process involved a take-home exercise to add email notifications to a basic Rails app which allowed voting on movies, affectionately known as Movierama. The take home exercise took around an hour to complete and it wasn't used as a screen; everybody who completed it would be invited in for a two hour on-site interview.

In those two hours the candidate meet one engineer who would spend ten minutes on introductions and outlining the interview format, an hour pairing with them to extend the feature they had done in the take-home exercise, half an hour asking general technical questions, and twenty minutes answering their questions. Then the engineer would make a decision and that would be it.

There were some good parts to this. In particular the take-home exercise wasn't just a throwaway waste of time to "prove yourself" and formed an integral part of the interview where candidates worked on code they were familar with on their own laptop. This meant we could avoid the whiteboard coding nonsense that is so common in tech interviews, which serves primarily to terrify candidates and make the interviewer feel smart.

There were also, fairly obviously, some bad parts. The fact that candidates only met a single person meant that the decision could easily be clouded by their perceptions, their mood on the day, or even just differences in what each of us looked for; there was no standardisation of what we wanted in a candidate beyond them being "good" and knowing Rails to at least some extent. It also meant the candidate didn't get to meet a cross-section of the people they'd be working with so it was harder for them to decide whether they wanted to join.

However, for all its flaws, it actually seemed to function pretty well for what we needed which was hiring people who could work with very little support and build moderately scalable stuff quickly in a big Rails monolith. At that early stage we barely had time to think, no matter teach, so we needed people who could hit the ground running in the language and framework we were using.

That's really the key to interviews. There are no perfect questions, and no way to thoroughly assess the capabilities that somebody has built up over two or ten or forty years in a few hours. What you need to do is focus on a set of criteria that matters to your company at the current time and the relatively near future and try to get enough signal to make a decision.

It would have been pointless for us to spend time asking about things we might do in the future such as building distributed systems, because it wasn't likely to be within the next eighteen months and we honestly didn't know if the company would still exist at that point. We certainly had no idea that it would reach the scale it has.

## The decomposition era

Through a mixture of luck, judgement, and sheer tenacity Deliveroo grew hugely over the next eighteen months and our team of ten engineers turned into ten teams of engineers. We were all still working on the monolith though and things were getting painful as the one-size-fits-all model was less than optimal, tests took hours to run, and of course a single code or deployment issue meant that everything could go down. Which it did. Frequently. Far too frequently now that we were leaving the trendy niche startup phase where people forgive these things and into the mainstream where they don't.

For a variety of reasons that I won't go into here, as it's a whole other series of posts, we decided that the best approach was to decompose the monolith into a federation of services.

The trouble is that you get what you hire for, so while we had a couple of people who had worked on distributed systems and service decomposition in the past, most people had just worked on Rails monoliths and many were already working on the biggest and most complex project of their career. We just didn't have enough people with the knowledge and experience to be able to drive the effort in any significant way.

As such, we decided to add a distributed systems stage to the interviews for anybody applying to senior level roles, to help us select for people with the skills we needed.

The question that would become our standard for the next eighteen months or so never really had much thought put into it. I'd started to plan extraction of customer identity from the monolith into a new service with no downtime (as we were now operating 24x7 around the world) and so when I needed to ask somebody about distributed systems and service decomposition it came fairly naturally that I'd ask about that. It's a harder problem than you might initially think once you consider things like registration and sessions.

Other people shadowed the interviews, and I wrote up a couple of pages on the kind of things I was looking for and the avenues people might go down, so others started using it too. Then people who had joined the company and been through the process started interviewing candidates and as far as anybody knew that was how we did things so they also used the same question.

For the specific set of skills we were looking for it wasn't a bad question. Sure, it had problems in that people who had done this kind of decomposition before could somewhat breeze through it without really being pushed anywhere near their limits; conversely people who hadn't sometimes got completely stuck and we never actually found out what they could do meaning we probably missed out on some really good people. But as noted previously you have to tailor interviews for what you need at the time.

## The transitional era

Around nine months ago we were noticing that the candidate pipelines had been a little dry. We weren't sure why because Deliveroo was going from strength to strength, and we'd been making ourselves more visible in the tech community by writing blog posts, speaking at conferences, hosting events, and all the other stuff tech companies try to do to raise their profile. But we just weren't getting many people in for interviews, and even the ones that got scheduled were frequently being delayed or cancelled.

We already knew we had pretty much exhausted the pool of Rubyists and had extended our hiring profile to be anybody who knew any language and was willing to learn and work in Ruby. What it took us longer to realise was that the take-home exercise being in Ruby was putting a lot of people off as either they didn't want to spend time learning it for a job they hadn't got yet, or they didn't feel that they could show themselves in the best light doing an exercise in a language they had just picked up. These are both completely reasonable viewpoints. But many people didn't tell us; they just dropped out of the process.

We discussed dropping the take-home exercise entirely, but that would mean we'd either end up starting a new project in the interview or going back to whiteboard coding, which are both things we wanted to avoid as we want to keep interviews as comfortable and productive as possible. I started chatting to [Tom Leitch](https://twitter.com/shoez) and [Lyn Vallet](https://twitter.com/sherlynvallet) about designing and trialling a new language-agnostic question and soon we had something we were using instead of Movierama.

The number of candidates picked up again. I won't discuss what the exercise is as we're still using it, but although it's been better than Movierama and it has worked well in the take-home part, it hasn't been as good as I'd hoped for the pairing part of the interview. I guess that's what happens when you do something in a rush. Designing interview questions is hard, and takes time to do well.

There were a whole bunch of changes that also happened around the same time.

A "culture fit" interview was added which aimed to ensure that the candidate was the type of person who would be successful at Deliveroo and not a [brogrammer](https://en.wikipedia.org/wiki/Brogrammer) or a [rockstar](https://www.hanselman.com/blog/TheMythOfTheRockstarProgrammer.aspx) or any of those other stereotypes who will completely and utterly ruin your culture.

The two hour pairing interview was also reduced to one hour instead of two. This was partly in response to engineers who found that a two hour block was just too disruptive to their day because we were still very stretched, and because you already had enough signal in the first hour to make a decision (I have to admit I was particularly vocal about this). It was also partly because with the addition of the culture fit interview there would have been four hours of interviews back-to-back which is bordering on inhumane.

Yeah, I know Amazon and Google and the like do six hours or more of back-to-back interviews. I've been though them. They're harrowing. Don't make excuses for it, and don't copy them.

So we had a four part process which became the template for what we currently do:

- Take home exercise (typically 2-3 hours)
- 1 hour on-site pairing interview
- 1 hour on-site distributed systems interview
- 1 hour on-site culture fit interview

But we still had some major changes to make before we were happy with it.

## The modern era

First things first, the "culture fit" interview became a behavioural interview. The goal was still the same--to try and ensure that we hired people who would be successful at Deliveroo--but the focus was changed to be less about culture fit and more about whether people exhibited desirable behaviours. This might seem like a subtle distinction, but it's an important one as culture fit implies that we're trying to hire a brigade of clones, whereas Deliveroo values diversity and people shouldn't have to 'fit' into a culture. Culture can and should evolve.

We also added more people to the interviews. While we had already added a second person to the pairing interviews, the architectural and behavioural interviews were done by a single person. The reasoning behind this was rather primitive: We had fewer people capable of running those interviews and we didn't want to use up all their time doing it.

This was horribly flawed reasoning: Firstly, if nobody else from Deliveroo was in the interviews then we weren't training anybody else up to be able to run them, so as the company grew faster we had the same sized pool of interviewers running more and more interviews. Secondly it meant that the candidates could be subject to a single interviewer's communication style, biases, mood, etc. on the day and not have a second opinion who might see a different side of them (for good or for bad). Thirdly, in those interviews where you can't quite work out what you think, it meant the interviewers had nobody who they could discuss it with.

The solution was obvious. All sessions now have two interviewers. There was some resistance at first because even more of people's time was spent doing interviews rather than "real work" but in the longer run it means we have a much larger pool of interviewers so everybody has to do fewer of them.

Finally we changed the distributed systems interview to be an architectural interview. We were already a long way down the service decomposition route and were running over twenty services in production with about the same number again in development, so while people with distributed systems skills were still very desirable we also needed people who were great at building the individual systems. In particular, we were often missing out or mis-levelling people from larger companies who often had worked on large-scale systems but who our question just didn't work for.

This time we didn't rush into it though. [JP Hastings-Spital](https://twitter.com/jphastings) and I managed to rally a reasonable sized group together and we spent a few sessions working out what we wanted to test for and brainstorming to come up with a scalable question that would work for people of different levels and types of experience. We then worked through it ourselves and spent weeks mock-interviewing volunteers to refine the question, wording, and ensure that there were different directions it could be taken in depending on the candidate's experience. It was a really interesting process which I'll write up as a separate post.

The four part process remains, but now the interviews are much better and we've been getting pretty good feedback on it from candidates, both successful and otherwise.

## The future

The current process isn't the end of the evolution.

What we need will change over time and I'm sure our interview process will too. We're already trying out phone screens for some jobs to improve the signal-to-noise ratio and as with everything else we're trying to make these fairly 'developer friendly' because we know that many people don't particularly like talking on phones (I'm one of them).

Another group of people are also working to improve the take-home exercise and pairing interview so that part should get better in the not-too-distant future. It won't happen immediately as we've learned from our mistakes and know we need to really trial these things before we roll them out.

If you're not already working at Deliveroo maybe you'll consider [applying](https://careers.deliveroo.co.uk/?country=united-kingdom&remote=&remote=true&team=engineering#filter-careers) and helping us improve. We'd love to hear from you.
