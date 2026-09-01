# 🛠️ Tool and Function Calling

Tool calling in `Microsoft.Extensions.AI` is two things that must both be present: **tools declared on the call** (`ChatOptions.Tools`) and **middleware that executes them** (`UseFunctionInvocation`). Declaring tools without the middleware is the single most common way to get a chat loop that appears to do nothing. Tools the *provider* executes, and functions that need a human's approval before they run, are in [hosted-tools-and-approval.md](hosted-tools-and-approval.md).

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
        c.TerminateOnUnknownCalls           = true;   // hand an unknown tool name back instead of replying "not found"
    })
    .Build();
```

- **Always set `MaximumIterationsPerRequest`** for anything user-facing. It is the failure-safe for a model that keeps re-calling the same tool.
- **Keep `IncludeDetailedErrors = false` in production.** It puts raw exception text into the model's context, which then tends to surface in the user-visible answer.
- **`TerminateOnUnknownCalls = true`** turns a hallucinated tool name into a stop — the call comes back to you in `response.Messages` — rather than an error the model keeps retrying. The default sends the model a `FunctionResultContent` reading *Error: Requested function "‹name›" not found.* and lets the loop continue.
- `AllowConcurrentInvocation = true` only if every tool is genuinely thread-safe and side-effect independent.

## Inside a tool: context and services

```csharp
using Microsoft.Extensions.AI;
using Microsoft.Extensions.DependencyInjection;

AIFunction lookup = AIFunctionFactory.Create((string city, IServiceProvider services, CancellationToken cancellationToken) =>
{
    // Special-bound parameters never appear in the schema the model sees.
    var api = services.GetRequiredService<IWeatherApi>();
    FunctionInvocationContext context = FunctionInvokingChatClient.CurrentContext!;   // null outside a tool
    return api.GetForecast(city, context.Iteration, cancellationToken);
}, "get_weather");

interface IWeatherApi { string GetForecast(string city, int iteration, CancellationToken cancellationToken); }
```

- **`IServiceProvider`, `CancellationToken` and `AIFunctionArguments` parameters are bound by the factory, not by the model** — they are excluded from the JSON schema (executed: only `city` appears). The provider a tool receives is the one the function-invoking client was built with: `services.AddChatClient(...).UseFunctionInvocation()` and `new FunctionInvokingChatClient(inner, loggerFactory, services)` hand it your container; a bare `raw.AsBuilder().UseFunctionInvocation().Build()` hands it an *empty* provider where every `GetService` returns `null`.
- **`[FromKeyedServices]` is not a binding here.** The parameter becomes a required property in the schema; when the model omits it the call fails with an `ArgumentException` and the model is told `Error: Function failed.` Take the `IServiceProvider` and resolve keyed services yourself.
- **`FunctionInvokingChatClient.CurrentContext`** is set for the duration of your tool: `Function`, `Arguments`, `CallContent`, `Messages`, `Options`, `Iteration` (zero-based), `FunctionCallIndex`, `FunctionCount`, `IsStreaming`. Set **`Terminate = true`** and the loop ends after this tool — the result is returned to *your* caller in `response.Messages` instead of going back to the model (executed: one provider call, no final text).

## Parameters the model must not control

The rule below says tool arguments never carry authorization. This is the mechanism that enforces it — the model cannot set what it cannot see:

```csharp
using Microsoft.Extensions.AI;

AIFunction scoped = AIFunctionFactory.Create((string city, string userId) => LookupFor(userId, city), new AIFunctionFactoryOptions
{
    Name = "get_weather",
    ConfigureParameterBinding = parameter => parameter.Name == "userId"
        ? new AIFunctionFactoryOptions.ParameterBindingOptions
        {
            ExcludeFromSchema = true,                                                    // the model never sees it
            BindParameter = (_, arguments) => arguments.Context?["userId"] ?? "anonymous",   // you supply it
        }
        : default,
});

IChatClient client = raw.AsBuilder()
    .UseFunctionInvocation(configure: c => c.FunctionInvoker = (context, cancellationToken) =>
    {
        context.Arguments.Context ??= new Dictionary<object, object?>();
        context.Arguments.Context["userId"] = currentUserId;                           // from your auth, per request
        return context.Function.InvokeAsync(context.Arguments, cancellationToken);
    })
    .Build();

static string LookupFor(string userId, string city) => $"{userId}: {city}";
```

Executed: the schema lists only `city`; a `userId` the model tries to supply is discarded in favour of `BindParameter`; and `FunctionInvoker` — which wraps every invocation the client makes — is where per-request context enters `AIFunctionArguments.Context`.

## Tools the model already knows about

- **`AdditionalTools`** on the function-invoking client are *executable but not advertised*: nothing is added to the request, yet a call to one of them is executed (executed: the provider saw `Tools = null`, the call still ran). Use it for tools the model learned about elsewhere.
- **Declaration-only tools** — `weather.AsDeclarationOnly()`, or `AIFunctionFactory.CreateDeclaration(name, description, schema)` — are the opposite: *advertised but not executed*. A call to one is handed back to you as a `FunctionCallContent` in `response.Messages` (executed), for execution somewhere else: a remote worker, a UI, another process. `AIFunctionDeclaration` (`JsonSchema`, `ReturnJsonSchema`) is the base; `AIFunction` adds `InvokeAsync`.

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
- Irreversible operations (write, delete, deploy, payment) are gated by application policy, not by the tool description asking the model nicely — and by [approval](hosted-tools-and-approval.md) where a human must say yes.
- Identity and scope parameters are bound from `Context` or services with `ExcludeFromSchema`, never exposed to the model; keyed services come from the injected `IServiceProvider`, not from `[FromKeyedServices]`.

---
*Verified against Microsoft.Extensions.AI 10.9.0 DLL surface (`Microsoft.Extensions.AI` + `.Abstractions`), compiled and executed against the pinned package (2026-08-28). Every code fence on this page compiles against 10.9.0. Execution facts: `IServiceProvider`, `CancellationToken` and `AIFunctionArguments` parameters are bound by the factory and absent from the schema; `[FromKeyedServices]` is not (the parameter enters the schema as required, and a missing value fails the call with `ArgumentException`); a bare `AsBuilder().Build()` hands tools an empty provider while DI and the explicit constructor hand them yours; `CurrentContext` is populated inside a tool and `Terminate` ends the loop with the result returned to the caller; `ExcludeFromSchema` + `BindParameter` discard a model-supplied value; `FunctionInvoker` wraps every invocation; `AdditionalTools` execute without being advertised; declaration-only tools and unknown names are handed back unexecuted when `TerminateOnUnknownCalls` is set, otherwise the model receives an error result. That `ChatToolMode.Required` does not exist was re-confirmed by compile test (CS0117).*
