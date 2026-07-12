---
description: >
  Full code review of branch changes against all u-* skill rules. Checks style, architecture,
  performance, data-driven design, input, UI, and Extensions usage. Outputs via ReportFindings.
when_to_use: >
  "review my code", "code review", "check my changes", "audit", "lint my branch".
disable-model-invocation: true
context: fork
agent: general-purpose
allowed-tools: Read Bash
---

## Changed Files

!`git diff main...HEAD --name-only`

## Instructions

Review every C# file listed above. Read each one in full before reporting findings.
Also read `${CLAUDE_SKILL_DIR}/../u-arch/extensions-ref.md` before reviewing to know which
Extensions utilities already exist (so you can catch reinventions).

For each finding, verify it is a real violation before reporting — do not report plausible guesses
without reading the relevant lines. Rank findings most-severe first.

Output all findings using the `ReportFindings` tool. Do not also output them as text.

---

## Review Checklist

### Style (`u-style`)
- [ ] Every class and every public method/property has `/** <summary>...</summary> */` doc comment
- [ ] No `/// <summary>` triple-slash comments anywhere
- [ ] Every `[SerializeField]` has a `[Tooltip("...")]` attribute
- [ ] No inline comments (`//`) — only doc comments
- [ ] `#region` names match the exact vocabulary: Inspector Fields, Private Systems, Private Fields,
      Properties, MonoBehaviour Callbacks, Public API, Event Handlers, Helpers
- [ ] Private non-serialized fields use `_camelCase`; serialized inspector fields use `camelCase`
- [ ] Public members use `UpperCamelCase`; interfaces use `IFoo`; events use `OnEventName`
- [ ] Auto-property style used (`{ get; private set; }`) — no `private _x; public X => _x;` pattern
- [ ] No extra alignment spaces to line up `=` signs across multiple field declarations
- [ ] `private` by default — no unnecessarily public members

### Architecture (`u-arch`)
- [ ] MonoBehaviours contain only wiring, lifecycle hooks, and dispatch — no domain logic
- [ ] ScriptableObject roles are pure (Config / Factory / Data Provider / Event Channel) — not mixed
- [ ] No singletons — `Services.Get<T>()` used instead
- [ ] No Zenject or heavy DI framework imports
- [ ] Event routing: `EventBus<T>` for global, C# events for tight coupling — no `UnityEvent` fields
- [ ] Interfaces injected, never concrete types
- [ ] `[CreateAssetMenu]` present on all concrete Config / Factory / Data Provider SOs
- [ ] `[SerializeReference]` used for polymorphic SO fields where appropriate

### Data-Driven (`u-arch`)
- [ ] No magic numbers or hardcoded string literals anywhere in game code
- [ ] No string-based scene / tag / layer / audio references
- [ ] Designer-facing fields on SOs have `[Tooltip]`
- [ ] `OnValidate()` derives low-level constants; derived fields have `[HideInInspector]`
- [ ] `[FormerlySerializedAs]` on renamed fields

### Performance (`u-arch`)
- [ ] No `Find` / `FindObjectOfType` / `FindFirstObjectByType` / `FindGameObjectWithTag` at runtime
- [ ] No `GetComponent` calls in `Update`, `FixedUpdate`, or any per-frame callback
- [ ] No standard LINQ (`System.Linq`) in hot paths — `ZLinq` used instead
- [ ] `renderer.material` not mutated directly — `MaterialPropertyBlock` used instead
- [ ] Runtime-spawned GameObjects use object pooling

### Input (`u-input`)
- [ ] No `Input.GetKey` / `Input.GetButton` / `Input.GetAxis` in game logic
- [ ] No string-based button names — enum values only
- [ ] Input flows through `IInputSource` interface

### UI (`u-ui`)
- [ ] `Canvas` component used for visibility (not `GameObject.SetActive`)
- [ ] No Animator controllers driving UI animation — PrimeTween only
- [ ] No `UnityEvent` fields in UI components
- [ ] No runtime `Instantiate` for UI elements
- [ ] No hardcoded `Color(r,g,b)` values — ThemeConfig adapter or SO token used

### Extensions (`u-extensions`)
- [ ] No reinvention of EventBus, PushdownAutomata, MonoBehaviourUpdatable, Timers, ICondition,
      RuleSystem, or Modifiers — use Extensions equivalents
