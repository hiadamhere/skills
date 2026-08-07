# 🟦 MCP in C# (`ModelContextProtocol`)

The official C# SDK builds an MCP **server** as a hosted service: register it on the DI container, choose a transport, and expose tools as attributed methods. Add the `ModelContextProtocol` package (`dotnet add package ModelContextProtocol --prerelease`) plus `Microsoft.Extensions.Hosting`.

> [!IMPORTANT]
> **There is no `ModelContextProtocol.SDK` namespace** — that is a common hallucination. Server wiring (`AddMcpServer`, `WithStdioServerTransport`, `WithTools<T>`) lives in the **`Microsoft.Extensions.DependencyInjection`** namespace; the tool attributes (`[McpServerTool]`, `[McpServerToolType]`) live in `ModelContextProtocol.Server`.

---

## Minimal stdio server with one tool

```csharp
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using ModelContextProtocol.Server;
using System.ComponentModel;

var builder = Host.CreateApplicationBuilder(args);
builder.Services
    .AddMcpServer()
    .WithStdioServerTransport()
    .WithTools<EchoTools>();
await builder.Build().RunAsync();

[McpServerToolType]
public class EchoTools
{
    [McpServerTool, Description("Echoes the input back.")]
    public static string Echo(string message) => message;
}
```

* `AddMcpServer()` (extension on `IServiceCollection`) returns an `IMcpServerBuilder`; chain the transport and tool registrations onto it.
* `WithStdioServerTransport()` runs the server over stdin/stdout — the standard transport for a locally-launched MCP server.
* `WithTools<T>()` scans a **`[McpServerToolType]`** class for **`[McpServerTool]`** methods. The type argument **must not be a `static` class** (`static` types can't be type arguments — `CS0718`); mark the class non-static and the tool methods `static`.
* `[Description]` (the standard System.ComponentModel attribute) supplies the tool/parameter descriptions the client sees.
* The host's `RunAsync()` keeps the server alive; don't wrap it in your own stdin loop.

## Registering tools other ways

`WithTools<T>()` is the typed form. The surface also offers:

* `WithToolsFromAssembly()` — scan the calling (or a given) assembly for every `[McpServerToolType]`.
* `WithTools(IEnumerable<McpServerTool>)` — register pre-built `McpServerTool` instances (create them with `McpServerTool.Create(...)`).

## Tool results

Returning a `string` (as above) is the simplest case. For richer results a tool can return a `CallToolResult`, whose `Content` is an `IList<ContentBlock>` (e.g. text blocks) — use this when a tool produces structured or multi-part output.

## Transports: what these packages actually give you

> [!WARNING]
> **`WithHttpTransport()` does not exist** on `IMcpServerBuilder` in these packages — it fails with **CS1061**, and there is no `MapMcp` anywhere in either surface. The turnkey ASP.NET Core wiring that most samples show (`AddMcpServer().WithHttpTransport()` + `app.MapMcp()`) ships in a **separate** `ModelContextProtocol.AspNetCore` package, which is **not** pinned or verified by this skill. Do not write it from memory against these packages.

The builder offers exactly two transports:

| Builder method | Use |
|---|---|
| `WithStdioServerTransport()` | stdin/stdout — the standard transport for a locally launched server |
| `WithStreamServerTransport(Stream input, Stream output)` | any paired streams you supply |

HTTP *is* present in `ModelContextProtocol.Core`, but as primitives rather than wiring:

```csharp
using Microsoft.Extensions.Logging.Abstractions;
using ModelContextProtocol.Server;

// Server side: a primitive you drive from your OWN HTTP endpoint.
var transport = new StreamableHttpServerTransport(NullLoggerFactory.Instance)
{
    Stateless = true,      // init-only -- see the note below
};
```

You then route your endpoint's traffic into `HandleGetRequestAsync(Stream, CancellationToken)` and `HandlePostRequestAsync(JsonRpcMessage, Stream, CancellationToken)` yourself. That is the work the AspNetCore package exists to do for you.

> [!IMPORTANT]
> **`Stateless` is `init`-only.** Assigning it after construction fails with **CS8852**; set it in an object initializer. A reflection surface dump renders `init` and `set` identically, so the dump alone will mislead you here.

> [!IMPORTANT]
> **`HttpClientTransport` is the client side, not a server transport.** It lives in `ModelContextProtocol.Client` and connects *to* a remote MCP server:
> ```csharp
> var options = new HttpClientTransportOptions { Endpoint = new Uri("https://example.com/mcp") };
> var client  = new HttpClientTransport(options, NullLoggerFactory.Instance);
> ```
> The name reads like a server transport; reaching for it to *host* a server is a dead end.

**Practical guidance:** if you need an HTTP MCP server, add `ModelContextProtocol.AspNetCore` and verify its API against that package's own version — this skill's ground truth does not cover it. If you need a locally launched server, `WithStdioServerTransport()` is the shipped, verified path and should be the default.

---
*Verified against ModelContextProtocol 2.0.0-preview.3 DLL surface (`ModelContextProtocol` + `ModelContextProtocol.Core`) and compile-tested against the pinned package (2026-08-05). That `WithHttpTransport()` does not exist (CS1061), that `Stateless` is `init`-only (CS8852), and the `ModelContextProtocol.Client` / `.Server` split of the HTTP types are all compile-test facts.*
