# Extensions Library Reference

The same Extensions library ships across all projects (Treeformance, HackNSlashGame, EnergyCombat).
**Always check here before proposing a new utility class.**

---

## Core Systems

| Class | Namespace | Summary |
|-------|-----------|---------|
| `EventBus<T>` | `Extensions.EventBus` | Static typed global bus. `Register(IEventBinding<T>)` / `Deregister` / `Raise(T)`. Register in `OnEnable`, deregister in `OnDisable`. |
| `EventBinding<T>` | `Extensions.EventBus` | Concrete binding. Supports `Action<T>` or parameterless `Action`. |
| `PushdownAutomata<T>` | `Extensions.PushdownAutomata` | Stack-based FSM. `ChangeState(T)` / `Interrupt(T)` / `ResumePrevious()`. |
| `StateController<T>` | `Extensions.PushdownAutomata` | `MonoBehaviourUpdatable` wrapper around `PushdownAutomata`. States receive full lifecycle callbacks. |
| `Entity<T>` | `Extensions.EntityComponent` | Component dictionary on any object. `AddComponent<T>()` / `GetComponent<T>()`. Plugin extension point. |
| `MonoBehaviourUpdatable` | `Extensions.Other` | Gives generic plain C# classes `Update` / `FixedUpdate` / `LateUpdate` via a proxy MonoBehaviour. |
| `WrappedField<T>` | `Extensions.Other` | Getter/setter proxy with an `OnChanged` callback. |

---

## Logic & Rules

| Class | Namespace | Summary |
|-------|-----------|---------|
| `ICondition<TContext>` | `Extensions.Logic` | Composable boolean. Implementations: `AndCondition`, `OrCondition`, `NotCondition`, `LeafCondition`. Use `[SerializeReference]` to build trees in SOs. |
| `RuleSystem<TContext, TResult>` | `Extensions.Rules` | Bucketed rules engine. `IRule<TEvent, TContext, TResult>` registered per event type. `Evaluate(event, context)` returns the first matching result. |

---

## Modifiers (HackNSlash / EnergyCombat)

| Class | Namespace | Summary |
|-------|-----------|---------|
| `IModifierStrategy` | Extensions Modifiers | Strategy for modifying a stat query result. |
| `Mediator` | Extensions Modifiers | Routes `mediator.Query(IQueryKey, baseValue, context)` through all registered `IModifierStrategy` instances. |
| `QueryContext` | Extensions Modifiers | Context object passed to every modifier in the chain. |
| `IQueryKey` | Extensions Modifiers | Typed query key (e.g. `QueryKey.MoveSpeed`). Prefer typed constants over raw enum values. |

Usage:
```csharp
float speed = _mediator.Query(QueryKey.MoveSpeed, _config.BaseSpeed, _context);
```

---

## Timers (PlayerLoop-injected, not MB Update)

| Class | Summary |
|-------|---------|
| `CountdownTimer` | Counts down from a duration; `OnTimerStart` / `OnTimerStop` delegates. |
| `FrequencyTimer` | Fires at a fixed rate (Hz). `OnTick` delegate. |
| `IntervalTimer` | Fires after a delay, then repeats. |
| `TickTimer` | Fixed number of ticks then stops. |
| `StopwatchTimer` | Counts up; query `ElapsedTime`. |

All timers implement `IDisposable`. `bool UseUnscaledTime` supported. Delegates initialized to
`delegate { }` — always callable without null-checking. Registered with `TimerManager` which runs
via Unity's `PlayerLoop` (not per-MB `Update`).

```csharp
var timer = new CountdownTimer(3f);
timer.OnTimerStop += () => SpawnEnemy();
timer.Start();
// ...
timer.Dispose();
```

---

## Utilities

| Class | Namespace | Summary |
|-------|-----------|---------|
| `CircularList<T>` | `Extensions.Utils.CollectionUtil` | Fixed-size ring buffer with circular indexing. |
| `InverseLookup<TKey,TVal>` | `Extensions.Utils.CollectionUtil` | Bidirectional dictionary. |
| `TransformUtil` | `Extensions.Utils` | Common transform helpers (world-local conversion, hierarchy ops). |
| `MathUtil` | `Extensions.Utils` | Game math helpers. |
| `TweenUtil` | `Extensions.Utils` | Tween/interpolation helpers complementing PrimeTween. |
| `AudioUtil` | `Extensions.Utils` | Audio playback helpers; detect FMOD availability. |
| `EaseUtil` | `Extensions.Utils` | Easing functions including `Damp` (framerate-independent smoothing). |
| `SODEvaluator` | `Extensions.Other` | Evaluates second-order spring dynamics for smooth camera/motion following. |
| `SecondOrderDynamics` | `Extensions.Other` | Underlying spring simulation with configurable frequency, damping, and initial response. |

---

## Quick Lookup

Before writing any of the following, check Extensions first:

| Need | Extension to use |
|------|-----------------|
| Global typed event | `EventBus<T>` |
| Stack-based FSM | `PushdownAutomata<T>` / `StateController<T>` |
| Timer (countdown, repeating, tick) | Timers family |
| Composable boolean condition | `ICondition<TContext>` |
| Rules engine | `RuleSystem<TContext, TResult>` |
| Stat/buff modifier pipeline | Modifiers `Mediator` + `IModifierStrategy` |
| Plugin extension point on MB | `Entity<T>` |
| Plain C# gets Unity Update loop | `MonoBehaviourUpdatable` |
| Smooth spring following | `SODEvaluator` / `SecondOrderDynamics` |
| Ring buffer | `CircularList<T>` |
| Framerate-independent smoothing | `EaseUtil.Damp` |
