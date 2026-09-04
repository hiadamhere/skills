# 🧠 Agent Layer Core (v1.18)

The core `AIAgent`, `ChatClientAgent`, `AgentSession`, and `AIAgentBinding` surfaces carry forward from v1.17. Use [the v1.13 agent-layer guide](../v1.13/agent-layer-core.md) for agent construction, sessions, and workflow binding, and [the v1.14 agent-layer guide](../v1.14/agent-layer-core.md) for the asynchronous agent-mode contract, asynchronous message injection, and the approval middleware.

`Microsoft.Agents.AI.Abstractions` and `Microsoft.Agents.AI.Workflows` are **byte-identical to v1.17** by mechanical surface diff. Every v1.18 change is in `Microsoft.Agents.AI`, and this layer takes four of the five new members (the fifth, the auto-approval iteration cap, is in [Agent Skills, Files, and Tool Approval](agent-skills.md)).

## 🆕 Concurrent tool invocation

```csharp
using Microsoft.Agents.AI;

var options = new ChatClientAgentOptions
{
    Name = "analyst",
    AllowConcurrentInvocation = true,   // default: false
};
```

- `AllowConcurrentInvocation` decides whether *this agent's* function-invoking pipeline runs several function calls from one model response **in parallel**. It is independent of the chat-options flag that lets the model *return* several tool calls in one response — one governs what the model may emit, the other how the agent executes it.
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

## 🧹 Releasing a background-agent session

> [!WARNING]
> **`BackgroundAgentsProvider` and `BackgroundAgentsProviderOptions` are both `MAAI001`-gated at the type level** (compile-tested unsuppressed on 1.17.0 through 1.20.0), so a project that so much as constructs the options gets a compile error until it suppresses the diagnostic, scoped to that project. The package documentation adds a security note worth repeating: every background agent you hand the provider receives text from the parent agent and feeds text back into its context, so an untrusted agent is an exfiltration and prompt-injection path.

`BackgroundAgentsProvider` — experimental (`MAAI001`) in every version tested here, 1.17.0 through 1.19.0 — gains one method:

```csharp
// Signature: ReleaseSessionAsync(AgentSession session, bool cancelRunning = true,
//                                TimeSpan? timeout = null, CancellationToken cancellationToken = default)
await provider.ReleaseSessionAsync(session);                          // cancel in-flight tasks, wait up to 30 s
await provider.ReleaseSessionAsync(session, cancelRunning: false);    // throws if any task is still running
```

- Background tasks keep invoking models and tools after the host stops using the session that started them. Call this when a conversation ends, or from your eviction policy, so abandoned work stops instead of running to completion for nobody.
- Only `session` is required, and `cancelRunning` defaults to `true` — compile-test facts the surface dump cannot show. Per the package documentation (not executed here): a `null` timeout means 30 seconds, an infinite timespan waits indefinitely, `cancelRunning: false` throws while tasks are still running, and when the timeout elapses the remaining tasks are abandoned. The returned `Task` completes normally either way, so put your own deadline token on the call and log it if abandonment matters.
- Releasing an already-released session raises nothing — executed against the pinned 1.18.0 packages on a session that had started no task; the in-flight-task path was not exercised. Afterwards the start/continue background tools refuse to run for that session (package documentation).

## 🛠️ Engineering guidance

- Pin the agent, abstractions, and workflows packages to the same `1.18.0` version; the three ship in lockstep.
- Keep agent identity, session identity, and run identity distinct in logs. Recovery and audit questions are asked in terms of all three.
- An agent passed as a Magentic *manager* is an ordinary `AIAgent`; the orchestration behavior lives in the builder, not in a special agent type.
- The v1.14 async migration is still the live one: await mode reads/writes and message injection, and propagate cancellation through both.

## ✅ Review checklist

- `AllowConcurrentInvocation` is `true` only where every tool the agent can call is safe to run alongside every other.
- The invocable-function bypass is enabled only in hosts that actually mix frontend and backend tools, and its `MAAI001` suppression is scoped to that project.
- A custom pipeline that registers `UseInvocableFunctionBypassing` also registers approval-response binding **above** it.
- Every host that starts background agents releases the session on conversation end or eviction.
- Session reuse or isolation is intentional at every call site.
- Mode access and message injection are still awaited, with cancellation propagated (the v1.14 contract is unchanged).

## ⚠️ Adoption traps

<!-- shared:v118-adoption-traps -->
| Trap | Reality |
| --- | --- |
| Suppressing `MAAI001` for the whole v1.18 agent layer | Only `EnableInvocableFunctionBypassing`, `UseInvocableFunctionBypassing`, and `BackgroundAgentsProvider` are gated. `AllowConcurrentInvocation` and `MaxAutoApprovalIterations` compile clean — scope the suppression to what needs it. |
| Treating `AllowConcurrentInvocation` as "let the model call several tools" | That is the chat-options flag. This one decides whether the agent *executes* several returned calls in parallel. `AllowConcurrentInvocation` defaults to `false`; the chat-options flag is a nullable `bool` that defaults to `null` — the provider decides. |
| Reading `MaxAutoApprovalIterations = null` as "unbounded" | `null` means the default, `ToolApprovalAgent.DefaultMaxAutoApprovalIterations` — a `const int` of **40**. It is a constant, so a reflection dump never lists it and assigning to it is CS0131. |
| Registering `UseInvocableFunctionBypassing` above approval-response binding in a custom pipeline | Binding drops responses it never recorded; the bypass injects synthetic ones. In that order the stored calls are silently discarded. Put the bypass **below** binding, above the function-invoking client. |
<!-- /shared:v118-adoption-traps -->

---
*Verified against MAF v1.18.0 DLL surface and compile tests (2026-08-27). The four new members were compiled and executed against the pinned 1.18.0 packages and fail to compile against 1.17.0 (CS1061/CS0117). The `MAAI001` split, the optional parameters and their defaults, and the `false` defaults of both flags are compile-test facts a reflection dump cannot express; the decorator chain order was inspected on a built pipeline, and behaviours attributed to the package documentation are marked as such; the Abstractions and Workflows assemblies are byte-identical to v1.17 by mechanical diff. The adoption-trap table was relocated here from `version-map.md` on 2026-09-01, unchanged in substance. Fixed in place on 2026-09-03: the type-level `MAAI001` warning (compile-tested unsuppressed on 1.17.0–1.20.0) and the package's security note were added to the background-agent section; no other change.*
