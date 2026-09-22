# Beyond chat: choose the client family

For Microsoft.Extensions.AI 10.10.0. All five non-chat client interfaces below are experimental (`MEAI001`); suppress that diagnostic deliberately in the consuming project. Core chat and embedding contracts are separate from these experimental families.

| Need | Interface and input | Workflow guide |
|---|---|---|
| Generate/edit images | `IImageGenerator`, `ImageGenerationRequest` | [Images](image-generation.md) |
| Transcribe audio | `ISpeechToTextClient`, `Stream` (or `DataContent` convenience overload) | [Speech](speech.md) |
| Synthesize audio | `ITextToSpeechClient`, `string` | [Speech](speech.md) |
| Bidirectional session | `IRealtimeClient` creates `IRealtimeClientSession` | [Realtime](realtime.md) |
| Provider-held objects | `IHostedFileClient`, stream/path/content upload | [Hosted files](hosted-files.md) |

Each family has a builder and service lookup, but their APIs are not interchangeable. Image and speech families have dedicated DI registration helpers. The realtime and file guides use ordinary `AddSingleton` factory registrations; `AddRealtimeClient` and `AddHostedFileClient` do not exist in the pinned MEAI packages (compile-negative checks).

Builders assemble a pipeline; they do not add provider capabilities. Obtain a compatible adapter first, then verify formats, option support, credentials and ownership against that adapter. API signatures and synthetic offline checks do not establish a working network integration.

`UseImageGeneration` is chat middleware for image-generation tool calls; `HostedImageGenerationTool` asks the provider to execute a hosted tool. Likewise, uploading a file does not establish that a provider has indexed it for `HostedFileSearchTool`.

See [verification and coverage](verification-and-coverage.md) for the evidence levels and remaining gaps.

---
*Verified against Microsoft.Extensions.AI 10.10.0 DLL surface (2026-09-20). Workflow examples compile in the whole-skill fence harness; component behavior is checked with fake adapters. Dedicated realtime/file DI helper absence is compile-tested. Provider support remains integration-specific.*
