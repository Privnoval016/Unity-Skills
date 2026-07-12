---
description: >
  Modular Unity UI system. ThemeConfig SO with semantic tokens, theme adapter components that
  auto-apply colors/fonts/animation, per-component style SOs, PrimeTween animation from a
  centralized style guide. Changing the entire UI theme means changing one SO.
when_to_use: >
  Building or reviewing any Unity UI, questions about "theme", "style guide", "ThemeConfig",
  "ThemeColorAdapter", "color tokens", "font", "PrimeTween", "UI animation", "Canvas".
allowed-tools: Read Edit Write AskUserQuestion
---

## Overview

UI must be modular and theme-driven. Changing the visual style of the entire game should require
changing one SO — no scene edits, no hunting through individual components.

## ThemeConfig SO (Global Style Authority)

```csharp
[CreateAssetMenu(menuName = "UI/ThemeConfig")]
public class ThemeConfig : ScriptableObject
{
    [Header("Colors")]
    [Tooltip("Primary brand color.")]          public Color PrimaryColor;
    [Tooltip("Secondary accent color.")]        public Color AccentColor;
    [Tooltip("Main text color.")]               public Color TextColor;
    [Tooltip("Panel / card background.")]       public Color BackgroundColor;
    [Tooltip("Danger / destructive action.")]   public Color DangerColor;
    [Tooltip("Success / confirm action.")]      public Color SuccessColor;

    [Header("Typography")]
    [Tooltip("Default body font asset.")]       public TMP_FontAsset BodyFont;
    [Tooltip("Heading / display font asset.")]  public TMP_FontAsset HeadingFont;
    [Tooltip("Monospace / code font asset.")]   public TMP_FontAsset MonoFont;

    [Header("Animation Profile")]
    [Tooltip("Panel enter/exit duration.")]     public float PanelTransitionDuration = 0.25f;
    [Tooltip("Panel transition ease.")]         public Ease PanelTransitionEase = Ease.OutCubic;
    [Tooltip("Button press scale factor.")]     public float ButtonPressScale = 0.92f;
    [Tooltip("Button press duration.")]         public float ButtonPressDuration = 0.08f;
    [Tooltip("Tooltip fade-in duration.")]      public float TooltipFadeDuration = 0.15f;
    [Tooltip("Generic fade duration.")]         public float FadeDuration = 0.2f;
    [Tooltip("Generic fade ease.")]             public Ease FadeEase = Ease.OutSine;
}
```

One `ThemeConfig.asset` per visual theme (Light, Dark, custom skins).
Switch themes at runtime by swapping the active SO — all adapters refresh automatically.

Raise an `EventBus<ThemeChangedEvent>` when the active theme changes so adapters can refresh.

## Per-Component Style SOs

Each reusable widget has a `StyleConfig` SO referencing ThemeConfig tokens:

```csharp
[CreateAssetMenu(menuName = "UI/ButtonStyleConfig")]
public class ButtonStyleConfig : ScriptableObject
{
    [Tooltip("Which ThemeConfig color slot to use for the background.")]
    public ThemeColorToken BackgroundToken = ThemeColorToken.Primary;
    [Tooltip("Which ThemeConfig color slot for the label text.")]
    public ThemeColorToken LabelToken = ThemeColorToken.TextOnPrimary;
    [Tooltip("Sprite for button background.")]
    public Sprite BackgroundSprite;
}
```

This allows "danger button" and "primary button" variants to share a prefab with different style SOs.

## Theme Adapter Components

Attach to any UI element. Inspector-driven — pick a token, forget about raw colors.

```csharp
/** <summary>Applies a ThemeConfig color token to a Graphic component automatically.</summary> */
[RequireComponent(typeof(Graphic))]
public class ThemeColorAdapter : MonoBehaviour
{
    [Tooltip("ThemeConfig asset providing the active palette.")]
    [SerializeField] private ThemeConfig themeConfig;
    [Tooltip("Which semantic color token to apply to this Graphic.")]
    [SerializeField] private ThemeColorToken token;

    private Graphic _graphic;

    #region MonoBehaviour Callbacks

    private void Awake()
    {
        _graphic = GetComponent<Graphic>();
        ApplyToken();
    }

    private void OnEnable()
    {
        EventBus<ThemeChangedEvent>.Register(_onThemeChanged);
    }

    private void OnDisable()
    {
        EventBus<ThemeChangedEvent>.Deregister(_onThemeChanged);
    }

    #endregion

    #region Event Handlers

    private readonly EventBinding<ThemeChangedEvent> _onThemeChanged =
        new EventBinding<ThemeChangedEvent>(() => ApplyToken());

    #endregion

    #region Helpers

    private void ApplyToken()
    {
        _graphic.color = themeConfig.GetColor(token);
    }

    #endregion
}
```

**Similarly**: `ThemeFontAdapter` — binds TMP_FontAsset from ThemeConfig.
**Similarly**: `ThemeAnimAdapter` — exposes PrimeTween duration/ease from the animation profile.

Every adapter subscribes to `ThemeChangedEvent` so swapping ThemeConfig propagates instantly.

## Visibility

Enable/disable the `Canvas` component, NOT the GameObject. Disabling the GameObject destroys the
layout and re-triggers the entire layout rebuild on re-enable. `canvas.enabled = false` hides
rendering without touching layout.

## Animation Rules

- PrimeTween for ALL UI animation. No Animator controllers for UI.
- Duration and easing values always come from `ThemeConfig` — never hardcoded in scripts.
- Async sequences use UniTask. No coroutines for UI tweens.

```csharp
// Correct
await PrimeTween.Tween.Alpha(canvasGroup, 0f, 1f,
    _theme.FadeDuration, _theme.FadeEase);

// Wrong — hardcoded values
await PrimeTween.Tween.Alpha(canvasGroup, 0f, 1f, 0.2f, Ease.OutSine);
```

## Instantiation & Pooling

- NO runtime `Instantiate` for UI elements. Pre-instantiate in the scene hierarchy.
- For dynamic lists (inventory slots, leaderboard rows): use object pooling with pre-warmed items.

## Prefab-Based Components

Every reusable widget is a prefab. Style changes to the prefab propagate to every usage.
Canvas batching: elements that animate frequently should live on their own sub-Canvas.

## Events

No `UnityEvent` fields in UI component wiring. Use C# events or `EventBus<T>`.

## Questions to Ask Before Implementing

- Does this need a ThemeColorAdapter, ThemeFontAdapter, or ThemeAnimAdapter?
- Are there variant states (hover, pressed, disabled) — how do they map to ThemeConfig tokens?
- Is this a reusable widget that needs a prefab + style SO?
- Is there a dynamic list? Pre-pool how many items?
- Does this panel need enter/exit animation? Which ThemeConfig animation profile entry?

## Continuous Improvement

When the user adds new UI patterns or theme tokens: ask "Should I update this skill file?"
If yes, Read `${CLAUDE_SKILL_DIR}/SKILL.md` and apply the minimal edit.
