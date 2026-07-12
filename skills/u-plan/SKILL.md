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
3. Identify every file, system, or SO that this feature will interact with.

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
```

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
