# Reviewers

Four briefs, one per viewpoint. Each reviewer is read-only, reads every file in its scope in full, and
reports file:line · rule · what is wrong · failure scenario · concrete fix. Findings outside its
viewpoint are passed along in one line, not worked up. The lead merges, verifies and ranks.

| Reviewer | Asks | Checklist sections |
|---|---|---|
| Correctness | Does it do what it should, and did anything that worked break? | Correctness, Refactor vs feature, Input, UI |
| Design | Will the next change be easy? | Architecture, Smells and patterns, Extensions, Performance |
| Types and data | Is every value typed, owned and in data? | Types and values, Data-Driven, Style |
| Tests | Would a regression be caught? | Tests |

## Correctness

You are trying to break the change. For every changed path, construct the input that makes it wrong:
empty, single, many, dead, missing, repeated, re-entered, out of order, cancelled, disabled mid-way.
Compare behaviour before and after the diff (`git diff`), and against `Design/combat/combat-design.md`
and the assembly README. Check lifecycle pairs, exceptions skipping teardown, async work outliving its
owner, statics left changed, serialized data a rename would lose. Report only what you can show with a
concrete scenario.

## Design

Read `../u-arch/SKILL.md` (Code Smells, When to Refactor, Design Patterns) and
`../u-arch/refactoring-ref.md`. For each smell you find, name it and give its remedy in this
codebase's form. Ask of each type: would a new character, element, resource or kind of action need an
edit here? Flag a pattern that answers no present problem as firmly as a missing one. Respect the
exemptions listed in u-arch, and the project's accepted decisions in `Design/`.

## Types and data

Every value must say what it is and live where a designer can change it. Flag `object`-typed members,
raw primitives standing for ids, kinds, ranges or durations, any gameplay or tuning number in code,
typed strings for actions, assets, stats or ids, duplicated constants, fully qualified names where a
`using` would do, and u-style violations. A code constant passes only as a named, documented engine
safety limit.

## Tests

Read the change and its tests side by side. For each changed behaviour, name the test that would fail
if it regressed, or report that none would. Look for vacuous asserts, tests that depend on another
test's leftovers (stat bases, registries, statics), missing restores, ScriptableObjects never
destroyed, tests asserting a design that no longer exists, and missing edge, boundary and regression
cases. Propose each missing test as a name plus what it asserts.
