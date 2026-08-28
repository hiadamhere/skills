# 🧠 Agent Layer Core (v1.19)

The core `AIAgent`, `ChatClientAgent`, `AgentSession`, and `AIAgentBinding` surfaces carry forward from v1.18. Use [the v1.13 agent-layer guide](../v1.13/agent-layer-core.md) for agent construction, sessions, and workflow binding, [the v1.14 agent-layer guide](../v1.14/agent-layer-core.md) for the asynchronous agent-mode contract and the approval middleware, and [the v1.18 agent-layer guide](../v1.18/agent-layer-core.md) for concurrent tool invocation, the invocable-function bypass, and background-session release.

v1.19 adds two things to this layer: a chat client that **routes per session**, and a process-wide feature-usage tracker in the abstractions assembly. It also moves the framework's `Microsoft.Extensions.AI` dependency from 10.7.0 (v1.17 and v1.18) to **10.9.0** — the new routing client's base type lives there.

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
- Pin the agent, abstractions, and workflows packages to the same `1.19.0` version, and let the 10.9.0 `Microsoft.Extensions.AI` dependency flow transitively rather than pinning an older one alongside it.
- Keep agent identity, session identity, and run identity distinct in logs; a routed agent adds the active route as a fourth dimension worth recording per turn.
- The v1.14 async migration is still the live one: await mode reads/writes and message injection, and propagate cancellation through both.

## ✅ Review checklist

- Every route registered on a routing client uses client-side history.
- `SetActiveRoute` is called with names that exist and `DefaultRoute` names a registered route; the exception paths for an unknown route are tested.
- The router is only ever invoked through an agent run, and its `MAAI001` suppression is scoped to the project that owns it.
- Inner-client disposal is explicit: either `OwnsInnerClients = true` or a host-owned lifetime.
- Session reuse or isolation is intentional at every call site.
- An agent passed as a Magentic *manager* is an ordinary `AIAgent`; the orchestration behavior lives in the builder, not in a special agent type.

---
*Verified against MAF v1.19.0 DLL surface and compile tests (2026-08-27). The routing client, its options, and `FeatureUsage` were compiled and executed against the pinned 1.19.0 packages and fail to compile against 1.18.0 (CS0246/CS0103). The `MAAI001` gate, the optional `options` parameter, the `null` defaults, the non-nullable `GetActiveRoute` return, the inside-a-run-only behavior, the exception types, the state-bag key, and the 10.9.0 dependency bump are compile-, execution-, or package-metadata facts a reflection dump cannot express.*
