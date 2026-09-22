# Provider-hosted files

For Microsoft.Extensions.AI 10.10.0. `IHostedFileClient`, its builder and options are experimental (`MEAI001`). The client manages provider-held objects. An upload is not proof that a file has been indexed for search, and an id from one provider/account is not portable to another.

## Upload, inspect, download, delete

```csharp
public static class HostedFilesExample1
{
    public static async Task<DataContent> FileRoundTripAsync(IHostedFileClient client,
        DataContent input, CancellationToken cancellationToken)
    {
        HostedFileContent uploaded = await client.UploadAsync(input,
            cancellationToken: cancellationToken);
        try
        {
            HostedFileContent info = await client.GetFileInfoAsync(uploaded.FileId,
                cancellationToken: cancellationToken) ?? throw new FileNotFoundException(uploaded.FileId);
            Console.WriteLine($"{info.Name}: {info.SizeInBytes} bytes");
            return await client.DownloadAsDataContentAsync(uploaded.FileId,
                cancellationToken: cancellationToken);
        }
        finally
        {
            // A separate bounded cleanup token still works if the operation was canceled.
            using var cleanup = new CancellationTokenSource(TimeSpan.FromSeconds(10));
            bool deleted = await client.DeleteAsync(uploaded.FileId,
                cancellationToken: cleanup.Token);
            if (!deleted) Console.Error.WriteLine($"Cleanup did not delete {uploaded.FileId}");
        }
    }
}
```

This is a temporary-file example: deletion in `finally` is deliberate. Production code should preserve the original failure if cleanup also throws, and queue a retry according to its retention policy. `HostedFileClientExtensions` provides the `DataContent` and file-path upload conveniences. At interface level, upload takes a stream plus optional media type and file name. The offline probe checks bytes/name/media-type mapping; it does not contact storage.

`HostedFileContent` carries `FileId` and optional metadata (`Name`, `MediaType`, `SizeInBytes`, `CreatedAt`, `Purpose`, `Scope`). Do not infer availability or authorization from an id alone. `HostedFileClientOptions` supplies optional `Purpose`, `Scope` and `Limit`; their accepted values and listing semantics belong to the adapter/provider.

## Stream a large download and enumerate files

```csharp
public static class HostedFilesExample2
{
    public static async Task CopyDownloadAsync(IHostedFileClient client, string fileId,
        Stream destination, CancellationToken cancellationToken)
    {
        await using HostedFileDownloadStream download = await client.DownloadAsync(fileId,
            cancellationToken: cancellationToken);
        await download.CopyToAsync(destination, cancellationToken);
    }

    public static async Task ListAsync(IHostedFileClient client, CancellationToken cancellationToken)
    {
        await foreach (HostedFileContent file in client.ListFilesAsync(
            new HostedFileClientOptions { Limit = 20 }, cancellationToken))
            Console.WriteLine($"{file.FileId}: {file.Name}");
    }
}
```

The caller disposes a raw `HostedFileDownloadStream`. `DownloadAsDataContentAsync` buffers the payload; the offline probe checks that it disposes its download stream. `DownloadToAsync` writes to a file path. Avoid buffering unbounded payloads; enforce application size limits and verify provider paging behavior rather than treating `Limit` as a portable pagination protocol.

## Pipeline and registration

```csharp
public static class HostedFilesExample3
{
    public static void RegisterFiles(IServiceCollection services,
        Func<IServiceProvider, IHostedFileClient> createClient)
    {
        services.AddSingleton<IHostedFileClient>(sp => createClient(sp).AsBuilder()
            .UseLogging().UseOpenTelemetry().Build(sp));
    }
}
```

`HostedFileClientBuilder` composes a file pipeline. This example uses ordinary DI registration; `AddHostedFileClient` does not exist in the pinned MEAI packages. `LoggingHostedFileClient` and `OpenTelemetryHostedFileClient` supply diagnostics. A `DelegatingHostedFileClient` can wrap upload/download/list/delete policies; ensure all operations that need the policy are covered. Resolve optional `HostedFileClientMetadata` with `GetService<T>()`. The DI container owns the factory-created pipeline.

To use files with `HostedFileSearchTool`, follow the selected adapter's file/vector-store preparation contract. `HostedVectorStoreContent` represents a store reference; this guide does not implement indexing, readiness polling or provider retention guarantees.

---
*Verified against Microsoft.Extensions.AI 10.10.0 DLL surface and compile-tested against the pinned package (2026-09-20). The component probe checks upload adaptation, download buffering/disposal and token forwarding with a fake client. Provider persistence, indexing, paging and cleanup success are not verified.*
