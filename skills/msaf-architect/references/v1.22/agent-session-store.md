# 🗄️ Agent Session Storage (v1.22)

Use `AgentSessionStore` when a host must load and save agent conversations across requests. It is an agent-session contract, separate from workflow checkpointing. The three new types are `MAAI001`-gated: `AgentSessionStore`, `AgentSessionStoreKey`, and `DelegatingAgentSessionStore`.

## Contract and ownership

- `GetSessionAsync(agent, key, cancellationToken)` returns `AgentSession?`; a miss returns null and must not create a session.
- `GetOrCreateSessionAsync(agent, key, cancellationToken)` calls the lookup and creates through the agent on a miss. **It does not save the new session.** Save explicitly after the work you intend to persist.
- `SaveSessionAsync(agent, key, session, cancellationToken)` is implemented by your store. The abstraction does not choose a database or a concurrency policy.
- The package contract requires each successful lookup to return an independent session instance. Persist serialized state and deserialize through the owning agent; do not return a cached mutable session to concurrent callers.

```csharp
// Microsoft.Agents.AI 1.22.0; suppress MAAI001 in the consuming project.
// agent and store are host-owned AIAgent / AgentSessionStore instances.
var key = new AgentSessionStoreKey("conversation-42")
    .WithPartition("tenant", "tenant-a");
AgentSession session = await store.GetOrCreateSessionAsync(agent, key);
// Run the intended turn, then persist it explicitly.
await store.SaveSessionAsync(agent, key, session);
```

The key's `SessionId` and every `Partitions` entry contribute to identity. The implementation must honor all partitions and the owning agent; looking up only the session ID can cross tenant boundaries. Partition names are ordinal and case-sensitive; their ordering does not affect equality or the hash code. `WithPartition` returns a new key when adding/replacing a value and returns the same instance when the value already matches. No partitions means `Partitions` is null, not an empty dictionary.

> [!WARNING]
> A partition is an identifier, not authorization. Derive tenant and user partitions from trusted host context before calling the store. Independent session copies prevent shared-object mutation; they do not resolve conflicting saves. Choose a storage concurrency policy separately.

## Decorators and service lookup

Derive from `DelegatingAgentSessionStore` to add logging or policy around another store. Its constructor accepts the inner store; the inherited lookup and save methods forward to that store. Override only the operations the decorator changes.

`GetService<TService>()` and `GetService(Type, serviceKey)` provide service discovery. The base store returns itself for an assignable type with no key, otherwise null. The decorator forwards discovery to its inner store when appropriate. A minimal subclass accepting the inner store was compiled and exercised against 1.22.0.

## Verification boundaries

The retained offline probe checks a null lookup, creation without implicit save, explicit save forwarding, key equality/hash/partition behavior, and service discovery through a decorator. Its fake store always misses: it proves the base/decorator behavior, not durable storage. Test the independent-instance contract, serialization round trip, isolation and concurrent-save policy against your actual backend.

---
*Verified against MAF v1.22.0 DLL surface, package XML contract and pinned compile/execution probe (2026-09-19). Nullable lookup and optional cancellation/partition parameters compile with nullable checking enabled. The implementation requirements for independent lookup instances come from the package contract; no database backend was tested.*
