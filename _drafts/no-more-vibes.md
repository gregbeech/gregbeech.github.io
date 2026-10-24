---
layout: post
title: No more vibes
date: 2026-10-24
tags: [AI]
author: gregbeech
---

> TODO: Check all the numbers in this post against my notes, in particular the training and validation split (roughly 40k/20k?), Haiku's score on the description exam set (around 99%?), the per-class results, and how often the human labellers agreed before disputes were resolved (ideally as Cohen's kappa).
{: .prompt-warning }

At [Jitty](https://jitty.com/) we have a lot of enrichments that use LLMs to pull structured data out of property listings. Every one of them was built on vibes. You pick some listings that look representative, write a prompt, check it works on the listings you wrote it against, and call it good.

That works well enough until you need to know how well it works. We have no measure of precision or recall for any of them. Models change, sometimes even when the version number doesn't, and when they do we can't say whether an enrichment got better or worse. We also can't switch models, because we don't know whether it's safe. Our older enrichments use Gemini 3.1 Flash Lite. Gemini 3.5 Flash Lite is newer but more expensive, and we don't know if it's worth the money. Haiku 5.5 is cheaper than both, but we can't move to it either, because we have nothing to measure the change against.

I knew there was a proper way to do this. People in ML build evals, which are labelled test sets that give you real numbers for precision and recall, so you can compare one model or prompt against another. What I didn't know was how to build one, because I don't know anything about machine learning. So when we needed a new enrichment for one of our most important fields, I let AI walk me through it.

## The problem

Two of the fields that matter most to us are the property type, such as a house or a flat, and the built form, such as detached or semi-detached. Both are usually buried somewhere in a free-text description written by an estate agent. We also wanted to read Energy Performance Certificates (EPCs) from listing images, pulling out the current and potential scores and bands for energy efficiency and environmental impact, the certificate number, the issue date, and the valid until date. That's harder than it sounds, because there are several types of certificate including legacy ones, not every field appears on every type, and some show only a graph. Agents also misfile things, so an image filed as an EPC might turn out to be a floorplan, a note saying the EPC is to follow, or a certificate from a different scheme entirely.

Property type is a critical field for us, so I didn't want to build another enrichment on vibes. I needed a way to know it was right that didn't rely on my own judgement, because in this domain my judgement isn't worth much.

## The guide is the product

Almost all of the method came from AI. Claude guided me through most of it, and Copilot's reviews picked up a lot of places where bias could creep in, such as how candidates were selected for labelling and gaps in the methodology. I was mostly learning as I went, which means that, in the interests of full disclosure, the system for getting rid of the vibes was itself thoroughly vibe coded. I'm aware of the irony.

The core of it is a labelling guide, which is a written set of rules for deciding the right answer for any given item. Humans label against it, and the model is given the same guide, word for word, as its prompt. That makes the guide the product. The labels measure two things at once: how well the model follows the guide, and whether the guide is clear enough to follow.

What they don't measure is whether the guide's definitions are the right ones. That's a judgement call, and it's ours. But we work in property, we live and breathe it, and we talk to customers all the time, so if we agree on a definition it's probably one other people would agree on too. Most people wouldn't even know there's a difference between a property type and a built form.

The guide ends up as a long list of very specific rules, most with a worked example, because the general rules are the easy part and it's the edge cases where people disagree. The EPC guide has rules like these:

> Check which column each arrow sits in, by the column's heading: swapping `current` and `potential` is the commonest misreading.

> An arrow's band is the one whose range, printed on the scale, holds its score, not the row it seems to sit beside: an arrow often straddles the line between two rows, or carries no letter. An arrow of 69 drawn between the C (69-80) and D (55-68) rows gives band C.

And one principle runs through all of it: "Leaving a value out is always better than guessing it."

Floorplans are harder still. That guide is still a draft, so there are no numbers yet, but it shows how much judgement hides in what sounds like a simple question. Is the area in square metres or square feet, and does it include the garage? If a plan says "87 sq ft" for a three-bedroom house, do you record what it says or what it obviously means? (What it says.) And what counts as a bathroom?

> A WC or cloakroom on its own is not a bathroom, "En-suite WC" included; nor is a bedroom with a bath drawn in it. A room's colour alone is not a label.

None of those have an obviously right answer, which is why they need writing down.

The labellers have their own instructions, and the first is "Label what the guide says, not what you know." Where the guide doesn't settle something, they still give their best answer, but write a note saying what the guide left open. The model only has the guide, so a labeller who fills a gap from their own knowledge is hiding a mistake the model will go on to make. For example, the EPC guide used to say the certificate number was labelled "Reference number (RRN)", which is true of older certificates, but newer ones say "Certificate number". Anyone who knows EPCs would have read it correctly anyway, and the hole would have stayed hidden. Because the labellers stuck to the guide, it got flagged and fixed.

## Building the exam

The guide is built and tested with two sets of items labelled by humans.

The first is a practice set of 100 items. Two people label each one blind, without seeing each other's answers, and then resolve the disputes together, able to see what the other person said. The disputes and the labellers' notes are the most valuable thing the practice set produces, because each one is a gap in the guide. Once those are closed, the guide is locked.

Only then is the exam set of 300 items opened. Again, two people label each one blind. This time, when they resolve disputes, all they can see is that there was a dispute, not what the other person answered. Each checks their label against the guide and either corrects it or stands by it, and nobody changes a label just to agree. If the guide can't settle an item, it's taken out of the exam, and the guide is fixed for the next one. Items that are taken out are still counted and reported alongside the score, so an exam can't quietly lose the items it finds hard.

Three hundred isn't an arbitrary number. If a model gets every item in a set of *n* right, its real error rate could still be as high as about 3/*n*, so 300 items is roughly the smallest exam that can show 99%. Rare values and known traps are oversampled so the exam covers them, and the scores are weighted back to how often each case actually occurs.

We also made sure no estate agent appeared in more than one set. Agents have a house style, and if the same agent's listings appear in the training and test data, a model can score well by recognising the style rather than the property. We did that even for EPCs, where there's no house style to speak of.

The one idea I contributed was showing each labeller the items in a different order, to reduce any bias from the ordering. None of the models suggested that, and apparently it's a good idea, so I'm not a total idiot.

TODO: Who were the labellers, and how long did it take?

## Sitting the exam

For EPCs, the guide is the enrichment. In production, Haiku 5.5 reads each EPC using the locked guide, and on the exam set it scored 100% precision and recall.

Descriptions went a different way. We used Haiku and the guide to label 60,000 descriptions, trained on about 40,000 of them, and kept the other 20,000 back for validation. The model is DistilBERT, a small pretrained transformer, fine-tuned with two heads, one for property type and one for built form. They share most of the model, because knowing the built form tells you a lot about the property type, and vice versa. It takes up to 256 tokens of input. We trained it for five epochs and kept the third, which had the best validation loss, and then quantised it to int8 so it runs on CPUs. I've since learned the names for most of this: knowledge distillation, multi-task learning, and early stopping.

The reason for training a model rather than just using Haiku was determinism. Even with the temperature set to zero, an LLM won't always give you the same answer for the same input, whereas a fine-tuned classifier will. It also shows up in the scores. A model that isn't deterministic sits the exam more than once, and any item whose answer changes between sittings gets listed, because a model that wavers is worth less than its average score suggests. I originally wanted determinism for snapshot tests, which turned out to be naive, because models like this are far too slow and memory hungry to run in tests, even just to regenerate the snapshots. Determinism probably matters less than I thought, but property type is critical, and I still feel better having that stage of the pipeline give the same answer every time. Where the model's output doesn't match, we'll add a second pass that uses an LLM to fill in the property type. TODO: Doesn't match what?

On the exam set, which nobody looked at until training was finished, the model scored over 99% precision and recall. I've also been through a lot of production examples and haven't found a mistake on anything it was trained to handle. The recall errors we did find were on things like houseboats, which made up too small a fraction of the training data to register.

## What the numbers buy you

The first thing the exam sets gave us was an answer to the model question. In the new enrichments, Haiku 5.5 performs notably better than either version of Flash Lite, and it's cheaper than both. Without the exam sets that would have been another vibe.

They also make every future change measurable. Whenever the code, the guide, the prompt, or the model changes, the new version sits the same frozen exam, and the results are compared item by item rather than just in total, so you can see what the change fixed and what it broke. Nothing ships without its exam score next to the score of the version it replaces.

An exam is also a snapshot. Ours include every historical EPC format, but they can't include formats that don't exist yet.

None of that helps the existing enrichments, though. Even knowing that Haiku 5.5 does better on these tasks, it's still too risky to switch them over, because they don't have an exam to sit. TODO: What's the plan for the existing enrichments? Retrofit exam sets, or rebuild them this way as they're touched?

## Trusting the method

What I keep coming back to is how little of this I could have checked myself. One AI designed the method, and another AI reviewed it, but if they'd both been wrong in the same way, I wouldn't have known.

The thing that made it trustworthy wasn't the AI. It was the 300 items that two humans labelled blind, against a guide that was locked before anyone looked at them, from agents the model had never seen. Everything else in the pipeline came from a model, but the measure of whether it worked didn't. The production spot checks back that up.

It also helps that the labellers are measured too. If two people agree with each other less often than a model is meant to be right, the guide isn't clear enough yet, and no model can be shown to be better than the people marking it.

I still don't understand all the nuance, and some of it I'd never have thought of. If you change a model based on what it got wrong in the exam, the exam has to be retired into practice and a new one drawn from estate agents nobody has seen yet. That much I could follow, because otherwise you're tuning to the exam. But the obvious shortcut is to replace only the items it failed, and that's wrong too, because you keep the items you already know it gets right, so the next score can go up without the model getting any better. I take a lot of rules like that on trust, which isn't very satisfying, but it's the same position Rich, who looks after growth for us, is in when he [ships code relying on guardrails he didn't build]({% post_url 2026-10-22-the-line-has-moved %}).

What I do understand now is why data scientists say the job is 95% data prep and 5% data science. The model was the easy bit. Nearly all the work, and all of the confidence, came from the labelling.
