---
name: mcp-sdk
description: Verified guidance for building against the Model Context Protocol (MCP) SDKs — defining tools, wiring stdio/HTTP transports, and standing up a minimal server with the correct, version-matched API. Use when writing MCP server/client code. Every API is verified against the real SDK.
---

# 🔌 MCP SDK

The **Model Context Protocol** lets tools/resources be exposed to AI agents over a standard protocol. This skill gives the *correct, version-matched* SDK usage for building an MCP server (and client), grounded in each SDK's real API — not the invented shapes models reach for.

> [!IMPORTANT]
> **MCP postdates most training data, so models fabricate its API.** Measured baseline behavior (no skill): in C# they invent a `ModelContextProtocol.SDK` namespace that does not exist; in Python they import phantom types like `ToolResult`; in TypeScript they often don't reach for `@modelcontextprotocol/sdk` at all. Trust the verified reference here.

---

## Instructions

Reach for this skill when generating MCP server or client code. Pick the language reference:

* **C#** — [`references/csharp.md`](references/csharp.md) (`ModelContextProtocol` package): a hosted `AddMcpServer().WithStdioServerTransport().WithTools<T>()` server with `[McpServerTool]` methods.
* **TypeScript** and **Python** references are being added next (the `@modelcontextprotocol/sdk` and `mcp` packages), each verified against the pinned SDK before publish.

---

## Constraints

- C#: server wiring (`AddMcpServer`, `WithStdioServerTransport`, `WithTools<T>`) is in the **`Microsoft.Extensions.DependencyInjection`** namespace; the tool attributes are in `ModelContextProtocol.Server`. There is no `ModelContextProtocol.SDK` namespace.
- A `[McpServerToolType]` class passed to `WithTools<T>()` must **not** be `static` (static types can't be type arguments).
- Do not write MCP SDK API from memory; verify against the pinned SDK version named in each reference's stamp.

---

## Ground Truth (BINDING -- see CLAUDE.md Ground-Truth Policy)

The verifiable source is each **official MCP SDK** at a pinned version: the C# `ModelContextProtocol` assemblies (`ModelContextProtocol.dll` + `ModelContextProtocol.Core.dll`) reflected metadata-only into versioned API-surface dumps and compile-tested against the pinned package; the TypeScript/Python references (when added) are verified against the shipped type information (`tsc` / `pyright`) of the pinned `@modelcontextprotocol/sdk` and `mcp` packages, plus the MCP spec. No source, no claim. Every reference doc carries a stamp: *Verified against <SDK> <version> (YYYY-MM-DD).*
