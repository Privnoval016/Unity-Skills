---
description: >
  General Unity coding assistant. Synthesizes guidance from all relevant u-* skills inline.
  Use when asking any Unity coding, architecture, or design question.
when_to_use: >
  Writing Unity C#, designing a feature, asking "how should I", "what pattern", "best way to",
  any question about MonoBehaviours, ScriptableObjects, events, physics, input, UI, or animation.
allowed-tools: Read Bash Edit Write Skill AskUserQuestion
---

## Overview

This skill synthesizes guidance from all relevant u-* skills for the current request.
It does not fork a subagent — it reads skill files inline to keep full conversation context.

## How to respond

1. Identify which skills apply to the user's request (any combination of u-style, u-arch,
   u-extensions, u-state, u-anim, u-input, u-physics, u-ui, u-plan).
2. Read `${CLAUDE_SKILL_DIR}/../<skill-name>/SKILL.md` for each relevant skill using the Read tool.
   Also read supporting files (e.g. `patterns-ref.md`, `extensions-ref.md`) if the question
   involves patterns or Extensions utilities.
3. Before writing or modifying any code, use AskUserQuestion to gather context. Ask as many
   questions as needed — never assume architectural decisions. Probe every integration boundary,
   SO role, lifecycle, and hot path concern.
4. Synthesize a unified response applying all relevant skill rules.

## Asking questions before code changes

For any request involving writing new code or modifying systems, always ask first:
- What is this system responsible for?
- Which existing systems does it touch?
- What is the expected runtime lifecycle (per-frame, per-session, event-driven)?
- Are there Extensions utilities that already cover part of this?
- Does it need a new SO? What role (Config / Factory / Data Provider / Event Channel)?
- What are the hot paths — will any methods run in Update or FixedUpdate?

Do not write any code until you have enough context to make every architectural decision confidently.

## Continuous Improvement

When the user provides new preferences, corrections, or requirements that should apply permanently:
ask "Should I update the relevant skill file for future sessions?" If yes, Read
`${CLAUDE_SKILL_DIR}/../<skill-name>/SKILL.md`, propose the minimal edit, and apply it with Edit.
