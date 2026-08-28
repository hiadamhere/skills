# 📜 Changelog

All notable changes to the **AI Agent Skills Catalog** are recorded here, newest first.

Entries are dated by the day the change landed on `main`. The catalog is not versioned with semver — skills carry their own upstream version coverage (for example `msaf-architect` covers MAF v1.10 through v1.19), which is what you actually pin against.

---

## 2026-08-27

### Added

- **`msaf-architect` now covers MAF v1.18 and v1.19** — both verified against the real NuGet assemblies (reflection surface dumps, compile tests, and executed probes), both **purely additive** by mechanical diff, and both new reference folders wired into the version map, the truth gate, and the eval suite.
  - **v1.18** is agent-layer only (`Microsoft.Agents.AI.Abstractions` and `.Workflows` are byte-identical to v1.17): `ChatClientAgentOptions.AllowConcurrentInvocation` runs several returned function calls in parallel; `ToolApprovalAgentOptions.MaxAutoApprovalIterations` bounds the auto-approval re-invocation loop (default **40**, via a `const` the reflection dump cannot see — proven by CS0131); `EnableInvocableFunctionBypassing` / `UseInvocableFunctionBypassing` keep backend function calls from being orphaned when a frontend tool is in the same response; `BackgroundAgentsProvider.ReleaseSessionAsync` stops abandoned background work (idempotent, 30-second default wait).
  - **v1.19** touches all three assemblies: `RoutePersistingRoutingChatClient` picks a named inner chat client **per session** and persists the choice in the session's state bag (it throws outside an agent run — established by execution); `WorkflowAgentMetadata` identifies a workflow-hosting agent through `GetService`, even behind middleware; `WorkflowHostingExtensions.WithCheckpointing` redirects a built workflow agent's checkpoints into your `CheckpointManager`; `WorkflowSessionCheckpointRecovery` positions a session on a checkpoint; `FeatureUsage` is process-wide feature tracking the package marks as infrastructure. MAF 1.19.0 also moves its `Microsoft.Extensions.AI` dependency from 10.7.0 to **10.9.0**.
  - **The experimental gate is per member, and both releases are split.** `MAAI001` is a compile error on the invocable-function bypass, `BackgroundAgentsProvider`, the routing client and its options, `WorkflowSessionCheckpointRecovery`, and `FeatureUsage` — but **not** on `AllowConcurrentInvocation`, `MaxAutoApprovalIterations`, `WithCheckpointing`, or `WorkflowAgentMetadata`. A surface dump renders none of this; every cell came from a compile.
  - Traps established by execution, not by reading metadata: `WithCheckpointing` returns the **same instance, unchanged** for a wrapped agent (silently), for a non-workflow agent, and when the environment already names a checkpoint manager; it also regenerates an auto-generated agent id while preserving an explicit one. `WorkflowSessionCheckpointRecovery.CurrentCheckpoint` is really `CheckpointInfo?` (CS8600), and `TryPrepare` **does not check that the id exists** — `"bogus"` is accepted and the next run throws a KeyNotFoundException (only an empty or whitespace id is rejected, with an ArgumentException). `AsAIAgent` accepts any `Workflow` but the first run throws unless the graph speaks the chat protocol (`List<ChatMessage>` + `TurnToken`) — the orchestration builders qualify, a bare `Executor<string, string>` does not.
- **`msaf-architect` now documents hosting a workflow as an agent** (`WorkflowHostingExtensions.AsAIAgent`) — present since v1.10 and never mentioned until the v1.19 checkpoint controls made it unavoidable. The rule now sits in every version folder's state guide: all parameters are optional (reflected on 1.14.0, 1.17.0 and 1.19.0), without an `id` the agent gets a fresh identifier per call, and a workflow that does not speak the chat protocol throws on its first run (executed on the same three versions).
- **The visualizer gains a v1.18 & v1.19 Additions view** and its blueprint generator now targets 1.19.0. The 24 generated programs were compile-tested at 1.17.0; the Workflows members they use are unchanged through 1.19.0 by mechanical diff, and the page says exactly that rather than claiming a 1.19.0 build.

### Changed

- **`reviewers` now says what it is: a framework for running *your* rules as reviewers, with a starter pack.** The shipped code-review lenses are described as generic starters rather than as the product — on a real run they produced restatements, while the lenses encoding the repository's own incidents found every defect that mattered. Three additions to the contract, each from that run: **`facts`** (read-only commands the adapter runs once, whose output every lens receives as verified — on one recorded run six lenses had independently rebuilt the same probes, roughly a third of that run's cost); **`profiles`** (`quick` for a small edit, `--all` for a release); and a defined **`on_exceed`** behaviour when a change is over the scope cap. Adapters are asked to report per-lens cost, and to script the deterministic half (merge, globs, verdict registration) rather than have a model do it from prose.

### Fixed

- **The `reviewers` body contradicted its own contract.** `SKILL.md` said "dispatch the whole roster"; `panel.yaml` and the adapter contract said a triggered lens runs only when a glob matches. The constraint now says the latter. A lens's `mode` is also declared in the roster only — the `mode:` line every shipped lens carried in its frontmatter was a second source of truth (an overlay that retuned a lens silently disagreed with the file) and is gone.
- **The v1.14 guide said the approval builder extensions "require a logger factory". They do not.** `UseApprovalNotRequiredFunctionBypassing` and `UseApprovalResponseBinding` take `ILoggerFactory? loggerFactory = null` — the bare calls compile against the pinned 1.14.0 packages. The claim came from reading the surface dump, which renders an optional parameter identically to a required one; corrected in the v1.14 guides, the version-map trap table, the visualizer, and the eval case that had been grading models on the wrong answer.

---

## 2026-08-14

### Added

- **`msaf-architect` now documents declarative executors** — the attribute-driven way to write an executor that handles several message types, which the `Executor<TInput>` shape cannot express. All five attributes (`[MessageHandler]`, `[SendsMessage]`, `[StreamsMessage]`, `[YieldsMessage]`, `[YieldsOutput]`), plus `ProtocolBuilder` and `RouteBuilder`, had zero mentions.
- **`ReflectingExecutor<TExecutor>` is `[Obsolete]`** — in v1.11 and every version since — and the skill would have taught it as the recommended path. Its own message points at "a partial class deriving from `Executor`". **A surface dump cannot show this**: the analyzer emits members, not the attributes on a type, so the reflected API presents a deprecated type as the natural choice. Only a compiler warning (CS0618) reveals it.
  - The replacement is `Executor` + `protected abstract ConfigureProtocol` — also invisible to a dump, and **CS0534** if you omit it.
  - The obsoletion message describes a source generator that **is not in the package**: `Microsoft.Agents.AI.Workflows` 1.17.0 ships no `analyzers/` folder, and a partial `Executor` subclass with only `[MessageHandler]` methods still fails with CS0534. Write `ConfigureProtocol` by hand.
  - The working shape was **executed**, not merely compiled: the routed executor reports `InputTypes = System.String`, `OutputTypes = System.Int32`, and yields `5` for `"hello"`.

- **`msaf-architect` now maps the workflow event stream** — 21 event types, of which **12 had zero mentions** anywhere in the skill, including every superstep and lifecycle event. Streaming a workflow is how you observe it, and the skill described the run but not what comes back. The set is identical across v1.11–v1.17.
- Three traps in that taxonomy, all compile-established:
  - **`WorkflowOutputEvent` must be the last `case` in a `switch`.** `AgentResponseEvent` and `AgentResponseUpdateEvent` derive from it, so placing it earlier silently swallows both — and it compiles, because the pattern order is legal. The symptom is "no agent responses" with nothing to explain it.
  - **The Magentic events live in a different namespace** (`Microsoft.Agents.AI.Workflows.Specialized.Magentic`). Without that second `using` they are **CS0246 — not found**, which reads as "this version doesn't have them" rather than "you're missing an import".
  - **The failure payload is spelled two ways**: `ExecutorFailedEvent` exposes its exception as `Data` (shadowing the base `object Data`), `WorkflowErrorEvent` as `Exception`.
  - `InProcessExecution.StreamAsync` does not exist (**CS0117**) — the method is `RunStreamingAsync`, and its `checkpointManager`/`sessionId` are optional.

- **`msaf-architect` now documents context compaction** — the shipped answer to a long-running agent outgrowing its context window, and until now an entire namespace (`Microsoft.Agents.AI.Compaction`, 15 types) with **zero mentions** anywhere in the skill. Strategies decide what to drop or summarise, triggers decide when, and `CompactionProvider` plugs the pair into an agent so it happens without a run loop of your own. The namespace is byte-identical from v1.10 through v1.17, and the probe program behind the guide compiles unmodified against pinned 1.11.0, 1.14.0 and 1.17.0 — so the optional-parameter forms are asserted across the range, not only at the newest end.
- Four traps in that layer that a reflection dump cannot show, each established by a compiler error rather than by reading metadata:
  - `CompactAsync` is **not** the override target — it is public but not virtual (**CS0506**). The member you implement is `protected abstract CompactCoreAsync`, which never appears in a surface dump because the dumper emits public members only. The base constructor is likewise protected and requires a trigger (**CS7036**).
  - `ToolResultCompactionStrategy.ToolCallFormatter` reflects as `{ get; set; }` but is **`init`-only** (**CS8852**); reflection cannot tell an `init` accessor from a `set` accessor.
  - `AIAgentBuilder.UseAIContextProviders` **rejects** a `CompactionProvider` (**CS1503**) — its parameter is `MessageAIContextProvider[]`. The name is shared by two methods that take different types.
  - `ChatClientAgentOptions` has no `Instructions` property (**CS0117**).

---

## 2026-08-13

### Changed

- **The coverage ratchet now bounds the undocumented set, not just the documented one.** A floor on documented types cannot catch a package version that *adds* types nobody documented — `covered` is untouched, so the floor passes while coverage falls. `msaf-architect` would have gone from 37% to 27% on a version bump and passed. A second number now bounds the gap (`total − covered`), which grows both when a version adds types and when documentation is deleted. Floor may only rise; ceiling may only fall.
- **The type counter stopped miscounting.** Nested types were truncated onto their container — `ContentBlock.Converter` became `ContentBlock`, a different real type, crediting the wrong one as documented. Compiler-generated types were padding the denominator with entries that cannot be documented because they are not API. Fixing both recovers 39 real types across the pinned surfaces. (Generic arities still collapse — `Executor`, `Executor<T>` and `Executor<T,U>` count once — which is deliberate: the metric counts whether a type is *mentioned*, and prose writes `Executor`.)
- **Repeated guidance across version folders is now checked mechanically.** Some content is duplicated on purpose, because a reader lands in exactly one version folder and a rule that lives only in another prevents nothing. Nothing forced those copies to track their source — correct the original and stale copies remained. Marked blocks must now stay identical, and an unclosed marker fails rather than silently excluding the block.
- **`msaf-architect`'s two orchestration homes are now linked.** The routing guide also demonstrates the orchestration builders, and the version chain sends readers there — but it carried none of the three traps the dedicated guide exists for. It now says so and points at them.

---

## 2026-08-12

### Changed

- **`reviewers`: `triggers` are now honoured, not decorative.** The manifest said a `triggered` lens fires when one of its globs matches a changed path; the adapter contract said dispatch every lens that is not disabled. Both were normative and they contradicted each other, so `triggers` were consumed by nothing and every run paid for the whole roster. The contract now selects the roster from the triggers, reports which lenses ran and which were skipped, and reserves the full pass for `--all` or a pre-merge review. Measured against four real changes in the repository that develops this skill, that is **~40% fewer lens dispatches**.
- **The panel no longer lets one lens corrupt another's evidence.** Lenses run in parallel over a single working tree, so a lens that runs a test suite rewriting files in place changes what its siblings read. This is not hypothetical: a panel reported a finding about a value that existed for two seconds while a sibling rewrote a config file. Lenses may no longer run anything that mutates tracked files, and are told to check whether the tree is clean and state which version of a file they assessed.
- **Re-runs verify instead of inheriting.** When a change claims to fix an earlier round's findings, each lens is now told which of its own findings are claimed fixed and to verify rather than trust. Adopted after panels caught a blocker inside the fix to the previous blocker, a stamp whose reasoning was circular, and a sentence broken by the edit that fixed the one before it.
- **Disagreements are surfaced, not silently resolved.** When two lenses reach opposite conclusions while each cites the manifest correctly, the report carries both positions and the evidence for each. That call belongs to the author; one such disagreement exposed a design gap neither lens had named alone.

### Notes

- **Two behaviours the lenses had shown emergently are now in the lens template**: retract a finding once evidence shows it was churn, and never raise severity because a finding was declined — severity describes the defect, not the conversation about it.
- **A `core` lens that also declares `triggers` is incoherent** and the guidance now says so: the triggers can never be consulted. Making every lens `core` is the same mistake as removing the cost controls — the roster runs in full on every change until nobody runs it at all.

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
