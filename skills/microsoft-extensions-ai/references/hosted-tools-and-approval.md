# 🛡️ Hosted Tools and Tool Approval

Two more kinds of tool exist beyond [your own functions](tool-calling.md): tools the **provider** executes on its side, and functions that need a **human's yes** before they run. Both travel through `ChatOptions.Tools`, and the pipeline you already have handles both — as long as you know which half of the work is yours.

---

## Hosted tools: the provider does the work

| Tool | `Name` the provider sees | Notes |
|---|---|---|
| `HostedWebSearchTool` | `web_search` | |
| `HostedCodeInterpreterTool` | `code_interpreter` | `Inputs` (`IList<AIContent>`) seeds it with files |
| `HostedFileSearchTool` | `file_search` | `Inputs`, `MaximumResultCount` (`int?`); pairs with the files an `IHostedFileClient` uploaded |
| `HostedImageGenerationTool` | `image_generation` | `Options` (`ImageGenerationOptions`), `null` by default |
| `HostedMcpServerTool` | `mcp` | a remote MCP server the *provider* connects to — below |
| `HostedToolSearchTool` | — | `MEAI001` experimental: deferred-tool discovery (`DeferredTools`, `Namespace`) |

Every one derives from `AITool` (`Name`, `Description`, `AdditionalProperties`); none is an `AIFunction`.

```csharp
using Microsoft.Extensions.AI;

var options = new ChatOptions
{
    Tools =
    [
        weather,                                                        // your AIFunction -- executed by UseFunctionInvocation
        new HostedWebSearchTool(),                                      // executed by the provider
        new HostedMcpServerTool("docs", "https://mcp.example.com/sse")  // the provider connects to this MCP server
        {
            AllowedTools = ["search", "read_page"],
            ApprovalMode = HostedMcpServerToolApprovalMode.NeverRequire,
            Headers = new Dictionary<string, string> { ["Authorization"] = $"Bearer {mcpToken}" },   // from your secret store; the provider retains it
        },
    ],
};

ChatResponse response = await client.GetResponseAsync("What changed in the docs this week?", options);
```

> [!IMPORTANT]
> **Hosted tools are executed by the provider, not by `UseFunctionInvocation`.** The function-invoking client forwards them to the provider untouched and only ever invokes `AIFunction`s (executed: a `Tools` list mixing both reached the inner client intact). What a hosted tool did comes back as *content* — `WebSearchToolCallContent`, `CodeInterpreterToolResultContent`, `McpServerToolCallContent` and friends, all in [content-model.md](content-model.md). Nothing in the abstraction checks whether the provider you are talking to supports a given hosted tool; an unsupported one is the provider's error, at call time.

**`HostedMcpServerTool`** takes a server name and an address (`string` or `Uri`). Its defaults are all `null` — `ApprovalMode` (the provider's own default applies), `AllowedTools` (every tool the server offers), `Headers`, `ServerDescription`. The approval modes are `HostedMcpServerToolApprovalMode.AlwaysRequire`, `.NeverRequire`, and `.RequireSpecific(alwaysRequireApprovalToolNames, neverRequireApprovalToolNames)`. Restrict `AllowedTools` and keep approval on for anything that writes; the server is reachable by the provider, not by you.

## Approval for your own functions

Wrap a function in `ApprovalRequiredAIFunction` and the function-invoking client stops before calling it and asks:

```csharp
using Microsoft.Extensions.AI;

AIFunction deleteFiles = AIFunctionFactory.Create(DeleteFiles, "delete_files");
var options = new ChatOptions { Tools = [new ApprovalRequiredAIFunction(deleteFiles)] };
IChatClient client = raw.AsBuilder().UseFunctionInvocation().Build();

var history = new List<ChatMessage> { new(ChatRole.User, "Clean up the temp folder.") };
ChatResponse first = await client.GetResponseAsync(history, options);
history.AddMessages(first);

foreach (ToolApprovalRequestContent request in first.Messages.SelectMany(m => m.Contents).OfType<ToolApprovalRequestContent>())
{
    var call = (FunctionCallContent)request.ToolCall;
    bool approved = AskTheUser(call.Name, call.Arguments);              // your UI, your policy
    history.Add(new ChatMessage(ChatRole.User, [request.CreateResponse(approved, approved ? null : "Declined by the user")]));
}

ChatResponse final = await client.GetResponseAsync(history, options);   // same tools, same pipeline

static void DeleteFiles(string folder) { /* irreversible work */ }
static bool AskTheUser(string tool, IDictionary<string, object?>? arguments) => false;
```

The flow, as executed against the pinned package:

1. **The first call does not invoke the function.** The response is an assistant message carrying a `ToolApprovalRequestContent` whose `ToolCall` is the model's `FunctionCallContent` (same `CallId`, same arguments).
2. **You answer in a user message** built with `request.CreateResponse(approved, reason)` — a `ToolApprovalResponseContent` — after appending the response's own messages to the history.
3. **Approved:** the second call invokes the function, and the provider sees the ordinary `FunctionCallContent` / `FunctionResultContent` pair. The approval request and response never reach the provider; the client converts them.
4. **Rejected:** the function is not invoked, and the provider receives a `FunctionResultContent` reading `Tool call invocation rejected. <your reason>`; the model then answers normally.

`ApprovalRequiredAIFunction` derives from `DelegatingAIFunction`, so the wrapped function keeps its name, description and schema. `ToolApprovalRequestContent.RequiresConfirmation` is `MEAI001`-gated — a compile error until suppressed — and nothing on this page needs it.

## Engineering guidance

- **Approval belongs on irreversible tools** — writes, deletes, payments, deployments — not on lookups. Every approval is a round trip through the model and a human.
- **The approval lives in the conversation.** Keep the request's messages and your response message in the same history you send back; the client matches them by `CallId`.
- **Hosted MCP servers are a trust decision.** Allow-list the tools, keep an approval mode on anything that writes, and remember the provider holds whatever you put in `Headers`.
- **Hosted tools cost differently.** A web search or code run is billed and rate-limited by the provider; treat their results like any other untrusted tool output.

## ✅ Review checklist

- Hosted tools are not expected to be executed by `UseFunctionInvocation`, and their results are read from the response content.
- `HostedMcpServerTool` has `AllowedTools` set and an explicit `ApprovalMode`.
- Irreversible functions are wrapped in `ApprovalRequiredAIFunction`, and the rejection reason is meaningful to the model.
- The approval response goes back with the response's own messages preserved in the history.

---
*Verified against Microsoft.Extensions.AI 10.9.0 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`), compiled and executed against the pinned package (2026-08-28). The tool names, the `HostedMcpServerTool` defaults, the pass-through of hosted tools by the function-invoking client, and the full approve/reject round trip (what the caller receives, what the provider sees, the rejection text) are execution facts; the `MEAI001` gate on `HostedToolSearchTool` and on `RequiresConfirmation` was confirmed by compile error.*
