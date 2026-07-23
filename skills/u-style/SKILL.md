---
description: >
  Unity C# code style enforcer. Naming conventions, #region vocabulary, doc comment format,
  property style, field alignment rules. Loaded whenever writing or reviewing Unity C# code.
when_to_use: >
  Writing new classes or methods, reviewing code style, questions about naming conventions,
  region names, doc comment format, property vs backing field, field alignment.
allowed-tools: Read Edit Write AskUserQuestion
---

## Overview

These rules apply to every C# file in the project without exception.
For extended examples and templates see [style-ref.md](style-ref.md).

## Doc Comments

- Every class, struct, interface, enum, and every public method/property/constructor gets a
  `/** <summary>...</summary> */` doc comment.
- Use C-style block comment syntax. **Never** use `/// <summary>` triple-slash.
- `[Tooltip("...")]` on every `[SerializeField]` — the Tooltip is the field documentation.
  Do **not** add a `/** */` comment above a serialized field.
- Extended doc tags: `<para>`, `<list type="number/bullet">`, `<typeparam>`, `<param>`,
  `<returns>`, `<remarks>`, `<see cref="..." />`.
- **No inline comments** (`// ...`) anywhere. If logic needs explanation, extract a named method.

**Class-level summaries stay high-level.** One or two complete sentences describing what the class
*is* and its role — not a design-rationale excerpt. Skip the "why" (a past alternative considered,
a historical bug it fixes, an itemized list of every case it handles) — that belongs in the plan
document or a folder `README.md`, not repeated in the doc comment every reader hits first. Example:
a gauge class's summary is "A bounded numeric resource an actor has, such as HP or Energy, with
optional per-turn regen/decay and threshold-crossing behavior" — not a paragraph enumerating every
concrete resource it backs and the historical reason the class is unified.

**Method-level docs**: every public method gets a short functional-description sentence, plus
`<param>`/`<returns>`/`<exception>` tags wherever those aren't self-evident from the name and
signature alone. Keep it light — this is not the place for implementation narrative either; state
what the caller needs to know (what it does, what it returns, what it throws and when), not how it
does it internally. A trivial one-line delegating method (`IsHostile(a, b) => GetRelationship(a, b)
== Hostile`) does not need a tag-heavy doc block on top of an already-documented class; use judgment.

**Dictionary fields get a key/value comment**: every `Dictionary<TKey,TValue>` field gets a one-line
`/** <summary>...</summary> */` stating what the key and value represent, e.g. "Keyed by resource
type ID, resolving to that resource's live gauge." Lists get this only when the element's role isn't
obvious from the variable name and element type — case by case, not a blanket rule like dictionaries.

## #region Vocabulary

Use exactly these names, in this exact order, inside every class:

```
#region Inspector Fields        — all [SerializeField] fields
#region Private Systems         — private non-serialized service/subsystem references
#region Private Fields          — private non-serialized state
#region Properties              — public/internal properties
#region MonoBehaviour Callbacks — Awake, Start, OnDestroy, OnEnable, OnDisable
#region Public API              — public methods (or "Public API — Subsystem" for large classes)
#region Event Handlers          — C# event subscription callbacks
#region Helpers                 — private utility methods
```

Omit regions that would be empty. Do not invent new region names.

## Naming

| Target | Convention | Example |
|--------|-----------|---------|
| Private non-serialized field | `_camelCase` | `_navigator` |
| Serialized inspector field | `camelCase` (no underscore) | `nodePrefab` |
| Public member | `UpperCamelCase` | `BeginInsertion` |
| Interface | `IFoo` | `IValueGenerator<T>` |
| C# event | `OnEventName` | `OnNodeInserted` |
| Enum value | `PascalCase` | `NodeVisualState.Normal` |
| Namespace | One per system, not per folder (see Namespaces below) | `CombatEngine`, `DynamicPhysics` |

## Namespaces

One namespace per top-level system, not one per folder. A system with many subfolders (`Actors/`,
`Effects/`, `Targeting/`, `Simulation/`, ...) still declares the same single namespace —
`namespace CombatEngine`, say — in every file regardless of how deep it lives. Folder structure
documents organization; namespace is for the system as a whole.

This avoids a `using` per cross-folder reference within the same system, which is most references,
since subsystems inside one system talk to each other constantly. It also means a file can be moved
between subfolders during a refactor without touching its namespace declaration.

Only split into multiple namespaces when the pieces are genuinely separate systems someone could
reference independently — a shared library like `Extensions` legitimately has
`Extensions.Modifiers`, `Extensions.EventBus`, etc., since other projects import subsets of it. A
single feature's own internal folder layout is not that case.

## Property Style

Use auto-properties. Never use a backing field to expose state:

```csharp
// Correct
public int Count    { get; private set; }
public bool Enabled { get; set; }

// Wrong — verbose and unnecessary
private int _count;
public int Count => _count;
```

`{ get; private set; }` for externally read-only state.
`{ get; set; }` when external mutation is intentional.

## Field Alignment

Standard indentation only. Do **not** add extra spaces to align `=` or type names:

```csharp
// Correct
[SerializeField] private float speed = 5f;
[SerializeField] private int   count = 3;  // ← Wrong: padded to align

// Correct
[SerializeField] private float speed = 5f;
[SerializeField] private int count = 3;
```

## General Rules

- Default to `private`. Make something `public` only when external access is required.
- Break long methods into named private helpers — not partial classes.
- Inject SO references and data objects (not value copies) so inspector edits propagate live.
- Delegates: initialize to `delegate { }` (never null) to avoid null checks at every call site.
- `[DisallowMultipleComponent]` on any component that must be unique per GameObject.
- `[DefaultExecutionOrder(N)]` only when necessary to control Unity's script order.
- `#if UNITY_EDITOR` guard all `OnDrawGizmosSelected` and editor-only debug code.
- `Debug.LogWarning`/`Debug.LogError` messages: one brief line stating what's wrong. Not a full
  explanation of why it matters or how to fix it — that belongs in a doc comment or chat, not a
  runtime log line.

## Continuous Improvement

When the user provides new style preferences that should apply permanently:
ask "Should I update this skill file for future sessions?" If yes, Read
`${CLAUDE_SKILL_DIR}/SKILL.md`, propose the minimal edit, and apply it with Edit.
