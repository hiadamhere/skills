# 🧭 Navigation, MVVM, and Dependency Injection

The navigation model is one of the hardest decisions to reverse in a MAUI app: it shapes the back stack, deep linking, view-model lifetime, and how state survives suspension. Decide it deliberately, before feature work spreads assumptions through every page.

Resolve the project's toolchain first ([version and sources](version-and-sources.md)). This guide is about **structure and tradeoffs** — confirm exact APIs and behavior against the project's SDK and the matching official documentation, never from memory.

---

## 🗺️ Choosing a navigation model

| Model | Fits | Costs you |
|---|---|---|
| **Shell** | Apps with a stable top-level structure (tabs/flyout), URI-style routes, and deep links | A prescribed navigation shape; bending it to unusual flows fights the framework |
| **Page-stack navigation** | Wizard/linear flows, or apps whose structure does not map to tabs/flyout | You build routing, deep linking, and structure yourself |
| **Modal / nested stacks** | Interruptions: sign-in, consent, pickers | Extra lifecycle and back-behavior cases to test on every platform |

Pick **one primary model** and treat the others as exceptions inside it. A codebase that mixes two primary models arrives at pages that cannot be reached the same way twice, and back behavior that differs by entry path.

**Decide these together with the model — they are all consequences of it:**

- **Route ownership.** Where routes are declared, and whether a page can be reached by more than one route.
- **Deep links and cold start.** A deep link may arrive with no back stack. Decide what "back" does then, and verify on each platform — this is a common source of platform-only defects.
- **Back-stack policy.** What is popped on sign-out, what survives a tab switch, what a hardware/system back gesture means on each target.
- **Parameter passing.** Prefer identifiers over object graphs. Passing a live object across navigation couples two view models and breaks when the target is restored from a cold start rather than constructed.
- **Result return.** How a pushed page returns a value. Decide once; ad-hoc callbacks and static state are how navigation becomes untestable.

> [!IMPORTANT]
> **A deep-linked or restored page must be able to construct its own state from its parameters alone.** If it depends on state a previous page happened to leave behind, it works in manual testing and fails on cold start, process restart, and back-navigation from a notification.

## 🧩 MVVM boundaries

- **View models do not reference pages, controls, or platform types.** The moment one does, it stops being unit-testable and starts being a second view.
- **Navigation is a service to the view model**, behind a narrow interface. The view model asks to go somewhere; the implementation knows how. This keeps navigation policy testable and lets the model change without rewriting view models.
- **Keep constructors cheap and synchronous.** Do initialization in a lifecycle-aware, cancellable operation, not in a constructor that blocks or fires and forgets.
- **Treat lifecycle callbacks as re-entrant.** Appearing/disappearing can fire more than once. Guard initialization, cancel superseded work, and unsubscribe symmetrically with subscription.
- **Commands express what the user can do, including when they cannot.** Model busy and failure states explicitly rather than disabling controls from code-behind.

## 🔌 Dependency injection and lifetimes

Register services at app startup and resolve view models through the container rather than constructing them in navigation calls.

| Lifetime | Use for | Watch for |
|---|---|---|
| **Singleton** | Stateless services, caches, platform abstractions | Anything holding per-user or per-session state leaks across sign-out |
| **Scoped** | Per-flow or per-navigation state, where the model supports a scope | Scope boundaries in a mobile app are not the web's request boundary — define yours explicitly |
| **Transient** | View models and short-lived helpers | A transient that subscribes to a singleton event and is never disposed is the classic MAUI leak |

> [!WARNING]
> **A page that outlives its view model, or a view model that outlives its page, is a leak in waiting.** Decide which owns which, dispose subscriptions on the same lifecycle as the object that created them, and verify with a memory snapshot after repeated navigation — not by inspection.

Prefer constructor injection into view models. Service location from a page or view model hides dependencies from tests and makes lifetime bugs invisible until runtime.

## ✅ Review checklist

- One primary navigation model, with exceptions named and justified.
- Every page reachable by deep link constructs its state from parameters alone, and is tested from cold start.
- Back behavior after a deep link is defined and verified on each target platform.
- View models reference no page or platform type.
- Navigation is behind an interface the view model can be tested without.
- Service lifetimes are chosen deliberately; subscriptions are disposed on the owner's lifecycle.
- Repeated navigate-away/navigate-back does not grow memory (measured, not assumed).

---
*Reflects official .NET MAUI documentation and dotnet/maui engineering guidance (2026-08-06). Navigation APIs, route syntax, and lifecycle callback names must be resolved from the target project's SDK and the matching official documentation — this guide asserts structure and tradeoffs, not signatures.*
