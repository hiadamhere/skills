# 🧠 AI Agent Skills Catalog

Verified, version-matched skills for AI coding agents — Claude Code, OpenAI Codex, Cursor, Cline, Aider, GitHub Copilot, Gemini, Google Antigravity, and anything else that reads the Agent Skills format. Every API claim in these skills is checked against the real assemblies or SDKs it describes, and an automated gate rejects an unverified identifier before release.

🌐 **Browse the catalog: [hiadamhere.github.io/skills](https://hiadamhere.github.io/skills/)** — including the interactive MSAF Architect visualizer.

---

## 🚀 Install

### With `spm` (recommended)

[`spm`](https://www.npmjs.com/package/@hiadamhere/spm) installs skills into **every** coding agent on your machine at once — Claude Code, Codex, Cursor, Cline, Aider, GitHub Copilot, and more.

```bash
npm install -g @hiadamhere/spm      # or: dotnet tool install -g spm
spm install hiadamhere/skills        # every skill in this catalog
```

Or subscribe to the catalog and install by name:

```bash
spm catalog add hiadamhere https://github.com/hiadamhere/skills.git
spm catalog sync
spm install spectre-console          # one skill; `spm list` shows them all
```

> No global install? `npx @hiadamhere/spm install hiadamhere/skills`

### One-line remote install (no Node or .NET)

Deploys every skill to your user-level agent folders (`~/.agents/skills` for Codex/Gemini, `~/.claude/skills` for Claude Code):

```powershell
irm https://raw.githubusercontent.com/hiadamhere/skills/main/install.ps1 | iex     # Windows
```
```bash
curl -fsSL https://raw.githubusercontent.com/hiadamhere/skills/main/install.sh | bash   # macOS / Linux
```

### From a clone (copy or symlink, per skill, per workspace)

`.\install.ps1` / `./install.sh` run interactively; flags pick the mode (copy, or symlink for updates via `git pull`), the scope (user profile, or a workspace folder) and the skills:

```bash
./install.sh --mode link --scope folder --path /path/to/project --skills msaf-architect
./uninstall.sh --scope folder --path /path/to/project --skills msaf-architect
```

```powershell
.\install.ps1 -Mode Copy -Scope Folder -Path C:\MyProject -Skills msaf-architect
.\uninstall.ps1 -Scope Folder -Path C:\MyProject -Skills msaf-architect
```

---

## 📂 Skills

| Skill | For | Verified against |
|---|---|---|
| `msaf-architect` | Multi-agent systems on the Microsoft Agent Framework (C#) | Microsoft.Agents.AI v1.10 – v1.19 assemblies, per version |
| `microsoft-extensions-ai` | .NET's unified LLM abstractions | Microsoft.Extensions.AI 10.9.0 assemblies |
| `mcp-sdk` | MCP servers in C#, TypeScript and Python | `ModelContextProtocol` 2.0.0-preview.3 · `@modelcontextprotocol/sdk` 1.30.0 · `mcp` 2.0.0 |
| `spectre-console` | Rich .NET terminal UIs | Spectre.Console 0.57.2 assemblies |
| `maui-engineer` | Architecture and planning for .NET MAUI apps | Official docs + the target project (methodology skill) |
| `reviewers` | A configurable multi-lens review panel for any artifact | The Agent Skills standard |

### 🏛️ `msaf-architect`

Architecture, execution models and API guidance for the **Microsoft Agent Framework**: agents and workflows, the four orchestration builders, checkpointing and the hosted-workflow controls, context compaction, the workflow event stream and declarative executors — per version, **v1.10 through v1.19**.

> [!IMPORTANT]
> Tutorials and training data describe MAF APIs that **never shipped** (a `WorkflowSuspendedException` suspend pattern, for one). Every claim here is verified against the actual assemblies of each version, with compile and execution tests for what reflection cannot show.

v1.15 to v1.19 are purely additive, so the traps are in adoption rather than migration: nullable checkpoint results, `TryPrepare` accepting an id that does not exist, `WithCheckpointing` handing a wrapped agent back unchanged, a hosted workflow that must speak the chat protocol, and the `MAAI001` experimental gate applied per member. The visualizer walks the v1.14 migration and the v1.15–v1.19 additions.

### 🧩 `microsoft-extensions-ai`

[Microsoft.Extensions.AI](https://learn.microsoft.com/dotnet/ai/), .NET's unified LLM layer: `IChatClient` calls and streaming, `ChatOptions`, tool calling — your functions, provider-hosted tools, and human approval before a tool runs — structured output, embeddings, the middleware/DI pipeline, conversation state and background responses, the content model underneath `response.Text`, the five non-chat client families and — from 10.9.0 — routing and failover between chat clients. Written against the GA API, not the renamed preview one.

Its traps are the silent ones: `ChatOptions.Tools` without `UseFunctionInvocation()` (nobody executes the call), a cache placed on the wrong side of function invocation, `TextReasoningContent` not deriving from `TextContent`, resending the whole history to a provider that already holds it, a `[FromKeyedServices]` tool parameter that the *model* is asked to fill in, a failover client that no longer fails over once a stream has started — and one loud one, `MEAI001`: the non-chat families, the chat reducers and the routing/failover clients are compile **errors** until that experimental gate is suppressed.

### 🔌 `mcp-sdk`

MCP servers with the official SDKs in **C#, TypeScript and Python** — tools, the stdio transport, a minimal server — each verified against its own pinned SDK: reflection and compile tests for C#, `tsc` for TypeScript, `pyright` for Python. MCP postdates most training data, so models invent its shapes; each language carries a documented trap: `FastMCP` does not exist in `mcp` 2.0.0, `server.tool()` is deprecated in favour of `registerTool`, and `WithHttpTransport()` / `MapMcp()` live in a package the pinned C# SDK does not include.

### 🎨 `spectre-console`

Rich .NET terminal UIs with [Spectre.Console](https://spectreconsole.net/): tables, panels, trees, markup and colour, live displays, interactive prompts — plus the terminal-gating discipline that keeps interactive features from hanging in CI or hosted contexts. Verified against the 0.57.2 assemblies (`Spectre.Console`, `.Ansi`, `.Testing`).

### 📱 `maui-engineer`

Version-aware **architecture and planning** for .NET MAUI: platform, SDK and workload strategy, project layout, MVVM/DI, navigation and deep links, state and offline data, performance budgets you measure rather than copy, accessibility, publish and signing. A methodology skill: it resolves the real SDK, target frameworks and packages from your project and asks for platform evidence instead of one green desktop build.

### 🔍 `reviewers`

A **review panel**, not a code reviewer: independent lenses examine the same change in parallel, findings merge by severity, and verdicts roll up worst-case-wins. The shipped lenses are a starter kit; the value is the overlay where you encode the mistakes *your* project has actually made — a lens is a markdown file plus a roster entry, and your overlay survives every update. Declare read-only `facts` (your gate, your tests) and they run once for the whole panel.

---

## 🔒 How the skills are verified

Every API-bearing skill pins a ground truth — the package's assemblies reflected into a surface dump, or the SDK's shipped type information — and every type, member and signature in its documentation must exist there. What metadata cannot show (optional parameters, `init`-only setters, protected members, `[Experimental]` gates, runtime behaviour) is established by compiling and executing the exact documented pattern against the pinned version. Reference documents carry a dated verification stamp, and an automated gate rejects any unverified identifier, stale stamp or coverage regression before a release. Claims of *absence* — the phantom APIs above — are compile-tested, never assumed.

---
Distributed under the MIT License.
