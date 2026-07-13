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
