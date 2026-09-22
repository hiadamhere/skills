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
> **`TextReasoningContent` does *not* derive from `TextContent`.** They are siblings under `AIContent` — assigning one to the other fails with **CS0029**. A `case TextContent` will therefore **not** catch reasoning content, and a loop that handles only `TextContent` omits the reasoning content or summary the provider chose to expose. Handle both, or decide deliberately to skip reasoning.
>
> The public-members dump does not record base types. The hierarchy on this page is checked through reflection; the sibling assignment above is also checked by the retained CS0029 compile test.

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

The reflection shape comparison checks the base types in that tree; the public-members dump alone cannot establish them. Matching on the **base** `ToolCallContent` catches every hosted-tool flavour at once, which is what you want for logging; matching on `FunctionCallContent` catches only the calls you are expected to execute yourself. See [tool-calling.md](tool-calling.md) for the execution loop.

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

`UsageContent` wraps a `UsageDetails`, and appears in streaming responses too — with placement determined by the adapter. Scan updates for usage; the aggregated `ChatResponse` also exposes `Usage`.

## 📎 Annotations

Any content item can carry `Annotations` — `null` unless the provider attached some. The shipped annotation is the citation:

```csharp
foreach (AIContent content in response.Messages.SelectMany(m => m.Contents))
{
    foreach (CitationAnnotation citation in content.Annotations?.OfType<CitationAnnotation>() ?? [])
    {
        Console.WriteLine($"{citation.Title} {citation.Url} via {citation.ToolName}");
        foreach (TextSpanAnnotatedRegion region in citation.AnnotatedRegions?.OfType<TextSpanAnnotatedRegion>() ?? [])
        {
            Console.WriteLine($"  covers characters {region.StartIndex}-{region.EndIndex}");
        }
    }
}
```

`CitationAnnotation` carries `Title`, `Url`, `FileId`, `ToolName` and `Snippet`; its `AnnotatedRegions` say *which part* of the content it applies to, as `TextSpanAnnotatedRegion` (`StartIndex`/`EndIndex`, both `int?`). The types are the abstraction's; which of them a provider fills in is the provider's.

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
*Verified against Microsoft.Extensions.AI 10.10.0 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`), compiled and executed against the pinned package (2026-09-20). Every code fence on this page compiles against 10.10.0. The surface dump records no base types, so the hierarchy here was checked with the reflection shape comparison of both assemblies. A retained negative assignment separately confirms that `TextReasoningContent` is **not** assignable to `TextContent` (CS0029). The tool-call, tool-result and approval/input/hosted base types match the previous pin in that comparison. `UriContent`'s optional `mediaType`, and the `LoadFromAsync`/`SaveToAsync` static-versus-instance split, are likewise compile-test facts. `Annotations` is `null` on a fresh content item; the citation and region types were compiled, not observed from a provider.*
