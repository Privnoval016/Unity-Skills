---
description: >
  World visual effects. Effects are assets (VfxEffect) played through one pooled, backend-blind
  service (IVfxService); code names a cue and an owner, and the owner's VfxSet decides the look.
  Covers the system's contracts, how to add a new kind of effect, and how to build VFX Graph and
  particle effects that perform (capacity, bounds, events, pooling, prewarm, time).
when_to_use: >
  Building, wiring or reviewing any in-world effect; questions about "VFX", "VFX Graph",
  "Visual Effect", "particle system", "VfxEffect", "VfxSet", "VfxCue", "IVfxService", "hit effect",
  "impact", "trail", "prewarm an effect", or an effect that hitches, pops, vanishes at the screen edge
  or ignores hitstop.
allowed-tools: Read Edit Write Bash AskUserQuestion
---

## Overview

An effect is **data a designer assigns**, never a prefab a script instantiates. Gameplay code says
*which moment* happened and *whose* it was; it never names an effect, a prefab or a graph. That keeps
every character's look swappable in the Inspector and keeps one place responsible for pooling,
lifetimes and time.

Read the project's own VFX README first (in this project `Assets/Game/Vfx/README.md`) for the cue list
and what already plays cues. Check the project's hard rules on art sources before making any texture.

## The contracts

| Type | Role |
|---|---|
| `VfxEffect` (abstract SO) | One effect: `Lifetime`, `Prewarm`, `CreateInstance(parent)` → `IVfxInstance` |
| `IVfxInstance` | One pooled instance: `Play(context)`, `Stop(immediately)`, `IsShowing`, `SetStrength`, `SetColour`, `Release` |
| `VfxCue` (enum) | The moments code can name |
| `VfxSet` (SO) | An owner's rows of cue → effect, with an optional tint |
| `VfxContext` (struct) | Position, rotation, strength 0–1, scale, colour, follow target. Build with `VfxContext.At(...)` or `VfxContext.On(...)` |
| `IVfxService` | `Play(effect, context)`, `Play(set, cue, context)`, `Prewarm(set)`; returns a `VfxHandle` |
| `VfxHandle` (struct) | `Stop`, `MoveTo`, `Follow`, `SetStrength`, `SetColour`, `IsPlaying`. A default or stale handle is safe |

```csharp
// Playing: a cue from the owner's set. No service, no set or no row all mean "nothing plays".
if (Services.TryGet<IVfxService>(out var vfx))
    vfx.Play(actor.Vfx, VfxCue.HitHeavy, VfxContext.At(point, direction, strength: 1f));

// Something held: keep the handle, stop it when the thing ends.
_flight = vfx.Play(owner.Vfx, VfxCue.Projectile, VfxContext.On(transform));
...
_flight.Stop();
```

## Rules

1. **Name a cue and an owner, never an effect.** A serialized `VfxEffect` field on gameplay code is
   right only when the effect belongs to that asset alone (a status's own aura), never for something a
   character should be able to re-skin.
2. **Never `Instantiate` or `Destroy` an effect in play.** The service pools per asset. A pool that
   grows in play is a bug: it warns, and the fix is the effect's `Prewarm`.
3. **Prewarm = the most that show at once.** Owners prewarm their set when they spawn; scene-wide sets
   go on the service's own list.
4. **A lifetime of 0 means someone holds the handle** and stops it on every way out (end, interrupt,
   disable). Never play a 0-lifetime effect and drop the handle.
5. **Lifetimes run on game time.** Hitstop and slow motion must hold an effect with its blow. An effect
   that must keep moving through a freeze is the rare exception and says so on the asset.
6. **A new moment is a new enum value at the end** of `VfxCue` (never reorder: assets store the
   number), plus a row in the README's table of what plays it.
7. **A new kind of effect is a subclass**, with a private nested `IVfxInstance`. If it needs a package,
   it lives in the VFX assembly so nothing else references that package.
8. **Optional by construction.** Every path must do nothing, without error, when the service, the set
   or the row is missing. Tests run without a service.
9. Follow `u-style` and `u-arch` as everywhere: no `Find`/`GetComponent` per play, shader and graph
   property ids cached as `static readonly int`, no allocation per play.

## Building a VFX Graph effect

The graph kind drives any graph through fixed names, so a graph needs no script of its own.

| In the graph | Use |
|---|---|
| Event `OnPlay` | Wire to the Spawn context's Start. Clear the default "initial event name" on the component (the effect kind does this) |
| Event `OnStop` | Wire to the Spawn context's Stop, so what is alive finishes on its own |
| Exposed float `Strength` | Multiply count, size or speed. Optional |
| Exposed Vector3 `Direction` | The blow's direction, world space. Optional |
| Exposed colour `Colour` | A tint. Optional |

**Performance, in order of how often it bites:**

- **Capacity.** Set each system's capacity to the most it can have alive, not a round thousand. Capacity
  is memory and GPU work allocated whether particles exist or not. A burst of 24 wants 32.
- **Bounds.** Culling uses the bounds. Too small and the effect vanishes at the screen edge; too large
  and it never culls. Set them by hand for a short effect (*Recorded* or *Manual*); avoid *Automatic*
  on anything short-lived, since it costs a readback.
- **Single burst over constant rate** for impacts: one `Single Burst` on `OnPlay` and nothing per frame.
- **Space.** World space for anything left behind (a trail, smoke); local space for anything that must
  stay with its owner (an aura). Mixing them is the usual cause of "it lags behind".
- **Outputs.** Prefer unlit quads; lit outputs and distortion cost far more. Soft particles need the
  depth texture; check it is enabled on the pipeline asset before relying on it.
- **Overdraw.** A few large, mostly transparent quads on top of each other cost more than hundreds of
  small ones. Trim the quad to the texture (octagon output), keep alpha low-area, shorten lifetimes.
- **Instancing.** Many copies of the same graph are batched if the asset allows instancing (on by
  default). Exposed textures and meshes that differ per instance break the batch.
- **First use.** Prewarming makes the instances at load (the graph kind keeps each one's GPU buffers
  while it waits in the pool). It does not draw them: a graph's shaders still compile the first time it
  is seen. If that shows as a spike, show the effect once during load.
- **Fade Seconds** on the asset is the longest particle life in the graph. The live-particle count is
  read back from the GPU only about once a second, so it is not used to tell when a graph has finished.
- **Fixed time step.** VFX Graph simulates on its own step (Project Settings → VFX). Fast, short effects
  can stutter at a low step; keep the default unless a capture shows a problem.

**When to use which kind:**

| Use | Kind |
|---|---|
| Thousands of particles, GPU events, strips, sampling a mesh or a texture | VFX Graph |
| A handful of particles, sub-emitters, collisions with the world, anything that must read back on the CPU, or a platform without compute shaders | Particle system |

Both are played the same way, so the choice is per effect and can change later.

## Building a particle effect

- The prefab's root is the particle system; children are played and stopped with it.
- `Play On Awake` off, `Stop Action` None and `Scaling Mode` Hierarchy are forced on every system as an
  instance is made, so a bought effect that destroys itself cannot break the pool.
- It is simulated one frame at birth, so a burst shows on the frame of a blow that hitstop freezes.
- `Max Particles` set to what the effect needs, for the same reason as a graph's capacity.
- `Culling Mode` Always Simulate only for effects whose timing matters off screen; otherwise Automatic.
- Colour is taken through the main module's start colour only when the asset says the effect takes one.

## In a Timeline

VFX Graph ships a **Visual Effect Control Track**: a graph on a timeline scrubs, rewinds and previews in
Edit Mode. Use it for authored sequences (cutscenes, technique sequences) where the effect is part of
the shot. Use cues through the service for anything driven by gameplay. Particle systems scrub through
Timeline's own **Control Track**.

## Verifying

- EditMode tests with a fake `VfxEffect` cover pooling, lifetimes, handles and missing data.
- In play, read the service's playing and pooled counts after a fight: playing returns to zero and no
  "pool grew" warning appears.
- Measure with the project's frame-spike tooling before and after adding an effect to a hot moment; a
  hit effect must add no spike on its first play.

## Review checklist

- [ ] Gameplay code names a cue and an owner; no effect prefab or graph is referenced from it
- [ ] No `Instantiate`/`Destroy` of effects in play; `Prewarm` covers the most at once
- [ ] Lifetime set; a 0-lifetime effect has an owner that stops its handle on every exit path
- [ ] Graph: capacity fits, bounds set by hand, `OnPlay`/`OnStop` wired, optional properties named exactly
- [ ] Graph asset: Fade Seconds covers the longest particle life
- [ ] Particle prefab: Max Particles fits
- [ ] Nothing breaks with no service, no set or no row
- [ ] New cue appended to the enum and listed in the README

## Continuous Improvement

When the user gives a VFX rule that should hold from now on, ask "Should I update this skill file for
future sessions?" If yes, read this file and apply the smallest edit.
