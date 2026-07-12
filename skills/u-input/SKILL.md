---
description: >
  Input abstraction layer. IInputSource interface, hardware adapter pattern, typed button enums,
  InputBuffer with grace windows, chord detection, hold disambiguation. Universal standard for all
  projects regardless of genre — always abstract behind an interface.
when_to_use: >
  Wiring player input, designing an input system, questions about "IInputSource", "input buffer",
  "grace window", "chord", "hold duration", "PlayerInput", "typed buttons".
allowed-tools: Read Edit Write AskUserQuestion
---

## Overview

Game logic never reads hardware input directly. Always abstract behind a domain interface.
This decouples every consumer from the input backend so backends can be swapped (Unity Input System,
touch, network, replay) without touching any game logic.

## Required Abstraction Layers

```
1. Hardware layer
   Unity Input System PlayerInput (auto-generated)
   Keep this isolated — no game code references it directly.

2. IInputSource interface  (domain-defined, per context)
   event Action<InputEvent> ButtonEvent
   TSnapshot Snapshot { get; }
   void Enable()
   void Disable()
   Name per domain: IPlayerInputSource, IMenuInputSource, etc.

3. Adapter  (pure C#, NOT a MonoBehaviour)
   Implements IInputSource. Subscribes to hardware callbacks. Translates to domain events.
   One adapter per hardware backend. Swapped at the composition root.

4. Consumers (physics, UI, combat, camera)
   Depend on IInputSource only. Never reference the concrete adapter.

5. Domain adapters (optional)
   E.g. IMotionInputProvider: transforms IInputSource camera-space input to world-space XZ.
```

## IInputSource Interface Example

```csharp
/** <summary>Domain-level player input contract.</summary> */
public interface IPlayerInputSource
{
    event Action<PlayerInputButtonEvent> ButtonEvent;
    PlayerInputSnapshot Snapshot { get; }
    void Enable();
    void Disable();
}

public readonly struct PlayerInputSnapshot
{
    public Vector2 MoveAxis     { get; init; }
    public Vector2 LookAxis     { get; init; }
    public bool IsSprinting     { get; init; }
}
```

## Adapter Pattern

```csharp
/** <summary>Adapts Unity Input System to IPlayerInputSource.</summary> */
public sealed class PlayerInputAdapter : IPlayerInputSource, PlayerInput.IPlayerActions, IDisposable
{
    private readonly PlayerInput _input;
    private PlayerInputSnapshot _snapshot;

    public event Action<PlayerInputButtonEvent> ButtonEvent = delegate { };
    public PlayerInputSnapshot Snapshot => _snapshot;

    public PlayerInputAdapter(PlayerInput input)
    {
        _input = input;
        _input.Player.SetCallbacks(this);
    }

    public void Enable()  => _input.Player.Enable();
    public void Disable() => _input.Player.Disable();
    public void Dispose() => _input.Player.Disable();

    // Feature flags — settable at runtime
    public bool AttackInputEnabled { get; private set; } = true;
    public void SetAttackInputEnabled(bool value) => AttackInputEnabled = value;
}
```

## Typed Button Enums (Action Games)

```csharp
public enum CombatInputButton { Light, Heavy, Dodge, Jump, Interact, LightHeavyChord }
```

**NEVER** use string-based button names. Enum values only.

## InputBuffer (Grace Windows)

```csharp
// Per-button timestamp tracking
float pressTime = _buffer.GetPressTime(CombatInputButton.Light);
float held = _buffer.GetHoldDuration(CombatInputButton.Light);
bool consumed = _buffer.ConsumeButton(CombatInputButton.Light);  // marks consumed
```

Grace window durations live in a `CombatInputSettings` Config SO — never hardcoded.

**Advanced patterns:**
- **Chord detection**: if Light + Heavy both pressed within `ChordDetectionWindow`, synthesize
  a `LightHeavyChord` event. Consume both originals.
- **Sprint-light disambiguation**: when Light is pressed while sprinting, defer forwarding.
  If released before `SprintLightHoldThreshold` → tap (basic attack).
  If held past threshold → hold (running attack).
  Preserve original press timestamp so `GetHoldDuration` measures from the real press.

## Questions to Ask Before Implementing

- What hardware backends must this support now? (Unity Input System, touch, network replay?)
- Is this for locomotion, combat, UI, or a combination?
- Are there hold-duration abilities requiring `GetHoldDuration`?
- Are there chord inputs (two buttons simultaneously)?
- Does sprint affect how attack inputs are classified?
- What feature flags does the adapter need (e.g. lock input during cutscene)?

## Continuous Improvement

When the user adds new input patterns: ask "Should I update this skill file?"
If yes, Read `${CLAUDE_SKILL_DIR}/SKILL.md` and apply the minimal edit.
