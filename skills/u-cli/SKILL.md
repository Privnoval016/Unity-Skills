---
description: >
  How to drive the live Unity Editor through the Unity CLI (`unity` on PATH) and the
  `com.unity.pipeline` package — scene/prefab/ScriptableObject inspection and editing, screenshots
  of the Game and Scene view, console and compile status, tests, semantic scene diffs, and
  project-specific `[CliCommand]` verbs. Replaces the old MCP-server workflow. Carries the session
  gate, the approval model, and the guarded Play Mode loop.
when_to_use: >
  Any task touching the actual Unity Editor — inspecting or wiring scene objects, editing prefabs or
  SO assets, checking why a serialized field looks wrong, seeing what the UI actually renders,
  reading the console, running tests, diffing a .unity or .prefab file, or verifying that a change
  compiled. Not for writing .cs files (plain Read/Edit) and not for real play-testing (still the
  user's job — see Hard Rules).
allowed-tools: Read Grep Bash AskUserQuestion
---

## Overview

The Unity CLI is a standalone binary (`unity`) that drives the running Editor through the
`com.unity.pipeline` package — a localhost-only HTTP server the Editor hosts. It replaces the
Coplay/UnityMCP server entirely. Bash calls, no MCP server: an MCP server pays for its tool schemas
on every request whether or not the Editor gets touched, and Unity's own migration guidance is that
the CLI costs fewer tokens for the same work.

The catalog is **self-describing**. `unity command` with no argument lists what this Editor actually
exposes, so ask the tool rather than trusting a written list. [commands-ref.md](commands-ref.md)
groups the catalog and records the pitfalls carried over from the MCP era;
[recipes-ref.md](recipes-ref.md) has the loops worth running verbatim.

Vendored reference: `../../vendor/unity/unity-cli/` (Unity's own CLI skill, 9 reference files).
Verified against CLI `1.0.0-beta.8` and `com.unity.pipeline` `0.7.0-exp.1`. Both are pre-release —
if a command's shape disagrees with what is written here, the live catalog wins.

## Session Gate

**Before the first *mutating* Editor command in a session, ask once via `AskUserQuestion` whether to
drive the Editor live.** Carry that answer for the rest of the session; don't re-ask per command.
Reads never need the gate.

The `SessionStart` hook injects `unity status` and `unity pipeline list` output, so the Editor's
state is already known before asking. If no Editor is connected, say so rather than asking a
question whose answer can't be acted on.

## Hard Rules

1. **Inspect freely, no approval needed.** `unity status`, `unity command` (listing), `find_gameobjects`,
   `get_scene_hierarchy`, `get_component_properties`, `get_serialized_fields`, console reads,
   `capture_*`, `unity vcs diff`/`status`/`affected`, `unity test`. None of these change state.
2. **Preview before mutating.** Any command exposing `dry_run` runs with `dry_run: true` first, and
   **the returned preview is what gets shown for approval** — not a description written from memory.
   Then one approval covers the whole batch. Re-ask if the batch changes mid-flight.
3. **Commands without a `dry_run` gate** (most `set_*`, `create_*`) get the batch described in full
   before running: which objects, which fields, old value → new value.
4. **Use `batch` for multi-step mutation**, not a sequence of individual calls. It is transactional,
   collapses to one Undo step, reverts everything if any op fails, and takes `dry_run` for the whole
   set. 30 of the 151 commands require `confirm: true`; 43 accept `dry_run`.
5. **Report by name, never by instance ID.** Every user-facing sentence uses the GameObject name and
   hierarchy path, or the asset path — "set `ActionQueueHUD/Panel`'s `AnimatedPanel.content` to
   `Panel` (was `None`)", never `set_property(target=-235870, …)`. IDs are fine as tool arguments.
6. **Re-read after every write that matters.** A success return has previously come back on a no-op.
   Confirm the value actually landed before reporting it.
7. **Play Mode is guarded, not free.** See below. Real play-testing stays the user's job.
8. **Never `--force` a package or settings change** the user hasn't asked for. Asset, settings and
   UPM writes bypass Unity's Undo and are permanent; only scene/object edits are undoable.

## Guarded Play Mode

The old rule banned Play Mode outright after an incident where the Editor both froze while unfocused
*and* error-looped with NullReferenceExceptions. `set_autotick` fixes the first. **Nothing fixes the
second**, so this loop is built to detect and abort rather than to trust:

1. `console_status` — snapshot `groundTruth.consoleErrors`. **Do not require zero.** This project
   carries a benign pre-existing error (Odin's `ProjectWatcher` against Unity 6000.5), so a
   zero-errors precondition blocks Play Mode forever. Abort only if the count *rises*.
2. `editor_focus`. **Play Mode only advances with OS focus.** `set_autotick` keeps the *Editor*
   ticking but was verified (2026-09-23) *not* to advance the Play Mode player loop: `frameCount`
   stayed at 2 for six seconds until `editor_focus`. Focusing takes focus from the user's terminal;
   say so when you do it.
3. `editor_play`, then poll `editor_status` against a declared wall-clock timeout.
4. **Abort on any of:** timeout reached, frame count not advancing between polls, or the error count
   rising above the snapshot. Abort means `editor_stop` immediately, then the console tail to the user.
   Prefer `wait_for` with `on_met.capture` over a manual poll loop — it fires in the same editor frame
   the condition first holds, so the capture is of the exact moment.
5. On success: capture, then `editor_stop`. Always leave the Editor out of Play Mode.

Never simulate input, never drive a gameplay sequence longer than the declared timeout, and never
leave Play Mode running at the end of a turn. Anything needing real play-testing is the user's.

**Run the loop with [scripts/guarded-capture.sh](scripts/guarded-capture.sh)** rather than by hand:
`guarded-capture.sh Temp/shot.png <wait-seconds> [setup command]`. It implements every guard above,
captures through `ScreenCapture.CaptureScreenshot` into gitignored `Temp/` (overlay UI included, and
no megabyte of base64 dumped into context), and always stops Play Mode.

**Modal dialogs block everything.** A native dialog (for example Cinemachine's "Save changes made in
Play Mode") holds the main thread; every main-thread command then times out, including
`editor_status`. If commands start timing out right after `editor_stop`, suspect a dialog and ask
the user to dismiss it. Cinemachine's Save During Play is a per-machine EditorPref
(`SaveDuringPlay_Enabled`); keep it off, because it also writes runtime camera changes back into the
scene.

**Why Play Mode is unavoidable for UI work:** neither `capture_game_view --source camera` nor
`screenshot --view game` includes Screen Space - Overlay UI in Edit mode — verified empirically on
Playground, both returned the 3D scene with no HUD at all. `capture_game_view --source screen` does
include overlay canvases and requires Play Mode. World Space canvases capture fine in Edit mode.
Check the canvas's `RenderMode` before deciding which path a task needs.

**Where captures go.** Use `screenshot --output <path>` when you want a file: its path is
project-root-relative or absolute and defaults to `Temp/pipeline-screenshots/`, which is gitignored
and outside `Assets/`. **`capture_*`'s `save_path` is Assets-relative**, so it writes into the project,
Unity imports it, and a `.meta` appears — use `capture_*` without `save_path` (inline base64) instead.

## Project Commands

Projects register their own verbs with `[CliCommand]` on a static method. They are auto-discovered
via `TypeCache` and appear in `unity command` after a recompile. Four rules keep them alive:

- **Discover, don't hardcode.** Before building Editor work out of primitives, run
  `unity command --tag <project-tag> --format json`. The registry is the catalog; a hand-written list
  drifts the first time a command is renamed.
- **Tag everything.** `Tags = new[] { "<project>/<area>" }` so one filter finds the whole set.
- **Prefer the project verb** over reassembling the same primitive sequence. The verb already encodes
  the right ordering and cleanup.
- **Promote on repetition.** When a primitive sequence runs a third time, or a plan step names a
  sequence with no verb, stop and propose a new `[CliCommand]`. This is what makes the set compound
  instead of freezing at whatever shipped first.

### This project's verbs, and when to reach for each

Discover with `unity command --tag coc --format json`. Never assume this table is current.

| Verb | Reach for it when | Skill that expects it |
|---|---|---|
| `coc_missing_refs` | Anything is "not showing up", wired wrong, or a NullReference appears. Scans open scenes for null object-reference fields. `--filter <TypeName>` narrows it | `u-review`, `u-plan` |
| `coc_asset_audit` | Before trusting any ScriptableObject-driven feature. `--type ActionDefinitionSO` etc., or omit for everything under Game/Players/Battle | `u-review` |
| `coc_validate_actors` | Combat or party work — checks identity fields and gauge maxima on every `CombatActorDefinition` | `u-review` |
| `coc_hud_report` | Any UI task. Canvas render modes (tells you whether Play Mode is needed to capture), scaler config, navigation coverage | `u-ui/design-ref.md` |
| `coc_battle_debug` | Play Mode: starting a fight without playing. `--start neutral\|first\|caught` starts one the way F5–F7 do; `--start join` sends the nearest outside hostile into the fight under way | `u-plan` |
| `coc_battle_probe` | Play Mode: "what state is the fight in?" Context, roster (positions, bounds, gauges), boundary, live camera and every rig's priority, blend, time scale, HUD beats seen | `u-review` |
| `coc_battle_capture` | Play Mode: a probe JSON (and, unless `--shots false`, a Game view frame) per frame under `Temp/`, optionally starting a fight first. Frames at 4K slow the game; use `--shots false` when timing matters | `u-ui/design-ref.md` |
| `coc_theme_report` | Any visual work. Resolves `ThemeConfig` tokens, fonts and timings to concrete values so you can see what the theme actually says | `u-ui/design-ref.md` |

**Run the cheap ones before the expensive ones.** `coc_missing_refs` and `coc_asset_audit` answer
"is this a bug?" without entering Play Mode, and that is the first question in `design-ref.md`'s
rubric. A capture costs a Play Mode cycle; these cost a second.

### Authoring a new verb

Editor assembly, `u-style` throughout, tagged `coc/<area>`. Available after the next recompile — no
registration call.

**Compile it outside `Assets/` first.** Write to `Temp/<scratch>/`, run
`unity command run_script --file <path> --dry_run true`, and only copy into `Assets/Editor/` once it
returns zero diagnostics. A broken `.cs` under `Assets/` drops the Editor into Safe Mode, which kills
the Pipeline server and every command with it.

**`run_script --dry_run` does not validate asmdef references.** It compiles against every loaded
assembly, so a file that passes there can still fail in the project when its `.asmdef` is missing a
reference. Expect one more round of `recompile` → `console --since <cursor>` after copying in. Take
the cursor from `console_status` *before* recompiling so you read only new errors, not the standing
ones.

## Workflow

1. **Check readiness.** `unity pipeline list --format json`. Confirm `hasPipelinePackage` and
   `pipelineServer.isReachable`. If `safeMode` is true, the project has compile errors and the
   package isn't loaded — fix those first; don't fall back to blind file editing.
2. **Not reachable but package present?** The Editor hasn't resolved the manifest. It resolves on
   window focus. Ask the user to focus it; this cannot be forced from outside.
3. **Discover.** `unity command --format json` for the catalog, filtered by `--tag` or `--query`.
4. **Read before writing.** Answer questions with reads; don't call a mutating command to learn
   something a read already tells you.
5. **Verify.** Every change ends with the loop in [recipes-ref.md](recipes-ref.md): `recompile_status`
   → console → the relevant test filter → a capture if it's visual. A change that isn't verified
   isn't done.
6. **Report** by name, with what was checked and what the check returned.

## Continuous Improvement

When the user gives new CLI-workflow preferences or corrects an approach that should apply
permanently: ask "Should I update this skill file for future sessions?" If yes, Read
`${CLAUDE_SKILL_DIR}/SKILL.md` (and `commands-ref.md` if it's catalog- or pitfall-related), propose
the minimal edit, and apply it.
