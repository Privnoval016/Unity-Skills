---
description: >
  PushdownAutomata state machine pattern. Stack-based FSM with interrupt/resume, full state
  lifecycle callbacks, SO constructor args, AI brain integration. Use when implementing any
  game state machine for player, enemy, or game flow.
when_to_use: >
  "state machine", "FSM", "game state", "player state", "enemy state", "PushdownAutomata",
  "interrupt", "resume previous", "StateController", implementing character controllers or AI.
allowed-tools: Read Edit Write AskUserQuestion
---

## Overview

The PushdownAutomata (PDA) is the standard state machine for all game objects with distinct
behavioral modes. It uses a stack so interrupted states can resume without losing their place.
Available as `StateController<T>` (MB wrapper) or `PushdownAutomata<T>` (plain C#) in Extensions.

## PushdownAutomata API

```
ChangeState(T state)     — pop current, push new state. Current state gets OnExit.
Interrupt(T state)       — push on top WITHOUT popping. Current state gets OnInterrupt.
ResumePrevious()         — pop top, call OnResume on the now-exposed state.
```

`StateController<T> : MonoBehaviourUpdatable` — use this as the MB controller. It wraps the PDA
and drives state lifecycle via `Update` / `FixedUpdate` / `LateUpdate`.

## State Lifecycle

```
OnEnter()          — called when state becomes active
OnUpdate()         — called every frame
OnFixedUpdate()    — called every physics frame
OnLateUpdate()     — called after all Updates
OnExit()           — called before state is popped
OnInterrupt()      — called when a state is pushed on top of this one
OnResume()         — called when the state above is popped and this resumes
OnTriggerEnter(Collider)
OnCollisionEnter(Collision)
```

All delegate fields are initialized to `delegate { }` in constructors — never null.

## Defining States

```csharp
public class PlayerAttacking : PlayerState
{
    private readonly PlayerAttack _attack;

    public PlayerAttacking(PlayerAttack attack)   // ← SO passed via constructor
    {
        _attack = attack;
        OnEnter  = () => StartAttackAnimation(_attack);
        OnExit   = () => ResetCombo();
        OnUpdate = () => CheckComboWindow();
    }
}
```

Pass ScriptableObject references as constructor args. The MB creates states with the SO reference:
```csharp
_stateMachine.ChangeState(new PlayerAttacking(_config.PunchAttack));
```

## Preventing Pop (`doNotRemove`)

```csharp
public class PlayerMoving : PlayerState
{
    public PlayerMoving() { doNotRemove = true; }  // always base-layer state
}
```

Use for the base locomotion state that should never be popped — only interrupted.

## AI Brain Integration

Enemy state machines extend `AIBrainUser`. The brain scores candidate actions each `TickTimer`
interval and calls `ChangeState` when a higher-scoring action should run.

`ContextPayload` supports implicit tuple conversion for ergonomic context updates:
```csharp
// In EnemyStateMachine.OnContextUpdate:
return new ContextPayload[]
{
    (ContextKey.PlayerDistance, distance),
    (ContextKey.IsGrounded, true),
};
```

## Hierarchical FSM (complex controllers)

For multi-layer character controllers needing async transitions:
- `StateMachine<T>` with LCA-based transitions
- `TransitionSequencer` runs `ActivateAsync(CancellationToken)` / `DeactivateAsync(CancellationToken)`
- Exit skip policies: `WithExitSkipPolicy((from, to) => ...)` suppress exit animations for fast re-entries
- State builder: `new IdleState().AsInitialState(groundedState).WithParent(activeState).WithActivity(new LoopAnimActivity(...))`

## Questions to Ask Before Implementing

- How many distinct states does this object have?
- Are any states interruptible (push/resume) vs fully replaced (change)?
- Do states need to carry SO data (attack config, ability config)?
- Is there an AI brain driving state selection, or purely input-driven?
- Does the base state (e.g. locomotion) need `doNotRemove = true`?

## Continuous Improvement

When the user adds new state machine patterns: ask "Should I update this skill file?"
If yes, Read `${CLAUDE_SKILL_DIR}/SKILL.md` and apply the minimal edit.
