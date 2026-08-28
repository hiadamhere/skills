# 🧰 Agent Skills, Files, and Tool Approval (v1.18)

The agent-skills, file-access, and tool-approval surfaces carry forward from v1.17. Use [the v1.14 guide](../v1.14/agent-skills.md) for the contextual `ToolAutoApprovalRuleContext` rules and the migration away from bare `FunctionCallContent` lambdas, and [the v1.13 guide](../v1.13/agent-skills.md) for composable skill sources, disposable lifecycle, granular approval flags, and the `AgentFileStore` contract.

v1.18 adds exactly one member to this layer.

## 🆕 The auto-approval loop is bounded

```csharp
using Microsoft.Agents.AI;

var gated = new ToolApprovalAgent(innerAgent, new ToolApprovalAgentOptions
{
    AutoApprovalRules = [ ToolApprovalAgent.AllToolsAutoApprovalRule ],
    MaxAutoApprovalIterations = 8,        // int?; null means ToolApprovalAgent.DefaultMaxAutoApprovalIterations (40)
});
```

- Each time every surfaced approval request is auto-approved, `ToolApprovalAgent` re-invokes the inner agent — a **fresh** call, so a per-request iteration cap inside the chat pipeline restarts every time and cannot bound the loop. A model that keeps requesting an auto-approved tool used to drive an unbounded sequence of billable calls.
- `MaxAutoApprovalIterations` caps those re-invocations within a single run. On reaching it the agent makes **one final** inner invocation without auto-approving, so any remaining request is surfaced to the caller instead of approved silently.
- The default is `null`, which resolves to `ToolApprovalAgent.DefaultMaxAutoApprovalIterations` — a **`const int` of 40**. Being a constant, it is invisible to a reflection dump (which emits non-enum static fields for no type) and assigning to it is **CS0131**.
- Raise the cap only when a longer auto-approval chain is the intended behavior; lower it for agents whose auto-approval rules are broad.
- Not experimental — no diagnostic to suppress.

## 🔐 Approval guidance

- Auto-approval rules still receive `ToolAutoApprovalRuleContext`. Base policy on trusted identity and session state, not on model-supplied arguments.
- Keep write, delete, deploy, and payment tools explicitly gated regardless of how confident the calling agent appears.
- Log the rule that approved a call, not just the fact that a call was approved — and log when the iteration cap ends a run, because that is the signal a model is looping on a tool.
- Approval policy is enforced per participant. A Magentic manager whose prompts were customized still cannot widen what a participant is allowed to call — do not treat an orchestration prompt as a security control.

## ✅ Review checklist

- Every auto-approval rule has a test for the deny path.
- The auto-approval cap is explicit where the rules are broad, and the surfaced-request path after the cap is handled.
- File-access scopes are least-privilege and asserted in tests.
- Skill sources are disposed on the same lifecycle as the agent that owns them.

---
*Verified against MAF v1.18.0 DLL surface and compile tests (2026-08-27). `MaxAutoApprovalIterations` and the constant were compiled and read against the pinned 1.18.0 packages (value 40; CS0131 on assignment proves the `const`) and fail to compile against 1.17.0 (CS1061/CS0117). The rest of the agent-skills, file-access, and tool-approval surface is byte-identical to v1.17 by mechanical diff.*
