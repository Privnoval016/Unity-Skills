# UI Toolkit, mapped onto this architecture

This project's runtime UI is uGUI: 6 Screen Space - Overlay canvases and 4 World Space in Playground,
~60 files under `Assets/Game/Encounter/HUD/`, no runtime `.uxml` anywhere. UI Toolkit is a direction,
not the current state.

**This is a mapping document, not a migration plan.** Its job is that new UI authored in UITK keeps
the architecture in `SKILL.md` instead of quietly abandoning it. A full migration of the existing HUD
is a separate decision with a real cost, and nothing here assumes it.

Mechanics reference: `../../vendor/unity/ui-uitk/` — Unity's own skill plus seven reference files
(`uss-guide`, `painter2d`, `custom-elements`, `pointermanipulator-guide`, `common-issues`,
`ui-runtime-binding`, `svg-icons`). Read those for API detail. Read this for what to do with it here.

## The mapping

| This architecture (uGUI) | UI Toolkit equivalent | What actually changes |
|---|---|---|
| `ThemeConfig` SO + `ThemeAdapter` | USS custom properties (`--color-primary`) written from the same SO at runtime | The SO stays the authority. USS variables become the delivery mechanism, replacing per-component adapters |
| `Observable<T>` + `View<T>.Bind` | `[CreateProperty]` + `DataBinding` + `dataSource` | **Behavioural difference, not syntax — see below** |
| `AnimatedPanel` + PrimeTween | USS `transition` for simple fades; PrimeTween driving `style` values for sequenced work | PrimeTween stays for anything sequenced or awaited |
| `Canvas.enabled` for visibility | `display: none` vs `visibility: hidden` | Identical class of bug: `display` destroys layout and forces a rebuild, `visibility` does not. The rule survives, the property name changes |
| `UIWidgetPool<TView>` | `ListView` with virtualisation | ListView recycles for you. The pool remains correct for non-list widgets |
| `UIScreen` / `UINavigationHost` | Unchanged | The stack is PushdownAutomata over plain C#. It does not care what renders |
| `ViewModelBase` | Unchanged | Already Unity-free and unit-testable. This is the part that ports for free |
| Prefab-per-widget | `.uxml` template + custom element | Same idea, different file |

## The one that will bite: binding is polled, not pushed

`Observable<T>` raises `OnChanged` **only when the value actually differs**, and `View<T>` subscribes.
Push semantics, zero per-frame cost.

UI Toolkit's `DataBinding` **polls the data source every frame by default**. On a combat HUD with five
gauges per actor across a party, that is a meaningful difference in both cost and behaviour.

Two honest options:

1. **Keep `Observable<T>` and push into elements directly.** A custom element exposes setters, the
   ViewModel stays exactly as it is, and no UITK binding is used at all. Least new machinery, keeps
   the existing `ViewModelBase` tests, and keeps the change-detection semantics already relied on.
   **Prefer this** for anything ported from the existing HUD.
2. **Adopt UITK binding properly**, which means implementing `INotifyBindablePropertyChanged` on the
   data source to get change-driven updates instead of polling. Worth it for new, binding-heavy
   screens authored UXML-first, where UI Builder previewing the data source is a real benefit.

Do not mix the two on one screen. Pick per screen and say which in the file.

`[CreateProperty]` is required on anything bound, and `dataSourcePath` must be built with `nameof()`
so a rename does not silently break the binding at runtime.

## Validation: Unity's skill is out of date here

`vendor/unity/ui-uitk/SKILL.md` states there is "no way to validate UXML or USS from outside the
Editor" and builds its whole workflow around asking the user to focus the Editor and report console
output. **That was true before `com.unity.pipeline`. It is not true now**, and following it wastes a
round trip per iteration.

The replacement loop, per `u-cli/recipes-ref.md`:

1. Write the complete file. Never partial content — a half-written `.uxml` is a parse error the
   moment the Editor imports it. This part of Unity's guidance still stands.
2. `unity command import_asset` (or let the Editor pick it up), then `recompile_status`.
3. `unity command console --level error --tail 20` — UXML parse errors and unknown USS properties
   land here, named by file and line.
4. Capture and run `design-ref.md`'s rubric for the failures that parse cleanly and still render
   wrong, which the console will never report.

**Element-level capture is unavailable on this project.** `capture_editor_element` and
`capture_runtime_element` require Unity 6000.7+; this project is on 6000.5.3f1. Full-view capture
works, so critique whole screens rather than isolated elements until the Editor version moves.

## Conventions

Unity's UITK conventions differ from this project's uGUI ones, and both are right in their own file:

| Thing | Convention |
|---|---|
| `name` attribute in UXML | `camelCase` — `submitButton` |
| USS class / `class` attribute | `kebab-case` — `.submit-button` |
| C# behind a custom element | `u-style` as normal: `_camelCase` privates, `/** <summary> */`, regions |
| File location | Feature folder beside the screen it serves, matching existing HUD layout |

Do not let UXML naming leak into C#, or `u-style` naming into USS.

## Where UITK earns its place first

If UITK is adopted incrementally rather than wholesale, the order that costs least:

1. **New editor tooling.** Custom inspectors and `EditorWindow`s. Zero runtime risk, and UITK is
   already the Unity default there. Best place to learn it.
2. **New standalone screens** with no existing prefab — a settings or party-formation screen. Clean
   slate, no interop with the pooled combat widgets.
3. **Last: the combat HUD.** It is the most coupled, the most performance-sensitive, and the only part
   where the polled-binding difference genuinely matters. Moving it is a project, not a refactor.
