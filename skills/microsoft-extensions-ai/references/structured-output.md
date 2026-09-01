# 📐 Structured Output

`GetResponseAsync<T>` asks the model for a value of a specific shape and deserializes it for you, instead of returning prose you then have to parse.

---

## Getting a typed result

```csharp
using Microsoft.Extensions.AI;

sealed class Recipe
{
    public string? Title { get; set; }
    public string[]? Steps { get; set; }
}

ChatResponse<Recipe> typed = await client.GetResponseAsync<Recipe>("Give me a pancake recipe.");

if (typed.TryGetResult(out Recipe? recipe))
{
    Console.WriteLine(recipe!.Title);
}
```

`ChatResponse<T>` derives from `ChatResponse`, so `Text`, `Usage`, `FinishReason`, and the rest are still there — you are not trading observability for typing.

> [!IMPORTANT]
> **Prefer `TryGetResult(out T)` to `.Result`.** The model can return content that does not deserialize into `T`; `TryGetResult` reports that as `false`, while `.Result` throws — a `JsonException` for malformed JSON, an `InvalidOperationException` for an empty or `null` answer (executed). Leading noise is fatal and trailing noise is tolerated: an answer wrapped in a markdown code fence fails to deserialize while JSON followed by prose succeeds, so keep the schema response format on, or strip fences before deserializing. Structured output constrains the model — it does not make failure impossible.

Overloads accept a prompt string, a `ChatMessage`, or an `IEnumerable<ChatMessage>`, each with optional `JsonSerializerOptions`, `ChatOptions`, and a `bool? useJsonSchemaResponseFormat` flag.

## What is actually sent

`GetResponseAsync<T>` is a thin layer over `ChatOptions.ResponseFormat`, and what it sends depends on that flag (executed against a recording client):

| `useJsonSchemaResponseFormat` | `ResponseFormat` sent | Messages |
|---|---|---|
| `null` (default) or `true` | `ChatResponseFormatJson` carrying the schema of `T` (`SchemaName` = the type name) | unchanged |
| `false` | `ChatResponseFormat.Json` — JSON, no schema | one extra user message: *Respond with a JSON value conforming to the following schema: …* |

Use `false` for providers that accept JSON mode but not JSON schema. The schema comes from `AIJsonUtilities.DefaultOptions`: **camelCase property names** (`title`, not `Title`) and nullable types for reference members; deserialization is case-insensitive, so a model that answers in PascalCase still round-trips (executed).

The same plumbing is available directly, and is what you reach for when a provider wants a *strict* schema:

```csharp
using System.Text.Json;
using Microsoft.Extensions.AI;

var strict = new AIJsonSchemaCreateOptions
{
    TransformOptions = new AIJsonSchemaTransformOptions { DisallowAdditionalProperties = true, RequireAllProperties = true },
};
JsonElement schema = AIJsonUtilities.CreateJsonSchema(typeof(Recipe), inferenceOptions: strict);

var options = new ChatOptions { ResponseFormat = ChatResponseFormat.ForJsonSchema(schema, "recipe", "A cooking recipe") };
ChatResponse<Recipe> typed = await client.GetResponseAsync<Recipe>("Give me a pancake recipe.", options);
```

`ChatResponseFormat.Text` and `ChatResponseFormat.Json` are the two plain formats; `ForJsonSchema` takes a `JsonElement`, a `Type`, or `JsonSerializerOptions` plus a name and description. The transform above adds `"additionalProperties": false` and lists every property as `required` (executed), which is what schema-strict providers demand. `AIJsonUtilities.DefaultOptions` is also the serializer configuration behind `AIFunction` arguments — pass your own `JsonSerializerOptions` to the overloads when you need different naming or a source-generated context.

## Engineering guidance

- **Keep `T` small and flat.** Deeply nested graphs with many optional members give the model more ways to produce something that almost deserializes.
- **Name properties the way you would describe them aloud.** The property names are part of the schema the model sees; `Steps` guides better than `S1`.
- **Always handle the failure branch.** A `false` from `TryGetResult` is a normal outcome under load or with a smaller model, not an exceptional one.
- Structured output and tool calling are different mechanisms. Use `T` when you want *the answer* shaped; use tools when you want the model to *do* something. Combining both on one call makes failures hard to attribute.
- Validate the deserialized value against business rules. Schema-valid is not the same as correct — a well-formed `Recipe` can still list a nonsense ingredient.

## ✅ Review checklist

- `TryGetResult` is used, and the `false` path does something sensible.
- `T` is a flat DTO with descriptive property names, not a domain aggregate.
- Deserialized values are validated before use.
- Structured output is not being used to smuggle in behavior that belongs in a tool.

---
*Verified against Microsoft.Extensions.AI 10.9.0 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`), compiled and executed against the pinned package (2026-08-28). Every code fence on this page compiles against 10.9.0. Execution facts, recorded at the inner client: the default sends a `ChatResponseFormatJson` carrying the schema of `T` and leaves the messages alone; `useJsonSchemaResponseFormat: false` sends `ChatResponseFormat.Json` plus an appended user message with the schema; the schema uses camelCase names and deserialization is case-insensitive; `.Result` throws `JsonException` on a prose answer and `InvalidOperationException` on an empty or `null` one, and a markdown-fenced answer fails to deserialize; the strict transform adds `additionalProperties: false` and a full `required` list. The parameter name `useJsonSchemaResponseFormat` was read from the compiled assembly — the previous edition of this page called it `useJsonSchema`, which does not exist.*
