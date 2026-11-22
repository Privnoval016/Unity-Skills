---
description: >
  Planning assistant for Unity features. Explores codebase, asks thorough granular questions,
  writes an implementation plan, and runs a design review of the plan before it is shown. Invoke before
  any non-trivial implementation.
when_to_use: >
  "plan", "design", "implement", "add feature", "how should I implement", "think through",
  any request involving writing new systems or significant code changes.
allowed-tools: Read Bash Edit Write Skill AskUserQuestion
---

## CRITICAL RULE

**NEVER write or edit any code until you have asked all required questions and the user has answered
them.** This is not optional. No exceptions — even if the feature seems straightforward.

---

## Step 1: Explore First

Before forming any questions:

1. Read the relevant existing files using `Bash` (`find`, `grep`) and `Read`.
2. Read `${CLAUDE_SKILL_DIR}/../u-extensions/SKILL.md` and
   `${CLAUDE_SKILL_DIR}/../u-arch/extensions-ref.md` — identify which Extensions utilities are
   already available so you never propose reinventing them.
3. Check whether the Editor is reachable (`unity pipeline list --format json`). If it is, prefer
   reading real scene and asset state over inferring it from source — `get_scene_hierarchy`,
   `find_gameobjects`, `get_serialized_fields`. Source tells you what should be true; the Editor
   tells you what is.
4. Check for a project-level docs folder at the repo root (commonly named `Design/`, `.project-docs/`,
   `ProjectDocs/`, or `docs/` — the exact name varies per project). If one exists, read any files
   relevant to this feature (project state, installed packages, conventions, prior decisions)
   before proceeding — never assume a package is unavailable or a convention is unset without
   checking there first. If it holds a master game document or style bible (in this project,
   `Design/GAME.md` and `Design/STYLE.md`), any feature with a visible surface is planned against
   them, and any decision they mark **Open** is asked about, never assumed.
5. Identify every file, system, or SO that this feature will interact with.
6. If the project has its own workflow skill, engineering rules or reuse index (a `coc-workflow`-style skill, a
   `Design/project/engineering-rules.md`, a reuse skill listing its shared pieces), read them: they hold the project's
   standing practices and override this skill's defaults where they differ.
7. Read the design doc and guide of every area the feature touches, by section, and trust them. Where one is wrong,
   the plan fixes it. Never state a number, rule or name from memory: read the asset or the doc that holds it.
8. Explore wide work through small read-only agents (one per area, each with the files to read, what to report, and
   each claim marked read or inference), and read their reports' load-bearing claims yourself before relying on them.

---

## Step 2: Ask All Questions

Use `AskUserQuestion` to ask thorough, granular questions **before any code or plan is written**.

Ask as many question groups as the task requires. Do not compress distinct concerns into one
vague question. The goal is to eliminate all ambiguity before touching a file.

Cover every relevant area below. Skip a section only if it provably does not apply.

**How questions are asked and recorded** (these hold whatever the area):
- Ask directly in the conversation (`AskUserQuestion`): up to four at a time, two to four options each, the
  recommended one first and marked "(Recommended)", each saying what is already decided and what each option leads
  to. Never route the plan through a planning mode; the user approves it in the conversation.
- **One decision per question.** An option the user picks confirms what the question asked, not every field the option
  happened to describe; ask the fields separately when they matter.
- **Never decide for the user.** What the docs mark Open, what they are silent on, a name, a story element or a number
  nobody set is a question, never a choice the plan makes. A contradiction between two answers is asked again.
- **Record the answers word for word** where the project keeps decision records, with a line-by-line table marking
  each line a doc gains as the user's words, carried, or added by the planner (an added line is Proposed until asked).
- **Every decision gets a home**: each decided item that changes the game is a plan step, a to-do item, or built at
  once; a decision with none is a gap to fix before the next question.
- Visual questions are answered with mock-ups drawn over real captures of the product, never from memory.

### Feature Scope
- What is the exact behavior of this feature? Where does it start and stop?
- What is NOT in scope for this implementation?
- Are there edge cases or failure modes to handle now vs later?

### Architecture
- Does this belong in a MonoBehaviour (wiring/lifecycle only) or a plain C# class?
- Does this need a ScriptableObject? Which role (Config / Factory / Data Provider / Event Channel)?
- Are there existing systems it plugs into (Services, EventBus, state machine)?
- What is the ownership model — who creates, who holds, who destroys?
- Should this be injectable via interface?

### Data and Configuration
- What values does a designer need to configure? Where do those live (Config SO, inline)?
- Are there values derived from others (→ `OnValidate`)? Which fields should be `[HideInInspector]`?
- Are there magic numbers that need to be promoted to config fields?

### State and Lifecycle
- Does this have multiple states? If yes → PushdownAutomata or StateController?
- What triggers state transitions?
- What happens on enable/disable/destroy?

### Events and Communication
- What events does this emit? What events does it consume?
- Global broadcast (EventBus<T>), tight coupling (C# event), or SO channel?

### Performance
- Does it cost at first use (a compile, an instantiation, a shader variant)? A spike is worse than a steady cost.
- How is it measured before and after (the project's frame tools), for per-frame code, large surfaces or shaders?
- Is any code in Update, FixedUpdate, or a per-frame callback?
- Are there LINQ queries that need ZLinq?
- Is there runtime instantiation that needs pooling?
- Does this touch renderers (→ MaterialPropertyBlock)?

### Animation / Input / Physics (ask only if relevant)
- Animation: does this drive `IAnimationDriver`? What AnimDefs are needed?
- Input: does this read input? Through which `IInputSource`?
- Physics: does this add a pipeline stage? What priority? Does it query stats via Mediator?

### Integration Points
- What files need to change beyond the new ones?
- Are there serialized references that need wiring in the scene or prefab?
- What is the execution order (`[DefaultExecutionOrder]`) relative to existing systems?

---

## Step 3: Write the Plan

After the user has answered all questions, write a concrete implementation plan:

```markdown
# Plan: <Feature Name>

## New Files
- `<path>` — <one-line role>

## Modified Files
- `<path>` — <what changes and why>

## Implementation Steps
1. <First thing to do — specific>
2. …
<Small steps, each committed when it compiles with its tests green and its docs moved. General seams first: a
character's or a feature's mechanic is built from general pieces, never as an engine concept named after it. Visual or
structural work maps its parts and joints, and is reviewed, before it is built; never patch and recapture.>
<Mark each part that is a defined task (written input, files or a report out, a checkable done-when: tests for a
finished design, a helper to a spec, a doc sweep) as one a small agent can take beside the main work; it keeps the
main context clean and runs in parallel. Editor work and open judgements stay with the main session.>

## Architecture Notes
<Key decisions and why — reference answers from the Q&A>

## Folders
<Every new file's folder, named for its purpose and planned now, never moved later; split a folder before it holds
about eight loose files; each new folder gets its README and its line in the project's code map.>

## Authoring
<For each new serialized field or row: its tooltip, its default, what its picker offers (only valid choices: a narrow
type or a dropdown of what exists, never a typed key), what is hidden until it applies, and the warning shown for a
setup that would do nothing. Designers should find each seam easy and natural to author.>

## Tests
<Concrete cases per subsystem: edge, boundary, regression, empty, single, many, repeated, saved and loaded. A test never
pins a value a designer can tune (read it from the asset, or use made data); an assert inside a callback needs an
assert that the callback ran. Name the hollow-prone tests that get a break proof.>

## Docs
<Per step, every doc that describes what it changes: its design doc and guide, its folder README, the content index for
a new kind of asset, the to-do. Docs move in the same commit as the change.>

## Who pays
<Every field, flag, reference, list, interface member or branch the plan adds to a SHARED type (a component, config,
asset type or interface used by more than one thing): its users, and how many need it. If not all do, say where it
lives instead (the data that needs it, an opt-in component, a narrow capability interface). "None added" is a valid
answer; leaving the section out is not.>

## Performance Checklist
- [ ] ZLinq used instead of System.Linq where applicable
- [ ] No Find/GetComponent in hot paths
- [ ] Object pooling if runtime instantiation is needed

## Verification
<One runnable command per implementation step. See u-cli/recipes-ref.md.>
- Step N: `unity command ...` / `unity test --filter ...` — expected result
```

### The Who pays section is mandatory

A special case added to a shared type makes every user carry it (a field only three sequences use, on every sequence
director). Counting the users before writing the plan is cheaper than the refactor after; plan reviewers check this
section first.

### The Verification section is mandatory

Every plan ends with it, and every step needs a command that either passes or does not. A step nobody
can verify is a step that gets marked done without being done.

Draw the commands from `../u-cli/recipes-ref.md`: `recompile_status` for "does it build",
`unity test --filter` for "does it work", a capture for "does it look right", `unity vcs diff` for
"what actually changed in the scene".

**Prefer project verbs.** Run `unity command --tag coc --format json` first and cite existing
`[CliCommand]` verbs by name. For this project that currently means `coc_missing_refs` and
`coc_asset_audit` for wiring/data integrity, `coc_validate_actors` for combat work, and
`coc_hud_report` / `coc_theme_report` for anything visual — see `../u-cli/SKILL.md` for when each
applies. If a step names a sequence that has no verb and that sequence has come
up before, propose a new `[CliCommand]` for it as part of the plan — that is how the set compounds
instead of freezing at whatever shipped first.

Save the plan to `.claude/plans/<kebab-case-feature-name>.md`.

### The Design Review section is mandatory

Every plan ends with a `## Design Review` section, written in Step 4: who reviewed it, each finding kept
and what changed in the plan because of it, each finding dropped and why, and the questions it raised
for the user.

### Refactor plans

A refactor plan is a different kind of plan: it changes structure and no behaviour. Refactor does not
mean rewrite. Follow `../u-arch/refactoring-ref.md` ("How a refactor is done") and add to the plan:

- **Invariant**: what must not change, and how it is pinned (named tests, a before/after snapshot of
  data such as asset values, stat bases or references).
- **Steps**: new shape beside the old, callers moved in groups, a script for serialized data, the old
  shape deleted last; build and tests green after each step.
- **Smells addressed**: each one named, with its remedy.
- No feature or balance change in the same commits; list any found as separate follow-ups.

---

## Step 4: Design Review

A flaw found in the plan costs a paragraph; the same flaw found in code review costs the code. So every
plan is reviewed for design before it is shown, in addition to (never instead of) the code review that
ends the feature (`../u-review`).

1. **Two reviewers run in parallel**, read-only, on a cheaper model (sonnet), each with the plan's path,
   two of the four briefs from [reviewers.md](reviewers.md) (one takes design fit with data and authoring,
   the other behaviour with tests and verification), and the docs and decisions the plan rests on. Two,
   not the code review's four: the plan is short and the code review still runs in full. For a plan of a
   step or two, run the four passes yourself.
2. **Lead consolidates.** Merge duplicates, drop findings that contradict a documented decision, and
   **verify every remaining finding** against the code or doc it cites. A plausible guess is not a
   finding.
3. **Fix the plan.** Change the steps, files, tests or verification each kept finding calls for. A
   finding that needs a decision the docs don't hold becomes a question for the user, never a choice
   made in the plan.
4. **Record it** in the plan's `## Design Review` section, then present.

For a large plan, review it again after big changes; a re-review only reads what changed.

---

## Step 5: Present

After the design review, present the plan in the conversation for the user's approval before any implementation
begins (no planning mode), with the review's open questions asked alongside it (`AskUserQuestion`). Record the
answers as Step 2 says, fold them into the plan, and index the plan where the project lists its plans.

## Step 6: Build and close

Build in the plan's steps. A large step's staged diff gets a reviewer before it is committed; every line a helper agent
wrote is read before it is staged. The feature ends with the code review (`../u-review`), its findings fixed, the docs
checked, the lessons added to the skill that covers them as general rules, and the user's own check in the product.

---

## Continuous Improvement

When the user provides new planning requirements or workflow preferences that should apply
permanently: ask "Should I update this skill file for future sessions?" If yes, Read
`${CLAUDE_SKILL_DIR}/SKILL.md` and apply the minimal edit.
