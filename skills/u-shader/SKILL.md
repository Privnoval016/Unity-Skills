---
description: >
  Writing and reviewing shaders that stay cheap and safe in a Unity URP project: what a pixel may cost given the area
  it covers, noise from a texture rather than computed, early-outs before work, uniform branches instead of keywords,
  every graphics API compiling, warm-up for every new variant, per-instance values through property blocks, ground
  marks (premultiplied, depth-biased, terrain discs), distance fields, and how to measure before and after. Each fix
  that taught something adds its lesson here.
when_to_use: >
  Writing, changing, optimising or reviewing any shader, shader include, material or renderer feature (HLSL, Shader
  Graph, URP passes), a shader that "costs too much at 4K", a hitch the first time something draws, a shader that
  breaks on another platform, or choosing between a keyword and a property.
allowed-tools: Read Edit Write Bash AskUserQuestion
---

## Overview

A shader's cost is **per pixel times the area it covers**, every frame. A shader that is free on a card is not free on
a disc three metres across seen at 4K. Read this before writing one, and again before calling it done. The project's
own numbers and history live in its performance doc (here: `Design/project/performance.md`); this skill holds the
rules, and each fix that taught something adds its rule here, never one case's details.

## Cost

- **Count what a pixel does before choosing where it goes.** List the noise calls, texture samples and loops per
  pixel, then the largest area it can cover (a full-screen layer, a field on the ground, a card). Anything that can
  cover a large area gets the cheap path.
- **Noise from a texture, not computed, on large areas.** A computed gradient noise is several hashes per call and an
  fbm three of those; a baked noise texture is one sample. Keep computed noise for small areas (a mark, a strip) and
  for what must not repeat. Check the baked texture's period against the largest area in noise cells, so the repeat
  never shows.
- **Early-out before the work.** Return transparent first when the pixel can't contribute: zero opacity (painting
  in, dried, hidden), outside the area the shape can reach (derive the bound from the shape's own properties,
  conservatively), past a wall or gap (a present flag), or outside a texture's square. Put the test before the first
  noise call, not after.
- **Skip what a value makes pointless.** A width of zero, a strength of zero: skip that layer's maths with a uniform
  branch.
- **Never shade under something opaque.** Cut, switch off or order a costly layer so it is rejected; a fully covering
  screen tells the world camera to stop drawing.
- **Fewer passes, fewer layers.** Each transparent layer over an area is that area shaded again. Fold layers into one
  shader when they always draw together.

## Variants and warm-up

- **Options are properties and uniform branches, never new keywords.** Every keyword doubles the variants to compile,
  ship and warm. A mode chosen per material or per instance is a float the shader branches on (`_DiscRadius > 0`
  reads a disc, `0` a quad).
- **Every new shader, pass or keyword in use is warmed.** A variant compiles the first time it draws: in a build that
  is a hitch mid-fight. Record it into the warm-up (here: `.claude/scripts/tracebuild.sh`, the play merged into the
  trace; `WarmUpCoverageTests` fail until it is). If nothing in normal play draws it yet, give play a way to show it
  (here: a debug key that lays every field look). The Editor compiles as it draws, so a first-use spike seen only in the
  Editor is not proof of a build's.

## Every platform

- **Compile every pass on every graphics API in tests** (D3D, Vulkan, GL, Metal, mobile), not only the machine's own.
  A new world shader joins the compile test's list.
- **No undefined-channel tricks:** don't read a channel a texture format doesn't have, or rely on a value a platform
  leaves undefined (an uninitialised varying, a default texture's alpha).
- **Default textures mean something.** `"black"` reads 0, which may be the edge of a distance field: hide the layer
  until its real texture is set rather than drawing the default.
- **Renderer features resolve shader ids, tags and property blocks on the main thread** (in setup, not in an
  initializer), and blending attachments are read-write.

## Per-instance values

- **One shared material, values per instance on a property block** (`MaterialPropertyBlock`), never
  `renderer.material` (a copy per object). Properties live in the `UnityPerMaterial` CBUFFER so the SRP Batcher
  keeps the material batched; a block costs its own draw, so set it only on what differs.
- **Write a block when its values change, not every frame, where you can;** a value that does change each frame
  (a clock, a paint-in share) is fine.
- **A block written every frame wins over anything else written to that renderer**, a debug probe or a test's value
  included: probe the source that writes it, not the renderer after it.
- **A shared clock** (the presenter's unscaled seconds as a property) when the shader must agree with other drawn
  parts or ignore the game's time scale; `_Time` follows scaled time.
- **Colours the theme owns** come through the theme's bindings or a role resolved in code, never baked into a
  material by script.

## Marks on the ground

- **Premultiplied blending** (`Blend One OneMinusSrcAlpha`), every channel scaled by the final opacity.
- **ZWrite off, ZTest LEqual, and a small depth bias** pulled toward the camera along the view ray, so bodies standing
  on the mark hide it without the mark z-fighting the floor.
- **On a terrain-following mesh** read positions in metres from the mark's centre (UVs), never world positions, and
  honour the mesh's present flag (past a wall or cliff) so a mark never floats or bridges a gap.
- **Distance fields for crisp shapes at any size:** sample the field, scale it to metres, and anti-alias by the
  screen derivative (`fwidth`) so no texel stairs show; keep any edge noise within the field's range so it never
  reads the clamped plateau; clip outside the field's square.
- **Make the field once and share it.** A distance field is sampled off the main thread (a worker) and baked to a
  texture once per shape, kept for every user; never per placement, never on the main thread mid-fight.

## Before changing a shader or include

- **List its users first** (materials, prefabs, scenes, code; here `coc_shader_users`, and the shaders README's
  used-by list). A default value change reaches every material that never set it.
- **A new property defaults to the old behaviour** (`0` keeps the quad), so existing users are unchanged.

## Measuring

- **Measure before and after**, a state held (a median per stretch) for steady cost and a run of first uses for
  spikes, at the play size **and** at the largest resolution shipped (per-pixel cost scales with it). Here:
  `perfhold.sh` (its `fields` mode for ground marks), `perfrun.sh`, `firstfight.sh` for a build's first fight,
  `fieldscost.sh` for the fields' GPU time in a build (two builds to compare a change).
- **A frame capped by vsync or a frame-rate limit hides GPU cost:** every stretch reads the cap. Read the GPU's own time.
- **GPU time can't be read in the Editor.** Unity's frame timing there reports a GPU time for only a few frames in a
  hundred, and its frame includes the Editor's own windows (twice the whole frame's length): Editor frame times show a
  steady cost only when it is large against their own swing (several ms at 4K). To prove a sub-millisecond GPU saving,
  measure in a development build.
- **Compare the look too:** a capture before and after at the same frame; an optimisation that changes the look is a
  look change, asked about, not a fix.
- **Render tests by relation** (where ink lands, that it turns the right way, that it grows with its size), never a
  stored image of tuned values (the `u-test` skill).

## This project (Chains of Contract)

- **Helpers:** `Assets/Game/UI/Shaders/InkCommon.hlsl`: computed `InkFbm3`, `InkGradientNoise`, `InkFibre`; baked
  `InkBakedNoise`, `InkBakedFbm3`, `InkBakedFibre` (one sample each, period `INK_NOISE_PERIOD` 64 cells; the texture is
  built and set globally before the first scene by `InkNoiseTexture`); `InkCoverage` (derivative anti-aliasing of a
  signed distance). The element marks' and ground glyphs' distance field: `GlyphField` (128 px, RHalf, range 8 of a
  100-unit box), made off the main thread by `ElementGlyphPrewarm` and `GlyphFieldCache`.
- **Where things live:** world shaders `Assets/Game/Shaders/`, UI shaders and the shared include `Assets/Game/UI/Shaders/`
  (its README lists every shader with its users); effects `Assets/Game/Vfx/Shaders/` (warmed by a variant collection);
  the anime shader pack in `Assets/Privnoval-Tools/AnimeShaders/` (its own README, tier drops, `PackShaderTests`).
- **Tests:** `WorldShaderCompileTests` (every `Chains/World` shader on every API), `WarmUpCoverageTests` (the trace has
  every shader the build reaches), render tests by relation (`GroundGlyphRenderTests`, the UI's `ShaderRender`).
- **Numbers and history:** `Design/project/performance.md` ("What was found": each fix with its before and after).
- **Lessons from fixes:**
  - The fields (2026-11-20): eight cost 3.3 ms at 4K against 0.5 ms at the play size, so per-pixel times area. The
    wash already read baked noise but still made 16 reads on every pixel of its whole disc, including far outside its
    edge and deep in the fill where the edge's noise changes nothing: early-outs by the shape's own reach. The glyph
    on top computed its noise. Count reads per pixel, not only computed calls; and search a shader for the exact helper
    name before judging it (a search for `Fbm3` also matches `InkBakedFbm3`).
  - Measured in a build (2026-11-20, `fieldscost.sh`, 3456 x 2168): three fields cost about 0.3 ms of GPU, eight about
    15 ms: cost isn't linear in count when fields can lie near the camera and cover the screen. The early-outs and the
    baked noise made no measurable difference there: measure what dominates before cutting.
  - The field views' pool asset held 4 against a decided 8 (the asset was saved before the code's default changed):
    a decided number lives in the asset and a test holds it.
