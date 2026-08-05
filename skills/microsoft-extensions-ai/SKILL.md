---
name: microsoft-extensions-ai
description: Verified, version-matched guidance for the Microsoft.Extensions.AI unified LLM abstractions for .NET (IChatClient, streaming, ChatOptions, tool/function calling, embeddings, middleware pipeline). Use when writing C# that talks to LLMs through Microsoft.Extensions.AI. Every API is verified against the real assemblies.
---

# 🧩 Microsoft.Extensions.AI

`Microsoft.Extensions.AI` is .NET's **unified abstraction layer for LLMs** — one `IChatClient` / `IEmbeddingGenerator` contract that every provider (OpenAI, Azure AI, Ollama, …) implements, plus a middleware pipeline for function-calling, caching, telemetry, and logging.

> [!IMPORTANT]
> **API ground-truth alignment.** The core abstractions reached **GA** and the surface renamed several pre-GA members. LLM training data and tutorials mix the old preview API with the new one: `CompleteAsync` does not exist (use `GetResponseAsync`), and `ChatCompletion` does not exist (the response type is `ChatResponse`). Trust the reference guides here, verified against the real assemblies, not memory.

---

## Instructions

Reach for this skill whenever generating C# against `Microsoft.Extensions.AI`. Start from [`references/chat-client.md`](references/chat-client.md) for the core `IChatClient` calls (get a response, stream, `ChatOptions`). Additional reference guides cover tool/function calling, embeddings, and the `ChatClientBuilder` middleware pipeline as they are added.

**Package split to keep in mind:** the **core** abstractions (the `Microsoft.Extensions.AI` packages) are GA and stable. **Provider adapter** packages (the per-provider adapters) are still **preview** and take breaking changes — pin them and re-verify provider-specific calls against the exact package version you use.

---

## Constraints

- Use `GetResponseAsync` / `GetStreamingResponseAsync`; the old `CompleteAsync` does not exist.
- `ChatOptions` numeric properties are nullable value types (`float?`, `int?`) — pass `0.7f`, not `0.7`.
- Do not write provider-adapter (preview) API from memory; verify against the pinned adapter version.

---

## Ground Truth (BINDING -- see CLAUDE.md Ground-Truth Policy)

The verifiable source is the **`Microsoft.Extensions.AI` NuGet assemblies** — `Microsoft.Extensions.AI.dll` and `Microsoft.Extensions.AI.Abstractions.dll` — reflected metadata-only into versioned API-surface dumps, plus compile tests against the pinned package. No source, no claim. Every reference doc carries a stamp: *Verified against Microsoft.Extensions.AI X.Y.Z DLL surface (YYYY-MM-DD).*
