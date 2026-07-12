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
bash Unity-Skills/install.sh
```

`install.sh` symlinks each skill folder into `.claude/skills/` in your project. Skills are
immediately available in the current Claude Code session — no restart required.

---

## MCP Server Setup

Configure the Unity MCP server in Claude Code settings so Claude can inspect your scene
hierarchy and component data without reading binary `.unity` files.

**Always prefer `mcp__unity__*` tools over reading `.unity` scene files directly.**

Key tools:
- `mcp__unity__get_hierarchy` — full scene hierarchy
- `mcp__unity__get_component_properties` — component field values on any GameObject
- `mcp__unity__execute_menu_item` — run any Unity menu item programmatically
- `mcp__unity__add_component` — add a component to a GameObject
- `mcp__unity__get_gameobject_info` — position, active state, tag, layer
- `mcp__unity__find_objects_of_type` — find all objects of a given type in the scene

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
| `/u-ui` | Yes | ThemeConfig adapters, modular UI, PrimeTween |
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
bash Unity-Skills/install.sh
```
