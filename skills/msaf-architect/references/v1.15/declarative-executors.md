# 🏷️ Declarative Executors (v1.15)

The declarative executor surface is **identical to v1.11** — the five attributes, `ProtocolBuilder`, `RouteBuilder`, and the `protected abstract ConfigureProtocol` are unchanged.

Use [the v1.11 declarative executors guide](../v1.11/declarative-executors.md) as written: derive `Executor`, implement `ConfigureProtocol`, and route with `ConfigureRoutes(...AddHandler<T>(...))`.

> [!WARNING]
> **`ReflectingExecutor<TExecutor>` is `[Obsolete]` here too** — confirmed present in 1.11.0, 1.14.0 and 1.17.0. It compiles and runs, so only a **CS0618** warning marks it. No surface dump can show this: the analyzer emits members, not the attributes on a type.

The v1.11 guide's traps are unchanged in v1.15:

<!-- shared:declarative-executor-traps -->
> [!WARNING]
> **The attributes do not wire themselves.** `[MessageHandler]` is *metadata*, not registration. `AddClassAttributeTypes` and `AddMethodAttributeTypes` are what read the attribute family into the protocol, and `ConfigureRoutes(...AddHandler<T>(...))` is what actually routes a message to a method. Decorating a method and stopping there declares an intention nothing acts on.
>
> **The obsoletion message describes a generator that is not in the package.** It says *"a partial class deriving from `Executor`"*, but `Microsoft.Agents.AI.Workflows` 1.17.0 ships no `analyzers/` folder, and a partial `Executor` subclass with only `[MessageHandler]` methods fails with **CS0534** — nothing generates `ConfigureProtocol` for you. Write it by hand; `partial` alone buys nothing today.
<!-- /shared:declarative-executor-traps -->

For what an executor emits while running see [Workflow Events](workflow-events.md); for the orchestration builders that save you writing executors at all see [Orchestration Patterns](orchestration-patterns.md).

---
*Verified against MAF v1.15.0 DLL surface (2026-08-12). The `[Obsolete]` marker on `ReflectingExecutor` and the `protected abstract ConfigureProtocol` (CS0618, CS0534) are invisible to a reflection dump; the v1.11 guide's current shape was executed, not merely compiled.*
