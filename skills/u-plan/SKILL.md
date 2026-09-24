---
description: >
  Planning assistant for Unity features. Explores codebase, asks thorough granular questions,
  writes an implementation plan. Invoke before any non-trivial implementation.
when_to_use: >
  "plan", "design", "implement", "add feature", "how should I implement", "think through",
  any request involving writing new systems or significant code changes.
disable-model-invocation: true
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

---

## Step 2: Ask All Questions

Use `AskUserQuestion` to ask thorough, granular questions **before any code or plan is written**.

Ask as many question groups as the task requires. Do not compress distinct concerns into one
vague question. The goal is to eliminate all ambiguity before touching a file.

Cover every relevant area below. Skip a section only if it provably does not apply.

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

## Architecture Notes
<Key decisions and why — reference answers from the Q&A>

## Performance Checklist
- [ ] ZLinq used instead of System.Linq where applicable
- [ ] No Find/GetComponent in hot paths
- [ ] Object pooling if runtime instantiation is needed

## Verification
<One runnable command per implementation step. See u-cli/recipes-ref.md.>
- Step N: `unity command ...` / `unity test --filter ...` — expected result
```

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

---

## Step 4: ExitPlanMode

After writing the plan file, call `ExitPlanMode` to present it to the user for approval before any
implementation begins.

---

## Continuous Improvement

When the user provides new planning requirements or workflow preferences that should apply
permanently: ask "Should I update this skill file for future sessions?" If yes, Read
`${CLAUDE_SKILL_DIR}/SKILL.md` and apply the minimal edit.
