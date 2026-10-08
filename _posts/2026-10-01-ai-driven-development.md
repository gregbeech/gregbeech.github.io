---
layout: post
title: AI-Driven Development (AIDD)
date: 2026-10-08
tags: [ai, software engineering]
author: gregbeech
comments: true
---

I haven't written code by hand in months, and I've never felt busier. That might sound like a contradiction, but it's the key to understanding where software engineering is headed. If you've been using coding agents seriously, you've probably noticed the shift too. The question isn't whether manual coding is on its way out, but what the job turns into once it's gone.

## The Inflection Point

A couple of years ago, AI coding tools were basically autocomplete that was wrong most of the time. Amusing, though. A year ago Copilot's code reviews were a quick way to generate a load of false-positive comments that you had to manually ignore.

Around the Opus 4.5 era things started to change. The coding agents got good enough that if you used planning mode and went round a few iterations of that, they could write _relatively_ decent code and save you a bunch of time. The later 4.x iterations brought better plans and better code. I didn't write a lot of code from scratch in this era, but I still probably rewrote 25--30% of the code so it was cleaner and actually worked.

Then Opus 5 launched, followed shortly by 5.5, and writing code by hand was dead. Game over. I don't use planning mode any more because it's no longer necessary. Instead I tend to get Claude to write up work orders for complex pieces of work that might span many pull requests, and then work through them. I don't rewrite any code by hand. At all.

I'm using Claude as my benchmark here because it's my daily driver, but talking to devs using GPT or Gemini, the story is the same. The specific model names don't matter as much as the shift: we all hit that same inflection point where these tools stopped being curiosities, stopped being basic code generators, and started doing real work.

Around the same time as Opus 5, Copilot's reviews got so good that detailed code reviews were basically dead too. In the last couple of weeks alone it's caught several race conditions and deadlocks I'd never have spotted by eye. I've stopped reviewing line by line; all I'm really looking for is whether the overall shape and factoring are sound.

Few people are going to mourn the passing of line-by-line reviews, but it forces the question: If we aren't writing the code and we're barely reviewing it, what are we actually doing?

And if we're doing so little, why do I feel busier than ever?

## The Paradox

Writing code is the easy bit between the hard bits. Sure, when you're learning it seems hard, but once you've been around a while it's rinse and repeat: putting things into databases and getting them back out again. It's one of the reasons LLMs are so good at it---there's a massive corpus of very similar code to train on.

So if the easy bits are done for you, all that's left is the hard bits. That's where you come in. What's the business need? How should we fulfil it? How should it be prioritised? What's the right architecture? What are the constraints? How good is good enough? LLMs can help you with all of these things, but they cannot drive them. Not yet, at least.

We've shifted from being writers of implementation details to acting as technical leads, directing agents to complete tasks on our behalf. They're capable, but they need clear scope and guidance before you set them off on autopilot.

Unlike human teams, though, adding agentic teammates doesn't trigger [Brooks's Law](https://en.wikipedia.org/wiki/Brooks%27s_law) in the usual way. Ramp-up is virtually instant, synchronisation is straightforward as it all flows through you, and most projects split naturally into independent workstreams. So why stop at _one_ when you can have several running in parallel? All you need are deep pockets.

With multiple agents on the go, all those natural breathers while a build finishes, a test suite runs, or a pull request needs review still happen, but now they're when you switch to the next agent. The dull, low-cognition gaps where your brain used to rest have been filled, leaving you with a relentless, back-to-back stream of high-level problem solving and context switching.

The slack in the system is gone. You don't just feel busier than ever. You are.

## The First Law

Handling that takes a workflow. But before we get into it, we need to talk about the First Law of AI-driven development. The [AIDD Manifesto](https://www.ai-driven-development.org/) lists it second, which I trust will be corrected in the next edition.

You own what you ship---even what the AI wrote.

The agent doesn't sign the commit; you do. It doesn't post PR comments under its own handle; it posts them as you. If an agent introduces a subtle race condition, a memory leak, or a security vulnerability, "the AI did it" is not an excuse.

Taking full accountability for code you didn't write by hand can be daunting, and you won't get comfortable with it overnight. You need to develop a solid workflow with a lot of safeguards to feel, and be, in control.

## Work Orders

We're used to maintaining backlogs of projects and tickets, most of which will never get done anyway. Given this post is already a mortuary for pre-AI practices, we can wheel tickets in as well. For feature work, at least. They still have a place for isolated bugs and out-of-band changes. Otherwise, tickets are replaced by work orders: a single document describing an entire project.

A work order is closer to a living design doc than a ticket. It starts with the status, how it'll be delivered, its scope, and links to the architecture docs it touches. Then it covers why the work is needed, what exists today (including the gotchas an agent won't spot just by reading the code), and a numbered list of decisions that later PRs and reviews can refer back to.

After the design itself come the parts that are easy to skip but matter most: what doesn't change, what the work fixes and what it doesn't, open questions, and anything that came up along the way but is out of scope. I often include a PR plan: a table of small, stacked PRs, each with the behaviour it changes and a "done when" column that serves as its acceptance criteria. The work order itself is PR 0, which is where the spec review happens.

```markdown
# Work order: <title>

**Status:** ... **Delivery:** ... **Scope:** ... **Governing docs:** ...

## 1. Why
## 2. What is there today
## 3. Decisions
## 4. Design
## 5. What does not change
## 6. What it fixes, and what it doesn't
## 7. PR plan
## 8. Open questions
## 9. Notes and follow-ups
```

Work orders can get big. One of my recent ones restructured how a key part of a system worked, was split across 12 planned PRs, and ran to over seven thousand words by the time all the notes and follow-ups were added. Most are between one and four thousand words, though.

I don't type any of them. Claude writes them over several rounds of me guiding and pushing back on decisions, with Copilot reviewing each iteration. Review agents still tend to go too deep on them, so you'll have to decide when enough is enough: a potential race condition doesn't need to be solved inside a work order.

Unlike tickets, work orders don't live in your issue tracking system. They live in a `/docs` folder in git, updated as work progresses so their history matches the code. You can still link them to Linear or Jira if you like---and that may still have value, I'm undecided---but the primary driver of feature work is now the work order in the repository itself, not the issue tracker.

Work orders are essential for giving agents scope and context, while keeping that context outside transient session memory. That way, you can clear chat sessions freely, recover the flow if a context window degrades, and work with smaller windows to keep API costs down.

## Environment and Safety

When you start out with coding agents, you'll probably run them with default permissions and have to click "Approve" a lot. It's a nice way to see the sort of things they do and build trust, but it rather gets in the way of productivity. You'll want to be running them on autopilot with minimal restrictions so they can get on with work.

However, a coding agent can run arbitrary code, which means it can do _anything_ within its reach. Logged into your cloud provider with high-level permissions? Say goodbye to your production database. It won't do bad things on purpose, but it will follow patterns to solve problems, and resetting a database to work around test failures is one of the patterns it knows.

The trick is to move the restrictions from the agent to its environment. Always---ALWAYS---run agents in isolated dev containers with restrictive tokens giving only the minimal permissions needed for that context, so an errant command can't wreck things or leak high-level credentials.

I store tokens in 1Password and reference them from `.devcontainer/onepassword.env`:

```env
GH_TOKEN=op://Private/<repo>/gh_token
MCP_TOKEN=op://Private/<repo>/mcp_token
```

Then I start VS Code using a wrapper script `./bin/code`:

```bash
op run --env-file .devcontainer/onepassword.env -- code
```

I also use 1Password to forward my SSH signing key into the container, so agents can sign commits without ever having access to the key. This approach keeps tokens and SSH keys entirely out of my host environment.

You should also set up some preflight checks in git so agents can't forget to do things like sign commits, check style, run tests, scan for secrets, and so on. They can---and will---work around these checks, so they're more what you'd call guidelines than actual rules. Your CI must duplicate any preflight checks to actually enforce them.

## Worktrees

Now into the practicalities of how you actually _build_ with multiple agents in parallel. One branch per repo just isn't going to cut it any more, so if you're not using them already, you need to start using git worktrees. Worktrees are additional working directories attached to the same repository, each checked out on its own branch, so several agents can work side by side without cloning the repo again.

I keep my worktrees inside the repo, under `.worktrees/`. A worktree isn't a self-contained checkout: its `.git` is just a file pointing back to the main repository's `.git` directory, so the container needs to be able to see both. With worktrees inside the repo, mounting the repository root covers everything. If you create them as siblings instead, you'd have to mount the parent folder, and that can leak other repositories into the container.

There's a bit of housekeeping to make this work. Set `worktree.useRelativePaths` so those pointers don't use absolute host paths that mean nothing inside the container. Add `.worktrees/` to `.gitignore`, and tell any tools that scan the repo, such as file watchers, test discovery, and search, to ignore it too.

Assuming you're spinning up your dev infrastructure with Docker Compose, worktrees can all share the same database servers and so on, but you'll want to give them each their own test database instances at the very least so they don't trample on each other. You can package this all up in a script like `./bin/worktree`, and mine also takes a `--code` argument to start VS Code in the new worktree via the `./bin/code` script.

I'll typically run two to four active worktrees at any one point, with two or three doing real feature work, and one or two doing related but orthogonal things that come up while they're going. I find if I get to four worktrees actively doing complex features, I start to struggle with my own context window.

## Context

`AGENTS.md` is loaded into every agent session, so it should hold only what an agent must always know, and nothing it could look up when needed. A good starting point is three parts:

1. A short project overview: what the system does and the key design decisions behind it, so the agent understands why things are the way they are.
2. A set of non-negotiable rules, each with a line on why it exists, because an agent that understands the reason is much less likely to find a clever way around it.
3. Standing instructions for how to work, and these are mostly scar tissue: always branch from a fresh base, never from whatever `HEAD` the last task left; always generate migrations rather than hand-writing the version; reply to every review comment before pushing.

Everything else, such as architecture, detailed guides, and command references, lives in `docs/`, with `AGENTS.md` acting as a map to it. It's one file, kept short, and every tool reads the same one.

Some agents also read their own instruction files. Copilot's review agent can use skills, and it's more likely to pick one up if it's named `code-review`, so `.github/skills/code-review/SKILL.md` is a good choice. There you can teach it things the generic reviewer would never know to check. For example, some of our models write their version history in callbacks, so the skill tells Copilot to flag any Rails method that skips callbacks, like `update_all`, when it's used on one of those models. It also explains the fix for bulk updates: write the version records explicitly.

That's a great start, but to really give the agents power to work on autopilot, they need MCP (Model Context Protocol) servers, which provide a standard way to read from (or write to) the outside world. It's pretty common to give them access to fetch metrics, logs, exceptions and so on to let them diagnose issues.

Where I think you really gain, though, is MCP servers into your own products, so they can pull relevant application data when working through things. Today, for example, I asked an agent which of our integrations was producing the worst-quality data. It queried the product through the MCP server, ranked them, dug into the worst ones to see what the problems were, and came back with an analysis of the commonalities and differences, and a proposed set of actions. That might once have taken me a couple of hours of digging around with SQL and spreadsheets. This took two minutes, while I made myself a cup of tea.

Once you've worked with this kind of dynamic context and analysis right in your dev environment, it'll be hard to imagine working without it.

Be very careful. You'll likely need to implement OAuth and/or OIDC on your product to support it, and that's your chance to scope tokens tightly: read-only, and no personal data unless it's genuinely needed. Personal data exposed through an MCP server is a data breach waiting to happen.

## Closing the Loop

With all the setup done, it's finally time to have your agent write the code. Done. Told you it was the easy part.

But now you need to verify it, if you're going to own it.

The first part of this is to get the agent to document in the pull request description which work order it refers to, which step(s) it implements, how the implementation works, any deviations from the work order and why, and anything else discovered during implementation.

You now have enough for a four-way alignment on what was requested (the work order), what was built (the code), what was verified (the tests), and what was documented (the PR description). If any of these things disagree, the review agent should flag it, and this is where you may need to get involved and decide what the correct approach actually should be. This may go through several iterations, with the agent replying to review comments as it goes.

I'll often do an initial high-level pass through the code when the pull request is opened to make sure I'm happy with the overall implementation, and point out anything I don't like, such as poor naming. I'll then do a final pass after the automated reviews have signed off, where I'm not reviewing for correctness; I'm making sure I understand what's about to get merged, because I'm going to own it.

## What It Costs

Money. It costs a lot of money.

Running several agents in parallel all day isn't cheap: several thousand dollars per month per engineer is in the ballpark for the frontier models like Opus. Whether that's a bargain or a problem depends on your company's attitude to AI spend, and policies vary wildly. Models are, to an extent, interchangeable. But your workflow will have attuned itself to the one you use most, and using cheaper models may not be worth the trade-off.

The bigger cost is to people, starting with juniors. The traditional entry-level role---picking up small, well-scoped tickets and working through them---is precisely the work agents are best at, and it's largely gone. But if we stop hiring juniors, we stop producing seniors, and in five or ten years there's a gap where they should be. The way in hasn't disappeared, but it has moved. A junior's first couple of years will be less about learning syntax and more about learning to judge output, write a decent work order, and notice what's missing from one.

Will we end up with engineers who can't code? To some extent, probably, and not just juniors. I can already feel my coding skills starting to atrophy. But that tends to happen once you reach staff level and your job becomes more about direction than implementation, and nobody thinks staff engineers are worse engineers for it. We've also long accepted engineers building database-backed systems who can't write SQL or read a query plan. Syntax fades quickly. Principles fade much more slowly, and working this way exercises them more, not less.

Then there's the exhaustion. I've already said the slack has gone, but it bears saying plainly: working like this is tiring in a way that writing code never was. It's compounded by a sense of a race. If everyone around you is running three agents, nobody wants to be the one still typing. That's not a healthy dynamic, and I don't have a good answer to it beyond noticing that it's there.

Finally, it doesn't work everywhere. Everything in this post relies on fast, reliable feedback: tests, preflight checks, CI. If you've got a legacy system without them, or you're working in a niche language the models have seen little of, retrofitting this way of working will be a long haul. You'll need to build the safety net before you can lean on it.

## What It Doesn't Cost

There are a few concerns I hear a lot that don't worry me much. Comprehension is one: if nobody wrote the code by hand, does anyone understand it? But you've never remembered every line of a codebase, and most of it was written by someone else anyway. The difference now is that the author is always available. Point an agent at unfamiliar code and you'll have an explanation in seconds, which is more than you can say for a colleague who left two years ago.

Correlated blind spots are another. If one AI writes the code and another reviews it, couldn't they both miss the same thing? Sure, but human teams share blind spots too. Make sure your writer and reviewer are different model families, though, so you're not having a model mark its own homework.

And then code quality. I'm not convinced agents are worse than humans here, and a few humans with agents working to strong, written-down guidelines may well produce a more consistent codebase than a large team ever did.

## Last Argument of Kings

A lot of people will be surprised to see me writing a post like this, advocating for letting the machines write the code.

Didn't I use to have almost impossibly high standards?

Didn't I use to _care_?

But I haven't stopped caring about the code. I care about it more, because I still own every line of it, and that's a lot more lines than I ever could have produced writing it by hand. The thinking that used to be squeezed between bouts of typing is now the whole job. I've never been busier, and for once, I'm busy with the right things.
