---
name: microsoft-extensions-ai
description: Verified, version-matched guidance for the Microsoft.Extensions.AI unified LLM abstractions for .NET (IChatClient, streaming, ChatOptions, tool/function calling including provider-hosted tools and human approval, structured output, embeddings, the content model, conversation state and background responses, the middleware/DI pipeline, the non-chat client families — images, speech, realtime, hosted files — and routing/failover between chat clients). Use when writing C# that talks to LLMs through Microsoft.Extensions.AI. API signatures are checked against the pinned assemblies; selected behaviors are tested offline.
---

# 🧩 Microsoft.Extensions.AI

Version-matched guidance for **`Microsoft.Extensions.AI`**: shared chat/embedding contracts, middleware and experimental non-chat clients. Provider support must be verified separately.

> [!IMPORTANT]
> **API ground-truth alignment.** The core abstractions reached **GA** and the surface renamed several pre-GA members. LLM training data and tutorials mix the old preview API with the new one. Compile-verified against the pinned package: `CompleteAsync` does not exist (use `GetResponseAsync`, CS1061), `ChatCompletion` does not exist (the response type is `ChatResponse`), `ChatOptions.MaxTokens` does not exist (it is `MaxOutputTokens`, CS0117), and `ChatToolMode.Required` does not exist (it is `RequireAny`, CS0117). Trust the reference guides here, not memory.

---

## Instructions

**Verified baseline: 10.10.0 (2026-09-20).** Resolve the project's package version before using these references. Both assembly surfaces and the deeper shape comparison (defaults, accessors, inheritance and experimental annotations) are unchanged from 10.9.0. All 47 C# reference fences compile against 10.10.0. The component suite adds 31 offline assertions; earlier observational probes were also rerun. See the evidence guide for coverage and integration gaps. This is API-shape compatibility evidence, not a claim that every provider or implementation behavior is unchanged.

Reach for this skill whenever generating C# against `Microsoft.Extensions.AI`. Load the reference that matches the task:

| Task | Reference |
|---|---|
| Read what a response actually contains (reasoning, images, usage, errors) | [content-model.md](references/content-model.md) |
| Call a model, stream, tune with `ChatOptions` | [chat-client.md](references/chat-client.md) |
| Let the model call your code | [tool-calling.md](references/tool-calling.md) |
| Let the provider run a tool (web search, code interpreter, an MCP server), or require a human's approval before yours runs | [hosted-tools-and-approval.md](references/hosted-tools-and-approval.md) |
| Get a typed value instead of prose | [structured-output.md](references/structured-output.md) |
| Vectors for search/RAG | [embeddings.md](references/embeddings.md) |
| Choose a non-chat client family | [beyond-chat.md](references/beyond-chat.md) |
| Generate/edit images and handle result formats | [image-generation.md](references/image-generation.md) |
| Transcribe audio or synthesize speech, including streaming | [speech.md](references/speech.md) |
| Send/receive realtime session events | [realtime.md](references/realtime.md) |
| Upload, list, download and delete hosted files | [hosted-files.md](references/hosted-files.md) |
| Evidence levels, coverage and remaining gaps | [verification-and-coverage.md](references/verification-and-coverage.md) |
| Compose caching/telemetry/function invocation, write your own layer, register in DI | [middleware-and-di.md](references/middleware-and-di.md) |
| Send each request to the right client, or fail over when one is down | [routing-and-failover.md](references/routing-and-failover.md) |

**Two rules that cause most silent failures:**

1. **Tools need middleware.** `ChatOptions.Tools` declares tools; only `UseFunctionInvocation()` executes *your* `AIFunction`s — provider-hosted tools are the provider's to run. Without it the model asks for a call that nobody makes.
2. **Pipeline order is behavior.** The first `Use…` registered is the outermost layer. Where the cache sits relative to function invocation decides whether a cache hit skips the entire tool loop.

> [!IMPORTANT]
> **`MEAI001` is a compile error, not a warning.** The non-chat client families (images, speech, realtime, hosted files), the chat reducers behind `UseChatReducer`, and the 10.9.0 routing/failover clients are `[Experimental("MEAI001")]`: code that uses them does not build until the diagnostic is suppressed — `<NoWarn>$(NoWarn);MEAI001</NoWarn>` in the project, or `#pragma warning disable MEAI001` in the file. Core chat, embeddings, function invocation, caching, logging and telemetry are not gated (the exceptions beside them: the `AIFunctionNameAttribute` / `AIParameterNameAttribute` naming attributes, `HostedToolSearchTool`, and `ToolApprovalRequestContent.RequiresConfirmation`). Suppress deliberately and locally; experimental means the shape may change in a minor release.

**Package split to keep in mind:** the **core** abstractions (the `Microsoft.Extensions.AI` packages) are GA and stable. **Provider adapter** packages have independent release and stability policies. Pin them and re-verify provider-specific calls against the exact adapter version; the core package version does not establish adapter support.

---

## Constraints

- Use `GetResponseAsync` / `GetStreamingResponseAsync`; the pre-GA `CompleteAsync` does not exist.
- `ChatOptions` numeric properties are nullable value types (`float?`, `int?`, `long?`) — pass `0.7f`, not `0.7` (CS0266).
- Never put an `AIFunction` in `ChatOptions.Tools` without `UseFunctionInvocation()` in the pipeline; hosted tools are executed by the provider.
- Bound the tool loop with `MaximumIterationsPerRequest`, and keep `IncludeDetailedErrors = false` outside development.
- Tool arguments are model-supplied input: validate them, and never let them carry authorization.
- Consume `IChatClient` from DI rather than the raw provider client, or the pipeline layers are bypassed.
- Do not write provider-adapter API from memory; verify against the pinned adapter version.
- Suppress `MEAI001` only in the project that uses a gated type, never in a shared props file.
- A stream through a failover client can end in an exception after partial output; consumers must tolerate it.
- Routing and failover clients are root clients, not `Use…` layers — there is no `UseRouting()` or `UseFailover()`; build the pipeline on top of them.
- When the adapter uses `ConversationId` for server-held history, pass that id with only new messages. Confirm the adapter contract before combining local and server-held history.
- `[FromKeyedServices]` on a tool parameter is not a binding — it becomes an argument the model must supply. Take an `IServiceProvider` parameter (bound for you, hidden from the model) and resolve from it — it is the provider the pipeline was built with (DI or the `FunctionInvokingChatClient` constructor); a bare `AsBuilder()` hands tools an empty one.
- A custom `DelegatingChatClient` overrides both `GetResponseAsync` and `GetStreamingResponseAsync`; the base forwards streaming straight to the inner client, so a layer that overrides only one is bypassed by every stream.

---

## Ground Truth (BINDING -- see CLAUDE.md Ground-Truth Policy)

Ground truth is the pinned **`Microsoft.Extensions.AI` NuGet assemblies**, reflected metadata, compiler checks and offline probes. Every reference carries a dated verification stamp. The [evidence guide](references/verification-and-coverage.md) separates API existence, tested behavior and provider integration gaps.

Claims of **absence** require recorded compiler errors. Experimental status uses a reflection sweep of both assemblies plus negative compilation; neither metadata nor compilation proves provider behavior.
