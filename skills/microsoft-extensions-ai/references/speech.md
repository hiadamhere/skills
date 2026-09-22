# Speech input and output

For Microsoft.Extensions.AI 10.10.0. Both client families are experimental (`MEAI001`). **Speech-to-text consumes a `Stream`; text-to-speech consumes a `string`.** The interfaces do not have interchangeable input types.

## Transcribe audio

```csharp
public static class SpeechExample1
{
    public static async Task<string> TranscribeAsync(ISpeechToTextClient client,
        string audioPath, CancellationToken cancellationToken)
    {
        await using Stream audio = File.OpenRead(audioPath);
        var options = new SpeechToTextOptions { SpeechLanguage = "en" };
        SpeechToTextResponse response = await client.GetTextAsync(audio, options, cancellationToken);
        return response.Text;
    }
}
```

The caller owns this file stream and disposes it after the awaited operation. Confirm the adapter's accepted audio encoding, sample rate and stream requirements; `SpeechSampleRate` is an option, not a transcoder. `SpeechToTextClientExtensions` also accepts `DataContent` and supplies a stream to the interface. `TextLanguage` and `ModelId` are optional requests whose support depends on the adapter.

```csharp
public static class SpeechExample2
{
    public static async Task<SpeechToTextResponse> TranscribeStreamAsync(
        ISpeechToTextClient client, Stream audio, CancellationToken cancellationToken)
    {
        // Aggregate once. Enumerating the provider stream twice can start two operations.
        return await client.GetStreamingTextAsync(audio, cancellationToken: cancellationToken)
            .ToSpeechToTextResponseAsync(cancellationToken);
    }
}
```

For a live UI, inspect `SpeechToTextResponseUpdate.Kind`: `SpeechToTextResponseUpdateKind` includes `SessionOpen`, `TextUpdating`, `TextUpdated`, `Error` and `SessionClose`. Do not blindly append both interim and final text. `SpeechToTextResponseUpdateExtensions` supplies aggregation; the offline probe checks a response/update round trip, not every provider's interim/final sequence. `StartTime` and `EndTime` are nullable; do not invent timestamps when they are absent.

## Synthesize audio

```csharp
public static class SpeechExample3
{
    public static async Task<TextToSpeechResponse> SpeakAsync(ITextToSpeechClient client,
        string text, string voiceId, CancellationToken cancellationToken)
    {
        var options = new TextToSpeechOptions { VoiceId = voiceId };
        TextToSpeechResponse response = await client.GetAudioAsync(text, options, cancellationToken);
        foreach (ErrorContent error in response.Contents.OfType<ErrorContent>())
            throw new InvalidOperationException(error.Message);
        return response; // inspect Contents for the adapter's actual audio representation
    }
}
```

`TextToSpeechOptions` also exposes `AudioFormat`, `Language`, `Speed`, `Pitch`, `Volume` and `ModelId`. These are requests; check allowed values with the adapter. `TextToSpeechResponse` contains `AIContent`, not a guaranteed playable stream. Choose output handling based on each content item's actual type and media type.

```csharp
public static class SpeechExample4
{
    public static async Task<TextToSpeechResponse> SpeakStreamAsync(ITextToSpeechClient client,
        string text, CancellationToken cancellationToken)
    {
        return await client.GetStreamingAudioAsync(text, cancellationToken: cancellationToken)
            .ToTextToSpeechResponseAsync(cancellationToken);
    }
}
```

For progressive playback, inspect `TextToSpeechResponseUpdate` and its `TextToSpeechResponseUpdateKind` (`AudioUpdating`, `AudioUpdated`, session and error events). Do not concatenate encoded audio containers without checking their format and the adapter's chunk protocol. `TextToSpeechResponseUpdateExtensions` aggregation is compile-checked and exercised on synthetic updates; playback and codec validity are not.

## Composition and ownership

```csharp
public static class SpeechExample5
{
    public static void RegisterSpeech(IServiceCollection services,
        ISpeechToTextClient transcriber, ITextToSpeechClient speaker)
    {
        services.AddSpeechToTextClient(transcriber)
            .ConfigureOptions(o => o.SpeechLanguage ??= "en")
            .UseLogging().UseOpenTelemetry();
        services.AddTextToSpeechClient(speaker)
            .ConfigureOptions(o => o.Language ??= "en")
            .UseLogging().UseOpenTelemetry();
    }
}
```

`SpeechToTextClientBuilder` and `TextToSpeechClientBuilder` compose pipelines. The DI helpers live in `SpeechToTextClientBuilderServiceCollectionExtensions` and `TextToSpeechClientBuilderServiceCollectionExtensions`; keyed registrations are also available. `ConfigureOptionsSpeechToTextClient` and `ConfigureOptionsTextToSpeechClient` clone caller options before configuring them (offline assertions cover both).

`LoggingSpeechToTextClient` / `LoggingTextToSpeechClient` and `OpenTelemetrySpeechToTextClient` / `OpenTelemetryTextToSpeechClient` are diagnostics layers; their emitted records are not tested here. `SpeechToTextClientMetadata` and `TextToSpeechClientMetadata` are optional metadata obtained through `GetService<T>()`. Custom layers derive from `DelegatingSpeechToTextClient` or `DelegatingTextToSpeechClient`: override both ordinary and streaming methods when the policy must cover both. Dispose the owning pipeline after consumers finish.

---
*Verified against Microsoft.Extensions.AI 10.10.0 DLL surface and compile-tested against the pinned package (2026-09-20). Offline component assertions cover DataContent input adaptation, caller-option cloning, token forwarding and synthetic response/update aggregation. No microphone, codec, transcription accuracy or audio playback was tested.*
