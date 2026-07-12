---
description: >
  Animation system patterns. Animancer backend, IAnimationDriver abstraction, composable SO-based
  animation definitions using inheritance, StringAsset parameter names, FSM activity integration.
when_to_use: >
  Implementing or reviewing character animation, wiring Animancer, defining animation clips or blend
  trees, questions about "IAnimationDriver", "AnimDef", "LoopAnimDef", "Animancer parameters".
allowed-tools: Read Edit Write AskUserQuestion
---

## Overview

Animancer is the standard animation backend for all character and world animation.
PrimeTween handles all UI animation. Never mix the two.

## IAnimationDriver Abstraction

All game systems write to `IAnimationDriver`, never to Animancer directly.

```csharp
public interface IAnimationDriver
{
    void PlayLoop(LoopAnimDef def);
    void PlayOneShot(OneShotAnimDef def, Action onComplete = null);
    void SetParameter<T>(StringAsset param, T value);
    void Stop();
}
```

`AnimancerAnimationDriver : MonoBehaviour, IAnimationDriver` is the concrete implementation.
Inject `IAnimationDriver` at the composition root. This keeps all game logic backend-agnostic.

## SO-Based Animation Definitions

Define a composable hierarchy — never leave fields unused in a base class.

```csharp
/** <summary>Base animation definition. All shared fields only.</summary> */
public abstract class AnimDef : ScriptableObject
{
    [Tooltip("Fade-in duration in seconds.")]
    public float FadeIn = 0.15f;
}

/** <summary>Looping animation clip definition.</summary> */
[CreateAssetMenu(menuName = "Animation/LoopAnimDef")]
public class LoopAnimDef : AnimDef
{
    [Tooltip("Animancer transition asset for the looping clip.")]
    public TransitionAsset Clip;
}

/** <summary>One-shot animation clip definition.</summary> */
[CreateAssetMenu(menuName = "Animation/OneShotAnimDef")]
public class OneShotAnimDef : AnimDef
{
    [Tooltip("Animancer transition asset.")]
    public TransitionAsset Clip;
    [Tooltip("Fade-out duration in seconds.")]
    public float FadeOut = 0.1f;
}

/** <summary>Blend tree animation definition with a float blend parameter.</summary> */
[CreateAssetMenu(menuName = "Animation/BlendAnimDef")]
public class BlendAnimDef : AnimDef
{
    [Tooltip("Blend tree transition asset.")]
    public TransitionAsset BlendTree;
    [Tooltip("Animancer parameter name to drive the blend. Use a StringAsset asset.")]
    public StringAsset BlendParameter;
}
```

Add new capabilities by subclassing, never by adding optional fields to a base class.
Store all defs on a Config SO (e.g. `PlayerAnimationConfig`) — one SO per character/system.

## Parameter Names: StringAsset, Never Raw Strings

```csharp
// Correct — typed asset reference, set in the Inspector
animancer.Parameters.GetOrCreate<float>(moveSpeedParam);

// Wrong — raw string, fragile
animancer.Parameters.GetOrCreate<float>("moveSpeed");
```

`StringAsset` is an Animancer asset type that wraps a string. Create one per parameter name,
assign in the Inspector on the Config SO.

## Config SO Pattern

```csharp
[CreateAssetMenu(menuName = "Animation/PlayerAnimationConfig")]
public class PlayerAnimationConfig : ScriptableObject
{
    [Tooltip("Idle loop animation.")]
    public LoopAnimDef Idle;
    [Tooltip("Walk loop animation.")]
    public LoopAnimDef Walk;
    [Tooltip("Attack one-shot animation.")]
    public OneShotAnimDef LightAttack;
    [Tooltip("Movement blend parameter name.")]
    public StringAsset MoveSpeedParam;
}
```

## FSM Activity Integration

Activities attach to state machine states and run async enter/exit sequences.

```csharp
public class LoopAnimActivity : IActivity
{
    private readonly IAnimationDriver _driver;
    private readonly LoopAnimDef _def;
    private readonly Func<bool> _skipEnter;

    public LoopAnimActivity(IAnimationDriver driver, LoopAnimDef def, Func<bool> skipEnter = null)
    {
        _driver = driver;
        _def = def;
        _skipEnter = skipEnter;
    }

    public async UniTask ActivateAsync(CancellationToken token)
    {
        if (_skipEnter?.Invoke() == true) return;
        _driver.PlayLoop(_def);
    }

    public async UniTask DeactivateAsync(CancellationToken token)
    {
        // optional exit blend
    }
}
```

**Skip-enter predicate:** suppress enter animation on fast re-entry:
```csharp
new LoopAnimActivity(driver, cfg.Walk, skipEnter: () => moveState.TimeSinceExit < cfg.WalkEnterSkipWindow)
```

## Questions to Ask Before Implementing

- Is this character animation (Animancer) or UI animation (PrimeTween)?
- What animation states does this character have? Do any need one-shot vs loop?
- Are there blend trees? What parameter drives them?
- Does any animation need a skip-enter window for fast state re-entry?
- Where is the `IAnimationDriver` injected — composition root?

## Continuous Improvement

When the user adds new animation patterns: ask "Should I update this skill file?"
If yes, Read `${CLAUDE_SKILL_DIR}/SKILL.md` and apply the minimal edit.
