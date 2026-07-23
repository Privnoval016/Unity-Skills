---
description: >
  Modular Unity UI system. ThemeConfig SO + central IThemeProvider driving theme adapters, an MVVM
  binding layer (Observable<T> / ViewModelBase / View<T>), a UINavigationHost screen stack built on
  Extensions.PushdownAutomata, injectable IPanelTransition animations via PrimeTween, and pooled
  widgets. Changing the entire UI theme means changing one SO; changing a widget's animation means
  swapping one field.
when_to_use: >
  Building or reviewing any Unity UI, questions about "theme", "ThemeConfig", "ThemeColorAdapter",
  "color tokens", "ViewModel", "Observable", "UINavigationHost", "UIScreen", "PanelTransition",
  "PrimeTween", "UI animation", "Canvas", "widget pool".
allowed-tools: Read Edit Write AskUserQuestion
---

## Overview

UI must be modular, theme-driven, and MVVM-bound. Changing the visual style of the entire game
requires changing one SO — no scene edits, no hunting through individual components. Changing a
widget's animation requires swapping one field. This is the architecture actually implemented under
`Assets/Game/UI/` — read the real files there before assuming a signature; this doc summarizes intent.

## Theme System (`Assets/Game/UI/Theme/`)

**`ThemeConfig`** (SO, `[CreateAssetMenu(menuName = "Game/UI/Theme Config")]`) is the global style
authority: semantic colors via `GetColor(ThemeColorToken)`, fonts via `GetFont(ThemeFontRole)`, and
the animation profile (`PanelTransitionDuration`/`Ease`, `FadeDuration`/`Ease`, button press
scale/duration, tooltip fade). One `.asset` per visual theme.

**`ThemeColorToken`** / **`ThemeFontRole`** are the semantic slots (`Primary`, `Accent`, `Surface`,
`TextPrimary`, `Danger`, …) — components reference a token, never a raw `Color`/`TMP_FontAsset`.

**`IThemeProvider` / `ThemeService`** is the single source of truth for the *active* theme, registered
via the project's `Services` locator (not a per-adapter serialized reference — that breaks the moment
you swap to a genuinely different theme asset, and never reaches a widget pooled in after the swap).
`ThemeService.SetActive(theme)` swaps it and raises `ThemeChangedEvent` on `EventBus<T>`.

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
`FadeScaleTransition` (fade + scale-up from a configurable start scale), `SlideTransition` (fade + slide
from an anchored-position offset). Every implementation reads its timing/ease from the passed
`ThemeConfig` — never a hardcoded literal.

**`AnimatedPanel`** ties a transition to visibility: `ShowAsync()` enables the `Canvas` then plays the
enter transition; `HideAsync()` plays the exit transition then disables the `Canvas`. **Visibility is
always `Canvas.enabled`, never the GameObject** — disabling the GameObject destroys layout and forces a
full rebuild on re-enable.

**A move/scale transition never animates the Canvas's own RectTransform — always a child.** A root
Screen Space canvas has its RectTransform forcibly resized/repositioned by Unity every frame to fill
the screen; any script change to it gets overridden on the next layout pass, so `FadeScaleTransition`/
`SlideTransition` silently don't work if pointed at it. `AnimatedPanel` requires only `Canvas` +
`CanvasGroup` on its own GameObject (both safe to touch directly — `enabled` and `alpha` aren't layout
properties) and a separate serialized `Content` field pointing at a child `RectTransform`, which is
what transitions actually move/scale. `FadeTransition` (alpha-only) doesn't need `Content` at all.

```csharp
// Correct — PrimeTween's Tween/Sequence are directly awaitable
await Tween.Alpha(canvasGroup, 0f, 1f, theme.FadeDuration, theme.FadeEase);
await Sequence.Create(Tween.Alpha(cg, 0f, 1f, d, e)).Group(Tween.Scale(rt, Vector3.one, d, e));

// Wrong — hardcoded values instead of ThemeConfig
await Tween.Alpha(canvasGroup, 0f, 1f, 0.2f, Ease.OutSine);
```

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

## Prefab-Based Components

Every reusable widget is a prefab (View + optional `AnimatedPanel` + theme adapters), bound to an
element ViewModel at rent time. Style changes to the prefab propagate to every usage. Elements that
animate frequently should live on their own sub-Canvas (batching). **Scene/prefab assembly is the
designer's job** — provide components and clear wiring instructions, don't script the Canvas hierarchy
together.

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

## Continuous Improvement

When the user adds new UI patterns or theme tokens: ask "Should I update this skill file?"
If yes, Read `${CLAUDE_SKILL_DIR}/SKILL.md` and apply the minimal edit.
