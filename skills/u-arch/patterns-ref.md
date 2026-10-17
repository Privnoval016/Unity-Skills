# Design Patterns Reference

Patterns from refactoring.guru organized by frequency of use in this codebase.
Each entry shows the Unity-specific form used here.

---

## Most Common — Know These Deeply

### Strategy
Defines a family of algorithms, puts each in its own class, and makes them interchangeable.

**Unity forms:**
- `IModifierStrategy` — stat modifiers registered with `Mediator`, each modifying a query result independently
- `IMotionStage` / `IMotionAbility` — physics pipeline stages sorted by priority, each handling a slice of movement
- `IRule<TEvent, TContext, TResult>` — `RuleSystem<TCtx, TResult>` bucketed by event type
- Game mechanics: `IAttackAction`, `IAbilityPhase`, any swappable algorithm on a per-SO basis

**When to use:** the same operation needs multiple implementations, or behavior varies by configuration.
Use `[SerializeReference]` in SOs to select the strategy in the Inspector without code changes.

---

### Observer
Defines a one-to-many dependency so that when one object changes state, all dependents are notified.

**Unity forms:**
- `EventBus<T>` (Extensions.EventBus) — global typed bus; sender doesn't know subscribers
- C# `event Action<T>` — direct tight-coupling within the same system
- SO Event Channels — designer-wired bridges between scenes

**When to use:** EventBus for cross-system broadcast; C# events for same-system coupling.
Always `Register` in `OnEnable`, `Deregister` in `OnDisable`.

**Order is not a contract.** Subscribers run in registration order, which nobody controls. If one
handler must run before another (a relay before a presentation), make it one ordered stage list or
an explicit call, not two subscriptions.

---

### State (PushdownAutomata)
Alters behavior when internal state changes. PDA variant uses a stack so interrupted states resume.

**Unity form:** `StateController<T> : MonoBehaviourUpdatable` — see `u-state` skill for full API.

**When to use:** any game object with distinct modes (player, enemy, menus, game flow).

---

### Factory Method / Abstract Factory
Creates objects without specifying exact classes. Abstract Factory produces families of related objects.

**Unity forms:**
- Factory SO: `CreateXxx()` returns a new runtime object; `UpdateXxx(instance)` hot-patches it
- Abstract Factory SO: abstract base SO with `CreateXxx()`, concrete subclasses in the Inspector
- `[CreateAssetMenu]` on all concrete SOs

**When to use:** when the type of object to create should be designer-selectable.

---

### Command
Encapsulates requests as objects, allowing parameterization, queuing, and undo.

**Unity forms:**
- Input buffer: `CombatInputBuffer` stores typed button events with timestamps for deferred processing
- Ability phases: `IPipelineStep` / `IAbilityPhase` — each phase is an encapsulated action
- Game state transitions: typed request objects submitted to an orchestrator buffer per-tick
- Turn actions: `ITurnAction` is a request the simulation carries out (`CarryOutAsync`), so the same
  action can be chosen, previewed, inserted out of turn or replayed

**When to use:** input with grace windows; ability execution pipelines; undoable actions.

---

### Mediator
Centralizes communication between objects so they don't refer to each other directly.

**Unity forms:**
- `EventBus<T>` — all participants communicate through the bus, not each other
- Extensions Modifiers `Mediator` — `mediator.Query(key, baseValue, context)` routes through all `IModifierStrategy` implementations; callers never reference individual modifiers

**When to use:** stat/buff systems where multiple modifiers all affect the same value; decoupling event producers from consumers.

---

### Composite
Treats individual objects and compositions of objects uniformly.

**Unity form:** `ICondition<TContext>` (Extensions.Logic) — `And`, `Or`, `Not`, `Leaf` composable conditions. Use `[SerializeReference]` in SOs to build condition trees in the Inspector.

**When to use:** complex prerequisite systems (ability conditions, quest objectives, unlock gates).

---

## Use When the Problem Fits

### Chain of Responsibility
Passes requests along a chain of handlers until one handles it.

**Unity forms:**
- Motion pipeline stages / `IMotionStage` — each stage reads the context and modifies velocity or
  state. Orchestrator runs them in priority order. A stage can short-circuit by marking the request
  consumed.
- Blow stages / `IBlowStage` — `CombatContext.Strike` runs guards, then technique defence, then a
  real-time hit's own guard; the first to answer the blow decides it.

**When to use:** multi-step processing pipelines (physics, damage calculation, AI decision trees).
State the order in one place (a priority or an ordered list), never by registration order.

---

### Adapter
Converts the interface of a class into another interface clients expect.

**Unity forms:**
- `PlayerInputAdapter : IInputSource` — adapts Unity Input System callbacks to a domain event interface
- `AnimancerAnimationDriver : IAnimationDriver` — adapts Animancer API to a domain animation interface
- `IMotionInputProvider` — projects `IInputSource` world-space input for the physics system

**When to use:** bridging an external SDK/library to a domain interface so the library stays swappable.

---

### Template Method
Defines the skeleton of an algorithm in a base class and lets subclasses fill in specific steps.

**Unity forms:**
- Abstract SO base classes (`IntGeneratorConfig`, `SampleTreeProviderBase`) with `CreateGenerator()` / `Values`
- Abstract state base (`EnemyState`) with overrideable lifecycle methods

**When to use:** shared algorithm skeleton with per-subtype variation in specific steps.

---

### Decorator
Attaches additional responsibilities to an object dynamically.

**Unity form:** Extensions Modifiers system — each `IModifierStrategy` wraps the base stat query and
adds behavior (multiply speed, clamp range, add flat bonus) without subclassing or modifying base classes.

**Also:** `ElementalScale` wraps a blow's amount with the dealer's dealt and the target's taken stat
for its element, without the damage formula knowing elements exist.

**When to use:** runtime-composable behavior on top of existing objects (buffs, status effects, equipment).

---

### Flyweight
Shares the unchanging part of many objects so each instance holds only its own state.

**Unity form:** ScriptableObject definitions (`TechniqueDefinition`, `StatusEffectDefinition`,
`StatDefinition`) shared by every fighter that uses them; the runtime instance holds only per-fighter
state (stacks, remaining turns, cooldowns). Never copy a definition's data into each instance.

**When to use:** many runtime objects built from the same authored data.

---

### Builder
Constructs complex objects step by step.

**Unity forms:**
- State machine builder: `new IdleState().AsInitialState(grounded).WithParent(active).WithActivity(anim)`
- Pipeline step construction: adding `InsertStep` / `ReplaceStep` before executing an `AbilityPipeline`

**When to use:** when the construction of a complex object has many optional parameters or depends on runtime data.

---

### Facade
Provides a simplified interface to a complex subsystem.

**Unity forms:**
- `Services.Get<T>()` — single access point to all registered services
- Extensions library itself — a facade over many utility implementations

**When to use:** simplifying access to a complex subsystem for common use cases.

---

## Avoid

| Pattern | Why to avoid | Use instead |
|---------|-------------|-------------|
| **Singleton** | Hard to test, hides dependencies, pollutes global state | `Services.Get<T>()` |
| **Heavy DI (Zenject)** | Complexity without proportional benefit for game projects | Constructor injection + `ServiceBootstrapper` |
| **Service Locator as a crutch** | Can hide poor architecture if overused | Prefer direct injection at composition roots |
| **Visitor** | Needs type dispatch and edits every visitor for a new type | A member on the declared type, or a strategy |
| **Ambient static state** | Leaks between tests and fights | Pass it in; or a scoped static that restores itself on dispose, with a test |
| **A pattern with one implementation and no second in sight** | Speculative generality: indirection with no payoff | The plain class; extract the interface when the second case arrives |
