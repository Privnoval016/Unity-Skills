# Vendored reference material

Not skills. Copies of Unity's official agent skills, kept here as **reference material the
`u-*` skills cite** — never as competing top-level skills.

`install.sh` only links `skills/*/` into `.claude/skills/`, so nothing in this folder is
ever discovered as a skill. That is structural, not a convention: adding a `SKILL.md` here
does not make it load.

| Vendored | Cited by |
|---|---|
| `unity-cli/` | `u-cli` |
| `unity-package-management/` | `u-cli` |
| `generate-editor-search-query/` | `u-cli` |
| `ui-uitk/` | `u-ui/uitk-ref.md` |
| `ui-ugui/references/` | `u-ui` |
| `optimize-text-mesh-pro/` | `u-ui/design-ref.md` |
| `urp-postprocessing/` | `u-ui/design-ref.md` |
| `physics-3d-collision/` | `u-arch` |
| `validate-urp-render-graph-renderer-feature/` | `u-review` |

**`ui-ugui/SKILL.md` is deliberately absent.** Its guidance tells an agent to generate raw
Canvas hierarchies and knows nothing about `ThemeConfig`, `View<T>`, `AnimatedPanel` or
`UIWidgetPool`, which contradicts `u-ui`. Only its references are kept. Do not add it.

Source: https://github.com/Unity-Technologies/skills — vendored at Unity CLI `1.0.0-beta.8`,
`com.unity.pipeline` `0.7.0-exp.1`. Re-pull manually when the CLI leaves beta;
`unity skill refresh` does not track hand-vendored copies.
