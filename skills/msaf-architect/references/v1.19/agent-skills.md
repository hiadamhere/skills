# 🧰 Agent Skills, Files, and Tool Approval (v1.19)

The agent-skills, file-access, and tool-approval public API is byte-identical to v1.18. Use [the v1.18 guide](../v1.18/agent-skills.md) for the auto-approval iteration cap (`MaxAutoApprovalIterations`, default 40), [the v1.14 guide](../v1.14/agent-skills.md) for the contextual `ToolAutoApprovalRuleContext` rules and the migration away from bare `FunctionCallContent` lambdas, and [the v1.13 guide](../v1.13/agent-skills.md) for composable skill sources, disposable lifecycle, granular approval flags, and the `AgentFileStore` contract.

## 🔐 Approval guidance

- Auto-approval rules still receive `ToolAutoApprovalRuleContext`. Base policy on trusted identity and session state, not on model-supplied arguments.
- Keep write, delete, deploy, and payment tools explicitly gated regardless of how confident the calling agent appears.
- Log the rule that approved a call, not just the fact that a call was approved — and log when the auto-approval cap ends a run.
- Approval policy is enforced per participant and per route: an agent whose chat client routes per session (see [Agent Layer Core](agent-layer-core.md)) still runs one approval pipeline, so switching route does not widen what a tool call may do. A Magentic manager whose prompts were customized still cannot widen what a participant is allowed to call — do not treat an orchestration prompt as a security control.

## ✅ Review checklist

- Every auto-approval rule has a test for the deny path.
- The auto-approval cap is explicit where the rules are broad, and the surfaced-request path after the cap is handled.
- File-access scopes are least-privilege and asserted in tests.
- Skill sources are disposed on the same lifecycle as the agent that owns them.

---
*Verified against MAF v1.19.0 DLL surface (2026-08-27). The agent-skills, file-access, and tool-approval surfaces are byte-identical to v1.18 by mechanical diff.*
