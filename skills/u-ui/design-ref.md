# UI Visual Design

`SKILL.md` covers how UI is wired. This covers whether it looks good, and it is a separate
question with separate failure modes.

## Read this first: check for a bug before you critique taste

`BATTLE-SYSTEM.md` §11 says visual polish was "intentionally left simple/functional… real design
work for a later pass," and §17 opens with Phase 7 having "shipped functionally correct but visually
under-baked." The UI is not a failure to correct. It is a deferral.

More useful: when that visual feedback was investigated, it "surfaced two real bugs plus one
architectural mistake rather than pure style opinions."

- "Only one meter is visible" — rows only updated on `GaugeUpdatedEvent`, so a resource that started
  full and had not changed yet rendered at whatever `fillAmount` the prefab was authored with.
- "It doesn't expand fully" — `SetExpanded` scaled the same compact icons up, revealing no new
  information.

Both read as style complaints. Both were bugs. **So the first pass over any visual complaint is
triage, not taste.** Ask whether the thing is initialising, updating, and laying out correctly before
reaching for colour and spacing. In this project that has been the higher-yield question.

## The rubric

Run this against a capture **before** showing the user anything. Order matters.

| # | Question | What it catches |
|---|---|---|
| 1 | **Is it a bug?** | Stale values, uninitialised meters, layouts that don't expand, prefab-default `fillAmount`, widgets bound to the wrong actor, **unassigned icons** (`coc_validate_actors` found all 3 actor definitions missing one) |
| 2 | What reads first, and should it? | Inverted hierarchy — decoration louder than state |
| 3 | What is unreadable at combat speed, or over the worst-case background? | Contrast failures that only appear over bright or busy geometry |
| 4 | What is misaligned, or inconsistent with a sibling widget? | Per-widget literals instead of a shared grid |
| 5 | What is redundant, and what is missing at this game state? | Information that earns no space; state the player needs and can't see |
| 6 | Does this look like *this game*, or like default Unity UI recoloured? | Absence of a design language |

Question 6 is currently unanswerable. See "Deriving the design language" below.

**Run the project verbs before capturing anything.** They answer question 1 in a second, where a
capture costs a Play Mode cycle. All four have already found real defects here:

| Verb | Found |
|---|---|
| `coc_asset_audit` | Every technique, item and ultimate is missing its `icon` |
| `coc_validate_actors` | All 3 `CombatActorDefinition` assets are missing their `icon`; two are missing `kit` |
| `coc_theme_report` | Body, Heading and Mono all resolve to the same font — no typographic hierarchy at all |
| `coc_hud_report` | 12 canvases, 7 of them Screen Space - Overlay, so a capture needs Play Mode |

`coc_missing_refs --filter Panel` came back clean across 20 components, so panel wiring is not the
problem. That is a useful negative: it points the investigation at data, not scene wiring.

**Capturing to run this against:** see `u-cli/recipes-ref.md` §3 and §4. The short version — Screen
Space - Overlay UI is invisible to Edit-mode capture, so any screen-space HUD needs the guarded Play
Mode loop and `capture_game_view --source screen`.

## Three functional gaps, which outrank aesthetics

These are missing from `SKILL.md` entirely, and they are not polish.

**Focus navigation is bespoke here, and that changes the rule.** `coc_hud_report` finds **zero
`Selectable` or `Button` components across all 12 canvases** — this UI does not use Unity's
`EventSystem` focus model at all. Navigation runs through `IInputSource`: `_input.Navigate.y` drives
an index in each screen, with `NavigateRepeatDelay` and `NavigateDeadzone` centralised in
`CombatCameraConfig`. That is a deliberate choice consistent with `u-input`, and generic advice about
`Selectable.navigation` defaults simply does not apply.

What *does* apply, because a bespoke system has to re-earn what `EventSystem` gives you for free:

- **Initial index** on open — stated per screen, not left at whatever the last instance held.
- **Wrap behaviour** at the ends of a list — and it must agree between `ActionListScreen` and
  `TargetSelectScreen`, because inconsistency between two lists in one flow reads as a bug.
- **Skipping unusable entries** — a greyed-out technique the cursor still stops on is a dead step.
- **A visible highlight that survives pooling.** `UIWidgetPool.Rent()` returns a recycled widget; the
  highlight is per-index state, so it must be reapplied at bind time.
- **Nothing reports focus to accessibility tooling.** With no `EventSystem`, there is no selected
  object for anything external to read. Worth knowing before it is a requirement.

**Safe areas.** Notch, rounded-corner and TV overscan insets. Nothing anchored to a screen edge is
safe without reading `Screen.safeArea`. The action queue sits on the left edge and the meter bar on
the bottom, so both are exposed. This one is a real gap — nothing in the project reads `safeArea`.

**Scaling is already consistent — do not "fix" it.** `coc_hud_report` confirms every `CanvasScaler`
is `ScaleWithScreenSize` at 1920x1080 with `matchWidthOrHeight = 0`. The two `EnemyStatusBillboard`
canvases are World Space and correctly have no scaler. The one thing to know: `match = 0` scales by
width alone, so a taller aspect ratio yields more vertical room rather than smaller UI. That is a
defensible choice; just verify bottom-anchored elements at 16:10 and 4:3 before assuming it holds.

Sources: the safe-area and focus framing come from the `game-ui-ux` skill (gamedev-skills),
engine-neutral, absorbed here rather than installed so they land against this project's actual setup —
which, as above, turned out to differ from what the generic guidance assumes.

## Readability rules

- **Hierarchy by urgency.** HP and immediate threats get the strongest contrast and the most stable
  position. Cosmetic readouts get quieter treatment. Hierarchy only works when most elements are
  quiet — if everything is emphasised, nothing is.
- **Never encode critical state in colour alone.** Back it with shape, icon or position. The existing
  mixed shape language is already doing this correctly and is precedent worth keeping: compact
  secondary meters are radial (`Image.fillMethod = Radial360`), HP and every expanded meter is
  linear. Shape carries the distinction, not just hue.
- **Check contrast against the worst case, not the average.** A HUD over a moving 3D field meets a
  bright sky and a dark interior in the same session. Consistent backing treatment beats per-panel
  tuning. The `dataviz` skill (first-party, already available) has a runnable contrast validator, and
  an HP bar is a stat tile in every respect that matters — invoke it rather than eyeballing ratios.
- **Spacing and alignment from a grid in `ThemeConfig`**, never per-widget literals. Two widgets that
  disagree by 3px are a tell that both authored their own spacing.
- **Motion confirms state change.** It does not decorate. Through `IPanelTransition` and the
  `ThemeConfig` timing profile, never a hardcoded duration. The Phase 7 tween work is the model:
  `fillAmount` tweens from its previous value and flashes toward `Success`/`Danger` on a change,
  contained inside the swappable `IGaugeMeterVisual` so restyling a slot cannot lose the behaviour.

## Deriving the design language

The rules above stop UI being bad. They do not make it *yours*. What separates the reference games
from merely competent UI is a method, and it is the same method in all three:

**The interface is derived from the game's fiction rather than applied on top of it.** Persona 5's
phantom-thief premise produces ransom-note cut-out typography, a red/black/white restriction and
aggressive diagonals. Metaphor's lead UI designer Koji Ise treated every element as narrative art,
with paint splatters standing for emotional turmoil and geometric lines for the protagonist's
thinking, and transitions shifting as the character grows. Clair Obscur takes its name from the
light-and-shadow technique and builds an interface whose contrast *is* the theme.

### The procedure

1. Read the fiction. Name the two or three motifs that actually carry it.
2. Derive, in this order, from those motifs: **shape language** (what a panel edge does), **palette
   restriction** (how few colours, and which one means danger), **typographic treatment**, **motion
   vocabulary** (what entering and leaving look like), **texture**.
3. Write it down using the schema below.
4. Express it as a populated `ThemeConfig` asset plus an `IPanelTransition` set. Not per-widget
   literals — the architecture already supports the whole game restyling from one SO, and that
   machinery is currently holding placeholder values.
5. Capture, run the rubric, revise.

### Blocked: the fiction does not exist yet

`draft.txt` is 1109 words of pure mechanics with no setting, tone or lore. `party-members.md` has 14
`TBD` entries and its three archetypes (Berserker, Mage, Summoner) carry mechanics only. **There is
currently nothing to derive a design language from.**

Do not invent one. An invented motif produces a confident-looking interface that contradicts the game
once the fiction is written, and that is more expensive to undo than to defer. Ask for the setting,
tone and the meaning of the title's two nouns before running step 1.

### The schema to write it in

Adapted from `ui-ux-pro-max`'s `styles.csv` column structure, which is a good shape for recording a
visual style in a form an agent can act on. Its *content* is web-locked and useless here — Tailwind
classes, Google Fonts URLs, SaaS palettes — but the columns transfer:

| Field | Meaning here |
|---|---|
| Keywords | The motifs, in the game's own words |
| Primary / Secondary | `ThemeColorToken` values, not hex literals |
| Effects & Animation | Which `IPanelTransition` implementations, which `ThemeConfig` easing |
| Best for | Which screens this treatment belongs on |
| **Do not use for** | The exclusions — the most load-bearing column, and the one usually skipped |
| Implementation checklist | Concrete steps to apply it |
| Design system variables | The `ThemeConfig` fields this populates |

### Techniques worth stealing, once there is a language to apply them to

| Technique | Source | How it lands here |
|---|---|---|
| Line-of-sight guidance: a drawn line and changed angles steer the eye through a busy layout | P5 | The diamond and action-queue reading order, currently unconsidered |
| Lighting as hierarchy: high-priority regions bright, low-priority dimmed | P5 | `ThemeColorToken` surface tokens and panel alpha, not literal lights |
| Severe palette restriction as identity | P5, Metaphor | A deliberately small token set beats a large one. Restriction is the effect |
| Motion as signature: overshoot, slide, choreographed entry | P5, Metaphor | `IPanelTransition` + `ThemeConfig` easing already support this |
| Texture as theme carrier (halftone, paint, ink, patina) | all three | Sprite treatment on backing panels. Cheap, and the highest style-per-effort item |
| Contrast as literal subject matter | Clair Obscur | Light-on-dark discipline that doubles as readability over a 3D field |

### The counterweight

Atlus's own UI designer has said publicly that the menus can be overstimulating and that
accessibility options are something they know they need to provide. Clair Obscur's interface draws
real complaints too. **Strong style is not a licence to cost readability.** P5's answer was not
restraint, it was explicit craft: the line-of-sight and lighting techniques exist precisely to keep a
loud layout legible. Both halves, or neither.

## Related

- `u-cli/recipes-ref.md` §3, §4 — how to capture what you are critiquing
- `dataviz` (first-party skill) — meter and stat-tile guidance, contrast validator
- `../../vendor/unity/optimize-text-mesh-pro/` — TMP font stacks, SDF, AutoSize discipline
- `../../vendor/unity/urp-postprocessing/` — Volume framework, for the look the HUD sits on top of
