# AI Agent Skills Catalog

Verified, version-matched skills for any AI coding agent that reads the Agent Skills format. Every API claim is checked against the real assemblies or SDKs it describes.

**[Browse the catalog](https://hiadamhere.github.io/skills/)**, including the interactive MSAF Architect visualizer.

## Skills

| Skill | For | Verified against |
|---|---|---|
| [`msaf-architect`](#msaf-architect) | Multi-agent systems on the Microsoft Agent Framework (C#) | Microsoft.Agents.AI v1.10 - v1.20 assemblies, per version |
| [`microsoft-extensions-ai`](#microsoft-extensions-ai) | .NET's unified LLM abstractions | Microsoft.Extensions.AI 10.9.0 assemblies |
| [`mcp-sdk`](#mcp-sdk) | MCP servers in C#, TypeScript and Python | `ModelContextProtocol` 2.0.0-preview.3, `@modelcontextprotocol/sdk` 1.30.0, `mcp` 2.0.0 |
| [`spectre-console`](#spectre-console) | Rich .NET terminal UIs | Spectre.Console 0.57.2 assemblies |
| [`maui-engineer`](#maui-engineer) | Architecture and planning for .NET MAUI apps | Official docs and the target project (methodology skill) |
| [`reviewers`](#reviewers) | A configurable multi-lens review panel for any artifact | The Agent Skills standard |

## Install

Each skill is a folder with a `SKILL.md`, the format coding agents read natively.

```bash
npx skills add hiadamhere/skills
```

That detects the agents on your machine and installs into each of them. `--list` shows the six skills, `--skill <name>` picks one, `-g` installs for your user rather than the current project.

<details>
<summary><b>Claude Code plugin, spm, one-line remote, from a clone</b></summary>

### Claude Code

```text
/plugin marketplace add hiadamhere/skills
/plugin install agent-skills@hiadamhere      # the whole catalog
/plugin install msaf-architect@hiadamhere    # or any single skill
```

### By hand

Copy a skill folder into `.agents/skills/` in your project, the folder most agents read, or into your agent's user-level skills folder for every project.

### `spm`, one command for every agent at once

[`spm`](https://www.npmjs.com/package/@hiadamhere/spm) is this catalog's own installer. It installs into every coding agent on your machine at once, and can subscribe to the catalog so you install by name.

```bash
npm install -g @hiadamhere/spm      # or: dotnet tool install -g spm
spm install hiadamhere/skills        # every skill in this catalog
```

```bash
spm catalog add hiadamhere https://github.com/hiadamhere/skills.git
spm catalog sync
spm install spectre-console          # one skill; `spm list` shows them all
```

No global install? `npx @hiadamhere/spm install hiadamhere/skills`

### One line, no Node or .NET

Deploys every skill to your user-level agent folders (`~/.agents/skills` and `~/.claude/skills`):

```powershell
irm https://raw.githubusercontent.com/hiadamhere/skills/main/install.ps1 | iex     # Windows
```
```bash
curl -fsSL https://raw.githubusercontent.com/hiadamhere/skills/main/install.sh | bash   # macOS / Linux
```

### From a clone

`.\install.ps1` and `./install.sh` run interactively. Flags pick the mode (copy, or symlink so `git pull` updates the skills), the scope (user profile or a workspace folder) and the skills:

```bash
./install.sh --mode link --scope folder --path /path/to/project --skills msaf-architect
./uninstall.sh --scope folder --path /path/to/project --skills msaf-architect
```

```powershell
.\install.ps1 -Mode Copy -Scope Folder -Path C:\MyProject -Skills msaf-architect
.\uninstall.ps1 -Scope Folder -Path C:\MyProject -Skills msaf-architect
```

</details>

## What each skill covers

### `msaf-architect`

Agents and workflows on the **Microsoft Agent Framework**, documented per version from **v1.10 through v1.20**: the four orchestration builders, checkpointing, hosted workflows, context compaction, the workflow event stream and declarative executors.

On the current versions one question costs one page. Resolve your framework version, check the compatibility matrix, read the single topic page for the task. Older pinned folders keep their original per-release structure, and each page says where the rest is.

Prevents:

- `WorkflowSuspendedException`, a suspend pattern that tutorials teach and that never shipped in any version
- A `CheckpointInfo?` assigned to a non-nullable variable, when a session that never checkpointed returns null
- `WithCheckpointing` returning the agent unchanged, so your manager is never used, on an agent that is wrapped, hosts no workflow, or already has one
- `TryPrepare` accepting a checkpoint id that does not exist
- A hosted workflow that cannot speak the chat protocol failing on its first run
- The `MAAI001` experimental gate, which applies per type in some places and per member in others
- In v1.20, a background wait timeout that rejects `Timeout.InfiniteTimeSpan` while the release timeout beside it accepts it

### `microsoft-extensions-ai`

[Microsoft.Extensions.AI](https://learn.microsoft.com/dotnet/ai/), .NET's unified LLM layer: `IChatClient` calls and streaming, `ChatOptions`, structured output, embeddings, and the middleware and DI pipeline.

It also covers tool calling with your own functions or provider-hosted ones, human approval before a tool runs, conversation state, the content model beneath `response.Text`, the non-chat client families, and routing and failover between chat clients. Written against the GA API, not the renamed preview one.

Prevents:

- `ChatOptions.Tools` set without `UseFunctionInvocation()`, so nothing ever executes the call
- A cache placed on the wrong side of function invocation
- `TextReasoningContent` assumed to derive from `TextContent`
- Resending a whole history to a provider that already holds it
- A failover client that stops failing over once a stream has started
- `MEAI001`, which makes the non-chat families, the chat reducers and the routing clients compile errors until it is suppressed

### `mcp-sdk`

MCP servers with the official SDKs in **C#, TypeScript and Python**: tools, the stdio transport and a minimal server, each verified against its own pinned SDK by reflection and compile tests for C#, `tsc` for TypeScript and `pyright` for Python.

MCP postdates most training data, so models invent its shapes.

Prevents:

- `FastMCP`, which does not exist in `mcp` 2.0.0
- `server.tool()`, deprecated in favour of `registerTool`
- `WithHttpTransport()` and `MapMcp()`, which live in a package the pinned C# SDK does not include

### `spectre-console`

Rich .NET terminal UIs with [Spectre.Console](https://spectreconsole.net/): tables, panels, trees, markup and colour, live displays and interactive prompts. Verified against the 0.57.2 assemblies.

Prevents:

- A prompt or live display that hangs in CI, because interactive features assume a real terminal and need gating on `AnsiConsole.Profile.Capabilities.Interactive` and `Out.IsTerminal`
- Interpolated user text that throws or mis-renders, because `[` and `]` are markup control characters and need `Markup.Escape`
- Two live displays competing for a console that only one may drive at a time

### `maui-engineer`

Version-aware **architecture and planning** for .NET MAUI: platform and workload pinning, native XAML against Blazor Hybrid, project layout and platform-code boundaries, MVVM and DI, navigation, app lifecycle, storage and offline data, testing, performance budgets you measure rather than copy, accessibility, and publishing.

A methodology skill. It resolves the real SDK, target frameworks and packages from your project, and asks for platform evidence rather than one green desktop build.

Prevents:

- Planning around the .NET LTS beneath MAUI, when a MAUI major is supported for a minimum of six months after its successor ships
- Runtime code generation that works in the simulator and fails on the device, because iOS and ARM64 Mac Catalyst forbid JIT
- A trim failure that surfaces in Debug and hides in Release, because iOS trims any device build while the others trim in Release
- State that does not survive Android process death or platform backup and restore
- An unpinned workload, so the same repository builds against a different toolchain tomorrow

### `reviewers`

A **review panel** rather than a code reviewer. Independent lenses examine the same change in parallel, findings merge by severity, and verdicts roll up worst-case-wins.

The shipped lenses are a starter kit. The value is the overlay, where you encode the mistakes your own project has made: a lens is a markdown file plus a roster entry, and your overlay survives every update. Declare read-only facts, such as your gate and your tests, and they run once for the whole panel rather than once per lens.

## How the skills are verified

Every API-bearing skill pins a ground truth: the package's assemblies reflected into a surface dump, or the SDK's shipped type information. Every type, member and signature in its documentation must exist there.

What metadata cannot show is established by compiling and executing the exact documented pattern against the pinned version. That covers optional parameters, `init`-only setters, protected members, experimental gates and runtime behaviour.

Reference documents carry a dated verification stamp. An automated gate rejects any unverified identifier, stale stamp or coverage regression before a release. Claims that an API does not exist are compile-tested rather than assumed.

---

Distributed under the MIT License.
