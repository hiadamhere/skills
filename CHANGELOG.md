# 📜 Changelog

All notable changes to the **AI Agent Skills Catalog** are recorded here, newest first.

Entries are dated by the day the change landed on `main`. The catalog is not versioned with semver — skills carry their own upstream version coverage (for example `msaf-architect` covers MAF v1.10 through v1.17), which is what you actually pin against.

---

## 2026-08-11

### Added

- **Every skill now has a reference page.** `skill.html?name=<skill>` renders a skill's own `SKILL.md` and lists its reference files. Previously only `msaf-architect` and `spectre-console` had pages; the other four linked straight to raw markdown, which the browser either dumped unstyled or refused to render. One data-driven page serves all six on purpose — a hand-written page per skill would be another artifact to keep in step with every skill change, and the page we maintain most is the one that went three MAF releases stale.

### Changed

- **The catalog page no longer hides the "View Reference" button.** `msaf-architect` carries eight version pills (v1.10–v1.17) in a flex row that could neither wrap nor shrink, so the pills pushed the button out of the card. Only that card was affected; every other skill has one to three pills.
- **The "Explore Docs Folder" card is gone.** It popped an alert saying the docs were being created and then navigated anyway — the alert never cancelled the click — to a `docs/` directory that is not published. A card advertising something that does not exist was the defect, not its wording.
- **The interactive visualizer's blueprint generator now offers the orchestration builders.** A new **Agent Orchestration** topology generates `AgentWorkflowBuilder` code — the shipped facade — alongside the existing hand-wired graph, which is now labelled **Multi-Agent Graph (hand-wired)** and is the right choice when you need to mix agents with plain `Executor` nodes. Previously the only agent option produced `new WorkflowBuilder(...)` + `.AddEdge(...)`: exactly the hand-rolling the orchestration reference tells you to avoid, on the page that reference links to.
  - The builders return a **finished `Workflow`**, so the generator no longer offers a human gate on that topology — a `RequestPort` needs edges to attach to. It says so instead of emitting code that cannot compile.
  - The generator is re-pinned from **v1.14.0 to v1.17.0**, on a page that already badged v1.10–v1.17.

### Notes

- **Every program the generator can produce is now compile-tested.** All 24 combinations of topology × persistence × human-gate were generated headlessly and built against pinned `Microsoft.Agents.AI.Workflows` 1.17.0 — 24/24 compile. That check found two real defects before release: the new topology emitted a call to an `IChatClient` factory it never declared (CS0103), and two later human-gate branches still emitted a gate the orchestration path cannot support (CS0246).

---

## 2026-08-10

### Added

- **`msaf-architect` documents the four orchestration builders** — sequential, concurrent, group chat, and handoff — in every version folder from v1.11 to v1.17. These are the shipped multi-agent topologies, and until now the skill documented none of them — Magentic, the fifth topology, appears only from v1.16 — so this was a whole category of workflow you would otherwise hand-roll from executors and edges.
  - **`AgentWorkflowBuilder` is the entry point and it is a `static` class** — reached through one-call methods (`BuildSequential`, `BuildConcurrent`) or factories that hand you a builder. Not obvious from the type names, and not where anyone looks first.
  - **`GroupChatWorkflowBuilder` has no public constructor** (CS1729) — it must be created through `CreateGroupChatBuilderWith`, which takes a `GroupChatManager` factory.
  - **There are two handoff builder types and both work.** `HandoffWorkflowBuilder` and `HandoffsWorkflowBuilder` — note the `s` — are separate sealed classes that both compile to a working workflow. The facade returns the non-`s` one.
  - **The reflected signature of `BuildConcurrent` is misleading:** its aggregator reads as required but is **optional**, as are `RoundRobinGroupChatManager`'s terminate function and every parameter of `WithAutonomousMode()`. A reflection dump renders an optional parameter identically to a required one — these three are compile-test facts the surface alone would have got wrong.

### Changed

- **Documentation coverage is now a ratchet, not a hope.** The gate measures how much of a pinned API surface a skill actually documents and **fails when that number drops**. Coverage may rise but never silently fall, and a package version that introduces undocumented types can no longer pass unnoticed. `msaf-architect` moves from 92 to 102 of 276 public MAF types with this release.

---

## 2026-08-07

### Added

- **`reviewers` — a configurable multi-lens review panel.** Several independent lenses examine the same change in parallel, each answering one question well rather than one reviewer answering all of them adequately. Findings merge by severity; verdicts roll up **worst-case-wins**, so one blocking lens outranks every approval.
  - **The default pack is organised by who pays when a change is wrong**, not by job title. Always-on: `correctness` (behavior at the edges nobody tried), `evidence` (test quality over test count — does a test fail without the change?), `risk` (blast radius, detection, reversibility), `clarity` (can the next person change it safely). Triggered by what the change touches: `security`, `performance`, `interface`, `docs`.
  - **Customization survives updates.** Shipped files under `references/` are replaced on every update; a `reviewers.local/` overlay is never touched. Disable a lens, retune when it fires, replace one wholesale, or add your own — a lens is a markdown file plus a roster entry, with no code to write and nothing else to register.
  - **It reviews more than code.** Nothing in the machinery assumes source code; only the default lenses do. Point it at specs, migrations, infrastructure, or documentation by turning off what does not apply and adding lenses that carry your own rules.
  - **Point it at your own history.** Set `lessons` to your post-mortems or ADRs and every lens reads them *before* hunting new findings — which is what stops a panel rediscovering a defect you already paid for.
  - **Vendor-neutral by construction.** Lenses are plain markdown with no tool names or vendor framing; a thin adapter per harness dispatches them. Any agent that can run a sub-task with a prompt can run the panel.

### Notes

- **The cost controls are load-bearing, not convenience.** A trivial-change clause (typo → one-line acknowledgement) and a scope cap (large diffs → top findings only) exist because an expensive gate gets skipped, and a skipped gate catches nothing. Removing them to be "more thorough" ends with the panel unused.
- **The panel reports; it never edits.** A reviewer that fixes is one nobody dares run on a whim — and running it on a whim is the entire value.

---

## 2026-08-06

### Added

- **`mcp-sdk` gains TypeScript and Python references**, completing the three-language coverage the skill's name promised. Each is verified against its own pinned SDK and type-checked before publish: `@modelcontextprotocol/sdk` **1.30.0** (`tsc --noEmit`) and `mcp` **2.0.0** (`pyright`).
  - **Python:** `from mcp.server.fastmcp import FastMCP` — the import in nearly every MCP tutorial — **does not exist in `mcp` 2.0.0**. The class is now `MCPServer` in `mcp.server.mcpserver`. `mcp.types.ToolResult` does not exist either; both fail in the type checker *and* at runtime. Type annotations on the decorated function are the input schema.
  - **TypeScript:** `server.tool()` is **`@deprecated`** in the shipped types — use `registerTool`. Import paths require `.js` suffixes under `Node16`/`NodeNext` resolution, and a tool result's `content` is an array of typed blocks; returning a bare string is a type error.
  - **All languages:** a stdio server must never write to stdout — the transport *is* stdout, so a stray `console.log`/`print()` corrupts the protocol stream.

### Changed

- **`microsoft-extensions-ai` substantially expanded.** The skill previously documented only chat calls, streaming, and `ChatOptions` while its description advertised tool calling, embeddings, and the middleware pipeline. Four new references close that gap, each compile-tested against the pinned 10.8.1 package:
  - **Tool and function calling** — `AIFunctionFactory`, `ChatOptions.Tools`, the four `ChatToolMode` values, and bounding the invocation loop.
  - **Structured output** — `GetResponseAsync<T>` and handling the deserialization failure branch.
  - **Embeddings** — the three `GenerateAsync` call shapes and their differing return types.
  - **Middleware and DI** — `ChatClientBuilder` composition, layer ordering, and `AddChatClient` registration.

- **`maui-engineer` gains navigation/MVVM and performance-budget guidance.** The skill advertised Shell navigation, MVVM/DI, and performance budgets while its references covered none of them. Two new guides close that: choosing one primary navigation model (and the deep-link/back-stack consequences), MVVM boundaries and DI lifetimes including the page/view-model ownership leak, and how to set, measure, and hold a performance budget. The performance guide deliberately contains **no threshold values** — per this skill's ground-truth policy, a performance claim is a before/after measurement on the target platform, never a number quoted from documentation.

- **`mcp-sdk` now documents what the pinned packages actually ship for HTTP.** The skill advertised "stdio/HTTP transports" while documenting stdio only. `WithHttpTransport()` does not exist on `IMcpServerBuilder` in `ModelContextProtocol` 2.0.0-preview.3 (CS1061), and there is no `MapMcp` in either assembly — that turnkey ASP.NET Core wiring ships in a separate `ModelContextProtocol.AspNetCore` package this skill does not verify. What *is* there: `WithStdioServerTransport()`, `WithStreamServerTransport(input, output)`, the `StreamableHttpServerTransport` primitive you host yourself, and `HttpClientTransport` — which is the **client** side despite the name.

### Notes

- **`ChatOptions.Tools` alone executes nothing.** The provider returns a function-call request; `UseFunctionInvocation()` is what invokes it. Declaring tools without that middleware produces a chat loop that appears to do nothing — the most common silent failure with this library.
- **Middleware order is behavior.** The first `Use…` registered is the outermost layer, so placing the cache before or after function invocation changes whether a cache hit skips the whole tool loop.
- Four names that model memory reaches for do not exist, each confirmed by compile test: `CompleteAsync` (CS1061), `ChatOptions.MaxTokens` (CS0117 — it is `MaxOutputTokens`), `ChatToolMode.Required` (CS0117 — it is `RequireAny`), and `Temperature = 0.7` as a `double` (CS0266 — the property is `float?`).

---

## 2026-08-05

The largest update so far: three new skills, and Microsoft Agent Framework coverage extended by four releases.

### Added

- **`microsoft-extensions-ai`** — verified guidance for [Microsoft.Extensions.AI](https://learn.microsoft.com/dotnet/ai/), .NET's unified LLM layer: `IChatClient` calls and streaming, `ChatOptions`, tool/function calling, embeddings, and the middleware pipeline. Verified against the **v10.8.1** assemblies. Training data mixes the old preview API with GA, so generated code frequently targets renamed members; this anchors it to the shipped surface.
- **`mcp-sdk`** — building **MCP servers** with the official SDKs: tool definition, stdio transport, and a minimal working server. The **C# reference** is verified against **ModelContextProtocol v2.0.0-preview.3**. TypeScript and Python references are planned, each to be verified against its pinned SDK.
- **`maui-engineer`** — architecture and planning guidance for .NET MAUI apps: target platforms, SDK/workload/package strategy, project layout, MVVM/DI, navigation, state and offline data, platform-abstraction boundaries, performance budgets, accessibility, and publish/signing constraints. Ships an environment inspector that produces a reviewable JSON snapshot of a project's toolchain. This is a **methodology** skill — it deliberately does not assert version-specific API signatures, and says so in its own Ground Truth section.
- **`msaf-architect` v1.14, v1.15, v1.16, and v1.17 reference folders**, each verified against the matching DLL surface.
- A **v1.15 & v1.16 Additions** view in the interactive visualizer, alongside the existing v1.14 Migration Map.

### Changed

- **`msaf-architect` version map rebuilt** for eight releases (v1.10 through v1.17), with an explicit distinction between an API that was *never present* in a version and one that was *removed or renamed* in it.
- The catalog page and README now present all five skills.

### Notes for upgraders

- **MAF v1.15 and v1.16 are purely additive** by mechanical surface diff — nothing was removed or renamed, so v1.14 code compiles unchanged. The traps are in adoption rather than migration.
- **v1.16's Magentic prompt customization is experimental and does not compile by default.** It raises `MAAI001` as a compile **error**, not a warning; the project needs `<NoWarn>$(NoWarn);MAAI001</NoWarn>`. The pre-existing `MagenticWorkflowBuilder` methods are not gated.
- **`MagenticPromptOverrides` properties are `init`-only.** Set them in an object initializer; assigning after construction does not compile.
- **`GetLatestCheckpointAsync` returns a nullable `CheckpointInfo?`.** A session that has never checkpointed yields `null`. Assigning it to a non-nullable `CheckpointInfo` raises CS8600 and sets up a null dereference at resume — declare it nullable and branch. This corrects guidance published earlier in this release cycle.
- **MAF v1.17 changes nothing at the API level.** The public surface of all three assemblies is byte-identical to v1.16 by mechanical diff — no additions, no removals, no renames — so v1.16 code compiles unchanged. The v1.17 reference folder exists so version resolution lands somewhere that says so. Note the Magentic prompt surface is *still* behind `MAAI001` a second release later.
- **v1.14 remains the breaking one** in this range: async agent modes, async message injection, contextual tool auto-approval, and the approval-middleware replacements. See the v1.14 migration trap table in the version map.

---

## 2026-07-20

### Changed

- README now presents [`spm`](https://www.npmjs.com/package/@hiadamhere/spm) as the recommended installer, alongside the existing one-line remote install and clone-based options.

---

## 2026-07-19

### Added

- **`spectre-console`** — verified, version-matched guidance for rich .NET terminal UIs with [Spectre.Console](https://spectreconsole.net/): tables, panels, trees, markup and color, live displays (`Status`/`Progress`/`Live`), and interactive prompts, plus the terminal-gating discipline that keeps interactive features from hanging in CI or non-tty contexts. Verified against the **v0.57.2** assemblies.

### Fixed

- Remote installs are now **snapshot-consistent** — all files come from a single pinned repository state rather than whatever each individual download happened to fetch.
- The MSAF visualizer gained a "Back to the Skills Catalog" link, matching the Spectre page.

---

## 2026-07-14

### Added

- **`msaf-architect` v1.13 support** — composable and disposable agent skill sources, granular skill/file approval flags, and the renamed `AgentFileStore` contract.

---

## 2026-07-08

### Added

- Installers gained **multi-select** (choose individual skills), **uninstallers**, and **folder scope** for workspace-level installs.

---

## 2026-07-07

### Fixed

- The visualizer's architecture generator now emits **complete, compilable programs** rather than fragments.
- The `irm … | iex` one-line Windows install works as documented.

---

## 2026-07-06

### Added

- **Initial catalog release.**
- **`msaf-architect`** — DLL-verified Microsoft Agent Framework guidance covering **v1.10 through v1.12**.
- Cross-agent installers for Windows and macOS/Linux.
- The interactive catalog site (GitHub Pages) and the MSAF visualizer.
- Repository documentation, governance, and issue templates.

---

*Entries dated before 2026-08-05 were reconstructed from this repository's commit history. They record what shipped and when; they are not contemporaneous release notes.*
