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
* `ChatResponse.Text` is the concatenated assistant text. Other properties: `Messages`, `Usage` (`UsageDetails`), `FinishReason` (`ChatFinishReason?`), `ModelId`, `ResponseId`, `ConversationId`, `ContinuationToken` — see *Reading the response* below.

## Stream a response

```csharp
using Microsoft.Extensions.AI;

await foreach (ChatResponseUpdate update in client.GetStreamingResponseAsync("Tell me a story."))
{
    Console.Write(update.Text);   // each chunk's incremental text
}
```

`GetStreamingResponseAsync` returns `IAsyncEnumerable<ChatResponseUpdate>`; accumulate `update.Text` as chunks arrive. Both the string and message-list overloads exist for streaming too. When you need the *whole* answer after streaming it, do not glue strings together — fold the updates back into a `ChatResponse`:

```csharp
using Microsoft.Extensions.AI;

ChatResponse full = await client.GetStreamingResponseAsync(history).ToChatResponseAsync();   // one ChatResponse from the stream
await history.AddMessagesAsync(client.GetStreamingResponseAsync(history));                   // or append the answer straight to the history
```

`ToChatResponseAsync` merges *consecutive* same-role updates into one message until a *different, non-null* `MessageId` arrives — a shared id is not merged across a gap, and id-less updates never start a new message — carries `ResponseId`, `ConversationId` and `FinishReason` across, and turns `UsageContent` updates into `Usage` (executed). `ToChatResponse()` does the same for updates you already collected, and `AddMessages(history, response)` appends a non-streamed response.

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

`ChatOptions` numeric properties are nullable value types (`float?`, `int?`, `long?`) — pass `0.7f`, not `0.7`, or you get **CS0266** (`cannot implicitly convert double to float?`). Full set includes `Temperature`, `TopP`, `TopK`, `MaxOutputTokens`, `FrequencyPenalty`, `PresencePenalty`, `Seed`, `StopSequences`, `Instructions`, `ModelId`, `ResponseFormat` (see [structured output](structured-output.md)), `Reasoning`, `ToolMode`, `Tools` and `AllowMultipleToolCalls` (see [tool calling](tool-calling.md)), plus the state controls below: `ConversationId`, `AllowBackgroundResponses`, `ContinuationToken`.

For reasoning models, `Reasoning = new ReasoningOptions { Effort = ReasoningEffort.High, Output = ReasoningOutput.Summary }` asks for more thinking and a summary of it; the summary arrives as `TextReasoningContent` (see [content-model.md](content-model.md)) and the spend as `Usage.ReasoningTokenCount`. `Reasoning` is `null` by default, and every option here reaches the provider unchanged through the pipeline (executed).

> [!IMPORTANT]
> The token limit is **`MaxOutputTokens`**. `ChatOptions.MaxTokens` — the name most tutorials and model memory reach for — does not exist and fails with **CS0117**.

## Reading the response

```csharp
using Microsoft.Extensions.AI;

ChatResponse response = await client.GetResponseAsync(history);

if (response.FinishReason == ChatFinishReason.Length)
{
    // The answer was cut off at MaxOutputTokens -- do not treat it as complete.
}

sessionUsage.Add(response.Usage ?? new UsageDetails());       // running total for the conversation
ChatClientMetadata? provider = client.GetService<ChatClientMetadata>();
```

- **`FinishReason`** is `ChatFinishReason.Stop`, `Length`, `ToolCalls` or `ContentFilter` (string-backed; the values are `stop`, `length`, `tool_calls`, `content_filter`). `Length` is the one to check before trusting an answer.
- **`Usage`** is a `UsageDetails`: `InputTokenCount`, `OutputTokenCount`, `TotalTokenCount`, `CachedInputTokenCount`, `ReasoningTokenCount`, and provider extras in `AdditionalCounts`. `UsageDetails.Add` sums every counter, `AdditionalCounts` included (executed) — keep one instance per session and add each response to it.
- **`ChatClientMetadata`** (`ProviderName`, `ProviderUri`, `DefaultModelId`) answers `client.GetService<ChatClientMetadata>()` through every layer of a pipeline (executed through function invocation and a custom layer); `GetRequiredService<T>()` throws instead of returning `null`.

## Conversation state

Some providers keep the conversation on their side. When they do, the response carries a **`ConversationId`**, and from then on you send **only the new messages** with that id on the options — resending the whole history duplicates every turn on the provider's copy:

```csharp
using Microsoft.Extensions.AI;

ChatResponse first = await client.GetResponseAsync(history, options);
history.AddMessages(first);

var pending = new List<ChatMessage>();                        // what the provider has not seen yet
if (first.ConversationId is string conversationId)
{
    options.ConversationId = conversationId;                  // the provider holds the history now
}

var question = new ChatMessage(ChatRole.User, "And tomorrow?");
history.Add(question);                                        // your own record stays complete
pending.Add(question);
ChatResponse next = await client.GetResponseAsync(options.ConversationId is null ? history : pending, options);
```

`UseFunctionInvocation` already does this inside its own loop: once the provider returns a `ConversationId`, the next iteration sends only the tool-result message with that id set (executed: one message instead of the full history). Keep your own history complete anyway — it is what you reason about, log, and fall back on when the id expires or a failover moves the request to a client that never saw it.

## Background responses

For long-running work a provider may return before the answer exists. Opt in with `AllowBackgroundResponses = true`; a response that is still running comes back with **no messages and a `ContinuationToken`**, which you send back — with an empty message list — until the answer arrives:

```csharp
using Microsoft.Extensions.AI;

var options = new ChatOptions { AllowBackgroundResponses = true, ModelId = "gpt-4o-mini" };
ChatResponse pending = await client.GetResponseAsync(history, options, cancellationToken);

for (int attempt = 0; pending.ContinuationToken is ResponseContinuationToken token; attempt++)
{
    if (attempt == 30) throw new TimeoutException("The background response did not complete.");   // bound the wait
    await Task.Delay(TimeSpan.FromSeconds(2), cancellationToken);
    var poll = options.Clone();                                // keep the caller's model and instructions
    poll.ContinuationToken = token;
    pending = await client.GetResponseAsync([], poll, cancellationToken);
}
```

`ResponseContinuationToken.ToBytes()` / `FromBytes(...)` persist a token across processes (executed round trip). Both flags are `null` by default, and a background response passes through `UseFunctionInvocation` untouched — no tool loop runs on an answer that has not arrived (executed). Bound the poll and pass your cancellation token — a provider that keeps returning a token would otherwise stall the caller forever.

## Where to go next

- Let the model call your code → [tool calling](tool-calling.md); let the provider run one, or require approval → [hosted tools and approval](hosted-tools-and-approval.md)
- Get a typed value instead of prose → [structured output](structured-output.md)
- Add caching, telemetry, or DI registration → [middleware and DI](middleware-and-di.md)

---
*Verified against Microsoft.Extensions.AI 10.9.0 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`), compiled and executed against the pinned package (2026-08-28). Every code fence on this page compiles against 10.9.0. Execution facts: `ToChatResponseAsync` merges consecutive same-role updates until a different non-null `MessageId` and carries `ResponseId`, `ConversationId`, `FinishReason` and usage across; once a provider returns a `ConversationId`, the function-invoking client's next iteration sends only the new message with that id; background responses (no messages, a `ContinuationToken`) pass through the pipeline untouched and the token round-trips through `ToBytes`/`FromBytes`; `Reasoning`, `StopSequences`, `Seed` and `TopK` reach the provider unchanged; `UsageDetails.Add` sums every counter including `AdditionalCounts`; `ChatClientMetadata` resolves through function invocation and a custom layer.*
