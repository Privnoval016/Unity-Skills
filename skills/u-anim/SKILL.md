---
description: >
  Animation system patterns. Animancer backend, IAnimationDriver abstraction, IAnimationSource
  polymorphic inline embedding, AnimationConfig SO pattern, locomotion source selection.
when_to_use: >
  Implementing or reviewing character animation, wiring Animancer, defining animation clips or blend
  trees, questions about "IAnimationDriver", "IAnimationSource", "AnimationConfig", "Animancer layers".
allowed-tools: Read Edit Write AskUserQuestion
---

## Overview

Animancer is the standard animation backend for all character and world animation.
PrimeTween handles all UI animation. Never mix the two.

## IAnimationDriver Abstraction

All game systems write to `IAnimationDriver`, never to Animancer directly. It's a "publish this
frame's state" seam, not an imperative "play this def" API — the driver decides what to actually
play based on the params it receives every frame:

```csharp
public interface IAnimationDriver
{
    void UpdateLocomotion(in LocomotionParams parameters);
}
```

`LocomotionParams` is a `readonly struct` carrying everything a driver needs to pick and blend a
locomotion source without knowing anything about physics: planar speed, vertical velocity, grounded/
sprinting/strafing flags, move input magnitude, local-space planar velocity (for a directional blend),
and any current special-state variant (e.g. which landing animation is active).

`AnimancerAnimationDriver : MonoBehaviour, IAnimationDriver` is the concrete implementation. A
`NullAnimationDriver` no-op stands in for a body with no visual, so callers never need a null check.
Inject `IAnimationDriver` at the composition root. This keeps all game logic backend-agnostic.

For non-locomotion playback (combat attacks, hit reactions — anything that plays once on demand
rather than being continuously state-driven), a driver can additionally implement a narrower
capability interface exposing a direct one-shot play call:

```csharp
public interface ICombatAnimationDriver
{
    AnimancerLayer BaseLayer { get; }
    AnimancerLayer UpperBodyLayer { get; }
    AnimancerState PlaySource(IAnimationSource source, AnimancerLayer layer, float fadeDuration, FadeMode mode = default);
    void SetRootMotionEnabled(bool enabled);
    // + AnimationEvent-relayed events (hitbox windows, cancel windows, phase-end) — see combat docs
}
```

This is the same "optional capability interface, not a bloated base interface" shape the rest of the
codebase uses (`IRootMotionSource` is another such optional capability `IAnimationDriver` can
implement) — a driver with no animator just doesn't implement the capabilities it can't support.

## IAnimationSource: Polymorphic Inline Embedding, Not Separate SO Assets

Animation playability is one `[SerializeReference]`-embeddable interface, composed inline directly on
whatever Config SO owns it — **not** a hierarchy of separate `ScriptableObject` asset types you have
to create and drag in. This matches the project's general "prefer `[SerializeReference]` over nested
SO refs" rule.

```csharp
public interface IAnimationSource
{
    /** <summary>Starts this source playing on the given layer and returns the resulting state.</summary> */
    AnimancerState Play(AnimancerLayer layer, float fadeDuration, FadeMode mode = default);
}
```

Optional capabilities layer on top as narrow, single-purpose interfaces — implement only the ones
that apply, exactly the same "no hanging fields" shape used elsewhere in the codebase:

- `ISingleAxisBlendSource : IAnimationSource` — `void SetBlend(AnimancerState state, float value)`,
  for a source whose blend position is one float set every frame (`BlendTree1DSource`).
- `IPlanarBlendSource : IAnimationSource` — `void SetBlend(AnimancerState state, Vector2 value)`, for
  a directional (right, forward) blend set every frame (`BlendTree2DSource` — the strafe blend).
- `IReleasableAnimationSource : IAnimationSource` — `AnimancerState Release(...)`, for a source with a
  distinct exit phase that must be explicitly ended (`StartLoopEndSource`: a start clip hands off to a
  looping sustain clip, which plays until `Release()` plays the end clip — covers a charge-up held
  until the button releases).

Concrete implementations, all `[Serializable]`, all embedded directly via `[SerializeReference]`:
`SingleClipSource` (one `ClipTransition`, the common case), `BlendTree1DSource` (`LinearMixerTransition`),
`BlendTree2DSource` (`MixerTransition2D`), `StartLoopEndSource` (three `ClipTransition`s: start/loop/end).

Add a new animation shape by implementing `IAnimationSource` (+ an optional capability interface if it
needs blending or a release phase) — never by adding a new field to an existing source type.

## Blend Parameters: Direct Method Calls, Not Named Animancer Parameters

Blending is driven by the caller invoking a resolved source's own `SetBlend` every frame, **not** by
looking up a named Animancer `Parameter`/`StringAsset`:

```csharp
// Correct — the driver knows the concrete blend-capable source type it just played
switch (_activeLocomotionSource)
{
    case IPlanarBlendSource planar:
        planar.SetBlend(_locomotionState, new Vector2(parameters.LocalPlanarVelocity.x, parameters.LocalPlanarVelocity.z));
        break;
    case ISingleAxisBlendSource single:
        single.SetBlend(_locomotionState, parameters.PlanarSpeed);
        break;
}

// Wrong — this project doesn't use named-parameter/StringAsset-keyed Animancer parameters at all
animancer.Parameters.GetOrCreate<float>("moveSpeed");
```

## AnimationConfig: The Locomotion Config SO Pattern

One `AnimationConfig` asset per character (referenced by that character's `CharacterConfig`), holding
a source for every locomotion mode the movement state machine always has, plus the thresholds/
durations animation selection needs — all read live so Inspector edits apply in Play mode:

```csharp
[CreateAssetMenu(menuName = "Game/Animation Config", fileName = "AnimationConfig")]
public class AnimationConfig : ScriptableObject
{
    [SerializeField] private float movingSpeedThreshold = 0.15f;
    [SerializeField] private float locomotionFadeDuration = 0.15f;

    [SerializeReference] private IAnimationSource idleSource;
    [SerializeReference] private IAnimationSource moveSource;
    [SerializeReference] private IAnimationSource strafeSource;
    [SerializeReference] private IAnimationSource sprintSource;
    [SerializeReference] private IAnimationSource jumpSource;
    [SerializeReference] private IAnimationSource fallSource;
    // ...one field per universal locomotion mode the state machine always builds.

    [SerializeReference] private CharacterAbilityAnimations characterAbilities;
    // Optional slot for a character-specific ability's own animation data (a mage's float/hover) —
    // a new universal ability gets a new field directly here; a new character-specific one gets its
    // own CharacterAbilityAnimations subclass instead of a new AnimationConfig field.
}
```

Selection is a **pure, MonoBehaviour-free static function** taking the whole config plus the current
`LocomotionParams`, kept separate from the driver specifically so it's directly unit-testable with no
Pawn/physics harness:

```csharp
public static class LocomotionSourceSelector
{
    public static IAnimationSource Select(AnimationConfig config, in LocomotionParams parameters) { ... }
}
```

Any state-machine-driven timed/variant animation choice that can't be recomputed purely from
instantaneous physics numbers (e.g. "which landing animation, snapshotted at touchdown speed, for how
long") gets its own similarly pure, separately-tested static resolver (see `LandingRecovery`) rather
than embedding that logic inline in the selector or the driver.

## Layers

`AnimancerLayer` via `AnimancerComponent.Layers[index]` — locomotion plays on the base layer; combat
exposes a mask-overlay layer (`UpperBodyLayer`) for actions that should play over continued locomotion
(a quick attack that doesn't root the character in place), chosen per-attack via a `LayerMode` enum.

## Root Motion

An optional `IAnimationDriver` capability, `IRootMotionSource.TryConsumeRootMotion(out positionDelta,
out rotationDelta)` — off by default; enabled only around specific root-motion-authored sources
(a lunge, a lift-off) and fed into the motion pipeline's own `RootMotionStage`, never applied directly
by the driver. A driver with no animator (a debug visual) simply doesn't implement this interface.

## Questions to Ask Before Implementing

- Is this character animation (Animancer) or UI animation (PrimeTween)?
- What locomotion/ability modes does this need a source for? Does the movement state machine
  (`PawnStateFactory`) already have a matching state, or does this need a new one?
- Does it need blending (`ISingleAxisBlendSource`/`IPlanarBlendSource`) or a release phase
  (`IReleasableAnimationSource`)?
- Is the selection logic for this a pure function of instantaneous physics values, or does it need
  its own timed/stateful resolver (like `LandingRecovery`)?
- Is this universal (every character gets it — a new `AnimationConfig` field) or character-specific
  (a new `CharacterAbilityAnimations` subclass)?
- Does this play on the base layer or an overlay layer?

## Continuous Improvement

When the user adds new animation patterns, or when this file is found to have drifted from what's
actually implemented (check the real `Assets/Game/Locomotion/Animation/` sources before trusting this
doc's own code samples): ask "Should I update this skill file?" If yes, Read
`${CLAUDE_SKILL_DIR}/SKILL.md` and apply the minimal edit.
