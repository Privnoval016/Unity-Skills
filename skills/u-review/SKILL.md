---
description: >
  Full code review of branch changes against all u-* skill rules, by a lead and four parallel
  reviewers (correctness, design and smells, types and data, tests). Outputs via ReportFindings.
when_to_use: >
  "review my code", "code review", "check my changes", "audit", "lint my branch".
disable-model-invocation: true
allowed-tools: Read Bash Agent
---

## Changed Files

!`git diff main...HEAD --name-only`

If the branch has no diff (work on `main`), the scope is the uncommitted and staged changes, or the
files the request names.

## How the review runs

One lead (you) and four reviewers, each with one viewpoint. Four is enough to cover the ground without
reviewers repeating each other; do not add more for a small change, and for a change of a file or two
run the passes yourself.

1. **Lead prepares.** List the scope, run the non-C# checks below, and run the tests the change
   touches. Read `../u-arch/extensions-ref.md` and `../u-arch/refactoring-ref.md`.
2. **Reviewers run in parallel**, read-only (`code-auditor` agent, or general-purpose told it may not
   edit), on a cheaper model (sonnet). Each gets the scope, its brief from
   [reviewers.md](reviewers.md), and its checklist sections below. Each reads every file in its scope
   in full and returns findings as file:line · rule · what is wrong · failure scenario · fix.
3. **Lead consolidates.** Merge duplicates (two reviewers on one line is one finding), drop findings
   that contradict a documented decision (`Design/`, an accepted audit baseline), and **verify every
   remaining finding by opening the lines**. A plausible guess is not a finding.
4. **Rank** most severe first: wrong behaviour or lost data, then a rule the project calls hard (types,
   hardcoded values, typed keys, type checks), then design and smells, then style.
5. **Report** with `ReportFindings`, not as text. When asked to fix: fix, rebuild, re-run the touched
   tests, and re-report with each finding's outcome.

## Non-C# changes

`git diff` on a `.unity` or `.prefab` file is unreadable, which is how scene changes go unreviewed.
Before the C# pass:

```bash
unity vcs status                              # grouped by what it means to Unity
unity vcs diff <path-to-.unity-or-.prefab>    # by GameObject and component name, not fileID
unity vcs affected --format json              # which assemblies and tests this diff touches
unity vcs doctor                              # ignore rules, LFS, meta pairing, package pinning
```

Review every changed scene and prefab this way. `vcs doctor` reports defects, not style: ignored
`.meta` files come back as errors and genuinely break references on a fresh clone.

Then run the tests the change actually touches, rather than the whole suite:

```bash
unity test --mode EditMode --filter <from vcs affected> --format json
```

**Exit code `8` means tests ran and failed. `1` means the run itself broke.** Do not conflate them —
reporting a broken harness when the real answer is "your tests fail" wastes a cycle. See
`../u-cli/recipes-ref.md` §2.

---

## Review Checklist

Which reviewer owns each section is in [reviewers.md](reviewers.md).

### Style (`u-style`)
- [ ] Every class and every public method/property has `/** <summary>...</summary> */` doc comment
- [ ] No `/// <summary>` triple-slash comments anywhere
- [ ] Doc comments state the contract (what it does, returns, requires), not the history or the reasoning
- [ ] Every `[SerializeField]` has a `[Tooltip("...")]` attribute
- [ ] No inline comments (`//`) — only doc comments
- [ ] `#region` names match the exact vocabulary: Inspector Fields, Private Systems, Private Fields,
      Properties, MonoBehaviour Callbacks, Public API, Event Handlers, Helpers
- [ ] Private non-serialized fields use `_camelCase`; serialized inspector fields use `camelCase`
- [ ] Public members use `UpperCamelCase`; interfaces use `IFoo`; events use `OnEventName`
- [ ] Auto-property style used (`{ get; private set; }`) — no `private _x; public X => _x;` pattern
- [ ] No extra alignment spaces to line up `=` signs across multiple field declarations
- [ ] `private` by default — no unnecessarily public members
- [ ] `using` directives, not fully qualified names (aliases only for real clashes)

### Architecture (`u-arch`)
- [ ] MonoBehaviours contain only wiring, lifecycle hooks, and dispatch — no domain logic
- [ ] ScriptableObject roles are pure (Config / Factory / Data Provider / Event Channel) — not mixed
- [ ] No singletons — `Services.Get<T>()` used instead
- [ ] No Zenject or heavy DI framework imports
- [ ] Event routing: `EventBus<T>` for global, C# events for tight coupling — no `UnityEvent` fields
- [ ] No handler relies on running before another subscriber; order lives in one stage list
- [ ] Interfaces injected, never concrete types
- [ ] No type checks (`is`, `as`, type switches) in game logic; optional capabilities via `Capability<T>()`
- [ ] `[CreateAssetMenu]` present on all concrete Config / Factory / Data Provider SOs
- [ ] `[SerializeReference]` used for polymorphic SO fields where appropriate

### Smells and patterns (`u-arch` Code Smells, `refactoring-ref.md`, `patterns-ref.md`)
- [ ] No long method that wants a comment per block; no more than 3 parameters without a parameter object
- [ ] No data clump or parallel fields duplicating an engine type
- [ ] No class edited for unrelated reasons; no file over ~300 lines without a stated reason
- [ ] No switch on a kind that new content must edit (a strategy instead)
- [ ] No query that mutates; no flag parameter switching what a method does
- [ ] No feature envy, inappropriate intimacy, or message chain across three or more owners
- [ ] No dead code, unused parameter, serialized field nobody reads, or commented-out code
- [ ] No speculative generality: every hook, virtual, generic and parameter has a caller
- [ ] No lazy class or middle man that only forwards (strategies, adapters, facades exempt)
- [ ] Every pattern answers a problem present today; none has one implementation and no second in sight
- [ ] Duplication: a second copy is a note, a third is a finding (structure only; values always)

### Refactor vs feature
- [ ] A commit called a refactor changes no behaviour, and ships no feature or balance change
- [ ] A test changed in a refactor is explained (behaviour changed, or it was coupled to internals)
- [ ] Renamed fields and moved `[SerializeReference]` types carry `[FormerlySerializedAs]` / `[MovedFrom]`
      or a migration script, and a before/after snapshot shows the data is unchanged

### Types and values (`u-arch` Data-Driven Design)
- [ ] No `object`-typed identity, owner, token or bag (a sealed type or a marker interface instead)
- [ ] No raw `int`/`string`/`float` standing for an id, range, duration or kind
- [ ] No gameplay or tuning number in code; it goes through the stat pipeline or a config field
- [ ] A code constant is only an engine safety limit, named and documented
- [ ] No typed string naming an input action, asset, stat or id; Inspector refs are assets or dropdowns
- [ ] Combat durations count turns or uses, not seconds

### Data-Driven (`u-arch`)
- [ ] No string-based scene / tag / layer / audio references
- [ ] Designer-facing fields on SOs have `[Tooltip]`
- [ ] `OnValidate()` derives low-level constants; derived fields have `[HideInInspector]`
- [ ] Scalability: a new character, weapon, element or variant needs a new asset, not a code edit
- [ ] Organisation: purpose-named folders, nothing loose beside an asmdef, one owner per value

### Performance (`u-arch`)
- [ ] No `Find` / `FindObjectOfType` / `FindFirstObjectByType` / `FindGameObjectWithTag` at runtime
- [ ] No `GetComponent` calls in `Update`, `FixedUpdate`, or any per-frame callback
- [ ] No standard LINQ (`System.Linq`) in hot paths — `ZLinq` used instead
- [ ] `renderer.material` not mutated directly — `MaterialPropertyBlock` used instead
- [ ] Runtime-spawned GameObjects use object pooling
- [ ] Only real, per-frame or first-use costs are findings; tens of bytes are not

### Correctness
- [ ] Every changed path is right for empty, single, many, dead, missing and repeated inputs
- [ ] Lifecycle: subscribe/unsubscribe pair, teardown runs on exceptions and on disable, no stale reference after re-enable
- [ ] Async: no fire-and-forget that can outlive its owner; cancellation honoured
- [ ] Statics and registries restored after use (tests and fights both)
- [ ] Behaviour matches `Design/combat/combat-design.md` and the assembly README, or they are updated

### Tests
- [ ] Every changed behaviour has a test that fails without the change
- [ ] Edge, boundary and regression cases, not only the happy path
- [ ] Each test sets up its own state (stat bases, registries) and restores it in `finally` or TearDown
- [ ] No vacuous assert (a loop over an empty set, an assert that can't fail); empty sets guarded with `Is.Not.Empty`
- [ ] Names say the behaviour; created ScriptableObjects destroyed
- [ ] Tests match the project as it is now, not a removed design

### Input (`u-input`)
- [ ] No `Input.GetKey` / `Input.GetButton` / `Input.GetAxis` in game logic
- [ ] No string-based button names — enum values or InputActionReferences only
- [ ] Input flows through `IInputSource` interface

### UI (`u-ui`)
- [ ] `Canvas` component used for visibility (not `GameObject.SetActive`)
- [ ] No Animator controllers driving UI animation — PrimeTween only
- [ ] No `UnityEvent` fields in UI components
- [ ] No runtime `Instantiate` for UI elements
- [ ] No hardcoded `Color(r,g,b)` values — ThemeConfig adapter or SO token used

### UI visual (`u-ui/design-ref.md`)
- [ ] New list/menu screens state initial index, wrap behaviour, and how unusable entries are skipped
      (navigation here is bespoke via `IInputSource`, not `Selectable`/`EventSystem`)
- [ ] Anything anchored to a screen edge accounts for `Screen.safeArea`
- [ ] New canvases match the existing scaler config (ScaleWithScreenSize, 1920x1080, match 1)
- [ ] `coc_validate_actors` and `coc_hud_report` run clean, or the new failures are explained
- [ ] No critical state encoded in colour alone (shape, icon or position backs it)
- [ ] Meter and panel values initialise on bind, not only on a change event

### URP render features (`../../vendor/unity/validate-urp-render-graph-renderer-feature/`)
- [ ] Any `ScriptableRendererFeature` touched follows Render Graph rules — resource wiring, material
      binding, descriptor usage

### Extensions (`u-extensions`)
- [ ] No reinvention of EventBus, PushdownAutomata, MonoBehaviourUpdatable, Timers, ICondition,
      RuleSystem, or Modifiers — use Extensions equivalents
