# 🐍 MCP in Python (`mcp`)

The official Python SDK builds an MCP **server** from decorated functions: create an `MCPServer`, decorate handlers with `@mcp.tool()`, and run a transport.

> [!WARNING]
> **`from mcp.server.fastmcp import FastMCP` does not exist in `mcp` 2.0.0.** That import is in essentially every MCP tutorial and is what model memory reaches for; in 2.0.0 it fails outright (`ModuleNotFoundError`, and pyright `reportMissingImports`). The class is now **`MCPServer`** in `mcp.server.mcpserver`. This is the single highest-value fact in this document — measured baseline behavior imported the real package in 5 of 5 trials and then hallucinated the API inside it.

---

## Minimal stdio server with one tool

```python
from mcp.server.mcpserver import MCPServer

mcp = MCPServer(name="echo-server", version="1.0.0")


@mcp.tool(description="Echoes the input back.")
def echo(message: str) -> str:
    """Echo the given message."""
    return message


if __name__ == "__main__":
    mcp.run(transport="stdio")
```

* `MCPServer(...)` takes `name`, `title`, `description`, `instructions`, `version`, `icons`, `website_url` — all keyword, all optional.
* `@mcp.tool()` takes `name`, `title`, `description`, `annotations`, `icons`, `meta`, `structured_output` — all optional. Omit `name` and the function's own name is used.
* **Type annotations are the schema.** `message: str` becomes the tool's input schema; the SDK derives it from the signature, so annotate every parameter.
* The docstring supplies the tool description when `description=` is omitted.

## Transports

`run()` takes a literal transport name:

```python
mcp.run(transport="stdio")            # locally launched server -- the default
mcp.run(transport="streamable-http")  # HTTP
mcp.run(transport="sse")              # server-sent events
```

Async equivalents exist for embedding in an existing event loop: `run_stdio_async()`, `run_streamable_http_async()`, `run_sse_async()`. For mounting into an ASGI app, `streamable_http_app()` and `sse_app()` return the application object.

## Names that do not exist

Confirmed by pyright against the pinned package — each fails as a *hard* error, not a warning:

| Reached-for name | Reality |
|---|---|
| `mcp.server.fastmcp` / `FastMCP` | Does not exist in 2.0.0 — use `mcp.server.mcpserver.MCPServer` |
| `mcp.types.ToolResult` | Does not exist — not an exported symbol (it also raises at runtime, not just in the type checker) |

Return an ordinary Python value from a tool. The SDK converts it into the protocol's content blocks; you do not construct a result wrapper yourself.

## Engineering guidance

- **Annotate every parameter and the return.** The annotations *are* the contract the model sees; an unannotated parameter gives it nothing to reason about.
- Write the docstring for the model, not for a maintainer. It is prompt content.
- **stdio servers must keep stdout clean.** The transport is stdout; a stray `print()` corrupts the protocol stream. Use `logging` (which defaults to stderr).
- Keep tool returns small and structured — everything returned re-enters the model's context on the next turn.
- **Pin the `mcp` version.** The 1.x → 2.0 transition moved the primary server class and the import path; a floating dependency turns that into a runtime failure in someone else's environment.
- Type-check the server (`pyright`) before shipping. MCP servers are launched by another process, so an import error usually surfaces as "the server didn't start" with no visible traceback.

## ✅ Review checklist

- Imports `MCPServer` from `mcp.server.mcpserver` — no `fastmcp` anywhere.
- Every tool parameter and return is annotated.
- Docstrings/descriptions are written for the calling model.
- Nothing writes to stdout in a stdio server.
- The `mcp` dependency is pinned, not floating across the 1.x/2.x boundary.
- `pyright` passes against the project's own virtualenv.

---
*Verified against `mcp` 2.0.0 shipped type information and type-checked with `pyright --pythonpath <venv>` (2026-08-06). The absence of `mcp.server.fastmcp` and `mcp.types.ToolResult` was confirmed by pyright and by runtime import against the pinned package.*
