---
description: >
  Unity architecture principles. MonoBehaviour split, ScriptableObject roles, Service Locator,
  event routing, data-driven design, performance rules, design patterns. Loaded when designing
  or reviewing any Unity system.
when_to_use: >
  Designing a new feature or system, choosing a ScriptableObject role, wiring services, selecting
  a design pattern, questions about "how to structure", "singleton", "event bus", "data-driven",
  "performance", "ZLinq", "no magic numbers", "service locator", "MonoBehaviour split".
allowed-tools: Read Edit Write AskUserQuestion
---

## Overview

These rules apply to every system in the project. For design pattern details see
[patterns-ref.md](patterns-ref.md). For the Extensions library see [extensions-ref.md](extensions-ref.md).

Also check for a project-level docs folder at the repo root (commonly named `.project-docs/`,
`ProjectDocs/`, or `docs/` — the exact name varies per project). If one exists, consult it before
proposing an architecture decision — it may already document which packages are installed, which
libraries own which responsibility, and prior decisions that should constrain the choice.

## Scene Assembly

Never write Editor tooling (`[MenuItem]` scripts, programmatic `GameObject`/`Canvas`/`RectTransform`
construction, `EditorSceneManager` scene generation) to assemble scene layout on the user's behalf
— even when it seems like it'd save time or reduce manual-step risk. Scene assembly (Canvas
hierarchies, dragging component references, wiring Inspector fields) is the user's to do by hand in
the Editor. Give clear step-by-step instructions instead — what to create, where, how to wire it —
and let them build it themselves.

## MonoBehaviour Split (strict)

MonoBehaviours **only** do:
- Declare `[SerializeField]` references to SOs and scene objects
- `Awake` / `Start`: create plain C# systems, call wiring methods
- `Update` / `FixedUpdate`: dispatch into plain C# systems
- `OnEnable` / `OnDisable`: subscribe / unsubscribe events

**All logic lives in plain C# classes.**

`MonoBehaviourUpdatable` (Extensions.Other) gives plain C# generic/reusable classes access to
Unity's update loop via a proxy MonoBehaviour. For a dedicated per-feature class, a normal
MonoBehaviour is fine if creating a proxy is more awkward.

## ScriptableObject Roles

One role per SO. Never mix.

| Role | Purpose | Key rule |
|------|---------|----------|
| **Config SO** | Immutable designer parameters | `OnValidate()` for derived values; `[HideInInspector]` on derived fields; must never store mutable runtime state |
| **Factory SO** | `CreateXxx()` → new runtime object | `UpdateXxx(instance)` hot-patches live instances |
| **Data Provider SO** | Asset lists/sequences | `IReadOnlyList<T>` lazy property; `OnEnable()` clears cache |
| **Event Channel SO** | `Raise()` + `Register()`/`Deregister()` | Designer-accessible bridge between scenes |

`[CreateAssetMenu]` on every concrete Config / Factory / Data Provider SO.

## Service Locator

```csharp
Services.Get<T>()         // throws if not registered — coding error, not null-fallback
Services.Register<T>(T)
Services.Unregister<T>()
```

`T` must implement `IService` (empty marker interface). `ServiceBootstrapper : MonoBehaviour`
registers all core systems in `Awake()` via serialized Inspector refs.

- Prefer over singletons everywhere.
- **Never use Zenject or heavy DI frameworks** unless explicitly requested.
- Composition roots (PlayerController, scene roots): wire via serialized Inspector refs + method injection.

## Event Routing

Pick in this order:

1. **`EventBus<T>`** (Extensions.EventBus): global broadcast where sender doesn't know subscribers.
   Always pair `Register` in `OnEnable` with `Deregister` in `OnDisable`.
2. **C# events** (`event Action<T>`): tightly coupled components in the same system.
3. **SO Event Channels**: when designers need to wire event bridges in the Inspector across scenes.

No `UnityEvent` fields for component wiring.

## Interfaces

Place interfaces in the same module folder as the system they describe.
Inject the interface, never the concrete type.

### No hanging fields — split optional capabilities into narrow interfaces

When a multi-implementer interface would need a property or method that's genuinely meaningless
for some implementers, don't add it to the shared interface for everyone to answer. Split it into
its own narrow, optional capability interface instead, and let only the implementers that truly
have that capability implement it.

A concrete worked example from `Assets/CombatEngine`: `ITurnAction` is implemented by
`TechniqueAction`, `ItemAction`, `SkipTurnAction`, `JointTechniqueAction`, and others. Not all of
them have an owner, a resource cost, or a Joint Technique priority — `SkipTurnAction` has none of
the three; the harness's `OwnedTurnAction` wrapper has all three. Rather than bloating `ITurnAction`
with `Owner`/`CostResource`/`CostAmount`/`JointPriority` fields that most implementers would have to
either fake or ignore, each became its own interface — `IOwnedTurnAction`, `ICostedTurnAction`,
`IJointTechniqueParticipant` — implemented only by whichever classes genuinely have that concept.
`ITurnAction` itself stayed exactly as small as it was. `IFrontend` already followed this same
pattern before this: it's composed from `IActionSelectionPort` / `ITargetSelectionPort` /
`IJointPartnerSelectionPort` / `IJointTechniqueSelectionPort` rather than being one flat interface —
treat that composition as the reference shape for how a "many small ports" interface should look.

This generalizes beyond `ITurnAction`: whenever a new multi-implementer interface would need a
member only some implementers can meaningfully answer, reach for a narrow optional-capability
interface instead, by default — not just when someone happens to notice the smell.

### Prefer a small interface + named strategy classes over a bare multi-parameter `Func`/enum

When behavior needs to be pluggable ("who owns this," "which condition applies," "how should this
be resolved"), reach for a small single-method interface with a few named concrete implementations
— not a bare `Func<A, B, C>` (positional parameters can't be documented or named at the call site,
so a three-`IActor`-parameter `Func` reads as noise) and not a closed enum (can't express "wraps
this specific pre-existing object" or "here's a fully custom case," and adding a case means editing
the enum's every switch statement instead of just adding a class). This is the same shape as
`IActionValueSource`/`StandardSpeedSource`/`FixedIntervalSource`, `ITargetOrigin`/`CasterOrigin`/
`EntityOrigin`, and `IJointPartnerEligibility`/`ProximityJointEligibility` already establish
elsewhere in this codebase — apply it by default, not just where it already exists. Worked example:
`Core/Effects/IEffectOwnerSelector.cs` (`ResolveOwner(IActor caster, IActor target)`) replaced an
earlier draft's `Func<IActor, IActor, CombatContext, IModifierDuration>` parameter on
`ApplyModifierEffect`/`ApplyStatusEffectEffect` — `BearerOwnsEffect`/`CasterOwnsEffect` read clearly
at the call site, and `FixedOwner(owner)` covers "wraps a specific pre-registered actor" (even a
synthetic one, like a Domain's own pseudo-actor in the turn queue) without needing a new enum case.

### Reach for a generic type parameter when a primitive is genuinely reusable across trigger types

Don't hardcode a primitive to the one trigger/event/key type it happens to be needed for today if
the underlying mechanism doesn't actually care what that type is — make it generic instead, so the
next caller with a different trigger type reuses the same class rather than a near-duplicate.
Worked example: `Core/Modifiers/EventScopedDuration.cs`'s `EventScopedDuration<TEvent>` advances an
inner duration only when a matching `CombatEventBus` event fires. The only concrete need today is
"advance on a specific actor's `TurnStartEvent`" (exposed as the non-generic
`EventScopedDuration.OwnerTurns(...)` convenience, the same companion-class-alongside-the-generic-type
shape as `Task`/`Task<T>`), but nothing about the class itself is turn-specific — a future "expires
when a specific actor is defeated" or "expires when a named status is removed elsewhere" trigger
reuses the identical generic class with a different `TEvent` and predicate, not a parallel
`DefeatScopedDuration` written from scratch.

### Checking for an optional capability interface via `is` is fine — checking a concrete type is not

The project's usual rule against type-checking (`is`/pattern matching used to branch on what
something *is* rather than trusting polymorphism) still holds for **concrete types** — checking
`is SomeConcreteClass` to decide behavior breaks encapsulation and should be avoided, same as
always.

But checking `is ISomeCapability` for one of these optional capability interfaces is a *different*,
acceptable category — it's the same shape as `TryGetComponent<T>` in an ECS-style system, or
checking `is IDisposable` before calling `Dispose()`. You're not asking "what concrete class is
this", you're asking "does this thing support this specific, narrow contract" — which is trusting a
(narrower) interface contract, not bypassing one. `JointTechniqueAction` reads
`IOwnedTurnAction`/`ICostedTurnAction`/`IJointTechniqueParticipant` this way when scanning
`CombatContext.ActionCatalog`, defaulting sensibly (unowned, free, default priority) when an action
doesn't implement one — that's the intended usage pattern for these interfaces, not a workaround.

The rule was never "never use `is`" — it's "never branch on a concrete implementation type instead
of trusting the interface contract." Checking for an optional capability interface *is* trusting a
contract, just a narrower one than the base interface.

## Namespace Scope

A new system gets **one** namespace for its entire folder tree (e.g. `CombatEngine` for everything
under `Assets/CombatEngine/`, however many subfolders it grows), not one namespace per subfolder.
Decide this once, up front, when the system is first scaffolded — see the `u-style` skill's
Namespaces section for the full rule and reasoning.

## Data-Driven Design

- No magic numbers or hardcoded strings anywhere. Every tunable parameter on a SO with `[Tooltip]`.
- No string-based references to scenes, tags, audio clips, or layers. Use typed constants, enums, or SO refs.
- `[SerializeReference]` for polymorphic inline embedding — prefer over nested SO asset refs for
  conditions, ability phases, and strategy objects.
- Odin Inspector fully: `[MinMaxSlider]`, `[ShowIf]`, `[FoldoutGroup]`, `[InlineEditor]`, `[Required]`, `[ValidateInput]`.
- `OnValidate()`: derive low-level constants from designer-friendly inputs. Derived = `[HideInInspector]`.
- `[FormerlySerializedAs("oldName")]` on renamed fields to preserve existing asset data.
- Enums for categorization only. `[SerializeReference]` + interface when type choice implies behavior.

## Performance (global — applies everywhere, always)

- **NEVER** `Find` / `FindObjectOfType` / `FindFirstObjectByType` / `FindGameObjectWithTag` at runtime.
  Wire at Inspector time or `Services.Get<T>()` once in `Awake`.
- **NEVER** `GetComponent` in `Update`, `FixedUpdate`, or any per-frame callback. Cache in `Awake`.
- **NEVER** standard LINQ in hot paths. Use **ZLinq** (`using ZLinq;`) for allocation-free equivalents.
  This rule applies universally — physics, combat, UI, event processing, everything.
- Object pooling for all runtime-spawned GameObjects (projectiles, VFX, UI items).
- `MaterialPropertyBlock` for per-instance material properties — never `renderer.material.SetXxx`.
- UniTask over coroutines. Coroutines only when sequential flow is simpler to read.
- Extensions.Timers for all timer/frequency needs — not per-Update countdown variables.
- LODs on objects visible at distance.

## Design Patterns

For full Unity-specific examples see [patterns-ref.md](patterns-ref.md).

**Reach for these first:**
Strategy · Observer · State (PushdownAutomata) · Factory · Command · Mediator · Composite (ICondition)

**Use when the problem fits:**
Chain of Responsibility · Adapter · Template Method · Decorator · Builder · Facade

**Avoid:** Singleton (Service Locator instead) · Heavy DI containers

## Continuous Improvement

When the user provides new architectural preferences that should apply permanently:
ask "Should I update this skill file for future sessions?" If yes, Read
`${CLAUDE_SKILL_DIR}/SKILL.md`, propose the minimal edit, and apply it with Edit.
