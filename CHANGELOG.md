# 📜 Changelog

All notable changes to the **AI Agent Skills Catalog** are recorded here, newest first.

Entries are dated by the day the change landed on `main`. The catalog is not versioned with semver — skills carry their own upstream version coverage (for example `msaf-architect` covers MAF v1.10 through v1.16), which is what you actually pin against.

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
