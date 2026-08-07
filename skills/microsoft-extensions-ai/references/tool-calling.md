# 🛠️ Tool and Function Calling

Tool calling in `Microsoft.Extensions.AI` is two things that must both be present: **tools declared on the call** (`ChatOptions.Tools`) and **middleware that executes them** (`UseFunctionInvocation`). Declaring tools without the middleware is the single most common way to get a chat loop that appears to do nothing.

> [!WARNING]
> **`ChatOptions.Tools` alone does not execute anything.** The provider returns a `FunctionCallContent` in the response and stops there. `FunctionInvokingChatClient` — added by `UseFunctionInvocation()` — is what actually invokes your method and feeds the result back to the model. Without it in the pipeline you get a response containing a request to call a function that nobody ever calls.

---

## A function the model can call

Any delegate or method becomes an `AIFunction` through `AIFunctionFactory`. `[Description]` attributes are how the model learns what the tool and its parameters mean — they are not decoration.

```csharp
using System.ComponentModel;
using Microsoft.Extensions.AI;

[Description("Gets the current weather for a city.")]
static string GetWeather([Description("City name")] string city) => $"Sunny in {city}";

AIFunction weather = AIFunctionFactory.Create(GetWeather);

// Override the advertised name/description without renaming your method:
AIFunction named = AIFunctionFactory.Create(GetWeather, "get_weather", "Weather by city");
```

`AIFunctionFactory.Create` also accepts a `MethodInfo` + target instance, and an `AIFunctionFactoryOptions` overload for serializer options, JSON-schema control, and result marshalling.

## Wiring it up

```csharp
using Microsoft.Extensions.AI;

// The middleware is not optional — see the warning above.
IChatClient client = raw.AsBuilder().UseFunctionInvocation().Build();

var options = new ChatOptions
{
    Tools = [weather],
    ToolMode = ChatToolMode.Auto,
};

ChatResponse response = await client.GetResponseAsync("Weather in Oslo?", options);
Console.WriteLine(response.Text);
```

## Choosing when tools are used

| `ChatOptions.ToolMode` | Behavior |
|---|---|
| `ChatToolMode.Auto` | The model decides whether to call a tool. The default posture. |
| `ChatToolMode.None` | Tools are advertised but the model must answer without calling one. |
| `ChatToolMode.RequireAny` | The model must call **some** tool. |
| `ChatToolMode.RequireSpecific("get_weather")` | The model must call **that** tool. |

> [!IMPORTANT]
> There is no `ChatToolMode.Required` — that name does not compile (`CS0117`). The "must call something" mode is **`RequireAny`**, and the single-tool form is the method `RequireSpecific(string)`, not a property.

## Bounding the invocation loop

Tool calling is a loop: model asks → you execute → result goes back → model may ask again. Left unbounded, a confused model can spin. `UseFunctionInvocation` takes a configuration callback:

```csharp
IChatClient client = raw.AsBuilder()
    .UseFunctionInvocation(loggerFactory, c =>
    {
        c.MaximumIterationsPerRequest       = 5;      // hard stop on the call/response loop
        c.MaximumConsecutiveErrorsPerRequest = 2;     // give up after repeated tool failures
        c.IncludeDetailedErrors             = false;  // do not leak exception detail to the model
        c.AllowConcurrentInvocation         = false;  // serialize tool execution
        c.TerminateOnUnknownCalls           = true;   // stop if the model invents a tool name
    })
    .Build();
```

- **Always set `MaximumIterationsPerRequest`** for anything user-facing. It is the failure-safe for a model that keeps re-calling the same tool.
- **Keep `IncludeDetailedErrors = false` in production.** It puts raw exception text into the model's context, which then tends to surface in the user-visible answer.
- **`TerminateOnUnknownCalls = true`** turns a hallucinated tool name into a stop rather than an error the model keeps retrying.
- `AllowConcurrentInvocation = true` only if every tool is genuinely thread-safe and side-effect independent.

## Engineering guidance

- **A tool is an API boundary, not a helper method.** Validate arguments inside the function; the model supplies them and can supply nonsense.
- **Never let tool arguments carry authorization.** Base access decisions on the caller's identity from your own context, never on a parameter the model filled in.
- Keep tool descriptions short and behavioral. The description is prompt text and competes for the model's attention with everything else.
- Return structured, compact results. A tool returning a wall of text costs tokens on every subsequent turn of the loop.
- Make tools idempotent where possible — the loop can call the same tool twice.

## ✅ Review checklist

- `UseFunctionInvocation()` is in the pipeline wherever `ChatOptions.Tools` is set.
- `MaximumIterationsPerRequest` is set explicitly for user-facing calls.
- `IncludeDetailedErrors` is `false` outside development.
- Every tool validates its own arguments and does not trust them for authorization.
- Irreversible operations (write, delete, deploy, payment) are gated by application policy, not by the tool description asking the model nicely.

---
*Verified against Microsoft.Extensions.AI 10.8.1 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`) and compile-tested against the pinned package (2026-08-05). That `ChatToolMode.Required` does not exist was confirmed by compile test (CS0117).*
