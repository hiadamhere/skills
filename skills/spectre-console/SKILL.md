---
name: spectre-console
description: Expert guidance for building rich .NET terminal UIs with the Spectre.Console library — tables, panels, trees, markup/color, live displays (Status/Progress/Live), and interactive prompts (Selection/MultiSelection/Text/Confirmation). Use when writing or debugging C# console output/interaction that references the Spectre.Console, Spectre.Console.Ansi, or Spectre.Console.Cli NuGet packages, or when a hosted/non-interactive/CI context needs safe terminal gating. Not for System.Console formatting or non-.NET TUIs.
---

# 🎨 Spectre.Console Expert Skill

This skill embeds verified, version-matched guidance for building polished terminal UIs with **[Spectre.Console](https://spectreconsole.net/)** in C#.

> [!IMPORTANT]
> **Ground-truth policy.** Every type, method, and property named in this skill's code is verified against the actual **Spectre.Console v0.57.2** assembly surface (`Spectre.Console`, `Spectre.Console.Ansi`, `Spectre.Console.Testing`) and compile-tested against the pinned package. LLM training data mixes APIs across major versions and invents fluent methods that were never shipped — trust the reference guides here, not memory.

---

## 🧭 Getting Started: Resolve the Version First

Spectre.Console is pre-1.0 and its fluent surface shifts between minor releases. **Resolve the installed version before writing code:**

1. Check the project's `.csproj` / `Directory.Packages.props` for the `Spectre.Console` (and optionally `Spectre.Console.Cli`) `PackageReference` version.
2. These guides target **v0.57.2**. If the project pins an older minor, treat fluent-method names as *unverified* until confirmed — the identifiers documented here were extracted from 0.57.2.
3. Note the assembly split: high-level widgets (`Table`, `Panel`, `Progress`…) live in **`Spectre.Console.dll`**, while the `Color`, `Style`, and `Decoration` value types live in the companion **`Spectre.Console.Ansi.dll`** (transitively referenced). Both ship with the `Spectre.Console` package.

### Reference guides
* **[Output widgets](references/output-widgets.md)** — `Table`, `Grid`, `Panel`, `Tree`, `Rule`, `Columns`, `Rows`, `Padder`, `Align`, `TextPath`, `FigletText`, charts.
* **[Markup & color](references/markup-and-color.md)** — the `[style]…[/]` markup language, `Markup.Escape`, `Color`, `Style`, `Decoration`, emoji, escaping pitfalls.
* **[Live displays](references/live-displays.md)** — `Status`, `Progress`, `Live` and the exclusive-console-control rule.
* **[Prompts](references/prompts.md)** — `TextPrompt`, `ConfirmationPrompt`, `SelectionPrompt`, `MultiSelectionPrompt`, and terminal gating.
* **[Layout, DI & testing](references/layout-and-testing.md)** — `IRenderable`, `Layout`, `AnsiConsole` vs injected `IAnsiConsole`, `TestConsole`, non-tty/CI behavior.

---

## 🚦 The One Rule That Prevents Hangs

Spectre's **interactive** features — every prompt, and the `Status`/`Progress`/`Live` displays — assume a real terminal. In a redirected-stdin, CI, or hosted (non-tty) context they will throw or block waiting for input that never comes.

**Always gate interactive calls on terminal capability** using verified APIs:

```csharp
using Spectre.Console;

// Interactive == a real, attached terminal that can read keystrokes.
if (AnsiConsole.Profile.Capabilities.Interactive && AnsiConsole.Profile.Out.IsTerminal)
{
    var name = AnsiConsole.Ask<string>("Your [green]name[/]?");
    AnsiConsole.MarkupLine($"Hello, [bold]{Markup.Escape(name)}[/]!");
}
else
{
    // Non-interactive fallback: plain output, defaults, or read from args/env.
    AnsiConsole.WriteLine("Running non-interactively; using defaults.");
}
```

* `AnsiConsole.Profile.Capabilities.Interactive` — `false` when input is redirected or the console can't be driven interactively.
* `AnsiConsole.Profile.Out.IsTerminal` — `false` when stdout is redirected (piped/captured).

---

## 🧱 Core Principles

* **Prefer injected `IAnsiConsole` over the static `AnsiConsole`.** The static facade is convenient for apps, but taking an `IAnsiConsole` parameter makes code testable (swap in a `TestConsole`) and DI-friendly. Both expose the same extension methods (`Write`, `MarkupLine`, `Prompt`, `Status`, `Progress`, `Live`, …).
* **Everything printed is an `IRenderable`.** Widgets (`Table`, `Panel`, `Tree`, `Markup`, …) implement `IRenderable` and nest inside one another; render with `console.Write(renderable)`.
* **Escape all interpolated/user text with `Markup.Escape`.** Raw `[` and `]` are markup control characters and will throw or mis-render if they appear in untrusted strings.
* **Live displays take exclusive control of the console region.** Never start a second live display (or write directly to the console) from inside a running `Status`/`Progress`/`Live` callback — mutate through the supplied context instead.
