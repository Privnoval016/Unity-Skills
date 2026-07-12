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
| Namespace | Scoped, not always required | `Combat`, `DynamicPhysics` |

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

## Continuous Improvement

When the user provides new style preferences that should apply permanently:
ask "Should I update this skill file for future sessions?" If yes, Read
`${CLAUDE_SKILL_DIR}/SKILL.md`, propose the minimal edit, and apply it with Edit.
