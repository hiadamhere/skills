# Image generation and editing

For Microsoft.Extensions.AI 10.10.0. `IImageGenerator` and its pipeline are experimental: suppress `MEAI001` deliberately in the consuming project. Obtain the raw generator from an adapter that supports this interface; these examples accept one as a parameter and make no provider SDK assumptions.

## Generate, edit, and inspect the result

```csharp
public static class ImageGenerationExample1
{
    public static async Task<ImageGenerationResponse> MakeImageAsync(
        IImageGenerator generator, CancellationToken cancellationToken)
    {
        var options = new ImageGenerationOptions { Count = 1 };
        ImageGenerationResponse response = await generator.GenerateImagesAsync(
            "A red bicycle on a plain background", options, cancellationToken);
        foreach (AIContent content in response.Contents)
        {
            switch (content)
            {
                case DataContent bytes:
                    Console.WriteLine($"Inline {bytes.MediaType}: {bytes.Data.Length} bytes");
                    break;
                case UriContent link:
                    Console.WriteLine($"Remote result: {link.Uri}");
                    break;
                case HostedFileContent file:
                    Console.WriteLine($"Hosted result: {file.FileId}");
                    break;
                case ErrorContent error:
                    throw new InvalidOperationException(error.Message);
            }
        }
        return response;
    }
}
```

The response is a list of content items, not a single guaranteed byte array. Treat returned URLs and file ids according to the provider's access policy. `ImageGenerationResponseFormat` requests a representation; it does not establish that an adapter supports every value. Likewise, validate support for `ImageSize`, `MediaType`, `Count` and `ModelId` with the adapter. `Usage` may be absent.

```csharp
public static class ImageGenerationExample2
{
    public static Task<ImageGenerationResponse> EditAsync(IImageGenerator generator,
        ReadOnlyMemory<byte> png, CancellationToken cancellationToken)
    {
        var original = new DataContent(png, "image/png");
        return generator.EditImageAsync(original, "Make the bicycle blue",
            cancellationToken: cancellationToken);
    }
}
```

`ImageGeneratorExtensions` maps the prompt convenience call to an `ImageGenerationRequest`. Editing supplies `OriginalImages` as well as `Prompt`. Use `EditImagesAsync` for multiple input content items, or call `GenerateAsync` with a request you constructed. The offline probe checks these mappings and cancellation-token forwarding; it does not generate an image.

## Pipeline and DI

```csharp
public static class ImageGenerationExample3
{
    public static void RegisterImages(IServiceCollection services,
        IImageGenerator generator, IImageGenerator editingGenerator)
    {
        services.AddImageGenerator(generator)
            .ConfigureOptions(o => o.Count ??= 1)
            .UseLogging()
            .UseOpenTelemetry(configure: telemetry => telemetry.EnableSensitiveData = false);
        services.AddKeyedImageGenerator("editing", editingGenerator);
    }
}
```

`ImageGeneratorBuilder` composes the layers; `ImageGeneratorBuilderServiceCollectionExtensions` supplies the two registrations. `ConfigureOptionsImageGenerator` clones caller options before configuration (checked offline), so `??=` can provide a default without changing the caller's object. `LoggingImageGenerator` and `OpenTelemetryImageGenerator` provide diagnostics; the example compiles but emitted logs/spans have not been asserted. Review log settings before handling private prompts or images.

For a custom layer, derive from `DelegatingImageGenerator` and override `GenerateAsync`. Resolve provider metadata with `GetService<ImageGeneratorMetadata>()`; handle `null`. Dispose an owned pipeline, and do not independently dispose a shared inner generator while another consumer uses it.

`UseImageGeneration` on a chat builder installs `ImageGeneratingChatClient`, which is distinct from asking the provider to execute `HostedImageGenerationTool`. The composition is compile-checked; image tool-loop behavior and provider image formats remain integration-test gaps.

---
*Verified against Microsoft.Extensions.AI 10.10.0 DLL surface and compile-tested against the pinned package (2026-09-20). The component probe executes convenience request mapping, option cloning and token forwarding using a fake generator. Image quality, supported formats and provider execution are not tested.*
