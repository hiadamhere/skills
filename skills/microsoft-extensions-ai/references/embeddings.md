# 🔢 Embeddings

`IEmbeddingGenerator<TInput, TEmbedding>` is the embedding counterpart to `IChatClient` — one contract every provider implements. For text the concrete shape is almost always `IEmbeddingGenerator<string, Embedding<float>>`.

---

## Generating vectors

There are three call shapes, and they return **different types**. Picking the wrong one is the usual first compile error.

```csharp
using Microsoft.Extensions.AI;

// 1) Batch — the interface method. Returns a collection.
GeneratedEmbeddings<Embedding<float>> batch =
    await generator.GenerateAsync(["first document", "second document"]);

foreach (Embedding<float> e in batch)
{
    Console.WriteLine(e.Dimensions);
}

// 2) Single input — extension method. Returns ONE embedding.
Embedding<float> one = await generator.GenerateAsync("just this one");
ReadOnlyMemory<float> vector = one.Vector;

// 3) Single input, straight to the raw vector.
ReadOnlyMemory<float> v = await generator.GenerateVectorAsync("shortcut");
```

> [!IMPORTANT]
> `GenerateAsync(IEnumerable<TInput>)` returns `GeneratedEmbeddings<TEmbedding>`; `GenerateAsync(TInput)` returns a single `TEmbedding`. Same method name, different return type, chosen by argument shape. When you want the numbers and nothing else, `GenerateVectorAsync` skips the wrapper entirely.

`Embedding<T>` exposes `Vector` (`ReadOnlyMemory<T>`) and `Dimensions`. `GeneratedEmbeddings<TEmbedding>` is enumerable and preserves input order.

## Options

```csharp
var options = new EmbeddingGenerationOptions
{
    Dimensions = 512,                          // int? — request a reduced dimensionality
    ModelId = "text-embedding-3-small",        // override the generator's default model
};

GeneratedEmbeddings<Embedding<float>> result =
    await generator.GenerateAsync(["with options"], options);
```

## In the pipeline and in DI

Embedding generators compose exactly like chat clients:

```csharp
services.AddEmbeddingGenerator(embeddingGenerator)
        .UseLogging();
```

`UseDistributedCache`, `UseLogging`, and `UseOpenTelemetry` all have `EmbeddingGeneratorBuilder<TInput, TEmbedding>` overloads. See [middleware and DI](middleware-and-di.md).

## Engineering guidance

- **Batch aggressively.** One call with 100 inputs is dramatically cheaper and faster than 100 calls. Use the `IEnumerable` overload wherever you control the loop.
- **Pin the model, and store which model produced each vector.** Embeddings from different models are not comparable, and a silent model change invalidates a whole index without any error.
- **Treat `Dimensions` as part of your storage schema.** Changing it means re-embedding the corpus, not just changing a parameter.
- Cache embeddings for stable inputs. The same document embedded twice is pure waste — this is where `UseDistributedCache` pays for itself far more predictably than on chat.
- Normalize inputs (trim, collapse whitespace, consistent casing policy) before embedding, or near-identical documents produce needlessly different vectors.

## ✅ Review checklist

- Inputs are batched rather than looped one call at a time.
- The model id and dimensionality are recorded alongside stored vectors.
- Re-embedding is a planned operation, not an emergency, when the model changes.
- The generator is consumed from DI so caching and telemetry layers apply.

---
*Verified against Microsoft.Extensions.AI 10.9.0 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`) (2026-08-28): every type on this page is byte-identical to 10.8.1 by mechanical diff of the dumps, and base types, parameter defaults, accessors and `[Experimental]` gating are unchanged by a reflection shape diff of both pins; the patterns were compile-tested against 10.8.1 on 2026-08-05. The differing return types of the batch and single-input `GenerateAsync` overloads were confirmed by compile test.*
