---
layout: post
title: Just build it! (but don't ship it)
date: 2025-05-15
tags: [decision making, deployment, velocity]
author: gregbeech
comments: true
---

How much time have you spent arguing whether you should build something or not, while you've been sitting there thinking "I could have built it in the time we've spent arguing about this"? Probably more than you'd like to admit. I know I have. The problem is you're having the wrong argument. The question isn’t whether you should build it; it’s whether you should ship it.

Just build it!

But---for heaven's sake---don't ship it to anybody outside your team.

If you’ve been arguing for more than a small portion of the time it’d take to just build the thing, it means your docs, designs, or prototypes aren’t sufficient to build conviction one way or the other. You’re already [using feature flags](/2020/11/02/feature-flags/) to safely try things in production, so instead of going in circles, hack together a quick-and-dirty real version and actually try it.

Documents are great. Prototypes are even better. But for some features there’s nothing like using the real thing with real production data to see if it actually passes [the eye test](https://bleacherreport.com/articles/144924-the-eye-test). The idea that half the team dismissed might be a gamechanger, and the slick design everyone's excited about could turn out to be a damp squib.

At [Jitty](https://jitty.com/) we spent _ages_ debating whether natural language search was worth implementing. Various arguments about whether it could be done well, whether i'd be a better user experience, and whether the data we'd collect about what people really want would be worth it. It kept coming up again and again over the course of months, and it never quite made it in, but never quite made it out. So one hack day I just implemented it and pushed it into production for the team.

It was crusty and rough round the edges and got a whole bunch of stuff wrong, but it got a whole bunch of stuff right too, and the idea that seemed kinda "meh" became an obvious thing we needed to ship. So we built improved versions for ourselves at least daily---[straight into production](/2024/12/22/exit-staging-left/)---until it was good enough to ship to real users.

We talked about embeddings a lot too. Same deal, it kept coming up again and again for months. Until one afternoon [Coops](https://coops.dev/) hacked together a terribly ugly prototype in the admin site with a bunch of vectors in a GCS bucket, and we were all blown away. Why hadn't we just done this months ago? A few days later we had a version on the main site, just for us, and when that was good enough for real users we shipped it to them too.

Stop discussing, start doing. [Eat your own dogfood](https://en.wikipedia.org/wiki/Eating_your_own_dog_food) until it's people food, and then dish it out.

But not all dogfood turns into people food. Sometimes dogfood is just dogfood.

Some features are obviously great from the first hacked-together version. Some are obviously not. But most of the time, you're stuck in the middle. It feels like it has potential, but it’s not quite there. So you keep iterating, shipping internal versions, polishing the rough edges. And eventually, it's... fine. Not exciting, but fine. Nobody on the team's thrilled about it, but you’ve already sunk time and effort into it, so you might as well ship it and see what users think.

Don’t do that.

Have the real conversation: should we actually ship this? Now you’ve got a working version, you have all the information you need. It might not be an obvious yes or no, but that's why you need to be open and honest. If you’re going to ship it, you need real conviction. If it doesn’t pass the eye test internally, and you’re the ones who designed and built it, then it sucks. You could ship it and let the metrics tell you it sucks, but deep down you already know.

Cut your losses. Move on.

Just build the next thing!

(but don't ship it)
