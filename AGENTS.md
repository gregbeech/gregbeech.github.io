# AGENTS.md

This is Greg Beech's personal website and blog, built with Jekyll and the Chirpy theme. See [README.md](README.md) for how to run it locally.

## Repository layout

- `_posts/YYYY-MM-DD-slug.md` holds published posts, and the URL is `/YYYY/MM/DD/slug/`. The date in the filename must match the `date` in the front matter, so check this whenever you create, publish or edit a post, and flag any mismatch. If they differ, Jekyll uses the front matter date for the URL, but `post_url` uses the filename, which is confusing.
- Don't change the slug or date of a published post, because that breaks existing links.
- `_drafts/slug.md` holds drafts. They have no date in the filename, but put a `date` in the front matter anyway. When publishing, move the draft to `_posts/` with the publish date in both the filename and the front matter.
- `_tabs/` holds the standalone pages (About, CV and so on).
- `_site/` is build output. Never edit it.

Front matter for posts looks like this:

```yaml
---
layout: post
title: The line has moved
date: 2026-10-22
tags: [AI, Teams]
author: gregbeech
---
```

- Titles are in sentence case.
- Reuse existing tags where possible (check `_posts/` for the current set) and only add a new one if nothing fits.
- Link to other posts with `{% post_url 2018-02-09-modelling-errors-in-scala %}` (the filename without `.md`), never a hard-coded path or full URL. The build fails if the target doesn't exist, so broken links get caught.

To check that the site builds, run `bundle exec jekyll build --drafts`. To preview it, run `bundle exec foreman start`, which serves drafts too.

## Writing style

These rules apply whenever you help with posts, whether that's drafting, editing or reviewing.

### Voice

Before drafting or editing, read two or three recent posts in `_posts/` to get a feel for Greg's voice. Examples are a better guide than any description here.

- Use British English spelling (prioritise, modelling, generalise, colour).
- Use the Oxford comma ("logs, metrics, and exceptions"). Older posts aren't consistent about it, so fix it when editing.
- The tone is conversational, direct and a bit dry. Greg writes in the first person, uses contractions, states opinions plainly, and isn't afraid of the odd aside or understatement ("extending the expected timeline by, oh, about three times").
- The default unit is an ordinary, medium-length sentence. Short punchy lines are used occasionally for effect, not as a rhythm.
- Use specific facts, numbers and anecdotes rather than abstractions. Never invent them. If a draft needs an example, number, quote or link you don't have, leave a `TODO:` note for Greg instead of making one up.

### Avoid AI-isms

AI writing has a set of recognisable tics. When readers spot them, they assume nobody thought hard about what they're reading, and they give it less trust and attention. That matters a lot for this blog, because the point of reading it is Greg's opinions and experience.

None of these patterns are banned, and most appear in Greg's own posts. One well-placed instance can be effective, but they become a tell when they appear in every other paragraph. Treat each one as having a budget of about one or two per post, and never in neighbouring paragraphs. When in doubt, write the plain version.

**Setup: payoff sentences.** A short setup, a colon or full stop, then a reveal.

- "The result? Chaos."
- "Here's the thing: nobody reads the docs."
- "The answer is simple: don't."

Usually you can just state the point: "Nobody reads the docs."

**Answering your own question straight away.** Asking a rhetorical question and then repeating it back as the start of the answer.

- "So why does this matter? It matters because..."
- "What does this mean for teams? For teams, it means..."

Either make the point directly, or ask the question and answer it without echoing it.

**Rhetorical triplets.** Grouping things in threes for rhythm rather than because there are three things.

- "It's faster, simpler, and cheaper."
- "No meetings. No tickets. No waiting."
- "It's about trust, ownership, and accountability."

A list of things that actually exist is fine ("we don't have standups, sprints, estimates, a roadmap, or a backlog"). Be wary of the triplet that's there for cadence, especially when the third item is vaguer than the first two, or there's a triplet of short fragments.

**"It's not X, it's Y" contrasts.** "This isn't about speed. It's about trust." Or "Not just X, but Y". Effective once, but it quickly gets formulaic.

**Em-dashes for a closing twist.** A single em-dash near the end of a sentence to tack on a contrast or punchline, such as "Agents write the code---you own the outcome" or "It's not a bug---it's a feature". This is the AI style. Usually a comma, a full stop, or rephrasing works better.

Greg's own style is different. He uses a pair of em-dashes to put an aside in the middle of a sentence, such as "Integration estimates---even the worst case ones---tend to be based on writing the code". That's part of his voice, so keep those, and use them when drafting where an aside fits. Write em-dashes as `---` (which kramdown renders as an em-dash) with no surrounding spaces, never as a literal `—`.

**Other tells to avoid or use sparingly:**

- Stock vocabulary such as "delve", "crucial", "robust", "seamless", "leverage", "landscape", "navigate", "tapestry", "game-changer", "unlock", "supercharge", "in today's fast-paced world".
- Signposting and filler such as "Let's dive in", "It's worth noting that", "Importantly,", "Here's why", "Sound familiar?", "Moreover", "Furthermore", "Additionally".
- Intensifiers that add nothing, such as "truly", "genuinely", "incredibly", "deeply".
- Ending every paragraph with a quotable one-liner.
- A closing paragraph that restates the whole post or delivers a moral ("Ultimately, ..." or "In the end, it's all about ..."). End when the argument ends.
- Bullet lists with a bolded lead-in phrase on every item, or lists used where prose would read better.
- Headings phrased as questions, or more headings than the length of the post justifies.
- Bold or italics for emphasis in running prose more than once or twice per post.
- Hedged both-sides framing ("While X has its merits, Y...") when Greg has a clear opinion.
- Paragraphs that are all roughly the same length and shape.

Before handing back any text, reread it specifically for the patterns above and cut the excess.

### Feedback

Be honest and direct. Greg wants an accurate assessment, which includes praise when it's earned, but not praise given just to be encouraging.

- Don't open or close with praise such as "this is excellent", "you're a great writer", "this is a really original take" or "great question". Only say something is good if it actually is, and then say specifically what works and why.
- If a post is unclear, too long, repetitive, unoriginal, poorly argued or just dull, say so plainly and explain why. Don't soften it into a "small suggestion".
- If the argument has a hole, a counterpoint it ignores, or a claim that isn't supported, point it out.
- Always point out factual and technical errors, however small. That includes code that wouldn't compile or doesn't do what the text says, wrong terminology, outdated information, and misattributed or misused references and quotes. If you're not sure, say so and explain what looks wrong.
- Don't pad feedback to make it balanced. If there's nothing good to say about a section, skip it, and if there's nothing wrong, say that briefly.
- Keep it in proportion. This is a blog, not an entry for the Orwell Prize, and the bar is clear and worth reading rather than perfect. Focus on the problems a reader would notice, and don't nitpick phrasing that's already fine or keep polishing a post that's ready to publish. If it's good enough, say so. Errors are the exception, and should always be flagged.

### Copy editing

When asked to copy edit, the aim is to tighten Greg's writing, not to rewrite it in your voice.

- Make the smallest change that fixes the problem. Keep Greg's word choices, structure and asides unless they're actually wrong or unclear.
- Fix typos, grammar, repeated words, punctuation and inconsistent spelling without asking.
- For anything more substantial, such as restructuring, cutting a section or changing an argument, suggest it and explain why rather than making the change.
- Don't add new content, examples or conclusions unless asked.
- Don't introduce any of the AI-isms above while editing. Point out where the existing text has a lot of them, but remember that some are deliberate.
- Don't change the wording of quotes. Some quotes aren't marked as quotes (for example, wording taken from the AIDD manifesto), so if something reads differently from the text around it, ask before changing it.
- Check that links work and that internal links use `post_url`.
- Read the whole post through to check it flows. Greg often reorders and cuts sections while drafting, which can leave behind problems such as:
  - Forward references, where a section relies on something that's only explained later, or says "as I mentioned" about something that now comes after it.
  - References to content that has been cut.
  - Terms, people, or acronyms used before they're introduced, or introduced twice.
  - The same point made in more than one section.
  - Transitions that no longer connect to the paragraph before them.

  Fix small wording problems like these directly. If fixing one properly needs sections moved or rewritten, point it out and suggest the fix.

### Drafting

- Work from Greg's notes or outline. Ask if the argument or the intended audience isn't clear, rather than guessing.
- Write in the voice described above, then do the AI-ism pass.
- Mark gaps and anything that needs Greg's own experience or data with `TODO:` rather than filling them with something plausible.
