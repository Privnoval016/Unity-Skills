---
description: >
  Writing and reviewing Unity EditMode tests that catch regressions and never fail on a designer's tweak: the six
  patterns for a tuned value, honest reads (ratios, independent evaluators, fixtures that can't be tweaked into a
  false pass), made data and clean-up, render tests by relation, failure messages, and the break and tweak proofs.
when_to_use: >
  Writing or changing a test, reviewing tests, a test failing after an Inspector tweak, a test that passed when the
  code was broken, "how do I test X", deciding what a test should read from an asset and what it should set itself.
allowed-tools: Read Edit Write Bash
---

## Overview

A test exists to catch a regression in code. It must fail when the code is wrong and pass whatever a designer sets in
the Inspector. A test that fails on a tweak is a false alarm; a test that passes on broken code is worse. Both are
bugs in the test.

## The rule: never pin a tunable

A value a designer can change in the Inspector (a power, a cost, a size, a word, an order, a colour) is never a
literal in an expectation. Every test that meets one takes one of six shapes:

| Pattern | When | What it asserts | Why a regression still fails it |
|---|---|---|---|
| **Read and relate** | a shipped asset's value drives an outcome | the outcome equals the rule applied to the value read from the asset (`after == min(cap, before + delta)`) | the code turning the value into the outcome is still checked |
| **Made data** | the test is about a mechanic (stacking, a ramp, a cap, a layout rule) | the mechanic on data the test makes and sets | checked with known numbers |
| **Wiring** | how a shipped asset is hooked up | references, kinds, which resource, which material | unchanged by tuning |
| **Relation** | structure (draw order, bindings, rows) | the rule as a relation: A draws below B; parts don't overlap; each action has a pad and a keyboard binding | the rule is still checked |
| **Rule minimum** | a written rule on a tuned value (a minimum size, a contrast) | kept; the message names the rule and where it is written | unchanged |
| **Gone** | a test that only restates an asset | deleted, naming the test that still covers its rule (or adding one) | the rule's test stays |

Words on screen come from the copy assets: build the expected text through the same copy method the screen uses, and
test the copy's formats once on a made copy (code defaults) so the format itself stays covered.

## Reading honestly

A read value can hide a bug. These keep a read-and-relate test able to fail:

- **Never re-implement the formula.** Check a ratio through the real thing: a reference result divided by its read
  input gives "per unit"; each other result is that times its own read input. `Assume.That(input != reference)` so a
  tweak to equal values can't hide an "input ignored" bug.
- **Evaluate with an independent evaluator.** A curve's points are read raw and evaluated by the engine's own
  `AnimationCurve.Evaluate`, never by the code under test.
- **Check a cost three ways**: the serialized row, what the build makes of it, and the gauge's change after use.
- **Fix the edge cases in the fixture, never leave them to luck**: apply caps (`min(max, start + delta * n)`); give a
  spending fixture a deep pool, full; start a heal low enough that a larger share can't clamp, plus one explicit clamp
  case; handle a count of 1; test both branches of a cap with two fixtures.
- **Compare counts with an independent enumeration** (the assets the database lists), never `> 0` or a floor.
- **Read a value from where the code reads it** (the widget's field, the copy, the prefab), not a copy of it.
- **Floats compare within a tolerance**; vectors with `Vector2EqualityComparer` / `Vector3EqualityComparer`.

## Made data and clean-up

- Make what the test needs (`ScriptableObject.CreateInstance`, `new GameObject`) and destroy all of it in teardown;
  a shared helper that records what was made keeps that one line.
- A copy of a shipped asset (`Object.Instantiate`) with one field set is a fixture: the test owns its values.
- A test never writes a real project file. Scratch files go under a scratch name and are deleted in setup and teardown;
  a test that writes asserts every real file it could touch is unchanged. (A test that rewrote the real pages once
  made the next test compare them against themselves.)
- Never leave global state behind: services registered, static flags, globals set, Play Mode entered. Restore in a
  `finally` or teardown.

## Asserting what ran

- An assert inside a callback proves nothing if the callback never runs: count the calls and assert the count.
- A loop over found things asserts it found some, against an independent count, or the loop can be empty.
- A test of "it fails cleanly" asserts the failure's message, not only that something threw.

## Render tests

- Draw a material the test makes and sets, never a shipped one, unless the test is about the shipped one's wiring.
- Assert relations in pixels with a tolerance: width shrinks as distance doubles; the lit side is the light tone; the
  boundary is no wider than the softness. A stored reference image is a fixture only when the made material carries
  every value it renders with.
- For a fade or reveal, render N steps and assert covered pixels never decrease and each step's covered set contains
  the last (no pixel flickers off).
- Graphics devices: a headless run started with `-nographics` can't make render textures; run such suites with
  graphics.

## Failure messages

Name the asset, the row or field, and the rule in words, with the values read:
`Tiger's Eye: damage row 1, power 1.15 read: the reference × 1.15 = 1,150 expected, dealt 1,000`. A helper that can't
find a row fails naming the asset and the row kind.

## Proving a test

- **The break proof**: break the code the test covers (ignore an input, drop a line, off-by-one a clamp), run, see it
  fail, undo. A test that passes a break is vacuous: fix it before trusting it.
- **The tweak proof**: change the tuned values it reads, up and down and to the edges, run, see it pass, restore. A
  test that fails a tweak pins a tunable. Check the tweak really applied (count what changed) and that nothing it
  touched in memory survives the restore.

## The reviewer's question

For each test: "If a designer changed any value in the Inspector, would this fail? If someone broke the code it
covers, would this fail?" The answers must be no and yes.

## This project (Chains of Contract)

- **The kits and helpers** are indexed in the `coc-reuse` skill's Tests table (`Made`, `TestReflection`,
  `ActionRows`, `ShippedAssets`, `PrefabChecks`, `PartyKit`, `TreeTeaching`, `SavedGameFixtures`, ...). Check it before
  writing a helper. `TestReflection` is fine in tests; the type-check guard skips test code.
- **Running**: `.claude/scripts/utest.sh <name> [assembly]`. A filter is a name, never a pattern
  (`utest.sh Game.Party.Tests assembly` for one assembly). Run the assemblies a change touches; CI runs every test on
  every commit (`.claude/scripts/ci/ci-status.sh -v`).
- **The tweak proof**: `TWEAKS="tweaktunables.cs tweaklayout.cs" .claude/scripts/tweakproof.sh "<Assembly> assembly"`
  (`KEEP=<folder>` keeps each run's results). It restores only the assets it tweaked.
- **Save fixtures**: the recording holds what tuned content can't move; party, quests and bonds are relations to the
  save (`Assets/Game/Session/Tests/Saves/Fixtures/README.md`).
- **The rule's home**: `Design/project/engineering-rules.md`, "A test never pins a value that can be tuned by hand".
