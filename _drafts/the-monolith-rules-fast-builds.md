---
layout: post
title: "The monolith rules: Fast builds"
date: 2025-06-07
tags: [monoliths, rails, django, ruby, python, ci, cd]
author: gregbeech
comments: true
---

This is part 2 of the monolith rules series; previous parts can be found here:

<ol start="0">
  <li><a href="/2025/06/06/the-monolith-rules-introduction/">Introduction</a></li>
</ol>

## Rule 1: Have fast build/test/deploy cycles

Monoliths seem to tend towards a painful state where setting up the application and its dependencies takes hours, running the tests locally takes an eternity, some of the tests won't run locally unless you spend another day or two finding the right incantations to get _those_ native dependencies to install correctly, and then even though you've split your tests out into numerous parallel jobs in CI it still takes twenty minutes to check a pull request and another half hour or so to deploy.



Your cycle time to deploy even a small change goes to an hour plus, and you get nervous deploying because issues will be slow to fix, rolling forwards is too slow to be viable, and rolling back is risky or even impossible if you've made incompatible database changes. Say goodbye to productivity, and hello to everybody building new services outside the monolith, if only to get away from the painfully slow cycle times.

More than anything else, slow tests, build and deploys will kill your monolith because if nobody _wants_ to work on it you haven't just lost the battle, you've lost the war.

The biggest culprit by far tends to be the use of database entities in tests, so even web or controller tests need to have data set up, queried, and torn down. For tens of test suites this might not seem like a huge deal, but once you've got hundreds or even thousands of suites, it can be the difference between sixty seconds and sixty minutes for a full test run. Avoid hitting the database in tests unless you're specifically testing database interactions, or in a very limited set of full system tests.

As a heuristic, I'd suggest any time your builds or deploys get above around five minutes, you should spend some time making them faster. Don't wait until they get to twenty or ten minutes before you act, because by then you're already on the fated path.