# Unity-Skills

A reusable Claude Code skill library encoding a Unity coding style, architecture patterns,
and project conventions. Each `/u-*` skill is a folder under `skills/` — install once per
project, use across sessions.

**This library enforces production standards. It is not for prototyping.**

---

## Installation

Add as a git submodule from your Unity project root:

```bash
git submodule add <url> Unity-Skills
```

Then link the skills into `.claude/skills/`:

**macOS / Linux:**
```bash
bash Unity-Skills/install.sh
```

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File Unity-Skills\install.ps1
```

`install.sh` symlinks each skill folder into `.claude/skills/` in your project.
`install.ps1` does the Windows equivalent using directory junctions instead of symlinks —
real symlinks on Windows require admin rights or Developer Mode, while junctions need
neither. Both link live: editing a skill under `Unity-Skills/skills/` is reflected in
`.claude/skills/` immediately, with no reinstall needed. Skills are available in the
current Claude Code session right away — no restart required.

---

## Editor Control Setup

Claude drives the live Unity Editor through the **Unity CLI** and the `com.unity.pipeline`
package — not through an MCP server. Unity deprecated its own in-Editor MCP server in favour of
the CLI, which costs fewer tokens for the same work and doubles as CI tooling.

```bash
# 1. Install the CLI (standalone binary, no dependencies)
curl -fsSL https://public-cdn.cloud.unity3d.com/hub/prod/cli/install.sh | UNITY_CLI_CHANNEL=beta bash

# 2. Sign in, then add the Pipeline package to the project
unity auth login
unity pipeline install

# 3. Focus the Unity Editor window — it resolves the manifest on focus, and
#    the Pipeline server does not start until it does.
unity pipeline list        # expect Pipeline: true, Server Reachable: true
```

`unity command` then lists what the Editor exposes (151 commands on Unity 6000.5 with package
0.7.0-exp.1). See the `u-cli` skill for the safety model, the session gate, the guarded Play Mode
loop and the full catalog.

**Never read `.unity` or `.prefab` files directly to answer a question about scene state.** Use
`unity command get_scene_hierarchy` / `find_gameobjects` for reads and `unity vcs diff` for changes —
the latter diffs by GameObject and component name instead of by fileID.

### Vendored reference material

`vendor/unity/` holds copies of Unity's official agent skills, cited by the `u-*` skills but never
loaded as skills themselves (`install.sh` only links `skills/*/`). See `vendor/README.md`.

---

## Skills

| Command | Auto-load | Purpose |
|---------|-----------|---------|
| `/u-assist` | Yes | Synthesizes all relevant skills inline for any Unity question |
| `/u-style` | Yes | C# naming, regions, doc comments, property style |
| `/u-arch` | Yes | MB split, SO roles, service locator, events, patterns, perf |
| `/u-extensions` | Yes (hidden) | Extensions library first-look before writing any utility |
| `/u-state` | Yes | PushdownAutomata state machine pattern |
| `/u-anim` | Yes | Animancer backend, IAnimationDriver, SO anim defs |
| `/u-input` | Yes | IInputSource abstraction, typed buttons, grace windows |
| `/u-physics` | Yes | Orchestrated physics, context reuse, modifier pipeline |
| `/u-ui` | Yes | ThemeConfig adapters, modular UI, PrimeTween, visual design, UI Toolkit |
| `/u-cli` | Yes | Driving the live Editor: captures, console, tests, scene diffs, project verbs |
| `/u-review` | Manual only | Full code review → ReportFindings (user-invoked) |
| `/u-plan` | Manual only | Planning assistant — thorough Q&A before any implementation |

---

## Self-Refinement

Every skill will offer to update its own `SKILL.md` when you provide new preferences or
corrections during a session. This keeps skills in sync with how you actually work over time.

---

## Updating

```bash
git submodule update --remote Unity-Skills
```

Existing links pick up file changes automatically. Re-run the installer for your platform
(`install.sh` or `install.ps1`) only if the update added or removed a skill folder.
