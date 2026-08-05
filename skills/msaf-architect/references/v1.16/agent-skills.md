# 🧩 Agent Skills, File Access, and Tool Approval (v1.16)

The agent-skills, file-access, and tool-approval public API is byte-identical to v1.15. Use [the v1.14 guide](../v1.14/agent-skills.md) for the contextual `ToolAutoApprovalRuleContext` rules and the migration away from bare `FunctionCallContent` lambdas, and [the v1.13 guide](../v1.13/agent-skills.md) for composable skill sources, disposable lifecycle, granular approval flags, and the `AgentFileStore` contract.

## 🔐 v1.16 approval guidance

- Auto-approval rules still receive `ToolAutoApprovalRuleContext`. Base policy on trusted identity and session state, not on model-supplied arguments.
- Keep write, delete, deploy, and payment tools explicitly gated regardless of how confident the calling agent appears.
- Log the rule that approved a call, not just the fact that a call was approved.
- Approval policy is enforced per participant. A Magentic manager whose prompts were customized still cannot widen what a participant is allowed to call — do not treat an orchestration prompt as a security control.

## ✅ Review checklist

- Every auto-approval rule has a test for the deny path.
- File-access scopes are least-privilege and asserted in tests.
- Skill sources are disposed on the same lifecycle as the agent that owns them.

---
*Verified against MAF v1.16.0 DLL surface (2026-08-01). The agent-skills and file-store surfaces are byte-identical to v1.15 by mechanical diff.*
