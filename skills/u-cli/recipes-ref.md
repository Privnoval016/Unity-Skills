# Recipes

Loops worth running verbatim. Each one ends in evidence, not an assertion.

All examples assume `unity` is on PATH and the project is the working directory. Add
`--project-path <path>` whenever more than one Editor may be running: without it the CLI targets
whichever Editor owns the current directory, so the target follows the shell's cwd.

---

## 1. Did it compile?

The first thing after any `.cs` edit. Replaces scraping the console for red text.

```bash
unity command recompile --format json
# poll until status is completed or up_to_date
unity command recompile_status --format json
```

`recompile_status` returns one of `idle | triggered | compiling | completed | up_to_date`. Only then
read the console — reading it mid-compile reports the previous state.

```bash
unity command console_status --format json   # counts + compilationFailed, pulls no entries
unity command console --level error --tail 20 --format json
```

`console_status` is the cheap check: it returns `groundTruth.compilationFailed` and error/warn counts
without pulling entries. Pull entries only once it says there is something to read, and follow with
the `since` cursor rather than re-reading the tail.

**If the Editor drops into Safe Mode**, the Pipeline package doesn't load and every Editor-driving
command fails to connect. `unity pipeline list` shows `safeMode: true`. Fix the compile errors in
source and have the user restart the Editor. Don't interpret a connection failure as "the Editor is
down" without checking this.

---

## 2. Did the tests pass?

Two paths, and they are not interchangeable.

```bash
# In the live Editor — fast, no batch-mode boot, needs a reachable server
unity command run_tests --mode editor --async_tests true --format json
unity command test_status --format json

# Standalone — works with no Editor running, writes a report, used for CI
unity test --mode EditMode --format json
```

**The two spellings are not interchangeable.** `run_tests --mode` takes `all | editor | playmode`;
standalone `unity test --mode` takes `EditMode | PlayMode`. Passing one to the other fails.

`unity test`'s exit codes are contractual and **`8` is not a failure of the tooling**:

| Code | Meaning |
|---|---|
| 0 | All passed |
| 8 | Tests ran and some failed |
| 1 | Error — the run itself broke |
| 2 | Usage error |

Treating `8` as `1` reports a broken harness when the real answer is "your tests fail." Check the
code explicitly rather than relying on a truthiness test.

Narrow the run to what actually changed:

```bash
unity vcs affected --format json          # which assemblies and tests this diff touches
unity test --mode EditMode --filter <pattern> --format json
```

Other flags worth knowing: `--rerun-failed` (only last run's failures), `--retries <n>` (reports
tests that pass on retry as flaky rather than green), `--shard N/M`, `--coverage`.

---

## 3. What does it actually look like?

The loop that ends building UI blind.

```bash
# Want a FILE: writes to Temp/pipeline-screenshots/ — gitignored, outside Assets/, no .meta
unity command screenshot --view game --format json
unity command screenshot --view scene --output Temp/shots/before.png --format json

# Want it INLINE (base64, nothing written): omit save_path
unity command capture_scene_view --max_resolution 1024 --format json
unity command capture_game_view --source camera --max_resolution 1024 --format json
```

**Never pass `capture_*  --save_path` casually — it is Assets-relative.** `--save_path "Temp/a.png"`
writes `Assets/Temp/a.png`, Unity imports it, a `.meta` appears, and it shows up in `git status`.
`screenshot --output` is project-root-relative and defaults somewhere already gitignored.

**Neither path shows Screen Space - Overlay UI in Edit mode.** Verified: both `capture_game_view
--source camera` and `screenshot --view game` returned the 3D scene with no HUD. Overlay UI needs
`capture_game_view --source screen`, which is Play Mode only — run recipe 4. Check `RenderMode`
first rather than capturing and wondering where the HUD went.

`max_resolution` caps the inline image only and does nothing when `save_path` is set.

Then run the critique rubric in `u-ui/design-ref.md` against the result **before** showing it to the
user. Step 1 of that rubric is "is this a bug?" — visual complaints in this project have historically
been initialization and layout bugs more often than taste.

---

## 4. Guarded Play Mode capture

The only way to see a Screen Space - Overlay HUD. Every step is a guard; none is optional.

```bash
# 1. Snapshot the error count. Do NOT require zero — abort only if it RISES.
unity command console_status --format json

# 2. Keep the Editor ticking while it lacks OS focus.
unity command set_autotick --enable true --interval_ms 16 --format json

# 3. Enter Play Mode.
unity command editor_play --format json

# 4. Prefer a server-side wait over a poll loop — on_met fires in the SAME frame.
unity command wait_for \
  --condition '{"member":"<Type>.<StaticMember>","op":"eq","value":true}' \
  --timeout_s 30 --on_met '{"capture":{"view":"game","source":"screen"}}' --format json

# ...or poll manually with a wall-clock budget if no condition expresses the beat.
unity command editor_status --format json

# 5. Capture with the overlay UI included (inline; no save_path, nothing written to Assets).
unity command capture_game_view --source screen --format json

# 6. ALWAYS stop, including on every abort path.
unity command editor_stop --format json
```

**Abort conditions, any one of which ends the run:** the timeout is reached, `frameCount` is
unchanged across two polls, or the error count has risen above the step-1 snapshot. On abort,
`editor_stop` and hand the console tail to the user.

**Do not require a clean console to start.** This project carries a benign standing error (Odin's
`ProjectWatcher` hitting a `MissingMethodException` against Unity 6000.5's `HierarchyProperty`
constructor). A zero-errors precondition would block Play Mode permanently. Compare against the
snapshot, not against zero.

This exists because Play Mode has previously both frozen while unfocused *and* error-looped with
NullReferenceExceptions. `set_autotick` addresses the freeze. Nothing addresses the error loop, which
is why the loop detects rather than trusts, and why real play-testing is still the user's job.

---

## 4b. Many mutations at once

Don't issue ten separate calls. `batch` runs up to 200 ops transactionally:

```bash
unity command batch --dry_run true --operations '[
  {"id":"go","command":"create_gameobject","params":{"name":"MeterRoot"}},
  {"command":"add_component","params":{"target":"$go.instanceId","type":"UnityEngine.Canvas"}}
]' --format json
```

`transactional: true` (default) makes the whole thing one Undo step and reverts every applied op if
any op fails. `$go.instanceId` references an earlier op's result by id or index. `dry_run` validates
names, parameters and reference topology without mutating — **this is the preview to show for
approval**. `result_fields` trims each op's result to the fields you need.

---

## 5. Reviewing a scene or prefab change

`git diff` on a `.unity` file is unreadable, which is how scene changes go unreviewed.

```bash
unity vcs status                                   # grouped by what it means to Unity
unity vcs diff Assets/Scenes/Playground/Playground.unity   # by GameObject and component name
unity vcs explain <path>                           # what each branch did to a conflicted asset
unity vcs summarize                                # branch summary, PR-ready
unity vcs doctor                                   # ignore rules, LFS, meta pairing, package pinning
```

`unity vcs doctor` reports real defects, not style: ignored `.meta` files (which break references on
a fresh clone) come back as errors, floating git package refs as warnings.

---

## 6. Bulk scene construction without domain reloads

When a task needs many Editor mutations, running them one at a time pays a domain reload each time.

```bash
unity command run_script --file Assets/Editor/Build/SetupThing.cs --entry Run --format json
```

`run_script` compiles one `.cs` in memory and runs a named `static` entry point **without a domain
reload**. Use it for the builder pattern — construct the whole hierarchy in one pass — rather than
issuing dozens of `create_gameobject` / `set_component_properties` calls.

---

## 7. Long-running work

Anything that may exceed the 30s default timeout:

```bash
unity command <cmd> --detach          # returns a job id immediately
unity job status <job-id>
unity job wait <job-id>
unity job cancel <job-id>
```

Prefer `--detach` over raising `--timeout` for builds, bakes and full test runs.
