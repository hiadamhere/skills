# 🔁 Agent Loops (v1.17)

The loop-agent public API is byte-identical to v1.16. Use the construction, evaluator, termination, and iteration-limit patterns in [the v1.13 loop guide](../v1.13/agent-loops.md), and the engineering guidance in [the v1.14 loop guide](../v1.14/agent-loops.md).

## 🧭 Choosing the right primitive in v1.17

Use a loop when one agent repeatedly produces and evaluates a result. Use a workflow when the system needs typed handoffs, fan-out/fan-in, durable checkpoints, or human requests. If both are needed, wrap the bounded loop as one stage of the workflow rather than recreating workflow routing inside the loop.

For a *manager-led* loop over several participants, the Magentic orchestration builder is the shipped primitive, and its manager prompts are customizable from v1.16 onward. Reach for it before hand-rolling a planner loop; see [Human-in-the-Loop and Routing](hitl-and-routing.md).

## 🛠️ Engineering guidance

- Treat `LoopAgent` as an agent-layer orchestration primitive, not as a replacement for a typed workflow graph.
- Keep a hard iteration bound even when an evaluator can terminate the loop; the bound is the failure-safe for evaluator errors, ambiguous outputs, and non-converging tasks.
- Make the evaluator's success condition narrow and observable. Record why the loop stopped, not only that it stopped.
- Preserve the same `AgentSession` when iterations must share conversational state. Start a new session when isolation is the intended boundary.
- Put irreversible tools behind explicit approval. A loop's autonomy does not weaken the host's approval policy.
- Propagate cancellation from the host through the loop and the wrapped agent calls.

## ✅ Review checklist

1. The iteration limit is explicit and covered by a test.
2. The termination evaluator has positive and negative cases.
3. Session reuse or isolation is intentional.
4. Tool approval and cancellation behavior are preserved on every iteration.
5. Telemetry distinguishes successful completion, iteration exhaustion, cancellation, and failure.

---
*Verified against MAF v1.17.0 DLL surface (2026-08-05). The loop-agent surface is byte-identical to v1.16 by mechanical diff.*
