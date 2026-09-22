# Realtime sessions

For Microsoft.Extensions.AI 10.10.0. `IRealtimeClient` and `IRealtimeClientSession` are experimental (`MEAI001`). A client creates sessions; a session sends client messages and yields server messages. The session is `IAsyncDisposable`, while the client is `IDisposable`. Keep the session alive for the receive operation and dispose it with `await using`.

## A bounded text turn

```csharp
public static class RealtimeExample1
{
    public static async Task TextTurnAsync(IRealtimeClient client, string prompt,
        CancellationToken cancellationToken)
    {
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        deadline.CancelAfter(TimeSpan.FromSeconds(30));
        var options = new RealtimeSessionOptions { OutputModalities = ["text"] };
        await using IRealtimeClientSession session = await client.CreateSessionAsync(options, deadline.Token);

        var item = new RealtimeConversationItem([new TextContent(prompt)], role: ChatRole.User);
        await session.SendAsync(new CreateConversationItemRealtimeClientMessage(item), deadline.Token);
        await session.SendAsync(new CreateResponseRealtimeClientMessage(), deadline.Token);

        await foreach (RealtimeServerMessage message in session.GetStreamingResponseAsync(deadline.Token))
        {
            if (message is ErrorRealtimeServerMessage failure)
                throw new InvalidOperationException(failure.Error?.Message ?? "Realtime request failed");
            if (message is OutputTextAudioRealtimeServerMessage text &&
                message.Type == RealtimeServerMessageType.OutputTextDelta)
                Console.Write(text.Text);
            if (message.Type == RealtimeServerMessageType.ResponseDone)
            {
                if (message is not ResponseCreatedRealtimeServerMessage done ||
                    done.Status != RealtimeResponseStatus.Completed)
                    throw new InvalidOperationException("Realtime response did not complete successfully");
                return;
            }
        }
        throw new InvalidOperationException("Session ended before a completed response");
    }
}
```

This example compiles and its send/receive/lifetime shape is exercised with a synthetic session. It assumes the adapter supports text output and these message types. It is not a provider integration test. `ResponseCreatedRealtimeServerMessage` also represents response lifecycle events; inspect its `Status`, `Error` and `Usage` as applicable. `RealtimeResponseStatus` distinguishes outcomes; a done event alone must not be displayed as success.

`RealtimeClientMessage` and `RealtimeServerMessage` are base types. Dispatch on both runtime type and `RealtimeServerMessageType`: `OutputTextAudioRealtimeServerMessage` can represent several kinds, so appending every `Text` would duplicate deltas and completed text. `RawRepresentation` is a provider-specific escape hatch, not a stable portable schema.

## Audio and session configuration

`RealtimeSessionOptions` includes `SessionKind` (`RealtimeSessionKind`), `Model`, `Instructions`, `Tools`, `ToolMode`, `InputAudioFormat`, `OutputAudioFormat` and `Voice`. `RealtimeAudioFormat` describes audio configuration; it does not convert bytes. `TranscriptionOptions` configures input transcription, and `VoiceActivityDetectionOptions` configures detection and interruption preferences. Check supported formats and settings with your adapter.

```csharp
public static class RealtimeExample2
{
    public static async Task SendAudioAsync(IRealtimeClientSession session, DataContent encodedAudio,
        CancellationToken cancellationToken)
    {
        await session.SendAsync(new InputAudioBufferAppendRealtimeClientMessage(encodedAudio), cancellationToken);
        await session.SendAsync(new InputAudioBufferCommitRealtimeClientMessage(), cancellationToken);
    }
}
```

These calls only send audio buffer messages. When and whether to commit manually or request a response depends on the selected session/VAD protocol. Do not claim this is a microphone-to-speaker loop. Receive transcription through `InputAudioTranscriptionRealtimeServerMessage`; handle failed/completed/delta variants separately. Audio output uses `OutputTextAudioRealtimeServerMessage.Audio`, a string payload: decoding and playback depend on the negotiated format.

`SessionUpdateRealtimeClientMessage` carries updated options. `ResponseOutputItemRealtimeServerMessage` exposes response items, including tool-related content. A production receiver must handle cancellation, errors, interruption and session closure according to the provider protocol.

## Middleware and DI

```csharp
public static class RealtimeExample3
{
    public static void RegisterRealtime(IServiceCollection services,
        Func<IServiceProvider, IRealtimeClient> createClient)
    {
        services.AddSingleton<IRealtimeClient>(sp => createClient(sp).AsBuilder()
            .UseFunctionInvocation(configure: c =>
            {
                c.MaximumIterationsPerRequest = 5;
                c.IncludeDetailedErrors = false;
                c.AllowConcurrentInvocation = false;
            })
            .UseLogging().UseOpenTelemetry().Build(sp));
    }
}
```

`RealtimeClientBuilder` builds the pipeline; registration above is ordinary DI, `AddRealtimeClient` does not exist in the pinned MEAI packages. `FunctionInvokingRealtimeClient` provides the realtime function-invocation layer. Its configuration compiles here; execution of its realtime tool protocol is still untested. Validate and authorize tool arguments in application code just as with chat.

`LoggingRealtimeClient` and `OpenTelemetryRealtimeClient` are diagnostic layers; this guide does not assert the emitted logs/spans. `DelegatingRealtimeClient` wraps client creation to intercept session creation; wrap `IRealtimeClientSession` yourself when you need to intercept session operations. Both client and session expose service lookup; ask for a type actually supplied by the selected adapter and handle an unavailable service.

---
*Verified against Microsoft.Extensions.AI 10.10.0 DLL surface and compile-tested against the pinned package (2026-09-20). Offline component assertions exercise a synthetic session's message dispatch, token forwarding and asynchronous disposal. Live transport, audio codecs, interruptions, reconnection and realtime function execution are not tested.*
