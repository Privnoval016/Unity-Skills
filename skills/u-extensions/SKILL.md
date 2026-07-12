---
description: >
  Extensions library first-look. Check here before writing any new utility, timer, event system,
  state machine, condition evaluator, rule system, or modifier stack — it likely already exists.
when_to_use: >
  About to write a new helper class, timer, event bus, state machine, condition tree,
  rule engine, or modifier system. Any time "I need a utility that..." appears in the conversation.
user-invocable: false
---

## Rule

**Before writing any new utility class, check the Extensions library.**

The Extensions library ships across all projects and covers the most common game programming utilities.
For the complete reference table see [extensions-ref.md](${CLAUDE_SKILL_DIR}/../u-arch/extensions-ref.md).

## Quick Checklist

Ask before proposing any new class:

- Timer / cooldown / delay → `CountdownTimer`, `FrequencyTimer`, `IntervalTimer`, `TickTimer`
- Global typed event → `EventBus<T>` with `EventBinding<T>`
- Stack-based state machine → `PushdownAutomata<T>` / `StateController<T>`
- Composable boolean condition → `ICondition<TContext>` (And / Or / Not / Leaf)
- Rules evaluation → `RuleSystem<TContext, TResult>`
- Stat modifier / buff pipeline → `Mediator` + `IModifierStrategy` + `QueryContext`
- Component plugin-point on MB → `Entity<T>`
- Generic class needing Unity Update loop → `MonoBehaviourUpdatable`
- Smooth spring following (camera, UI) → `SODEvaluator` / `SecondOrderDynamics`
- Ring buffer → `CircularList<T>`
- Framerate-independent smooth → `EaseUtil.Damp`
- Transform / math helpers → `TransformUtil`, `MathUtil`, `TweenUtil`, `AudioUtil`, `EaseUtil`

## If the Utility Already Exists

Do not reimplement it. Reference the existing class from Extensions, note its namespace, and
explain how to use it for the current task.

## If the Utility Does NOT Exist

Propose adding it to the Extensions library (not inline in game code), so it becomes available
across all future projects. Follow the same coding style as existing Extensions classes.
