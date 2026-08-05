# 💬 Chat with `IChatClient`

`IChatClient` (in `Microsoft.Extensions.AI.Abstractions`) is the single abstraction every provider implements. You get one from a provider package (OpenAI, Azure AI, Ollama, …) or wrap another client; the *usage* below is identical regardless of provider.

> [!IMPORTANT]
> **The method is `GetResponseAsync`.** The pre-GA preview method `CompleteAsync` does not exist in the GA surface — code from tutorials/model memory that calls it will not compile. Likewise `ChatCompletion` does not exist; the response type is `ChatResponse`, and a streaming chunk is `ChatResponseUpdate`.

---

## Get a response

Two equivalent forms — a plain prompt string, or an explicit message list:

```csharp
using Microsoft.Extensions.AI;

// 1) Convenience: a single user prompt
ChatResponse response = await client.GetResponseAsync("Write a haiku about C#.");
Console.WriteLine(response.Text);

// 2) Explicit messages (system + user, multi-turn, etc.)
var messages = new List<ChatMessage>
{
    new(ChatRole.System, "You are a terse assistant."),
    new(ChatRole.User, "Explain dependency injection in one sentence."),
};
ChatResponse response2 = await client.GetResponseAsync(messages);
Console.WriteLine(response2.Text);
```

* `ChatMessage(ChatRole role, string content)` — roles are `ChatRole.System`, `ChatRole.User`, `ChatRole.Assistant`, `ChatRole.Tool`.
* `ChatResponse.Text` is the concatenated assistant text. Other properties: `Messages`, `Usage` (`UsageDetails`), `FinishReason` (`ChatFinishReason?`), `ModelId`, `ResponseId`.

## Stream a response

```csharp
using Microsoft.Extensions.AI;

await foreach (ChatResponseUpdate update in client.GetStreamingResponseAsync("Tell me a story."))
{
    Console.Write(update.Text);   // each chunk's incremental text
}
```

`GetStreamingResponseAsync` returns `IAsyncEnumerable<ChatResponseUpdate>`; accumulate `update.Text` as chunks arrive. Both the string and message-list overloads exist for streaming too.

## Tuning the call with `ChatOptions`

```csharp
using Microsoft.Extensions.AI;

var options = new ChatOptions
{
    Temperature = 0.7f,          // float? — note the 'f'
    MaxOutputTokens = 500,       // int?
    TopP = 0.9f,
    Instructions = "Answer only in bullet points.",
    ModelId = "gpt-4o-mini",     // override the client's default model per call
};

ChatResponse response = await client.GetResponseAsync("Summarize MVU.", options);
```

`ChatOptions` numeric properties are nullable value types (`float?`, `int?`, `long?`) — pass `0.7f`, not `0.7`. Full set includes `Temperature`, `TopP`, `TopK`, `MaxOutputTokens`, `FrequencyPenalty`, `PresencePenalty`, `Seed`, `Instructions`, `ModelId`, `ResponseFormat`, `Reasoning`, and `Tools` (see [tool calling](tool-calling.md)).

---
*Verified against Microsoft.Extensions.AI 10.8.1 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`) and compile-tested against the pinned package (2026-07-21).*
