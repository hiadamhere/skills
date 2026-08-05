# 🧩 Agent Skills, File Access, and Tool Approval (v1.14)

The v1.13 composable skill sources, disposable lifecycle, granular approval flags, and renamed `AgentFileStore` contract remain available. Use [the v1.13 guide](../v1.13/agent-skills.md) for those patterns.

## 🔐 Tool auto-approval rules receive context

In v1.14, every auto-approval rule receives `ToolAutoApprovalRuleContext` instead of a bare `FunctionCallContent`. The context exposes the call plus the agent, session, request messages, and run options, allowing policy to consider more than the function name.

```csharp
using Microsoft.Agents.AI;

var options = new ToolApprovalAgentOptions
{
    AutoApprovalRules =
    [
        context => new ValueTask<bool>(
            context.FunctionCallContent.Name == "read_file" &&
            context.RequestMessages.Count > 0)
    ]
};
```

The built-in rules on `AgentSkillsProvider`, `FileAccessProvider`, and `ToolApprovalAgent` have the same contextual delegate shape and can still be assigned directly.

## ⬆️ Migration

Replace lambdas such as:

```csharp
call => new ValueTask<bool>(call.Name == "read_file")
```

with:

```csharp
context => new ValueTask<bool>(
    context.FunctionCallContent.Name == "read_file")
```

Do not auto-approve mutating tools solely from model-supplied arguments. Base policy on trusted identity/session state and keep write operations explicitly gated.

---
*Verified against MAF v1.14.0 DLL surface and compile tests (2026-07-22). The remaining agent-skills and file-store surfaces carry forward from v1.13.*
