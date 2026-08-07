---
name: mcp-sdk
description: Verified guidance for building against the Model Context Protocol (MCP) SDKs — defining tools, wiring the stdio transport, and standing up a minimal server with the correct, version-matched API, including which HTTP pieces these packages do and do not ship. Use when writing MCP server/client code. Every API is verified against the real SDK.
---

# 🔌 MCP SDK

The **Model Context Protocol** lets tools/resources be exposed to AI agents over a standard protocol. This skill gives the *correct, version-matched* SDK usage for building an MCP server (and client), grounded in each SDK's real API — not the invented shapes models reach for.

> [!IMPORTANT]
> **MCP postdates most training data, so models fabricate its API.** Measured baseline behavior (no skill): in C# they invent a `ModelContextProtocol.SDK` namespace that does not exist; in Python they import phantom types like `ToolResult`; in TypeScript they often don't reach for `@modelcontextprotocol/sdk` at all. Trust the verified reference here.

---

## Instructions

Reach for this skill when generating MCP server or client code. Pick the language reference:

* **C#** — [`references/csharp.md`](references/csharp.md) (`ModelContextProtocol` package): a hosted `AddMcpServer().WithStdioServerTransport().WithTools<T>()` server with `[McpServerTool]` methods.
* **TypeScript** — [`references/typescript.md`](references/typescript.md) (`@modelcontextprotocol/sdk`): an `McpServer` with `registerTool` + Zod schemas over `StdioServerTransport`.
* **Python** — [`references/python.md`](references/python.md) (`mcp`): an `MCPServer` with `@mcp.tool()`-decorated functions; type annotations are the schema.

---

## Constraints

- C#: server wiring (`AddMcpServer`, `WithStdioServerTransport`, `WithTools<T>`) is in the **`Microsoft.Extensions.DependencyInjection`** namespace; the tool attributes are in `ModelContextProtocol.Server`. There is no `ModelContextProtocol.SDK` namespace.
- A `[McpServerToolType]` class passed to `WithTools<T>()` must **not** be `static` (static types can't be type arguments).
- C#: **`WithHttpTransport()` does not exist** in the pinned packages (CS1061), and there is no `MapMcp`. The turnkey ASP.NET Core wiring lives in a separate `ModelContextProtocol.AspNetCore` package this skill does not verify. The shipped transports are `WithStdioServerTransport()` and `WithStreamServerTransport(input, output)`; `StreamableHttpServerTransport` is a primitive you host yourself, and `HttpClientTransport` is the **client** side despite the name.
- TypeScript: import paths carry a **`.js` suffix** (ESM, `Node16`/`NodeNext` resolution), and tools are registered with **`registerTool`** — the older `tool()`/`resource()`/`prompt()` family is `@deprecated` in the shipped types. A tool result's `content` is an **array of typed blocks**, never a bare string (TS2322).
- Python: **`mcp.server.fastmcp` / `FastMCP` does not exist in `mcp` 2.0.0** — the class is `MCPServer` in `mcp.server.mcpserver`. `mcp.types.ToolResult` does not exist either. Type annotations on the decorated function *are* the input schema.
- **stdio servers must not write to stdout** in any language — the transport is stdout, so a stray `console.log`/`print()` corrupts the protocol stream. Log to stderr.
- Do not write MCP SDK API from memory; verify against the pinned SDK version named in each reference's stamp.

---

## Ground Truth (BINDING -- see CLAUDE.md Ground-Truth Policy)

The verifiable source is each **official MCP SDK** at a pinned version: the C# `ModelContextProtocol` assemblies (`ModelContextProtocol.dll` + `ModelContextProtocol.Core.dll`) reflected metadata-only into versioned API-surface dumps and compile-tested against the pinned package; the TypeScript and Python references are verified against the shipped type information of the pinned `@modelcontextprotocol/sdk` and `mcp` packages, type-checked with `tsc --noEmit` and `pyright --pythonpath <venv>` respectively. No source, no claim. Every reference doc carries a stamp: *Verified against <SDK> <version> (YYYY-MM-DD).*
