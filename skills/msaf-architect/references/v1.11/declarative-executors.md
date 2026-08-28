# 🏷️ Declarative Executors (v1.11)

An executor can declare *what it handles* with attributes instead of overriding a dispatch method. Five attributes carry that declaration — `[MessageHandler]`, `[SendsMessage]`, `[StreamsMessage]`, `[YieldsMessage]`, `[YieldsOutput]` — and one `protected` method wires them up.

This is how you write an executor that handles **several message types**, which the `Executor<TInput>` shape cannot express.

> [!WARNING]
> **`ReflectingExecutor<TExecutor>` is `[Obsolete]` and slated for removal**, in v1.11 and every version since — its own message reads *"Use `[MessageHandler]` attribute on methods in a partial class deriving from `Executor`. This type will be removed in a future version."* It still compiles and still runs, so nothing tells you at the point of use except a **CS0618** warning you may have suppressed. **A surface dump cannot show this at all** — the analyzer emits members, not the attributes decorating a type — so the reflected surface presents a deprecated type as the natural way to write a multi-message executor. It is not.

## ✅ The Current Shape

Derive `Executor` directly and implement `ConfigureProtocol`:

```csharp
using Microsoft.Agents.AI.Workflows;

internal sealed class Router : Executor
{
    public Router(string id) : base(id) { }

    [MessageHandler]
    public ValueTask HandleText(string message, IWorkflowContext context)
        => context.YieldOutputAsync(message.Length);

    protected override ProtocolBuilder ConfigureProtocol(ProtocolBuilder protocol)
        => protocol
            .AddClassAttributeTypes(typeof(Router))
            .AddMethodAttributeTypes(typeof(Router).GetMethod(nameof(HandleText))!)
            .YieldsOutput<int>()
            .ConfigureRoutes(routes => routes.AddHandler<string>(HandleText));
}
```

Run that and the executor reports `InputTypes = System.String`, `OutputTypes = System.Int32`, and a `"hello"` input yields `5`.

> [!IMPORTANT]
> **`ConfigureProtocol` is `protected abstract`, so it does not appear in the surface dump either** — omit it and you get **CS0534**, naming a member you cannot find in the reflected API. Together with the obsolete marker above, both halves of the current authoring model are invisible to a reader working from the dump alone.

> [!WARNING]
> **The attributes do not wire themselves.** `[MessageHandler]` is *metadata*, not registration. `AddClassAttributeTypes` and `AddMethodAttributeTypes` are what read the attribute family into the protocol, and `ConfigureRoutes(...AddHandler<T>(...))` is what actually routes a message to a method. Decorating a method and stopping there declares an intention nothing acts on.
>
> **The obsoletion message describes a generator that is not in the package.** It says *"a partial class deriving from `Executor`"*, but `Microsoft.Agents.AI.Workflows` 1.17.0 ships no `analyzers/` folder, and a partial `Executor` subclass with only `[MessageHandler]` methods fails with **CS0534** — nothing generates `ConfigureProtocol` for you. Write it by hand; `partial` alone buys nothing today.

## 🧾 The Five Attributes

| Attribute | Applies to | Says |
|---|---|---|
| `[MessageHandler]` | method | this method handles a message; optional `Yield` and `Send` (`Type[]`) declare what it produces |
| `[SendsMessage(typeof(T))]` | class | this executor sends `T` to its edges |
| `[YieldsMessage(typeof(T))]` | class | this executor yields `T` as a message |
| `[StreamsMessage(typeof(T))]` | class | this executor streams `T` |
| `[YieldsOutput(typeof(T))]` | class | this executor produces `T` as workflow output |

`MessageHandlerAttribute` is the only one with settable properties; the other four take their `Type` in the constructor and expose it read-only.

```csharp
[SendsMessage(typeof(int))]
[YieldsOutput(typeof(string))]
internal sealed class Declared : Executor
{
    public Declared(string id) : base(id) { }

    [MessageHandler(Yield = new[] { typeof(string) }, Send = new[] { typeof(int) })]
    public ValueTask Handle(string message, IWorkflowContext context)
        => context.YieldOutputAsync(message);

    protected override ProtocolBuilder ConfigureProtocol(ProtocolBuilder protocol)
        => protocol.AddClassAttributeTypes(typeof(Declared))
                   .ConfigureRoutes(routes => routes.AddHandler<string>(Handle));
}
```

## 🎛️ Routing by Hand

`ProtocolBuilder.ConfigureRoutes` hands you a `RouteBuilder`, whose `AddHandler<TInput>` and `AddHandler<TInput, TResult>` overloads accept an `Action` or `Func`, with or without a `CancellationToken`, sync or `ValueTask`. Each takes an `overwrite` flag for replacing an existing route.

`AddCatchAll(...)` registers a fallback over `PortableValue` for messages no typed route claims — the executor equivalent of a default case, and the thing to reach for when a workflow silently drops messages.

`ProtocolBuilder` also offers the direct declarations `SendsMessage<T>()`, `SendsMessageType(Type)`, `SendsMessageTypes(IEnumerable<Type>)`, `YieldsOutput<T>()`, `YieldsOutputType(Type)` and `YieldsOutputTypes(IEnumerable<Type>)` — use them when the types are known at the call site and attributes would only add indirection.

## 🪜 When To Use Which

| Your executor… | Shape |
|---|---|
| handles one message type, returns nothing | `Executor<TInput>`, override `HandleAsync` |
| handles one message type, returns a result | `Executor<TInput, TOutput>`, override `HandleAsync` |
| handles **several** message types | `Executor` + `ConfigureProtocol` + `[MessageHandler]` methods |
| needs a fallback for unmatched messages | `ConfigureRoutes(r => r.AddCatchAll(...))` |

`Executor<TInput>` and `Executor<TInput, TOutput>` implement `IMessageHandler<TMessage>` and `IMessageHandler<TMessage, TResult>` from `Microsoft.Agents.AI.Workflows.Reflection`, and their `HandleAsync` takes an optional `CancellationToken`.

See [Workflow Events](workflow-events.md) for what an executor emits while running, and [State and Persistence](state-and-persistence.md) for what it can remember between supersteps.

---
*Verified against MAF v1.11.0 DLL surface (2026-08-12). The `[Obsolete]` marker on `ReflectingExecutor<TExecutor>` and the `protected abstract ConfigureProtocol` are invisible to a reflection dump — the analyzer emits public members, not type attributes — and were established by compiler diagnostics (CS0618, CS0534) against pinned packages. The obsolete marker was confirmed present in **1.11.0, 1.14.0 and 1.17.0**; the absence of a source generator was established by inspecting the 1.17.0 package (no `analyzers/` folder) and by CS0534 on a partial `Executor` subclass. The current shape was **executed**, not merely compiled: the routed executor reports `InputTypes = System.String`, `OutputTypes = System.Int32`, and yields `5` for `"hello"`.*
