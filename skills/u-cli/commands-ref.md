# Command Catalog & Pitfalls

**Generated from the live Editor**, not from documentation: `unity command --format json` against
Chains-Of-Contract on CLI `1.0.0-beta.8` / `com.unity.pipeline` `0.7.0-exp.1`, Unity `6000.5.3f1`.
**151 commands** — the published docs said ~120 and had several names wrong, which is why this file
is generated rather than transcribed.

**Always re-dump before trusting this file.** The registry is the ground truth:

```bash
unity command --format json                 # everything
unity command --query capture --format json # filter by substring
unity command --tag scenes --format json    # filter by tag subtree
```

`unity command <name> --help` is not a thing; get a command's parameters from the catalog's
`parameters` array. **Parameter names are validated and the CLI errors clearly** when you guess
wrong (`delete_asset has no parameter --path` — it's `--asset`). Read the schema, don't infer from
the name.

## Safety surface

Of 151 commands: **30 require `confirm=true`** and **43 accept `dry_run=true`**. The convention:

- `dry_run: true` validates and previews, changing nothing. It takes precedence over `confirm`.
- `confirm: false` (the default) on a destructive command **refuses to run**. This is a real gate,
  not advisory.
- Scene and object mutations are wrapped in `AuthoringUndoScope` — one Undo step.
- **Asset, settings and UPM writes bypass Undo entirely and are permanent.** No Ctrl-Z.

Per `u-cli`'s rules: run `dry_run` first where it exists and show *that output* for approval.

## `batch` — the right primitive for multi-step mutation

Don't fire ten `set_component_properties` calls. `batch` runs up to 200 operations in one
transactional request:

- `transactional: true` (default) groups everything into **one Undo step** and reverts every applied
  op if any op fails.
- `dry_run: true` validates command names, parameters and reference topology without mutating.
- Later ops reference earlier results: `"$0.instanceId"`, `"$myId.guid"` (`$$` escapes a literal `$`).
- `on_error: abort | continue`.
- `result_fields` projects each op's result down to the fields you need — real context economy on a
  large batch.

This maps exactly onto the one-approval-per-batch rule: the batch *is* the transaction.

## `wait_for` — condition, then act in the same frame

Better than a poll loop, and the right tool for capturing a specific game state:

```bash
unity command wait_for \
  --condition '{"member":"Game.Encounter.EncounterDirector.IsRunning","op":"eq","value":true}' \
  --timeout_s 30 \
  --on_met '{"capture":{"view":"game","source":"screen"}}'
```

`on_met` runs **in the same editor frame the condition first holds**, so the capture is of the exact
moment, not "some frames later". Use `async: true` for long waits (returns a `wait_id`, poll
`wait_status`). Sync waits hold the exec queue, so anything the condition depends on is blocked
behind it — keep them short or go async.

## Pitfalls

Carried forward from the MCP era plus what this migration found. Each was learned the expensive way.

1. **`save_path` is Assets-relative, not project-relative.** `--save_path "Temp/foo.png"` writes to
   `Assets/Temp/foo.png`, Unity imports it, and a `.meta` file appears next to it. Captures written
   this way land in source control. **Prefer no `save_path`** — the image comes back inline as base64
   by default — or delete afterwards with `delete_asset --asset <path> --confirm true`. Path
   confinement (`ProjectPaths.Resolve`) blocks `..` and is why the root cannot be escaped.
2. **`include_inline_image` only matters when `save_path` is set.** With no `save_path` the image is
   returned inline already. Passing `--include_inline_image true` alone is a no-op, not a fix.
3. **`source=camera` does not capture Screen Space - Overlay UI.** Verified empirically on
   Playground: the capture showed the 3D scene and no HUD whatsoever. `source=screen` includes
   overlay canvases and **requires Play Mode**. Check `RenderMode` before choosing.
4. **Do not require a clean console before Play Mode; require a *stable* one.** This project carries
   a pre-existing benign error (`MissingMethodException` from Odin's `ProjectWatcher` against Unity
   6000.5's `HierarchyProperty` ctor). A zero-errors precondition would block Play Mode permanently.
   Snapshot `console_status.groundTruth.consoleErrors` and abort only if it **rises**.
5. **`console_status` before `console`.** It returns the compile-failure flag and error/warn counts
   without pulling entries — cheap enough to poll. Pull entries with `console --level error --tail n`
   only once you know there is something to read. Follow with the `since` cursor rather than
   re-reading the tail.
6. **`run_tests` modes are `all | editor | playmode`**, not `EditMode`/`PlayMode`. The standalone
   `unity test --mode` *does* take `EditMode`/`PlayMode`. The two spellings are not interchangeable.
7. **Safe Mode makes everything fail to connect.** Compile errors boot the Editor into Safe Mode,
   where the Pipeline package doesn't load — `unity command`, `status` and `list` all fail. Check
   `unity pipeline list` for `safeMode: true` before concluding the Editor is down, and never fall
   back to blind file editing.
8. **The Editor resolves a manifest change only on window focus.** After `unity pipeline install` the
   package sits in `manifest.json` unresolved, `Library/PackageCache` has nothing, and the server
   never starts. This cannot be forced from outside — `set_autotick` needs the very server that is
   waiting. Ask the user to focus the Editor.
9. **`eval` does not accept top-level `using` statements.** Use fully-qualified type names. Prefer
   `run_script` for anything non-trivial: it compiles a real file with no domain reload, supports
   `dry_run` for compile-only diagnostics, and gives proper stack traces with `pdb: true`.
10. **A success return is not proof the value landed.** `set_property` has previously reported
    `success: true` on a no-op. Re-read anything that matters.
11. **GameObject IDs and Component IDs are different numeric namespaces.** A serialized reference
    field's reported `instanceID` may be the *referenced component's own* ID, not its GameObject's.
    Querying a GameObject endpoint with a component ID fails in a way that reads like "this
    reference is broken." Check the owner's component listing before concluding anything is wrong.
12. **`set_autotick` does not keep Play Mode running without focus.** Verified 2026-09-23: with
    autotick on and the Editor unfocused, `Time.frameCount` stayed at 2. `editor_focus` fixed it
    immediately. (`PlayerSettings.runInBackground` is false in this project.)
13. **Modal dialogs block the pipeline.** Main-thread commands time out while any native dialog is
    open. Cinemachine's Save During Play dialog appears on every Play Mode exit when its EditorPref
    is on.
14. **`run_tests` result keys differ by mode.** Synchronous runs return `Summary`/`Results`;
    `test_status` for async runs returns `summary`/`results`. Parse both.
15. **A domain reload during an async test run can hang it** (`status: running` forever, main-thread
    commands timing out). `cancel_tests`, then rerun synchronously. Don't save assets or recompile
    while tests are in flight.
16. **Play Mode has genuinely hung this Editor**, not merely throttled it — an error loop, separate
    from the unfocused-throttling problem `set_autotick` solves. This is why the guarded loop detects
    and aborts rather than trusting.
17. **Save open scenes before `run_tests`.** A dirty scene makes the test runner raise a modal save
    dialog, which blocks every main-thread command until a human clicks it; the run just times out.
    `eval --code 'UnityEditor.SceneManagement.EditorSceneManager.SaveOpenScenes(); return 0;'` first.
18. **A stack overflow in test or `run_script` code kills the Editor outright** (Mono cannot recover).
    After any crash, read the newest `~/Library/Logs/DiagnosticReports/Unity-*.ips` and the tail of the
    project's `Logs/Editor-prev.log` (the last test started) before running anything again.

## Catalog

### gameobjects (14)

- `add_component` — Add a component (by type name) to a GameObject
- `create_gameobject` — Create an empty GameObject or a built-in primitive (cube/sphere/capsule/cylinder/plane/quad) in the activ
- `create_gameobjects` — Batch-create N empty GameObjects or primitives in one call
- `delete_gameobject` — Delete a GameObject from the scene (reversible via Undo)
- `find_gameobjects` — Find GameObjects in loaded scenes by name, tag, component type, and/or hierarchy path (filters are combin
- `get_component_properties` — Get a component's serialized properties as a JSON map
- `remove_component` — Remove a component from a GameObject
- `rename_gameobject` — Rename a GameObject
- `set_active` — Set a GameObject's active self-state (activeSelf)
- `set_component_properties` — Set serialized properties on a component (one Undo step)
- `set_layer` — Set a GameObject's layer by name or numeric index (0-31)
- `set_parent` — Reparent a GameObject under a new parent, or detach it to scene root when no parent is given
- `set_tag` — Set a GameObject's tag (the tag must already exist in the project)
- `set_transform` — Set a GameObject's local position/rotation(euler)/scale

### scenes (9)

- `add_scene_to_build` — Add a scene to the Build Settings scene list (idempotent)
- `create_scene` — Create a new scene and save it to the given path under the authoring root
- `get_scene_hierarchy` — Return the GameObject tree of an open scene (or the active scene)
- `list_open_scenes` — List all currently open scenes with their load/active/dirty state
- `open_scene` — Open an existing scene from the given path
- `remove_scene_from_build` — Remove a scene from the Build Settings scene list (idempotent)
- `save_all` — Save all open scenes that have unsaved changes
- `save_scene` — Save an open scene
- `set_active_scene` — Set which open scene is the active scene (new objects are created in the active scene)

### prefabs (7)

- `apply_prefab_overrides` — Apply a prefab instance's overrides back to its source prefab asset
- `create_prefab` — Save a GameObject as a prefab asset at a project path; the source becomes a connected instance
- `create_prefab_variant` — Create a prefab variant asset that inherits from a base prefab
- `instantiate_prefab` — Instantiate a prefab asset into a loaded scene and return the created instance
- `revert_prefab_overrides` — Revert a prefab instance's overrides so it matches its source prefab asset
- `save_prefab_contents` — Open a prefab asset in an isolated prefab stage, apply a declarative edit, and save it back (nested-prefa
- `unpack_prefab` — Unpack a prefab instance into plain GameObjects (outermost level or completely)

### scripts (12)

- `attach_script` — Add a MonoBehaviour to a GameObject by its (compiled) type name OR by its script asset path
- `create_script` — Create a new C# script (default base class MonoBehaviour) from a template under the authoring root
- `eval` — Evaluate C# code dynamically using Roslyn compiler
- `eval_file` — Evaluate C# code read from a
- `get_serialized_fields` — Read serialized fields of a component/asset
- `recompile` — Force a script recompile (works while unfocused/minimized)
- `recompile_status` — Get the status of the last recompile: idle | triggered | compiling | completed | up_to_date
- `reload_file` — Compile and apply in-place [CodeReload] edits from a source file
- `reload_file_editor_interpreter` — Compile in-place [CodeReload] edits and run them through the IlInterpreter VM in this process instead of 
- `reload_file_player_interpreter` — Compile a file's (or folder's) [CodeReload] method(s) and push the IL to a connected player (IL2CPP-safe)
- `run_script` — has `dry_run` — Compile a project C# file in memory (no domain reload) and execute a named static entry point
- `set_serialized_field` — Set a serialized field on a component/asset

### assets (12)

- `copy_asset` — **needs `confirm`** — Copy an asset to a new path under the authoring root
- `create_asset` — **needs `confirm`** — Create a new ScriptableObject (or other UnityEngine
- `create_folder` — Create a folder under the authoring root (creates intermediate folders)
- `delete_asset` — **needs `confirm`** — Delete an asset from the project
- `find_assets` — Find assets by type and/or name and/or label, returning their path, GUID and type
- `get_import_settings` — Read an asset's import settings, structured by importer type (texture/model/audio), including the default
- `import_asset` — **needs `confirm`** — Import an external file (e
- `move_asset` — has `dry_run` — Move (or rename via a new path) an asset to a new location under the authoring root
- `read_text_file` — Read a UTF-8 text file under the authoring root and return its contents
- `rename_asset` — has `dry_run` — Rename an asset in place (keeps it in the same folder, keeps its GUID)
- `set_import_settings` — has `dry_run` — Set import settings on an asset's AssetImporter (default platform top-level properties, or a texture/audi
- `write_text_file` — **needs `confirm`** — Write UTF-8 text to a file under the authoring root, then import it

### capture (3)

- `capture_game_view` — Render the game view to a PNG
- `capture_scene_view` — Render the active Scene View to a PNG
- `screenshot` — Capture the Scene or Game view as a PNG and return its file path

### editor (7)

- `editor_focus` — Bring the Unity Editor window to the foreground
- `editor_pause` — Toggle pause state of Unity Editor play mode
- `editor_play` — Enter Unity Editor play mode
- `editor_status` — Get detailed Unity Editor status and state information
- `editor_stop` — Exit Unity Editor play mode
- `menu` — Execute an Editor menu item by path, or list available items when no path is given
- `set_autotick` — Keep the editor ticking while unfocused by forcing EditorApplication

### observability (7)

- `audit` — Run a Project Auditor static-analysis scan
- `audit_status` — Get the status of the last audit: idle | scanning | completed | failed | interrupted | unavailable
- `clear_console` — Clear the captured log buffer and the Unity Editor console
- `console` — Get captured Unity console output (Editor or Player; supports tail, level filtering, and follow via a cur
- `console_status` — Console ground truth and buffer counters without pulling entries: compile-failure flag, Editor console co
- `get_performance_stats` — Read render, memory, and frame-timing stats (structured, read-only)
- `report_evals` — Aggregate local eval-usage telemetry into a ranked report: API fingerprint frequency, one-liner percentag

### tests (4)

- `cancel_tests` — Cancel running test execution
- `list_tests` — List all available tests (EditMode and/or PlayMode) without running them
- `run_tests` — Execute Unity tests with filtering options
- `test_status` — Get status of running async test execution

### build (8)

- `build` — **needs `confirm`** — Trigger an async Player build and report the full BuildReport
- `build_status` — Status of the current/most recent build: idle | queued | building | completed, with the full BuildReport 
- `get_build_settings` — Read the current build configuration from EditorUserBuildSettings / EditorBuildSettings
- `list_build_profiles` — List Build Profile assets in the project (Unity 6 only)
- `list_build_targets` — List the known BuildTarget values with their group and whether build support is installed
- `set_build_settings` — **needs `confirm`** — Set mutable EditorUserBuildSettings fields
- `switch_build_target` — **needs `confirm`** — Switch the active build target (destructive, long-running: triggers a full reimport + domain reload)
- `switch_build_target_status` — Status of the last target switch: idle | switching | completed (with success + activeBuildTarget)

### settings (18)

- `get_audio_settings` — Read project Audio settings (volume, rolloff scale, doppler factor)
- `get_graphics_settings` — Read GraphicsSettings (default render pipeline)
- `get_input_settings` — Read the legacy Input Manager axes (names and count)
- `get_physics_settings` — Read Physics settings (gravity, solver iterations, bounce threshold)
- `get_player_settings` — Read PlayerSettings (company/product/version, scripting backend, API level)
- `get_quality_settings` — Read QualitySettings (current level, level names, vSync, anti-aliasing)
- `get_runtime_pipeline_settings` — Read Pipeline Runtime settings (enableInBuilds, port, requestTimeoutMs, enableAuditLogging, autoStart, ma
- `get_tags_layers` — Read the project's tags and (named) layers
- `get_time_settings` — Read Time settings (fixedDeltaTime, maximumDeltaTime, timeScale)
- `set_audio_settings` — **needs `confirm`** — Change project Audio settings
- `set_graphics_settings` — **needs `confirm`** — Set the default render pipeline asset
- `set_input_settings` — **needs `confirm`** — Tune a legacy Input Manager axis (sensitivity/gravity/dead) by name
- `set_physics_settings` — **needs `confirm`** — Change Physics settings
- `set_player_settings` — **needs `confirm`** — Change PlayerSettings
- `set_quality_settings` — **needs `confirm`** — Change QualitySettings
- `set_runtime_pipeline_settings` — **needs `confirm`** — Change Pipeline Runtime settings
- `set_tags_layers` — **needs `confirm`** — Add/remove tags and assign user layer names (index 8-31)
- `set_time_settings` — **needs `confirm`** — Change Time settings

### materials (4)

- `get_material_properties` — Read a material's shader, render queue, enabled keywords, and all shader properties with their current va
- `get_shader_properties` — Introspect a shader's declared property list (name, description, type Color|Vector|Float|Range|TexEnv|Int
- `list_shaders` — Discover available shaders so an agent can pick a valid name for set_material_properties / create_asset
- `set_material_properties` — **needs `confirm`** — Set shader properties on a material (Float/Range/Int=number; Color=[r,g,b,a] or "#RRGGBBAA" hex; Vector=[

### animation (14)

- `add_animator_layer` — has `dry_run` — Add a layer to an AnimatorController
- `add_animator_parameter` — has `dry_run` — Add a parameter (Float | Int | Bool | Trigger) to an AnimatorController
- `add_animator_state` — has `dry_run` — Add a state to a layer, optionally with a motion (AnimationClip or BlendTree) and as the layer default
- `add_animator_transition` — has `dry_run` — Add a transition between two states (or from AnyState/Entry, to Exit) on a layer, with optional condition
- `add_timeline_clip` — has `dry_run` — Add a clip to a named track on a TimelineAsset
- `add_timeline_track` — has `dry_run` — Add a track (Animation | Audio | Activation | Control | Playable | Signal | Marker) to a TimelineAsset, o
- `create_animation_clip` — **needs `confirm`** — Create an empty
- `create_animator_controller` — **needs `confirm`** — Create an
- `create_timeline` — **needs `confirm`** — Create a
- `get_animation_clip` — Read an AnimationClip's metadata and all float curve bindings (optionally with keyframes)
- `get_animator_controller` — Read an AnimatorController's full structure: parameters, layers, states (with motion / default), and tran
- `get_timeline` — Read a TimelineAsset's structure: frame rate, duration, and its tracks with their clips
- `remove_animation_curve` — **needs `confirm`** — Remove a float curve binding from an AnimationClip (SetEditorCurve(clip, binding, null))
- `set_animation_curve` — has `dry_run` — Add or replace a single float curve binding on an AnimationClip (via AnimationUtility

### packages (6)

- `package_add` — **needs `confirm`** — Add a UPM package by name@version, git URL, or 'file:' local path
- `package_list` — List packages by scope: installed (default) | available (registry) | all (both)
- `package_remove` — **needs `confirm`** — Remove a UPM package by name
- `package_resolve` — Resolve/refresh packages from the manifest (re-fetch and re-link)
- `package_search` — Search packages available in the registry
- `package_status` — Status of the last async package operation (add/remove/resolve): idle | in_progress | completed | failed,

### navigation (3)

- `get_selection` — Read the current Editor selection as structured object identities
- `search` — Run a Unity Search query and return structured results
- `set_selection` — Set the Editor selection to the given assets/scene objects

### baking (17)

- `bake_lighting` — **needs `confirm`** — Trigger an async lightmap bake of the open scene(s) via Lightmapping
- `bake_navmesh` — **needs `confirm`** — Trigger an async legacy NavMesh bake of the open scene(s) via UnityEditor
- `bake_navmesh_surfaces` — Bake NavMeshSurface components (AI Navigation package)
- `bake_occlusion_culling` — **needs `confirm`** — Trigger an async occlusion-culling bake of the open scene(s) via StaticOcclusionCulling
- `cancel_lighting_bake` — Cancel an in-progress lighting bake (Lightmapping
- `cancel_navmesh_bake` — Cancel an in-progress NavMesh bake (NavMeshBuilder
- `cancel_occlusion_bake` — Cancel an in-progress occlusion bake (StaticOcclusionCulling
- `clear_baked_lighting` — **needs `confirm`** — Clear baked lightmap data for the open scene(s)
- `clear_navmesh` — **needs `confirm`** — Clear the baked NavMesh for the open scene(s)
- `clear_occlusion_culling` — **needs `confirm`** — Clear baked occlusion-culling data for the open scene(s)
- `get_lighting_settings` — Read the active LightingSettings (lightmapper, bounces, resolution, directional mode, AO, etc
- `get_navmesh_settings` — Read the default agent's legacy NavMesh bake settings (agentRadius/Height/Slope/Climb, minRegionArea, vox
- `lighting_bake_status` — Get the status of the last lighting bake: idle | baking | completed
- `navmesh_bake_status` — Get the status of the last NavMesh bake: idle | baking | completed
- `occlusion_bake_status` — Get the status of the last occlusion bake: idle | baking | completed
- `set_lighting_settings` — has `dry_run` — Apply a subset of lighting settings to the active LightingSettings
- `set_navmesh_settings` — has `dry_run` — Apply a subset of legacy NavMesh bake settings to the default agent

### batch (1)

- `batch` — has `dry_run` — Run multiple registered commands in one transactional request

### wait (3)

- `wait_cancel` — Cancel an async wait started with wait_for (async=true)
- `wait_for` — Wait server-side until a member condition holds, then optionally act in the same frame
- `wait_status` — Get the status/result of an async wait started with wait_for (async=true)

### authoring (2)

- `get_authoring_root` — Get the base folder (under Assets/) that bare authoring paths resolve against
- `set_authoring_root` — Set the base folder (under Assets/) that bare authoring paths resolve against and are confined to
