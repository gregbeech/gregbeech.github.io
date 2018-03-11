---
layout: post
title: Evolution of an interview process
date: 2018-03-11
tags: interviews
author: gregbeech
comments: true
---

When I interviewed for Deliveroo a little over three years ago it was a tiny company so the 'process' was just a series of chats with a senior engineer, the CTO, and the CEO. All held in coffee shops because the single-room office had no free space. This approach is typical for early stage startups, and it actually seems to work reasonably well because we managed to hire some great engineers, many of whom still work at Deliveroo. But it's not really a scalable way to grow a team.

## The monolith days

Our first attempt at a 'proper' technical interview process involved a take-home exercise to add email notifications to a basic Rails app which allowed voting on movies, affectionately known as Movierama. The take home exercise would take about an hour and it wasn't used as a screen; everybody who completed it would be invited in for a two hour on-site interview.

In those two hours the candidate meet one engineer who would spend ten minutes on introductions and outlining the interview format, an hour pairing with them to extend the feature they had done in the take-home exercise, half an hour asking general technical questions, and twenty minutes answering their questions. Then the engineer would make a decision and that would be it.

There were some good parts to this. In particular the take-home exercise wasn't just a throwaway waste of time to "prove yourself" and formed an integral part of the interview. This meant we could avoid any of the whiteboard coding nonsense that is so common in tech interviews, and which serves primarily to terrify people and make the interviewer feel smart.

There were also, fairly obviously, some bad parts. The fact that candidates only met a single person meant that the decision could easily be clouded by their perceptions, their mood on the day, or even just differences in what we look for; there was no standardisation of what we wanted in a candidate beyond them being "good" and knowing Rails to at least some extent. It also meant the candidate didn't get to meet a cross-section of the people they'd be working with.

However, for all its flaws, it actually seemed to work pretty well for what we needed which was hiring people who could work with very little support and build moderately scalable stuff quickly in a big Rails monolith. At that early stage we barely had time to think, no matter teach, so we needed people who could hit the ground running in the language and framework we were using.

That's really the key to interviews. There are no perfect questions, and no way to thoroughly assess the capabilities that somebody has built up over two or ten or forty years in a few hours. What you need to do is focus on a set of criteria that matters to your company at the current time and the relatively near future and try to get enough signal to make a decision.

It would have been pointless for us to spend time asking about things we might do in the future such as building distributed systems, because it wasn't likely to be something we'd do for at least eighteen months and we honestly didn't know if the company would still exist at that point. We certainly had no idea that it would reach the scale it has.

## The decomposition days

---








However, when we did reach the point where we had started breaking the monolith up into multiple services, we reassessed our interview process. We had lots of people who were great at building features in a Rails monolity but a dearth of people experienced in building distributed systems. As such, we decided to add an architectural stage to bias the interviews more towards senior engineers who could help lead the service decomposition effort.

As the company grew, we also added a behavioural interview to better assess whether people would be successful at Deliveroo and share similar ethics, values, and so on. In tandem, we cut the pairing exercise from two hours to one, as we felt that any more than three hours on-site would start being too harrowing, and the signal we'd get from more would be subject to the law of diminishing returns. We now had a four part process:

- Take home exercise
- 1 hour on-site pairing interview
- 1 hour on-site architectural interview
- 1 hour on-site behavioural interview

This would become the template for our process, but we still had some major changes to make before we were happy with it.

While we always had two people in the pairing interviews, the architectural and behavioural interviews were done by a single person. The reasoning behind this was rather primitive: We had fewer people capable of running those interviews and we didn't want to use up all their time doing it.

This was horribly flawed reasoning in many ways.

Firstly, if nobody else from Deliveroo was in the interviews then we weren't training anybody else up to be able to run them, so as the company grew faster we had the same sized pool of interviewers running more and more interviews. Secondly it meant that the candidates could be subject to a single interviewer's communication style, biases, mood, etc. on the day and not have a second opinion who might see a different side of them (for good or for bad). Thirdly, in those interviews where you can't quite work out what you think, it meant the single interviewers had nobody who they could discuss it with.

The solution was obvious. All sessions now have two interviewers. There was some resistance at first because even more of people's time was spent doing interviews rather than "real work" but in the longer run it means we have a much larger pool of interviewers so everybody has to do fewer of them.

We also had the problem of the questions.

Movierama was a Rails app but by now only around twenty percent of the people we were hiring listed Ruby as their primary language. We were losing a lot of people at the pre-interview stage because they didn't feel they'd be able to show their best work.

The architectural interview was also just based on some work I'd done to initially separate out identity from the monolith, and was concerned entirely with service decomposition in a system where downtime wasn't an option. This wasn't what we needed any more as we were well on that track, and it was excluding people who were good systems builders, particularly those joining from larger companies.

More in designing interview questions (LINK IN FUTURE).













