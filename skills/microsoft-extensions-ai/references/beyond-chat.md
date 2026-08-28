# 🎛️ Beyond Chat: The Other Client Families

`IChatClient` is not the only abstraction in this library. Five more client families follow the **same shape**, which is the single most useful thing to know about them: if you can wire a chat client, you can wire all of them.

> [!IMPORTANT]
> **Every one of these families is `[Experimental("MEAI001")]`, and `MEAI001` is a compile error until suppressed** — `<NoWarn>$(NoWarn);MEAI001</NoWarn>` project-wide, or `#pragma warning disable MEAI001` per file. The gate covers the five interfaces and every builder, extension, DI-registration, metadata and middleware type around them — `UseImageGeneration` and `FunctionInvokingRealtimeClient` included — and most of their option and response types. The content types the families exchange (`DataContent`, `HostedFileContent`, `ImageGenerationToolCallContent`) are not gated; a handful of members on otherwise-stable types are (`HostedFileContent.Purpose` and `.Scope`, `ImageGenerationResponseFormat.Hosted`, `ToolApprovalRequestContent.RequiresConfirmation`, and the audio/text token counts on `UsageDetails`). Suppress locally and expect the shape to move between minor versions.

| Family | Interface | The call |
|---|---|---|
| Image generation | `IImageGenerator` | `GenerateAsync` / `GenerateImagesAsync` / `EditImageAsync` |
| Speech → text | `ISpeechToTextClient` | `GetTextAsync` / `GetStreamingTextAsync` |
| Text → speech | `ITextToSpeechClient` | `GetAudioAsync` / `GetStreamingAudioAsync` |
| Realtime sessions | `IRealtimeClient` | `CreateSessionAsync` → `IRealtimeClientSession` |
| Provider-hosted files | `IHostedFileClient` | `UploadAsync` / `DownloadAsync` / `ListFilesAsync` / `DeleteAsync` |

## 🔁 The Shape You Already Know

Every family repeats the same five pieces. Taking image generation as the worked example:

| Piece | Image generation | What it is |
|---|---|---|
| interface | `IImageGenerator` | the calls, plus `GetService(Type, object?)` |
| builder | `ImageGeneratorBuilder` | ctor takes the inner client; `.Use(...)`, `.Build()` |
| extensions | `ImageGeneratorExtensions` | convenience overloads on the interface |
| DI | `ImageGeneratorBuilderServiceCollectionExtensions` | `AddImageGenerator` / `AddKeyedImageGenerator` |
| metadata | `ImageGeneratorMetadata` | provider facts, resolved through `GetService` |

The other families are named the same way: `ISpeechToTextClient` with `SpeechToTextClientBuilder`, `SpeechToTextClientExtensions`, `SpeechToTextClientBuilderServiceCollectionExtensions` and `SpeechToTextClientMetadata`; likewise for `ITextToSpeechClient`, `IRealtimeClient` and `IHostedFileClient`.

So the three moves transfer verbatim from [middleware-and-di.md](middleware-and-di.md):

```csharp
// 1. wrap
IImageGenerator built = generator.AsBuilder().Build();

// 2. register
services.AddImageGenerator(generator);
services.AddKeyedImageGenerator("fast", generator);
services.AddSpeechToTextClient(speechClient);

// 3. resolve provider-specific bits through the pipeline
ImageGeneratorMetadata? meta = generator.GetService<ImageGeneratorMetadata>();
```

`ServiceLifetime` is optional on every one of those `Add…` methods, and each family ships an `AsBuilder()` extension exactly like `IChatClient`'s.

## 🖼️ Image Generation

```csharp
ImageGenerationResponse made = await generator.GenerateImagesAsync("a red bicycle");

ImageGenerationResponse edited = await generator.EditImageAsync(
    new DataContent(pngBytes, "image/png"), "make it blue");
```

`ImageGenerationOptions` and the `CancellationToken` are optional on all of these. The lower-level `GenerateAsync(ImageGenerationRequest, …)` is there when you need to build the request object yourself; `EditImagesAsync` takes an `IEnumerable<AIContent>` for multi-image edits, and a `ReadOnlyMemory<byte>` overload of `EditImageAsync` saves constructing a `DataContent`. `ImageGenerationResponseFormat` selects how the result comes back.

> [!IMPORTANT]
> **A chat client can fulfil image-generation tool calls for you.** `UseImageGeneration` puts an `IImageGenerator` into a chat pipeline, so an `ImageGenerationToolCallContent` in the response is executed rather than handed back to you:
>
> ```csharp
> IChatClient client = chatClient.AsBuilder().UseImageGeneration(generator).Build();
> ```
>
> This is the same middleware bargain as `UseFunctionInvocation` — see [content-model.md](content-model.md) for the tool-call content types it consumes, and [middleware-and-di.md](middleware-and-di.md) for why ordering matters.

## 🔊 Speech, Both Directions

```csharp
SpeechToTextResponse text = await stt.GetTextAsync(new DataContent(wavBytes, "audio/wav"));

await foreach (SpeechToTextResponseUpdate update in stt.GetStreamingTextAsync(audio))
{
    if (update.Kind == SpeechToTextResponseUpdateKind.TextUpdated) { /* … */ }
}

TextToSpeechResponse audioOut = await tts.GetAudioAsync("hello");
await foreach (TextToSpeechResponseUpdate update in tts.GetStreamingAudioAsync("hello")) { }
```

Both interfaces take a `Stream` at the interface level; the `DataContent` overloads above come from `SpeechToTextClientExtensions`, which is usually what you want since [content-model.md](content-model.md) already gives you `DataContent` from a file, a byte buffer, or a response. `SpeechToTextResponseUpdateKind` and `TextToSpeechResponseUpdateKind` distinguish the update kinds while streaming — do not assume every update carries text or audio.

## 📁 Provider-Hosted Files

Files that live on the provider's side, referenced by id rather than uploaded per request:

```csharp
HostedFileContent uploaded = await files.UploadAsync("notes.pdf");
DataContent bytes = await files.DownloadAsDataContentAsync(uploaded.FileId);

await foreach (HostedFileContent f in files.ListFilesAsync()) { }
bool deleted = await files.DeleteAsync(uploaded.FileId);
```

`HostedFileClientOptions` and the cancellation token are optional throughout. `DownloadAsync` returns a `HostedFileDownloadStream` when you want to stream rather than buffer, and `DownloadToAsync` writes straight to a path. `HostedFileSearchTool` lets the model search those files, and `HostedFileContent` is the same content type that shows up in a chat response — the families interlock.

## ⚡ Realtime

```csharp
IRealtimeClientSession session = await client.CreateSessionAsync(new RealtimeSessionOptions());
```

A session is the unit of work here, not a request: `RealtimeClientMessage` and `RealtimeServerMessage` flow in both directions, `RealtimeServerMessageType` and `RealtimeSessionKind` classify them, `RealtimeConversationItem` models the conversation, `RealtimeAudioFormat` the audio, and `RealtimeResponseStatus` the outcome. `FunctionInvokingRealtimeClient` is the realtime analogue of `UseFunctionInvocation` — it executes tool calls inside a live session.

## 🧭 Choosing

| You need… | Family |
|---|---|
| an image from a prompt, or an edit of one | `IImageGenerator` |
| a transcript from audio | `ISpeechToTextClient` |
| audio from text | `ITextToSpeechClient` |
| a live bidirectional session | `IRealtimeClient` |
| files the provider stores and the model can search | `IHostedFileClient` |
| images produced *during* a chat turn | `UseImageGeneration` on the chat pipeline |

---
*Verified against Microsoft.Extensions.AI 10.9.0 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`) (2026-08-28): every type on this page is byte-identical to 10.8.1 by mechanical diff of the dumps, and base types, parameter defaults, accessors and `[Experimental]` gating are unchanged by a reflection shape diff of both pins; the patterns were compile-tested against 10.8.1 on 2026-08-13. The optional `options`/`ServiceLifetime`/`CancellationToken` parameters, the `DataContent` convenience overloads on the speech and file clients, `AsBuilder()` on each family, and the `UseImageGeneration` chat-pipeline composition are compile-test facts a reflection dump renders identically to required ones. The `MEAI001` gate on this page's types was established on 10.9.0 by compile error and a reflection sweep of both assemblies for `[Experimental]`.*
