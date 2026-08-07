---
name: microsoft-extensions-ai
description: Verified, version-matched guidance for the Microsoft.Extensions.AI unified LLM abstractions for .NET (IChatClient, streaming, ChatOptions, tool/function calling, structured output, embeddings, and the middleware/DI pipeline). Use when writing C# that talks to LLMs through Microsoft.Extensions.AI. Every API is verified against the real assemblies.
---

# 🧩 Microsoft.Extensions.AI

This skill embeds the verified API surface and the engineering discipline for **`Microsoft.Extensions.AI`**, .NET's unified abstraction layer for LLMs — one `IChatClient` / `IEmbeddingGenerator` contract that every provider (OpenAI, Azure AI, Ollama, …) implements, plus a middleware pipeline for function invocation, caching, telemetry, and logging.

> [!IMPORTANT]
> **API ground-truth alignment.** The core abstractions reached **GA** and the surface renamed several pre-GA members. LLM training data and tutorials mix the old preview API with the new one. Compile-verified against the pinned package: `CompleteAsync` does not exist (use `GetResponseAsync`, CS1061), `ChatCompletion` does not exist (the response type is `ChatResponse`), `ChatOptions.MaxTokens` does not exist (it is `MaxOutputTokens`, CS0117), and `ChatToolMode.Required` does not exist (it is `RequireAny`, CS0117). Trust the reference guides here, not memory.

---

## Instructions

Reach for this skill whenever generating C# against `Microsoft.Extensions.AI`. Load the reference that matches the task:

| Task | Reference |
|---|---|
| Call a model, stream, tune with `ChatOptions` | [chat-client.md](references/chat-client.md) |
| Let the model call your code | [tool-calling.md](references/tool-calling.md) |
| Get a typed value instead of prose | [structured-output.md](references/structured-output.md) |
| Vectors for search/RAG | [embeddings.md](references/embeddings.md) |
| Compose caching/telemetry/function invocation; register in DI | [middleware-and-di.md](references/middleware-and-di.md) |

**Two rules that cause most silent failures:**

1. **Tools need middleware.** `ChatOptions.Tools` declares tools; only `UseFunctionInvocation()` executes them. Without it the model asks for a call that nobody makes.
2. **Pipeline order is behavior.** The first `Use…` registered is the outermost layer. Where the cache sits relative to function invocation decides whether a cache hit skips the entire tool loop.

**Package split to keep in mind:** the **core** abstractions (the `Microsoft.Extensions.AI` packages) are GA and stable. **Provider adapter** packages are still **preview** and take breaking changes — pin them and re-verify provider-specific calls against the exact package version you use.

---

## Constraints

- Use `GetResponseAsync` / `GetStreamingResponseAsync`; the pre-GA `CompleteAsync` does not exist.
- `ChatOptions` numeric properties are nullable value types (`float?`, `int?`, `long?`) — pass `0.7f`, not `0.7` (CS0266).
- Never set `ChatOptions.Tools` without `UseFunctionInvocation()` in the pipeline.
- Bound the tool loop with `MaximumIterationsPerRequest`, and keep `IncludeDetailedErrors = false` outside development.
- Tool arguments are model-supplied input: validate them, and never let them carry authorization.
- Consume `IChatClient` from DI rather than the raw provider client, or the pipeline layers are bypassed.
- Do not write provider-adapter (preview) API from memory; verify against the pinned adapter version.

---

## Ground Truth (BINDING -- see CLAUDE.md Ground-Truth Policy)

The verifiable source is the **`Microsoft.Extensions.AI` NuGet assemblies** — `Microsoft.Extensions.AI.dll` and `Microsoft.Extensions.AI.Abstractions.dll` — reflected metadata-only into versioned API-surface dumps, plus compile tests against the pinned package. No source, no claim. Every reference doc carries a stamp: *Verified against Microsoft.Extensions.AI X.Y.Z DLL surface (YYYY-MM-DD).*

Claims of **absence** are compile-tested, not merely grepped: `CompleteAsync`, `ChatOptions.MaxTokens`, and `ChatToolMode.Required` do not exist in the pinned surface, and each is recorded with the exact compiler error it produces.
