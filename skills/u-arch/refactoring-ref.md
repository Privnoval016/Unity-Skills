# Refactoring reference

Code smells, their standard remedies in Unity/C# form, and how a refactor is carried out safely. Drawn from
refactoring.guru (smells, techniques, patterns), adapted to this codebase's rules. The short rules live in
`SKILL.md` (Code Smells, When to Refactor); this file holds the detail.

## How a refactor is done

A refactor changes structure, never behaviour: no feature and no balance change in the same commit.

1. **State the invariant**: what must not change (values, outputs, serialized data).
2. **Pin it**: tests that cover the behaviour (write characterisation tests first if none exist), and a
   before snapshot of anything data-shaped (asset values, stat bases, references).
3. **Add the new shape beside the old**, and move callers across one group at a time, build and tests green
   after each step.
4. **Migrate serialized data by script**, never by hand: `[FormerlySerializedAs]` / `[MovedFrom]` for renames,
   a migration script for a changed type or shape. A `[SerializeReference]` type's name, namespace or
   assembly is serialized data too.
5. **Diff the after snapshot** against the before one; it must be identical (or differ exactly as intended).
6. **Delete the old shape** in its own commit once nothing reads it.

### Refactoring by script

Folding many sites at once is done by script, and scripts fail in quiet ways. Before writing any file:

- **Count the sites and assert the count.** A rewrite that matches a different number of sites than you
  found by hand is wrong; stop and look.
- **Match call sites, not declarations.** A rename regex that also hits a method's own declaration, or a
  same-named member elsewhere, changes code it was never meant to touch.
- **Never re-sort usings or reformat by script**; add a using in its sorted place and leave the rest.
- **Edit blocks with a brace-balanced scan**, never a regex that can swallow a closing brace or an argument.
- **After the rewrite**: compile, read the diff of every touched file, run every suite that covers them.
- **Stage what changed, all of it**: list the working tree after staging; an asset edited in the Editor
  alongside the code is the easy one to leave behind.
- **One reviewer per fold**, reading every changed line against the original, catches what the compiler
  and tests do not (unreachable overrides, a dropped default, a changed order).

A test that had to change in a refactor means either the behaviour changed (then it was not a refactor) or
the test was coupled to internals (move it to public behaviour). Say which.

## Code smells and their remedies

| Smell | What it looks like | Remedy (Unity/C# form) |
|---|---|---|
| Long method | Needs a scroll; a block that wants a comment | Extract Method into named private helpers (`#region Helpers`); guard clauses for deep nesting |
| Long parameter list | More than 3 parameters, or one group passed through several calls | Introduce Parameter Object: a `readonly struct` named for the concept (`HitSpec`, `HitOrigin`) |
| Data clumps | Fields or arguments that always travel together | One type, with the behaviour on them moved in; reuse an engine type first |
| Primitive obsession | A raw `int`/`string`/`float`/`object` standing for an id, range, duration, kind or identity | A typed value (`readonly struct`), an asset reference, a sealed token class (`ActionUse`), or an enum for a pure category; never a typed string key |
| Large class / divergent change | One class edited for unrelated reasons; ~300 lines or ~10 fields without a stated reason | Extract Class; a MonoBehaviour keeps wiring only and holds a plain C# class |
| Switch statements | A `switch`/`if` chain on a kind or type that new content must edit | Replace Type Code with Strategy, Replace Conditional with Polymorphism: a small interface, implementations as `[SerializeReference]` rows. A local exhaustive switch over a closed category, or one that picks which class to create, is fine |
| Type checks | `is`, `as`, type switches in game logic | A member on the declared type, or an optional capability through `Capability<T>()` (guarded by `TypeCheckGuardTests`) |
| Temporary field | A field null or meaningless outside one operation | A local, or a parameter object |
| Refused bequest | An override that throws, no-ops or ignores the base | Composition or a narrower interface ("no hanging fields"); no `NotImplementedException` in shipped code |
| Alternative classes, different interfaces | Two classes doing one job with different method names | Merge, or one interface both implement |
| Shotgun surgery | One change (a new character, element, resource) edits several files | Move the knowledge to data: one asset beside its owner, read by one general system |
| Parallel hierarchies | Adding a subclass forces one elsewhere | Merge the hierarchies, or pair thin mirrors (engine/authoring) with a guard test |
| Comments | Narration explaining unclear code | Rename or extract until the comment is unneeded; doc comments state the contract only |
| Duplicate code | Fragments differing only in a value or type | One method, a generic, or a data row; check Extensions first; rule of three for structure |
| Lazy class / middle man | A class with no behaviour of its own, or one that only forwards | Inline it or call the target directly. Strategies, decorators, adapters, facades, config assets and event structs are exempt |
| Data class | A runtime bag whose clients hold all its logic | Move the behaviour in. Config ScriptableObjects, event structs and authoring rows are deliberate data |
| Dead code | Unused types, members, parameters, serialized fields, commented-out code | Delete it after grepping code, tests, assets and prefabs |
| Speculative generality | A hook, virtual, generic or parameter with no caller | Remove it. A seam needs a real use today or a stated, imminent second one |
| Feature envy | A method using another object's data more than its own | Move Method to the data's owner (strategies reading their context are exempt) |
| Inappropriate intimacy | Two classes holding each other or touching each other's internals | A narrow interface between them, or one owner |
| Message chains | `a.B.C.D.Do()` across three or more owners | A method at the head of the chain; prefer a narrow interface or `Capability<T>()` over forwarding wrappers |
| Magic numbers and names | A literal number, input-action name or asset name in code | Gameplay or tuning: data (a stat, a config field, an asset). Engine safety limit: a named, documented `const`. Input actions and assets: references |
| Null checks everywhere | Repeated `if (x == null)` for an optional behaviour | Introduce Null Object: a no-op implementation as the default. Never for required wiring (`Services.Get<T>()` throws; `coc_missing_refs` must still catch a missing reference) |
| Query that mutates | A method that both returns and changes state | Separate Query from Modifier: a pure `Preview`/`Can…` and an `Apply`/`Resolve` |
| Flag parameter | A bool that switches what a method does | Explicit methods, or a strategy if designers vary it |
| Incomplete library class | A gap in Unity, Odin or Animancer | One extension method in a static `XxxExtensions`, or an adapter behind an interface; never copy the library |

## Conflicts reconciled

- **Rule of three vs this project's rules.** Rule of three applies to structure (helpers, abstractions).
  Hardcoded tuning values, typed keys and type checks are fixed on the first occurrence.
- **Generalise vs speculative generality.** "Generalise" means do not hardcode the one case into the engine
  (build the general seam: a stance is a status plus variant forms). It does not mean hooks, parameters or
  virtuals nobody calls.
- **Subclassing.** Guru's polymorphism is often by subclass; here it is a `[SerializeReference]` interface
  row, because ScriptableObject and MonoBehaviour hierarchies serialise and compose badly.
- **Parameter objects** are `readonly struct`s (no garbage in per-frame code), passed by `in` only if large.
- **Preserve Whole Object** passes a narrow engine interface (`IActor`), never a Unity type into the engine.
