# 🧠 Agent Layer and Tools Integration (v1.14)

The core `AIAgent`, `ChatClientAgent`, `AgentSession`, and `AIAgentBinding` surfaces remain compatible with v1.13. Use the construction and workflow-binding patterns in [the v1.13 guide](../v1.13/agent-layer-core.md). Apply the v1.14 migrations below when the application uses modes, message injection, or approval middleware.

## ⚡ Agent modes are asynchronous

`AgentMode` is the nested type `AgentModeProviderOptions.AgentMode`. Its second constructor argument and property now represent instructions, not a description. Dispose the provider and await mode state access.

```csharp
using Microsoft.Agents.AI;

var options = new AgentModeProviderOptions
{
    Modes =
    [
        new AgentModeProviderOptions.AgentMode(
            "review",
            "Review the proposed change and report concrete defects.")
    ],
    DefaultMode = "review"
};

using var provider = new AgentModeProvider(options);
await provider.SetModeAsync(session, "review", cancellationToken);
string currentMode = await provider.GetModeAsync(session, cancellationToken);
```

## 📨 Message injection is asynchronous

```csharp
await injectingClient.EnqueueMessagesAsync(session, messages, cancellationToken);
IReadOnlyList<ChatMessage> pending =
    await injectingClient.GetPendingMessagesAsync(session, cancellationToken);
```

## 🔐 Approval middleware changed

`ChatClientAgentOptions` now uses opt-out switches:

```csharp
var options = new ChatClientAgentOptions
{
    DisableApprovalNotRequiredFunctionBypassing = false,
    DisableApprovalResponseBinding = false
};
```

The direct builder extensions take an **optional** logger factory — the parameter is `ILoggerFactory? loggerFactory = null`, so `UseApprovalNotRequiredFunctionBypassing()` and `UseApprovalResponseBinding()` compile bare. The surface dump renders the parameter as required; the default is a compile-test fact:

```csharp
ChatClientBuilder builder = chatClient.AsBuilder()
    .UseApprovalNotRequiredFunctionBypassing(loggerFactory)
    .UseApprovalResponseBinding(loggerFactory);
```

Do not use the removed `EnableNonApprovalRequiredFunctionBypassing` option or `UseNonApprovalRequiredFunctionBypassing` extension in a 1.14 project. The full v1.13 → v1.14 rename table stays in [the version map](../version-map.md#-migration-traps-apis-that-were-removed-or-renamed): it names shapes that no longer exist in any current surface, and the version map is the one document checked against every version's dump.

---
*Verified against MAF v1.14.0 DLL surface and compile tests (2026-08-27). Originally verified 2026-07-22; the optional logger-factory parameter was re-verified by compile test against the pinned 1.14.0 packages on 2026-08-27. The core agent and Workflows surfaces otherwise carry forward from v1.13.*
