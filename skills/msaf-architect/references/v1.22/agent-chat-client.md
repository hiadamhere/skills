# 🔌 Exposing an Agent as a Chat Client (v1.22)

`AIAgentExtensions.AsIChatClient` wraps an agent as a `Microsoft.Extensions.AI.IChatClient`. It preserves the agent pipeline; it does not extract the underlying model client. The extension is `MAAI001`-gated in 1.22.0.

```csharp
// Microsoft.Agents.AI 1.22.0; suppress MAAI001 in the consuming project.
// agent is a ChatClientAgent, or a decorator exposing one through GetService.
using IChatClient stateless = agent.AsIChatClient();

AgentSession session = await agent.CreateSessionAsync();
using IChatClient stateful = agent.AsIChatClient(
    session, conversationId: "conversation-42");
```

## Pick the session contract

| Client | Caller supplies | Response conversation ID |
| --- | --- | --- |
| No bound session | Full history on each call | null; service IDs are cleared |
| Bound session | New messages only, optionally echoing the returned ID | The fixed explicit ID, or a generated client ID |

A conversation ID without a session is rejected with `ArgumentException`. For a bound client, an echoed matching ID is stripped before the agent sees the options; a different nonblank ID is rejected with `InvalidOperationException`. Bind another session to address another conversation.

> [!WARNING]
> Do not share a session-bound client between users or run concurrent requests through it. The session accumulates history and is not synchronized. The package contract requires one in-flight request per bound client.

By default, an agent must be a `ChatClientAgent` or expose one through unkeyed `GetService`. A custom agent is rejected with `InvalidOperationException`. Passing `allowNonChatClientAgents: true` explicitly accepts the limitations of a custom, remote or workflow agent:

```csharp
using IChatClient adapted = agent.AsIChatClient(
    allowNonChatClientAgents: true);
```

The package contract says the adapter passes options as `ChatClientAgentRunOptions`. Other agent implementations may ignore them. Only `ChatOptions.ResponseFormat` is additionally copied into the general agent run options; do not assume tools, instructions or sampling settings have an effect after opting in.

## Host boundaries

- Filter caller-controlled `ChatOptions`. On agents that honor them, supplied tools are added and instructions appended; this is not a harmless model-settings bag.
- Stateless here means no bound session. Agent-wide state or a separately configured service conversation can still persist between calls.
- Per the package contract, continuation/background responses do not round-trip through this adapter. Use the agent API for that workflow.
- The adapter rewrites conversation IDs, not all response metadata. Review other fields before returning provider responses to an untrusted caller.
- The package specifies that an empty bound stream still emits a conversation-ID update. Do not treat this as proof of generated text.

---
*Verified against MAF v1.22.0 DLL surface, package XML contract and pinned compile/execution probe (2026-09-19). Executed offline with a custom agent: default rejection, opt-in, sessionless ID clearing, bound-session identity, echoed-ID stripping and mismatched-ID rejection. Streaming edge cases, continuation limitations and caller-option merging above are attributed package contracts, not live-provider execution results.*
