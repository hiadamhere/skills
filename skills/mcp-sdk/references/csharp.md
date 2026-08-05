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

---
*Verified against ModelContextProtocol 2.0.0-preview.3 DLL surface (`ModelContextProtocol` + `ModelContextProtocol.Core`) and compile-tested against the pinned package (2026-07-21).*
