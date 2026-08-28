# 🧱 The Content Model

`response.Text` is a convenience. Underneath, every `ChatMessage` carries an `IList<AIContent>`, and **the interesting parts of a modern model response are not text** — reasoning traces, images, tool calls, citations, token usage, and errors all arrive as sibling content items in that list. Reading only `.Text` silently discards them.

There are 25 content types. This page is the map.

## 🌳 The Base

Everything derives from `AIContent`, which contributes three things worth knowing:

| Member | Why you care |
|---|---|
| `IList<AIAnnotation> Annotations` | citations and spans attached to this item |
| `object? RawRepresentation` | the provider's original object — the escape hatch when the abstraction has flattened something you need |
| `AdditionalPropertiesDictionary? AdditionalProperties` | provider extras that have no first-class property |

`RawRepresentation` is the pressure valve: reach for it when a provider exposes a field the abstraction does not model, and treat every use as provider-specific code.

## ✍️ Text, and the Thing That Is Not Text

```csharp
foreach (AIContent content in message.Contents)
{
    switch (content)
    {
        case TextReasoningContent reasoning:
            Console.WriteLine($"[thinking] {reasoning.Text}");
            break;
        case TextContent text:
            Console.WriteLine(text.Text);
            break;
    }
}
```

> [!WARNING]
> **`TextReasoningContent` does *not* derive from `TextContent`.** They are siblings under `AIContent` — assigning one to the other fails with **CS0029**. A `case TextContent` will therefore **not** catch reasoning content, and a loop that handles only `TextContent` drops the model's chain of thought without a word. Handle both, or decide deliberately to skip reasoning.
>
> This is invisible in the surface dump, which does not record base types at all — the hierarchy on this page came from compile tests, not from reading the dump.

`TextReasoningContent` also carries `ProtectedData`, the opaque blob some providers require you to echo back to preserve a reasoning chain across turns. Round-trip it verbatim; do not parse it.

## 🖼️ Binary and Referenced Data

Two types, and the difference matters for cost and privacy:

| Type | Holds | Use when |
|---|---|---|
| `DataContent` | the **bytes**, inline | the model must receive the payload |
| `UriContent` | a **link**, nothing else | the provider fetches it, or the user already has it |

```csharp
var inline = new DataContent(bytes, "image/png");
var linked = new UriContent("https://example.com/chart.png");   // mediaType optional

if (inline.HasTopLevelMediaType("image")) { /* image/* of any subtype */ }
```

`DataContent` exposes both `Data` (`ReadOnlyMemory<byte>`) and `Base64Data` (`ReadOnlyMemory<char>`) so you can hand it to whichever API you have, plus `Name`, `MediaType`, and a `Uri` string form. `LoadFromAsync` reads from a path or a `Stream`, and `SaveToAsync` writes back:

```csharp
DataContent loaded = await DataContent.LoadFromAsync("chart.png", "image/png");
await loaded.SaveToAsync("copy.png");
```

`HasTopLevelMediaType` is on both types — prefer it over string-prefix checks on `MediaType`.

## 🛠️ Tool Traffic

Tool calls and results are content, not a side channel, which is why a tool-calling loop reads the same list as everything else:

```
ToolCallContent  ──┬── FunctionCallContent          your C# function
                   ├── McpServerToolCallContent     an MCP server tool
                   ├── WebSearchToolCallContent      provider-hosted search
                   ├── CodeInterpreterToolCallContent
                   └── ImageGenerationToolCallContent

ToolResultContent ─┴── FunctionResultContent, McpServerToolResultContent,
                       WebSearchToolResultContent, CodeInterpreterToolResultContent,
                       ImageGenerationToolResultContent
```

Every edge in that tree is compile-verified by direct assignment, not read off the dump — which records no base types at all. Matching on the **base** `ToolCallContent` catches every hosted-tool flavour at once, which is what you want for logging; matching on `FunctionCallContent` catches only the calls you are expected to execute yourself. See [tool-calling.md](tool-calling.md) for the execution loop.

Human approval rides the same channel: `ToolApprovalRequestContent` and `ToolApprovalResponseContent`. So do `InputRequestContent` / `InputResponseContent` for mid-run input, and `HostedFileContent` / `HostedVectorStoreContent` for provider-side artifacts.

## 📊 Usage and Errors

```csharp
case UsageContent usage:
    Console.WriteLine(usage.Details.TotalTokenCount);
    break;

case ErrorContent error:
    Console.WriteLine($"{error.ErrorCode}: {error.Message} ({error.Details})");
    break;
```

> [!IMPORTANT]
> **An error can arrive as *content* rather than as an exception.** `ErrorContent` is an ordinary item in the list, so a response that "succeeded" may still carry a failure inside it. A pipeline that only catches exceptions will report success for a response whose content says otherwise — check for `ErrorContent` explicitly when partial failure matters.

`UsageContent` wraps a `UsageDetails`, and appears in streaming responses too — usually as the final update, which is why accumulating usage means scanning content rather than reading a property on the response.

## 🧭 What To Match On

| You want… | Match |
|---|---|
| the prose | `TextContent` |
| the model's reasoning | `TextReasoningContent` — **not** caught by `TextContent` |
| an image or file the model sent | `DataContent` (bytes) or `UriContent` (link) |
| every tool call, whoever runs it | `ToolCallContent` |
| only the calls you must execute | `FunctionCallContent` |
| token counts | `UsageContent` |
| in-band failures | `ErrorContent` |
| citations on any item | `content.Annotations` |
| something the abstraction dropped | `content.RawRepresentation` |

---
*Verified against Microsoft.Extensions.AI 10.9.0 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`) (2026-08-28): every type on this page is byte-identical to 10.8.1 by mechanical diff of the dumps, and base types, parameter defaults, accessors and `[Experimental]` gating are unchanged by a reflection shape diff of both pins; the patterns were compile-tested against 10.8.1 on 2026-08-13. The surface dump records no base types, so the hierarchy here was established by compile test: `TextReasoningContent` is **not** assignable to `TextContent` (CS0029), while every `*ToolCallContent` (function, MCP server, web search, code interpreter, image generation) is assignable to `ToolCallContent`, every `*ToolResultContent` to `ToolResultContent`, and the approval/input/hosted content types to `AIContent` — each edge asserted by a direct assignment that compiles. `UriContent`'s optional `mediaType`, and the `LoadFromAsync`/`SaveToAsync` static-versus-instance split, are likewise compile-test facts a reflection dump cannot show.*
