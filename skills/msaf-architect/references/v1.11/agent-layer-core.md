# 🧠 Agent Layer & Tools Integration (v1.11)

The Microsoft Agent Framework (MAF) separates its architecture into two distinct layers:
1.  **Workflows Layer:** The Pregel-style graph (executors, edges, steps) that drives execution logic.
2.  **Agent Layer:** The execution nodes (`AIAgent`) that wrap Language Models (LLMs) and tools to perform conversational tasks.

This guide details how to construct agents, manage their conversational sessions, and bind them directly as execution nodes inside your workflow graphs.

---

## 🏛️ Key Agent API Types

### 1. `AIAgent` & `ChatClientAgent`
`AIAgent` is the abstract base class for all LLM-driven actors. The standard concrete implementation is `ChatClientAgent`, which wraps an `IChatClient` (from `Microsoft.Extensions.AI`) and a set of instructions/tools.

```csharp
using Microsoft.Agents.AI;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Logging;

// Create the ChatClientAgent
var agent = new ChatClientAgent(
    chatClient: myChatClient, // IChatClient instance (e.g. OpenAI, Ollama, Azure OpenAI)
    instructions: "You are a helpful data analyst helper.",
    name: "DataAnalyst",
    description: "Analyzes tabular data and extracts metrics.",
    tools: new List<AITool> { myCalculationsTool },
    loggerFactory: myLoggerFactory,
    services: myServiceProvider
);
```

### 2. Conversational State: `AgentSession`
Agents do not store conversation history internally. Instead, conversation history and custom variables are stored in an `AgentSession` (typically a `ChatClientAgentSession` when using chat clients) using `AgentSessionStateBag`.

```csharp
// 1. Create a session for a conversation
AgentSession session = await agent.CreateSessionAsync("conv-id-123", cancellationToken);

// 2. Access state variables safely
AgentSessionStateBag bag = session.StateBag;
bag.SetValue("user_tier", "premium", jsonOptions);

if (bag.TryGetValue<string>("user_tier", out var tier, jsonOptions))
{
    Console.WriteLine($"Active Tier: {tier}");
}
```

---

## 🔗 Binding Agents to Workflows

To place an `AIAgent` inside a Pregel execution graph, wrap it in an `AIAgentBinding`. Since `AIAgentBinding` inherits from `ExecutorBinding`, it acts as a standard executor node that can be passed directly to `builder.AddEdge()`.

### AIAgentHostOptions Configuration
When binding an agent to a workflow, you configure how the agent host interacts with input/output channels via `AIAgentHostOptions`:

*   `EmitAgentResponseEvents`: Emits `AgentResponseEvent` nodes into the workflow event stream when the agent finishes a response turn.
*   `EmitAgentUpdateEvents`: (`Nullable<bool>`) Emits `AgentResponseUpdateEvent` token-streaming events; required for streaming UIs.
*   `ForwardIncomingMessages`: Forwards incoming workflow messages directly to the agent's prompt context.
*   `InterceptUnterminatedFunctionCalls`: Automatically resolves tool execution iterations before yielding.

```csharp
using Microsoft.Agents.AI;
using Microsoft.Agents.AI.Workflows;

// 1. Wrap agent in binding with custom host options
var agentBinding = new AIAgentBinding(
    agent, 
    new AIAgentHostOptions 
    { 
        EmitAgentResponseEvents = true,
        ForwardIncomingMessages = true 
    }
);

// 2. Add the agent directly into your workflow graph
var builder = new WorkflowBuilder(inputNodeBinding)
    .AddEdge(inputNodeBinding, agentBinding)
    .WithOutputFrom(agentBinding);
```

---

## 🛠️ Complete Integration Example

Below is a complete implementation showing how to define a `ChatClientAgent`, bind it to a workflow, save its state, and run it using the `InProcessExecution` runtime.

```csharp
using Microsoft.Agents.AI;
using Microsoft.Agents.AI.Workflows;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Logging.Abstractions;
using System.Text.Json;

public class AgentWorkflowService
{
    private readonly IChatClient _chatClient;

    public AgentWorkflowService(IChatClient chatClient)
    {
        _chatClient = chatClient;
    }

    public async Task ExecuteAgentWorkflowAsync(string conversationId, string userInput)
    {
        // 1. Create the LLM Agent
        var reviewerAgent = new ChatClientAgent(
            chatClient: _chatClient,
            instructions: "You review and format summaries. Be concise.",
            name: "SummaryReviewer",
            description: "Reviews summaries for grammar and flow.",
            tools: Array.Empty<AITool>(),
            loggerFactory: NullLoggerFactory.Instance,
            services: null
        );

        // 2. Wrap in AIAgentBinding
        var reviewerBinding = new AIAgentBinding(
            reviewerAgent,
            new AIAgentHostOptions
            {
                EmitAgentResponseEvents = true,
                ForwardIncomingMessages = true
            }
        );

        // 3. Construct the Workflow
        var workflow = new WorkflowBuilder(reviewerBinding)
            .WithOutputFrom(reviewerBinding)
            .Build();

        // 4. Create agent session
        AgentSession session = await reviewerAgent.CreateSessionAsync(conversationId, CancellationToken.None);

        // 5. Run workflow using InProcessExecution
        Run run = await InProcessExecution.RunAsync(
            workflow, 
            new ChatMessage(ChatRole.User, userInput), 
            conversationId, 
            CancellationToken.None
        );

        var status = await run.GetStatusAsync();
        if (status == RunStatus.Ended)
        {
            // Extract agent output — there is no GetOutputsAsync(); filter NewEvents instead
            foreach (var evt in run.NewEvents.OfType<WorkflowOutputEvent>())
            {
                var output = evt.As<ChatMessage>();
                Console.WriteLine($"Workflow Output: {output?.Text}");
            }

            // Optional: Serialize session state to persist history
            JsonElement stateJson = await reviewerAgent.SerializeSessionAsync(session, new JsonSerializerOptions(), CancellationToken.None);
            // Save stateJson to your database...
        }
    }
}
```

---
*Verified against MAF v1.11.0 DLL surface (2026-07-03).*
