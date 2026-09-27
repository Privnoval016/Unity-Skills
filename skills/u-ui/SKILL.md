---
description: >
  Modular Unity UI system. ThemeConfig SO + central IThemeProvider driving theme adapters, an MVVM
  binding layer (Observable<T> / ViewModelBase / View<T>), a UINavigationHost screen stack built on
  Extensions.PushdownAutomata, injectable IPanelTransition animations via PrimeTween, and pooled
  widgets. Changing the entire UI theme means changing one SO; changing a widget's animation means
  swapping one field. Owns ALL runtime game UI in this project, including visual design
  (design-ref.md) and UI Toolkit (uitk-ref.md).
when_to_use: >
  Building or reviewing any Unity UI, questions about "theme", "ThemeConfig", "ThemeColorAdapter",
  "color tokens", "ViewModel", "Observable", "UINavigationHost", "UIScreen", "PanelTransition",
  "PrimeTween", "UI animation", "Canvas", "widget pool". Also any question about how the UI *looks* —
  layout, spacing, contrast, readability, visual hierarchy, art direction — and anything about UI
  Toolkit, UXML, USS or UIDocument.
allowed-tools: Read Edit Write Bash AskUserQuestion
---

## Overview

UI must be modular, theme-driven, and MVVM-bound. Changing the visual style of the entire game
requires changing one SO — no scene edits, no hunting through individual components. Changing a
widget's animation requires swapping one field. This is the architecture actually implemented under
`Assets/Game/UI/` — read the real files there before assuming a signature; this doc summarizes intent.

## This skill owns runtime game UI

Generic Unity UI skills — including Unity's own `ui` router and `ui-ugui` — tell an agent to generate
Canvas hierarchies from scratch and know nothing about `ThemeConfig`, `View<T>`, `AnimatedPanel` or
`UIWidgetPool`. Following them produces UI that renders and violates every rule below.

**This skill decides architecture for all runtime game UI here.** Vendored material under
`../../vendor/unity/` is reference for framework *mechanics* only — never for structure. `ui-ugui`'s
`SKILL.md` is deliberately not vendored for this reason; only its references are.

| Concern | Read |
|---|---|
| Architecture, theming, MVVM, navigation, pooling | this file |
| The project's style bible, if it has one (here: `Design/STYLE.md`). **Read first for any visual work** | project root |
| How it looks, and the screenshot critique rubric | [design-ref.md](design-ref.md) |
| UI Toolkit, UXML/USS, runtime binding | [uitk-ref.md](uitk-ref.md) |
| Driving the Editor, capturing what you built | `../u-cli/` |

## Theme System (`Assets/Game/UI/Theme/`)

**`ThemeConfig`** (SO, `[CreateAssetMenu(menuName = "Game/UI/Theme Config")]`) is the global style
authority, and **the only place a colour is set**. Colour is two layers:

- **Swatches** (`ThemeSwatch`: the ink scale Charred…Paper, Vermilion, Iron, KeyLip, SilkPattern) are
  the named colours. Change one and everything using it follows.
- **Tokens** (`ThemeColorToken`: Ground, Panel, Lit, TextPrimary, TextSecondary, …) pick a swatch and
  an opacity **per ground** (`ThemeGround.Ink` for combat, `Paper` for menus). Components ask for
  `GetColor(token, ground)`, never a raw `Color`. `GetSwatch(swatch)` is for the rare non-semantic look.
- **Themed materials**: shader colours a Graphic's vertex colour can't reach (outlines, a key-cap's
  lip, seal paper, TMP halos, markers, ground marks, silk) are rows in ThemeConfig's
  `materialBindings` ({material, property, token or swatch}). The theme writes them on every edit and
  when it becomes active. **Never bake a palette colour into a material or prefab by script**: add a
  binding.

It also holds type (`GetTypeStyle(ThemeFontRole)`: font, material preset, casing, tracking), motion
(`Snap`, `Strike`, `Bleed`, `Dry` as unscaled-time `TweenSettings`, plus `MieHoldDuration`,
`CommitHoldDuration`), the meters' `CostPreviewAlpha`, and layout (`GridUnit`, `SafeMargin`).
`ThemePaletteTests` pins every token's colour; change them only with a deliberate palette change.
Editing the asset re-applies at once in Edit and Play mode (`ThemeConfig.Edited`).

**`IThemeProvider` / `ThemeService`** is the single source of truth for the *active* theme, registered
via the project's `Services` locator (not a per-adapter serialized reference — that breaks the moment
you swap to a genuinely different theme asset, and never reaches a widget pooled in after the swap).
`ThemeService.SetActive(theme)` swaps it and raises `ThemeChangedEvent` on `EventBus<T>`; so does
editing the active theme during play. A View that styles itself on demand (not through an adapter)
must also listen for `ThemeChangedEvent` and restyle.

**`ThemeAdapter`** (abstract base) resolves the theme via `ActiveTheme.Resolve(fallbackTheme)` —
registered active theme if present, else the serialized fallback (so a prefab still previews sensibly
in isolation with no `ThemeService` in the scene) — applies it in `Start` (guaranteeing
`ThemeService.Awake` ran first), and re-applies on `ThemeChangedEvent`. Concrete adapters
(`ThemeColorAdapter` on any `Graphic`, `ThemeFontAdapter` on any `TMP_Text`) just implement `Apply(theme)`.
A component that only needs the theme *once, on demand* (an animation about to play) should call
`ActiveTheme.Resolve(fallback)` directly rather than inheriting `ThemeAdapter` — that base is for
components with a standing visual property to keep in sync, not a one-shot read.

## MVVM Binding (`Assets/Game/UI/MVVM/`)

**`Observable<T>`** is the real observable-with-change-notification primitive — raises `OnChanged`
only when the value actually differs (via `IEqualityComparer<T>`), with a `BindAndInvoke` helper that
immediately syncs a handler to the current value then subscribes it. (`Extensions.Other.WrappedField<T>`
is a getter/setter *proxy* with no change notification — do not reach for it expecting observable
behavior.)

**`ViewModelBase`** — plain, Unity-free, unit-testable. Owns state, exposes `Observable<T>` properties,
implements `IDisposable` to unsubscribe from whatever it subscribed to on construction (combat-flow
EventBus events, etc.).

**`View<TViewModel>`** (MonoBehaviour base) — `Bind(viewModel)` tears down any previous binding
(`OnUnbind`) before wiring the new one (`OnBind`, where the View subscribes to the ViewModel's
observables and pushes their current values). Rebinding a pooled View onto a fresh ViewModel is just
calling `Bind` again — no leaked subscriptions onto a stale ViewModel. Input flows the other direction
as plain method calls / C# events the ViewModel exposes; this base only prescribes the display half.

```csharp
public class HealthBarView : View<CharacterMeterViewModel>
{
    [SerializeField] private Image fillImage;

    protected override void OnBind() => ViewModel.Health.BindAndInvoke(SetFill);
    protected override void OnUnbind() => ViewModel.Health.Unbind(SetFill);

    private void SetFill(float value01) => fillImage.fillAmount = value01;
}
```

## Navigation Stack (`Assets/Game/UI/Navigation/`)

**`UIScreen`** (abstract) is a thin, sealed bridge onto `Extensions.PushdownAutomata`'s
`PushdownState<UINavigationHost>` — reuse that existing stack machine directly, don't reinvent one.
Implement the async hooks:

- `EnterAsync()` — camera framing + player pose + panel animation for entering this screen fresh.
- `ExitAsync()` — played when popped for good (never resumed).
- `SuspendAsync()` — played when a screen is pushed on top of this one (default no-op; override to
  e.g. dim/hide without a full exit).
- `ResumeAsync()` — played when the screen above this one pops back off (default: same as `EnterAsync`).

The stack's push/pop bookkeeping (`PushdownAutomata.Interrupt`/`ResumePrevious`) stays fully
synchronous — each screen's async animation work rides along fire-and-forget rather than blocking it,
so the stack is always in a consistent state between calls. A screen guards its own input against
being interacted with mid-animation via its own state, if that matters — not the stack.

**`UINavigationHost`** (MonoBehaviour) owns one flow's stack: `Push(screen)` suspends the current
screen and opens the new one on top; `Pop()` closes the current screen and resumes what was
suspended beneath it; `Replace(screen)` swaps to a sibling with no history kept for the one replaced.
The stack starts empty — call `Push` once with the flow's first screen to seed it.

## Injectable Transitions (`Assets/Game/UI/Transitions/`)

**`IPanelTransition`** (`PlayInAsync`/`PlayOutAsync(RectTransform, CanvasGroup, ThemeConfig)`) is the
pluggable enter/exit animation, chosen per widget via `[SerializeReference]` — swapping the concrete
type restyles a widget's animation without touching code. Ships with `FadeTransition`,
`SnapTransition` and `BrushTransition`. Every implementation reads its timing/ease from the passed
`ThemeConfig` — never a hardcoded literal.

**`AnimatedPanel`** ties a transition to visibility: `ShowAsync()` enables the `Canvas` then plays the
enter transition; `HideAsync()` plays the exit transition then disables the `Canvas`. **Visibility is
always `Canvas.enabled`, never the GameObject** — disabling the GameObject destroys layout and forces a
full rebuild on re-enable.

**A move/scale transition never animates the Canvas's own RectTransform — always a child.** A root
Screen Space canvas has its RectTransform forcibly resized/repositioned by Unity every frame to fill
the screen; any script change to it gets overridden on the next layout pass, so a move/scale
transition silently doesn't work if pointed at it. `AnimatedPanel` requires only `Canvas` +
`CanvasGroup` on its own GameObject (both safe to touch directly — `enabled` and `alpha` aren't layout
properties) and a separate serialized `Content` field pointing at a child `RectTransform`, which is
what transitions actually move/scale. `FadeTransition` (alpha-only) doesn't need `Content` at all.

```csharp
// Correct — timing from ThemeConfig, unscaled, sequences from theme.NewSequence()
_fade = Tween.Alpha(group, new TweenSettings<float>(group.alpha, 1f, theme.Strike));
_motion = theme.NewSequence().Chain(Tween.Scale(rect, new TweenSettings<Vector3>(from, Vector3.one, theme.Snap)));

// Wrong — hardcoded values, scaled time (freezes during a mie)
Tween.Alpha(group, 1f, 0.2f, Ease.OutSine);
```

UI timers use `Time.unscaledDeltaTime`, never `Time.deltaTime`.

- PrimeTween for ALL UI animation. No Animator controllers for UI.
- Async sequences use UniTask (PrimeTween's `Tween`/`Sequence` support `await` natively) — no
  coroutines.
- UI is never just enabled/disabled — it is always animated on/off via `AnimatedPanel`.

## Pooling (`Assets/Game/UI/Widgets/`)

**`UIWidgetPool<TView>`** pre-warms `TView` instances at construction — the one place runtime
`Instantiate` for UI is allowed, and only there. `Rent()`/`ReturnAll()`/`SetCount(count, onRent)` toggle
`gameObject.SetActive` for *pool membership* (this is not the visibility-animation rule above — that's
about hiding an already-present, already-bound widget with flair; recycling a pooled instance in/out of
a dynamic list is standard pooling practice). Growing past the pre-warmed count instantiates on demand
and logs a warning so an undersized pool is noticed, not silently tolerated. Use for queue rows, damage
numbers, technique/item list entries — any dynamic list.

## Prefabs Are the Source of Truth

**Every piece of the HUD is a prefab, edited like any Unity prefab** (Chains of Contract:
`Assets/Battle/Prefabs/HUD/*.prefab` per HUD root, widget prefabs beside them). Every reusable widget
is a prefab too, pool templates included, bound to an element ViewModel at rent time. Elements that
animate frequently should live on their own sub-Canvas (batching). The user tunes sizes, positions
and values in the Inspector without code, so:

- **Never rebuild UI from a script.** Builders that recreate hierarchies wipe hand tuning; they are
  archived (`Design/revamp/builders/archive/`). A large mechanical change may be scripted, but only by
  loading the prefab (`PrefabUtility.LoadPrefabContents`), changing just what the edit is about, and
  saving it (`SaveAsPrefabAsset`). See `Design/revamp/builders/README.md`.
- **Never construct UI at runtime.** `UIWidgetPool` instantiating an authored template is the only
  runtime `Instantiate`.
- **One owner per value.** If code must set a rect or size (animation, state), read the rest value
  from the authored rect (captured in `Awake`) or from one serialized field, never a second copy in
  code. Example: the minimap rests exactly where its Map rect is authored and restores it when closed.
- **Every tunable is a serialized field with a `[Tooltip]`** (or a theme value if it's a shared
  look). No look or timing constants in code.

## The Scene View Shows the Real HUD

The user lays the HUD out in the Scene view and Prefab Mode, so it must look as it does in play:

- **`IEditModePreview`** (`PreviewInEditMode(theme)`, returns whether anything changed): a component
  that can show its rest look outside Play Mode implements it: themed colours and fonts, seals' fill,
  a panel that starts hidden authored visible, droplets hidden. It may only set serialized looks —
  never create material instances, touch services, events or pools. Use `ThemePreview.Tracked(this, …)`
  to report changes; if a runtime `Apply` isn't Edit-safe (it binds meters, creates instances, depends
  on data), preview a hand-picked subset instead.
- **The driver** (`Game.EditorTools.ThemePrefabPreview`) applies previews to the prefabs, widgets
  before the HUDs that nest them, saving only what changed, on every theme edit and from
  **Tools > Chains > Apply Theme to HUD Prefabs**. New UI components with a look get a preview.
- **Sample content**: each pooled list holds a few nested instances of its widget prefab, tagged
  `EditorOnly`, with `EditModeSample` (removes itself on `Awake` in play). Add samples for new lists.
- `AnimatedPanel` hides panels at startup, so author them visible. Use the Hierarchy's eye icons to
  isolate a HUD in the Scene view.

**Verify every change twice.** Edit mode: frame the canvas orthographically in the Scene view and
`capture_scene_view` (it saves under `Assets/`; move the file out and delete the folder). Play mode:
Screen Space - Overlay UI needs `capture_game_view --source screen` or a `ScreenCapture` via the
guarded loop in `../u-cli/recipes-ref.md` §4 — capture every HUD state and pixel-diff it against a
baseline taken before the change. On Metal, `ScreenCapture` itself logs two "memoryless depth
surface" warnings: read the console before capturing. Tests and captures both, before calling it done.

## Events

No `UnityEvent` fields in UI component wiring. Use C# events (ViewModel → View, View → caller) or
`EventBus<T>` (cross-system: theme changes, combat-flow events the UI reacts to).

## Questions to Ask Before Implementing

- Does this need a `ThemeColorAdapter`/`ThemeFontAdapter`, or is it a one-shot theme read
  (`ActiveTheme.Resolve`) instead?
- What's the ViewModel's shape — which properties are `Observable<T>`, what commands does the View
  raise back?
- Is this a `UIScreen` (has its own camera/pose/full-panel lifecycle) or a widget within one?
- Is this a reusable widget that needs a prefab + `UIWidgetPool`? How many pre-warmed?
- Does this panel need enter/exit animation? Which `IPanelTransition`, and which `ThemeConfig` timing
  profile entry backs it?
- **How is this reached with a gamepad?** This project uses no `Selectable`/`EventSystem` focus at
  all — navigation is an index driven by `IInputSource.Navigate`. State the initial index, the wrap
  behaviour, how unusable entries are skipped, and how the highlight survives pooling. See
  [design-ref.md](design-ref.md).
- Is anything anchored to a screen edge? Put it under a `SafeAreaFitter` and keep `ThemeConfig.SafeMargin`.
- `CanvasScaler` is uniform (ScaleWithScreenSize, 1920x1080, match 1: height). Match it, don't diverge.
- Does it have a look? Then it previews in the Scene view (`IEditModePreview`), and a pooled list gets
  samples.

## Continuous Improvement

When the user adds new UI patterns or theme tokens: ask "Should I update this skill file?"
If yes, Read `${CLAUDE_SKILL_DIR}/SKILL.md` and apply the minimal edit.
