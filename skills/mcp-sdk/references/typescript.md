# 🟨 MCP in TypeScript (`@modelcontextprotocol/sdk`)

The official TypeScript SDK builds an MCP **server** as an `McpServer` instance: register tools with Zod schemas, connect a transport, and the SDK handles the protocol.

> [!WARNING]
> **Reach for the real package.** Measured baseline behavior (no skill, 5 trials): the model did **not** import `@modelcontextprotocol/sdk` in any of them — it invented a plausible-looking local abstraction instead. There is no "MCP framework" to improvise; the package below *is* the API.

---

## Minimal stdio server with one tool

```ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({ name: "echo-server", version: "1.0.0" });

server.registerTool(
  "echo",
  {
    title: "Echo",
    description: "Echoes the input back.",
    inputSchema: { message: z.string().describe("Text to echo") },
  },
  async ({ message }) => ({
    content: [{ type: "text", text: message }],
  })
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

> [!IMPORTANT]
> **The `.js` extensions in the import paths are required**, even though you are writing TypeScript. The package ships ESM with `Node16` module resolution; dropping them, or importing from a bare `@modelcontextprotocol/sdk`, does not resolve. Your `tsconfig.json` needs `"module": "Node16"` (or `NodeNext`) to match.

## `registerTool`, not `tool`

The SDK carries an older `server.tool(name, cb)` family — the form most samples and model memory reach for — and it is marked **`@deprecated`** in the shipped type definitions. Use `registerTool`.

| Method | Status |
|---|---|
| `registerTool(name, config, cb)` | **current** |
| `registerResource(name, uriOrTemplate, config, cb)` | **current** |
| `registerPrompt(name, config, cb)` | **current** |
| `tool(...)` / `resource(...)` / `prompt(...)` | `@deprecated` — still compiles, so nothing warns you at runtime |

The `config` object accepts `title`, `description`, `inputSchema`, `outputSchema`, `annotations`, and `_meta` — all optional.

## Tool results are content blocks

```ts
async ({ message }) => ({
  content: [{ type: "text", text: message }],
})
```

Returning a bare string (`{ content: "hello" }`) is a **type error** (TS2322) — `content` is an array of content blocks, each tagged with a `type`. This is the most common shape mistake, and the type system does catch it, which is exactly why type-checking generated MCP code is worth doing.

`inputSchema` takes a **plain object of Zod validators**, not a wrapped `z.object({...})`. The SDK builds the JSON Schema from that shape and infers your callback's argument type from it — which is where the typed `{ message }` destructuring comes from.

## Engineering guidance

- **Let the schema do the validating.** `inputSchema` is enforced before your callback runs; re-checking types inside the handler is noise, but checking *business* preconditions is not.
- **`.describe()` every parameter.** That text is what the model sees when deciding how to call your tool — it is prompt content, not documentation.
- Keep tool results small and structured. Everything you return re-enters the model's context on the next turn.
- **stdio servers must keep stdout clean.** The transport *is* stdout; a stray `console.log` corrupts the protocol stream. Log to stderr (`console.error`) instead.
- Validate that your build actually type-checks (`tsc --noEmit`). MCP servers are usually launched by another process, so a shape error surfaces as a silent failure to start rather than a stack trace you see.

## ✅ Review checklist

- Imports use the real package with `.js` path suffixes, under `Node16`/`NodeNext` resolution.
- Tools are registered with `registerTool`, not the deprecated `tool`.
- Every tool result is a `content` **array** of typed blocks.
- Parameters carry `.describe()` text aimed at the model.
- Nothing writes to stdout in a stdio server.
- `tsc --noEmit` passes before the server is shipped or handed to an agent.

---
*Verified against @modelcontextprotocol/sdk 1.30.0 shipped type definitions and type-checked with `tsc --noEmit` (2026-08-06). The `@deprecated` status of the `tool`/`resource`/`prompt` family and the TS2322 on a bare-string `content` are type-checker facts.*
