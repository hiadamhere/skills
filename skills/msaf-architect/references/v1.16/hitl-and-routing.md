# 🔀 Human-in-the-Loop and Routing (v1.16)

The typed-edge, binding, fan-out/fan-in, and `RequestPort` surfaces are byte-identical to v1.15. Use [the v1.13 routing guide](../v1.13/hitl-and-routing.md) for edges, bindings, and HITL, [the v1.14 routing guide](../v1.14/hitl-and-routing.md) for the routing rules, and [the v1.15 routing guide](../v1.15/hitl-and-routing.md) for the streaming/pending-request interaction.

Human input still uses pending requests and `Run.ResumeAsync`; there is no suspend-by-exception API.

v1.16 changes exactly one thing in this layer: the Magentic orchestration builder can now customize the manager's prompts and its response language.

## 🧲 Magentic prompt customization

> [!WARNING]
> The v1.16 prompt-customization API is marked experimental and raises **`MAAI001` as a compile _error_**, not a warning. Code using `MagenticPromptOverrides`, `MagenticDefaultPrompts`, `WithPromptOverrides`, or `WithResponseLanguage` does not build until the diagnostic is suppressed:
> ```xml
> <NoWarn>$(NoWarn);MAAI001</NoWarn>
> ```
> The pre-existing builder API (`MagenticWorkflowBuilder`, `AddParticipants`, `WithMaxRounds`, `WithMaxStalls`, `RequirePlanSignoff`, `Build`) is **not** gated — only the new prompt surface is. Treat anything behind `MAAI001` as subject to change or removal in a future release, and isolate it behind your own seam.

```csharp
using Microsoft.Agents.AI;
using Microsoft.Agents.AI.Workflows;

Workflow workflow = new MagenticWorkflowBuilder(managerAgent)
    .AddParticipants(participants)
    .WithPromptOverrides(new MagenticPromptOverrides
    {
        ProgressLedgerPrompt = "…",
        FinalAnswerPrompt    = "…",
    })
    .WithResponseLanguage("French")
    .WithMaxRounds(10)
    .Build();
```

### The override slots

`MagenticPromptOverrides` exposes seven prompt slots, one per stage of the Magentic manager's reasoning:

| Property | Stage it replaces |
|---|---|
| `TaskLedgerFactsPrompt` | Initial fact gathering. |
| `TaskLedgerPlanPrompt` | Initial plan construction. |
| `TaskLedgerFullPrompt` | The combined task ledger handed to participants. |
| `TaskLedgerFactsUpdatePrompt` | Fact revision after a reset/replan. |
| `TaskLedgerPlanUpdatePrompt` | Plan revision after a reset/replan. |
| `ProgressLedgerPrompt` | Per-round progress evaluation (stall and completion detection). |
| `FinalAnswerPrompt` | Final answer synthesis. |

`MagenticDefaultPrompts` exposes the shipped default for each slot as a `static readonly string` under the same seven names — read one when you want to extend a default rather than replace it.

> [!IMPORTANT]
> The properties are **`init`-only**. Set them in an object initializer; assigning after construction (`overrides.ProgressLedgerPrompt = "…"`) does not compile. Any slot you leave unset keeps its shipped default, so a partial override is the normal case.

Both new builder methods take a nullable, optional argument (`WithPromptOverrides(MagenticPromptOverrides? = …)`, `WithResponseLanguage(string? = …)`), so passing `null` is a legal "use the defaults" call.

### Engineering guidance

- Override the narrowest slot that solves the problem. Replacing `TaskLedgerFullPrompt` because the final answer read badly discards planning behavior you did not intend to change.
- `ProgressLedgerPrompt` governs stall and completion detection. A weakened version here does not produce a worse answer — it produces a loop that does not terminate. Keep `WithMaxRounds` / `WithMaxStalls` bounds in place as the failure-safe.
- Prefer `WithResponseLanguage` over instructing the language inside a custom prompt; it is the supported seam and survives a prompt-default change.
- Never build an override string from untrusted input. These prompts drive the orchestrator, not a participant turn — injection here redirects the whole run.
- Pin the prompt text you ship and diff it against `MagenticDefaultPrompts` on every MAF upgrade. Defaults evolve; a frozen copy silently diverges.

## 👥 Human-in-the-loop lifecycle

1. An executor creates a request through its `RequestPort`.
2. The host observes the pending request and persists the run identity plus the user-visible decision context.
3. The host validates and records the human response.
4. The run continues through `Run.ResumeAsync` with that response.
5. Cancellation, expiry, duplicate responses, and unauthorized responders are handled as explicit host states.

For Magentic specifically, `RequirePlanSignoff` is the plan-approval gate; do not reimplement it with a custom prompt that merely *asks* the model to wait for approval.

Do not use `WorkflowSuspendedException`; that type is not part of the shipped API. Do not resume a run from display text alone—bind the response to the stored request and run identity.

## ✅ Review checklist

- All edges are type-compatible at `builder.Build()` time.
- Fan-in behavior is tested with late and failed branches.
- Every human request has authorization, expiry, idempotency, and audit rules.
- The stream's pending-request behavior is chosen deliberately, not inherited by accident.
- Resume tests use the real pending-request path rather than an invented exception flow.
- `MAAI001` suppression is scoped and reviewed, and experimental usage is isolated behind a project seam.
- Overridden prompts are version-pinned and diffed against `MagenticDefaultPrompts` at upgrade time.
- Round/stall bounds remain in place after any `ProgressLedgerPrompt` override.

## ⚠️ Adoption traps

<!-- shared:v116-magentic-adoption-traps -->
| Trap | Reality |
| --- | --- |
| Writing `overrides.ProgressLedgerPrompt = "…"` after construction | `MagenticPromptOverrides` properties are **`init`-only**. Use an object initializer; the surface dump's `{ get; set; }` cannot distinguish `init` from `set`. |
| Expecting the v1.16 Magentic prompt API to just compile | It raises **`MAAI001` as an error**. Add `<NoWarn>$(NoWarn);MAAI001</NoWarn>`. The pre-existing `MagenticWorkflowBuilder` methods are not gated. |
| Copying a default prompt once and freezing it | `MagenticDefaultPrompts` values are shipped defaults that evolve. Diff your overrides against them at every upgrade. |
<!-- /shared:v116-magentic-adoption-traps -->

---
*Verified against MAF v1.16.0 DLL surface and compile tests (2026-08-01). The `init`-only accessors, the optional/nullable parameters, the `MagenticDefaultPrompts` members, and the `MAAI001` error severity are compile-test facts — a metadata surface dump cannot express any of them. The adoption-trap table was relocated here from `version-map.md` on 2026-09-01, unchanged in substance.*
