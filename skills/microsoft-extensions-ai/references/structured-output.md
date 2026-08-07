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
> **Prefer `TryGetResult(out T)` to `.Result`.** The model can return content that does not deserialize into `T`; `TryGetResult` reports that as `false`, while `.Result` gives you no opportunity to handle it. Structured output constrains the model — it does not make failure impossible.

Overloads accept a prompt string, a `ChatMessage`, or an `IEnumerable<ChatMessage>`, each with optional `JsonSerializerOptions`, `ChatOptions`, and a `useJsonSchema` flag.

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
*Verified against Microsoft.Extensions.AI 10.8.1 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`) and compile-tested against the pinned package (2026-08-05).*
