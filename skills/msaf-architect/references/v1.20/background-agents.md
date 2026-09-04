# 🧵 Background Agents (v1.20)

`BackgroundAgentsProvider` is an `AIContextProvider` that lets a parent agent delegate work to named background agents through tools, wait on them, and keep going. This page covers the two host responsibilities the surface puts on you: **releasing** a session so abandoned tasks stop, and — from v1.20 — **bounding** how long the wait tool may block a run. For the decorator stack around an agent's chat client see [Agent Middleware and Routing](agent-middleware.md); for constructing the agent itself see [Agent Layer Core](agent-layer-core.md).

> [!WARNING]
> **Everything here is behind `MAAI001`** — `BackgroundAgentsProvider` *and* `BackgroundAgentsProviderOptions` are gated at the type level in every version tested, 1.17.0 through 1.20.0, so a project that so much as constructs the options gets a compile error until it suppresses the diagnostic (`<NoWarn>$(NoWarn);MAAI001</NoWarn>`, scoped to that project). The package documentation adds a security note worth repeating: every background agent you hand the provider receives text from the parent agent and feeds text back into its context, so an untrusted agent is an exfiltration and prompt-injection path.

---

## 🧹 Releasing a session

`BackgroundAgentsProvider` — experimental (`MAAI001`) in every version tested here, 1.17.0 through 1.20.0 — takes a session out of service:

```csharp
// Signature: ReleaseSessionAsync(AgentSession session, bool cancelRunning = true,
//                                TimeSpan? timeout = null, CancellationToken cancellationToken = default)
await provider.ReleaseSessionAsync(session);                          // cancel in-flight tasks, wait up to 30 s
await provider.ReleaseSessionAsync(session, cancelRunning: false);    // throws if any task is still running
```

- Background tasks keep invoking models and tools after the host stops using the session that started them. Call this when a conversation ends, or from your eviction policy, so abandoned work stops instead of running to completion for nobody.
- Only `session` is required, and `cancelRunning` defaults to `true` — compile-test facts the surface dump cannot show. Per the package documentation: a `null` timeout means 30 seconds, an infinite timespan waits indefinitely, `cancelRunning: false` throws while tasks are still running, and when the timeout elapses the remaining tasks are abandoned — of these, only the *acceptance* of `null` and `Timeout.InfiniteTimeSpan` was executed (on an idle session, 1.20.0); the waiting behaviour itself was not. The returned `Task` completes normally either way, so put your own deadline token on the call and log it if abandonment matters.
- Releasing an already-released session raises nothing — executed against the pinned 1.18.0 packages on a session that had started no task; the in-flight-task path was not exercised. Afterwards the start/continue background tools refuse to run for that session (package documentation).

## ⏱️ Bounding the wait tool: `WaitTimeout`

`BackgroundAgentsProviderOptions.WaitTimeout` arrived in **v1.20** and is the entire 1.19.0 → 1.20.0 surface diff. Per the package documentation it bounds how long the provider's **wait tool** blocks the parent agent's run for a background task to finish — a different timeout from `ReleaseSessionAsync`'s, and the two disagree about infinity:

```csharp
var provider = new BackgroundAgentsProvider(agents, new BackgroundAgentsProviderOptions
{
    WaitTimeout = TimeSpan.FromSeconds(90),   // default: 5 minutes
});
```

Executed against the pinned 1.20.0 packages:

- The default is **`00:05:00`** — five minutes of the run blocked per wait, which is a long time for a chat turn; set it from the host's own latency budget.
- **The options type validates nothing; the provider constructor does.** `options.WaitTimeout = TimeSpan.Zero` is accepted silently, and `new BackgroundAgentsProvider(agents, options)` then throws **`ArgumentOutOfRangeException`** naming the `options` parameter. Build the options where you build the provider, or the failure surfaces far from the assignment.
- The accepted range is **1 ms through 4,294,967,294 ms** inclusive (the package documents the upper bound as the largest delay the targeted .NET runtimes support); `TimeSpan.Zero`, any negative value, and **`Timeout.InfiniteTimeSpan`** are all rejected. That last one is the trap: `ReleaseSessionAsync(session, timeout: Timeout.InfiniteTimeSpan)` **completed** on the same provider, while the same value here throws. A `null` options argument is accepted.
- **The release timeout is not validated up front.** On a session that had started no task, `ReleaseSessionAsync` with `Timeout.InfiniteTimeSpan`, with `null`, and with a **negative** timeout all completed — the `ArgumentOutOfRangeException` the package documents for a negative release timeout was not observed on that path, so it is evidently raised only when there is work to wait for. A misconfigured shutdown timeout will pass every test that never has a task in flight.
- Per the package documentation (not executed here — it needs a live model): when the timeout elapses the tool **returns control to the agent and leaves the background tasks running**; nothing is cancelled. Releasing the session is still your job.
- Against 1.19.0 the property does not exist (CS1061), so a shared options block is the first thing that breaks when a solution pins its MAF packages at two versions.

## 🛠️ Engineering guidance

- Build `BackgroundAgentsProviderOptions` where you build the provider. The options type validates nothing, so a bad `WaitTimeout` set in one place throws from a constructor somewhere else.
- Treat the wait as part of the turn's latency budget: five minutes is the default, not a recommendation.
- Release the session from the same place you evict or end the conversation, and put your own deadline token on the call — the returned `Task` completes normally whether the tasks finished or were abandoned.

## ⚠️ Adoption traps

| Trap | Reality |
| --- | --- |
| Passing `Timeout.InfiniteTimeSpan` as `WaitTimeout` because `ReleaseSessionAsync` accepts it | The provider constructor throws **`ArgumentOutOfRangeException`** — the wait tool's timeout must be positive and finite (at most 4,294,967,294 ms). The two timeouts on this type have opposite infinite semantics. |
| Trusting a test with no running task to validate the release timeout | It will not: a negative `ReleaseSessionAsync` timeout completed on an idle session (executed on 1.20.0). Exercise the path with a task in flight, or validate the value yourself. |
| Setting a bad `WaitTimeout` on the options and expecting the setter to complain | The options type accepts any value; the throw comes later, from `new BackgroundAgentsProvider(…)`. |
| Expecting the wait tool to cancel anything when `WaitTimeout` elapses | Per the package documentation it returns control to the agent and **leaves the tasks running**. Only `ReleaseSessionAsync` stops them. |
| Passing `null` as the timeout to `ReleaseSessionAsync` and expecting `WaitTimeout` to apply | The two are unrelated: `null` there means 30 seconds (package documentation). `WaitTimeout` governs the wait tool only. |

## ✅ Review checklist

- Every host that starts background agents releases the session on conversation end or eviction.
- `WaitTimeout` is set from the host's latency budget, or the five-minute default is a documented decision.
- The `MAAI001` suppression for the provider is scoped to the project that owns it, and every background agent it is given is one you would trust with the parent's context.

---
*Verified against MAF v1.20.0 DLL surface and compile tests (2026-09-03). `WaitTimeout` is the entire 1.19.0 → 1.20.0 surface diff. **Executed against the pinned 1.20.0 packages** (`msaf-dll-analyzer/probes/probe-v120-wait-timeout`): the five-minute default, the accepted range of 1 ms through 4,294,967,294 ms, the rejection of zero, negative and `Timeout.InfiniteTimeSpan` values, the `ArgumentOutOfRangeException` from the provider constructor (`ParamName` = `options`) rather than from the setter, the acceptance of `null` options, and — on a session that had started no task — `ReleaseSessionAsync` completing with `Timeout.InfiniteTimeSpan`, with `null`, with a negative timeout, and when called a second time; the same probe fails against 1.19.0 with CS1061/CS0117, and built unsuppressed against 1.17.0, 1.18.0, 1.19.0 and 1.20.0 it reports `MAAI001` on both `BackgroundAgentsProvider` and `BackgroundAgentsProviderOptions`. What the wait tool governs and does when the timeout elapses, the 30-second `null` default of `ReleaseSessionAsync`, the upper bound's rationale, and the security note are package documentation, marked as such; the release path with a task in flight was not exercised. **Provenance of the carried material:** `ReleaseSessionAsync`, its optional parameters and the release of an already-released session were compiled and executed on pinned **1.18.0**, where they fail against 1.17.0 (CS1061/CS0117); the in-flight-task path was not exercised. Page created 2026-09-03 by splitting the v1.20 agent-middleware page to keep each inside the per-page budget; the release section was consolidated into that page on 2026-09-01 from the v1.18 guide. No claim was re-dated.*
