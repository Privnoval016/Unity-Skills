# Plan reviewers

The design review of a written plan, before any code. Four briefs, one per viewpoint, held by two
reviewers: one takes Design fit with Data and authoring, the other Behaviour with Tests and verification.
Each reviewer is read-only, reads the whole plan and the code and docs it names (in full, not skimmed), and reports
plan section · rule or decision · what is wrong · failure scenario · concrete fix. A finding must name
the file, doc section or decision it rests on; "might be a problem" is not a finding. Findings outside
its viewpoint are passed along in one line, not worked up. The lead merges, verifies and ranks.

| Reviewer | Asks | Reads |
|---|---|---|
| Design fit | Will this shape last, and does it reuse what exists? | `../u-arch/SKILL.md`, `../u-arch/refactoring-ref.md`, `../u-extensions/SKILL.md`, the project's reuse index |
| Behaviour | Does the plan do everything the design decided, and nothing it didn't? | The design docs and decisions the plan cites, and any it should have |
| Data and authoring | Is every value in data, typed, owned, and safe to author? | `../u-arch/SKILL.md` (Data-Driven Design), the project's engineering rules, its save docs |
| Tests and verification | Would a wrong build be caught, step by step? | The plan's Verification and test lists, the existing tests it relies on |

## Design fit

Check each new type, seam and file against the code it sits beside. Does something already do this, or
nearly (an interface with no implementer, a helper, a base class, an existing extension point)? Name it
and say how the plan should use or extend it instead. Is each piece in the right layer and assembly, and
does any dependency point the wrong way? Ask of each new type: would the next character, element,
resource or kind of action need an edit here? Flag a pattern that answers no present problem as firmly as
a missing one, a concept named after one character, and a folder plan that will need a later move.

## Behaviour

List every rule the design decided for this work (quote the doc or ruling) and find the plan step that
builds it; report each one with no step, and each step that builds something nobody decided. Construct the
cases that break it: empty, single, many, dead, missing, repeated, re-entered, out of order, cancelled,
joined mid-way, saved and loaded. Report every point the plan settles by assumption where the docs are
silent or marked Open: those are questions for the user, not choices for the plan.

## Data and authoring

Every gameplay and tuning number lives in data and goes through the stat pipeline; every Inspector pick
is an asset or a dropdown that offers only valid choices, never a typed key; every value has one owner.
Check what the plan does to existing assets (a migration step, or a silent default that changes them),
to saves (schema, fixtures, a loaded old save), and to recorded baselines. Flag `object`-typed members
and raw primitives standing for ids, kinds or durations in the proposed signatures.

## Tests and verification

For each step, name the test that would fail if it were built wrong, or report that none would. Check
the cases are concrete (edge, boundary, regression), not one token test; that each verification command
exists and fails when the step is wrong; that existing behaviour the plan changes on purpose is pinned
before and re-recorded deliberately; and that no step can only be verified by eye when a test could do it.
Propose each missing test as a name plus what it asserts.
