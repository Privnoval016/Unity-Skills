---
description: >
  Orchestrated physics design. Explicit per-frame velocity ownership, MotionContext reuse,
  prioritized pipeline stages, Extensions Modifiers/Mediator for stat queries, request buffering
  for abilities. Use when building character controllers or any physics-driven system.
when_to_use: >
  "physics", "character controller", "movement", "velocity", "Rigidbody", "FixedUpdate",
  "ability", "modifier", "buff", "stat", designing physics-driven or ability systems.
allowed-tools: Read Edit Write AskUserQuestion
---

## Overview

Own the physics simulation. Never rely on Unity's collision callbacks as the primary mechanism for
driving character state — they are reactive and unordered. Gather state, compute desired velocity,
and apply it explicitly each `FixedUpdate`.

## Core Principle: Orchestrated Tick

```
Each FixedUpdate:
  1. Snapshot current physics state → context object
  2. Gather input (read from IInputSource snapshot)
  3. Reset per-frame context values
  4. Route requests to active abilities
  5. Execute pipeline stages (sorted by priority)
  6. Apply velocity → Rigidbody.linearVelocity
  7. Apply rotation
  8. Clear request buffers
```

The orchestrator MonoBehaviour drives this tick. All stage logic lives in plain C# classes.

## MotionContext Pattern (Zero GC per Frame)

```csharp
/** <summary>
 * Per-frame physics context. Allocated once; mutated each FixedUpdate.
 * Must never be allocated inside FixedUpdate.
 * </summary>
 */
public class MotionContext
{
    public Vector3 Velocity   { get; set; }
    public bool IsGrounded    { get; set; }
    public Vector3 InputDir   { get; set; }
    public bool JumpRequested { get; set; }
}
```

Single instance created in `Awake`. Reused every frame. Zero per-frame allocation.

## Pipeline Stages

```csharp
public interface IMotionStage
{
    int Priority { get; }
    void Execute(MotionContext ctx);
}
```

Orchestrator sorts by `Priority` ascending and executes in order. New behavior = new stage class,
no existing code changes. Example ordering:

```
GravityStage    10  — applies gravity to Velocity
FrictionStage   20  — ground/air friction
InputStage      30  — move-direction input
AbilityStage    50  — overrides (dash, wall-run)
ConstraintStage 90  — clamp to max speed, ceiling checks
```

## Stat Queries — Extensions Modifiers/Mediator

When stats can be modified at runtime (speed buffs, damage multipliers, status effects):

```csharp
// Correct — routes through all registered IModifierStrategy instances
float speed = _mediator.Query(QueryKey.MoveSpeed, _config.BaseSpeed, _context);

// Wrong — hardcoded, ignores active modifiers
float speed = _config.BaseSpeed;
```

Register modifier strategies at bootstrap. Each `IModifierStrategy` is an independent class.
Never build a custom modifier stack — use the Extensions `Mediator` + `IModifierStrategy`.

## Request Buffering (Ability Systems)

Abilities submit typed requests to a buffer per tick instead of calling methods directly:

```csharp
_requestBuffer.Add(new JumpRequest());
```

Two-pass routing:
1. Active abilities consume from `_requestBuffer`
2. Unconsumed go to `_unconsumedBuffer` for cross-ability interception

This lets a wall-run ability intercept a `JumpRequest` and launch a wall-kick without the
orchestrator knowing wall-run specifics.

## Runtime Tags

Typed constants backed by a value struct — never raw string comparisons:

```csharp
context.AddTag(MotionTag.Grounded);
if (context.HasTag(CombatTag.Attacking)) { ... }
```

Define constants as static readonly fields on a tag class:
```csharp
public static readonly Tag Grounded = new("Grounded");
```

## Time-Scale Compensation (Bullet Time)

When `UseUnscaledDeltaTime` is true and `Time.timeScale < 1`:
- After `ApplyVelocity`: multiply `Rigidbody.linearVelocity` by `1 / timeScale`
- At next tick's snapshot: divide back by `timeScale`

Character moves at full real-world speed while the physics world slows.

## Questions to Ask Before Implementing

- Rigidbody or position-based movement?
- What pipeline stages are needed (gravity, friction, input, dashes, wall-run)?
- Are there stats that external modifiers affect (speed, jump height)?
- Is there an ability system requiring request buffering?
- Does this need bullet-time / time-scale compensation?
- What is the `[DefaultExecutionOrder]` relative to other physics bodies?

## Continuous Improvement

When the user adds new physics patterns: ask "Should I update this skill file?"
If yes, Read `${CLAUDE_SKILL_DIR}/SKILL.md` and apply the minimal edit.
