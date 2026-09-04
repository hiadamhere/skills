# 🧬 Agent Middleware and Routing (v1.20)

Everything that wraps an agent's chat client. For constructing the agent itself — sessions, bindings, modes — see [Agent Layer Core](agent-layer-core.md); for `BackgroundAgentsProvider` — releasing a session, the v1.20 `WaitTimeout` — see [Background Agents](background-agents.md).

The decorator stack is registered outermost-first by `ChatClientBuilder`, and the order is load-bearing: get it wrong and calls are discarded silently rather than loudly.

---

## 🔐 Approval middleware

`ChatClientAgentOptions` uses **opt-out** switches for the approval decorators:

```csharp
var options = new ChatClientAgentOptions
{
    DisableApprovalNotRequiredFunctionBypassing = false,
    DisableApprovalResponseBinding = false
};
```

The direct builder extensions take an **optional** logger factory — the parameter is `ILoggerFactory? loggerFactory = null`, so `UseApprovalNotRequiredFunctionBypassing()` and `UseApprovalResponseBinding()` compile bare. The surface dump renders the parameter as required; the default is a compile-test fact.

```csharp
ChatClientBuilder builder = chatClient.AsBuilder()
    .UseApprovalNotRequiredFunctionBypassing(loggerFactory)
    .UseApprovalResponseBinding(loggerFactory);
```

## ⚙️ Concurrent tool invocation

```csharp
using Microsoft.Agents.AI;

var options = new ChatClientAgentOptions
{
    Name = "analyst",
    AllowConcurrentInvocation = true,   // default: false
};
```

- `AllowConcurrentInvocation` decides whether *this agent's* function-invoking pipeline runs several function calls from one model response **in parallel**. It is independent of the chat-options flag that lets the model *return* several tool calls in one response — one governs what the model may emit, the other how the agent executes it. `AllowConcurrentInvocation` defaults to `false`; the chat-options flag is a nullable `bool` defaulting to `null`, meaning the provider decides.
- It has no effect when `UseProvidedChatClientAsIs` is `true`; a custom pipeline configures its own function-invoking client directly.
- Tools that share mutable state, or that must observe each other's results, keep the default. Turning this on is a statement that every tool the agent can call is safe to run alongside every other.
- Not experimental — it compiles without any diagnostic suppression.
- What was executed: the flag's presence, its `false` default, and an agent running with it set. The parallel execution itself is the package's documented behaviour and was not observed in the probe.

## ⚗️ Invocable-function bypass (experimental)

> [!WARNING]
> `EnableInvocableFunctionBypassing` and `UseInvocableFunctionBypassing` raise **`MAAI001` as a compile error** until suppressed with `<NoWarn>$(NoWarn);MAAI001</NoWarn>`. `AllowConcurrentInvocation` is **not** gated. Isolate the experimental flag behind your own seam; it may change or vanish in a later minor release.

The problem it solves: a model response that mixes an *invocable* (backend) function call with a *declaration-only* (frontend, e.g. a UI-executed tool) call. The function-invoking client stops its loop at the declaration-only call and returns **every** call in that iteration unexecuted. The caller resolves the frontend call, the backend call's id is left orphaned, and the provider rejects the next request. With the bypass on, the backend calls are stored in the session and executed on the next request instead.

```csharp
using Microsoft.Agents.AI;
using Microsoft.Extensions.AI;

// Default pipeline: opt in on the options.
var options = new ChatClientAgentOptions { EnableInvocableFunctionBypassing = true };   // default: false

// Custom pipeline (UseProvidedChatClientAsIs = true): register the decorators yourself, in this order.
ChatClientBuilder builder = chatClient.AsBuilder()
    .UseApprovalResponseBinding(loggerFactory)      // outermost: drops approval responses it never recorded
    .UseInvocableFunctionBypassing(loggerFactory);  // below binding; loggerFactory is optional
// ...then register the function-invoking client last, so it sits innermost.
```

- It is **opt-in** (default `false`) — the mirror image of the v1.14 approval-not-required bypass, which is on by default and switched off with `DisableApprovalNotRequiredFunctionBypassing`.
- The package documents the decorator's place as **above** the function-invoking client and **below** the approval-response binding decorator: binding drops any approval response it never recorded, and the responses this bypass injects are synthetic — in the wrong order they are silently discarded and the stored calls never run. `ChatClientBuilder` registers outermost-first, so the order in the sample is the order to write; the built chain was inspected (binding → bypass → function invocation). The discard itself is the package's documented behaviour and was not reproduced here.
- The decorator class itself is not public. The option flag and the builder extension are the only seams the surface exposes.
- `Clone()` on `ChatClientAgentOptions` carries both new flags.

## ⚗️ Session-persisted chat-client routing (experimental)

> [!WARNING]
> `RoutePersistingRoutingChatClient` and `RoutePersistingRoutingChatClientOptions` raise **`MAAI001` as a compile error** until suppressed with `<NoWarn>$(NoWarn);MAAI001</NoWarn>`. Treat the type as subject to change and keep it behind your own seam.

`RoutePersistingRoutingChatClient` derives from `Microsoft.Extensions.AI.RoutingChatClient` and holds several named inner clients. Which one answers a request is decided **per agent session**, and that choice is written into the session's `AgentSessionStateBag`, so it survives for the session's lifetime and across serialization. Because conversation history is carried by the agent's session rather than by the routed client, switching route mid-conversation hands the full history to whichever client takes the next turn.

```csharp
using Microsoft.Agents.AI;
using Microsoft.Extensions.AI;

var routes = new Dictionary<string, IChatClient>
{
    ["fast"]  = fastClient,
    ["smart"] = smartClient,
};

var router = new RoutePersistingRoutingChatClient(routes,
    new RoutePersistingRoutingChatClientOptions { DefaultRoute = "fast" });   // options are optional

AIAgent agent = new ChatClientAgent(router, instructions: "…", name: "triage");
AgentSession session = await agent.CreateSessionAsync();

string active = router.GetActiveRoute(session);      // "fast" — DefaultRoute, else the first entry
router.SetActiveRoute(session, "smart");             // must be a registered route
await agent.RunAsync("Escalate this.", session);     // answered by "smart"; history is the session's, not the client's
```

What the compile and execution tests established beyond the surface:

- **It works only inside an agent run.** The client resolves the current session from the running agent; calling it directly (`GetResponseAsync` on the router outside `RunAsync`) throws an **InvalidOperationException** that says so. It is an agent building block, not a general-purpose router.
- `GetActiveRoute` returns a non-nullable `string`. A fresh session already has a route: `DefaultRoute` when set, otherwise the **first entry** of the dictionary you passed (both `DefaultRoute` and `StateKey` default to `null`). An unregistered `DefaultRoute` is accepted by the constructor and returned by `GetActiveRoute`; the first run then throws an **InvalidOperationException** (*"No usable chat client is registered for the active route"*). With an empty dictionary and no default, `GetActiveRoute` itself throws an **InvalidOperationException**.
- `SetActiveRoute` with a name that is not a registered, usable route throws an **ArgumentException** naming the `route` parameter. The route is validated when selected, not when the options are built.
- The choice **survives `SerializeSessionAsync` / `DeserializeSessionAsync`** — it is stored in the state bag under a key that defaults to the type name (`StateKey` overrides it when two routers share one session).
- `Routes` is a **mutable** copy of the constructor dictionary; routes added afterwards are selectable. Mutate it only when no request is in flight.
- `OwnsInnerClients` defaults to `false` — you dispose the inner clients unless you say otherwise. Removing a route hands its client's lifetime back to you even when it is `true`.
- All route clients must use client-side conversation history; service-stored history is isolated to the service that created it and cannot follow a route switch.
- **Middleware wraps the router, not the routes.** Anything that must apply to every route — the function-invoking client above all — wraps `RoutePersistingRoutingChatClient`; decorating individual route clients gives each route its own stack (package documentation).
- A single session must not be used concurrently; the per-session routing state assumes one request in flight per session (package documentation).

## 🔬 Feature-usage tracking (experimental, infrastructure)

`FeatureUsage` is a `static` class in `Microsoft.Agents.AI.Abstractions`, also behind `MAAI001`. `MarkUsed(int index)` sets one of 128 process-wide feature bits (idempotent, never reset in production); `ApplyToUserAgent(string userAgent, bool includeFeatureToken)` appends — or, with `false`, strips — a single `feat=` comment carrying that bitmask. Executed against the pinned packages, marking bit 0 and applying the token to a User-Agent of MyApp/1.0 yields **MyApp/1.0 (feat=v1.1)**; applying it with `false` strips the comment again.

The package documents it as **not intended for direct use by applications**: it exists so framework integrations can report which features a process used. Two consequences for a host: the token is not a per-call count, and `ApplyToUserAgent` does not check where the request is going — a caller that forwards it must decide independently that the destination is approved. Setting the `AGENT_FRAMEWORK_FEATURE_MASK_DISABLED` environment variable to `true` or `1` turns marking into a no-op.

## 🛠️ Engineering guidance

- Route on facts the host owns — plan tier, cost budget, escalation state — and store the decision by calling `SetActiveRoute` on the session, never by swapping the agent's client.
- Register the decorator stack in one place and test the built chain, not the intent. Order is the failure mode here, and it fails silently.
- Scope every `MAAI001` suppression to the project that owns the experimental usage.

## ⚠️ Adoption traps

The `MAAI001` gate is **per member**: only `EnableInvocableFunctionBypassing` and `UseInvocableFunctionBypassing` are gated on this page (`BackgroundAgentsProvider` and its options type, gated too, are on [Background Agents](background-agents.md)); `AllowConcurrentInvocation` compiles clean. The auto-approval cap `MaxAutoApprovalIterations` is not gated either and lives in [Agent Skills, Files, and Tool Approval](agent-skills.md), where its `const` default of 40 is documented.

| Trap | Reality |
| --- | --- |
| Calling `RoutePersistingRoutingChatClient` directly | It resolves the session from the running agent and throws an **InvalidOperationException** outside `RunAsync` / `RunStreamingAsync`. Route through an agent, always. |
| Routing to a route name that was never registered | `SetActiveRoute` throws an **ArgumentException**. An unregistered `DefaultRoute` is accepted by the constructor and returned by `GetActiveRoute`; the first run then throws an **InvalidOperationException** (*"No usable chat client is registered for the active route"*), and an empty routes dictionary with no default makes `GetActiveRoute` itself throw. Validation happens at selection, not construction. |
| Pinning `Microsoft.Extensions.AI` below 10.9.0 next to MAF 1.19.0 or 1.20.0 | Both depend on 10.9.0 (1.17/1.18: 10.7.0); the routing client's base type lives there. Let the dependency float or pin at least 10.9.0. |

## ✅ Review checklist

- Every route registered on a routing client uses client-side history.
- `SetActiveRoute` is called with names that exist and `DefaultRoute` names a registered route; the exception paths for an unknown route are tested.
- The router is only ever invoked through an agent run, and its `MAAI001` suppression is scoped to the project that owns it.
- Inner-client disposal is explicit: either `OwnsInnerClients = true` or a host-owned lifetime.
- `AllowConcurrentInvocation` is `true` only where every tool the agent can call is safe to run alongside every other.
- The invocable-function bypass is enabled only in hosts that actually mix frontend and backend tools, and a custom pipeline registers approval-response binding **above** it.

---
*Verified against MAF v1.20.0 DLL surface and compile tests (2026-09-03). The routing client, its options, and `FeatureUsage` were compiled and executed against the pinned 1.19.0 packages and fail to compile against 1.18.0 (CS0246/CS0103); the `MAAI001` gate, the optional `options` parameter, the `null` defaults, the non-nullable `GetActiveRoute` return, the inside-a-run-only behavior, the exception types, the state-bag key, and the 10.9.0 dependency bump are compile-, execution-, or package-metadata facts a reflection dump cannot express. **Provenance of the carried-forward material:** the approval middleware and its optional `ILoggerFactory` were compile-tested on pinned **1.14.0** (re-verified 2026-08-27); concurrent invocation and the invocable-function bypass were compiled and executed on pinned **1.18.0**, where they fail against 1.17.0 (CS1061/CS0117), and the decorator chain order was inspected on a built pipeline. Behaviours attributed to the package documentation are marked as such throughout. Those claims rest on the compiles named above rather than on byte-identity, which cannot carry a parameter default. The `MAAI001` per-member split is an attribute fact and is therefore not carried by byte-identity either: it was re-confirmed against the 1.19.0 packages in the same sweep recorded on the production-readiness page. Page created 2026-09-01 by splitting the v1.19 agent-layer material to keep each page inside the per-page budget; no claim was re-dated. Copied forward from the v1.19 page on 2026-09-03: the 1.19.0 → 1.20.0 surface diff is a single added member, `BackgroundAgentsProviderOptions.WaitTimeout`, which is documented and executed on the [Background Agents](background-agents.md) page — split from this one on the same date so that each stays inside the per-page budget — so the re-stamp rests on that mechanical diff and every compile and execution fact above keeps the pin it names; no claim was re-dated.*
