# 🧩 Layout, Dependency Injection & Testing

## `IRenderable` — the composition contract

Every widget implements `IRenderable`. Anything that is `IRenderable` can be nested inside a `Table` cell, a `Panel`, a `Columns`, a `Layout` region, or passed to `console.Write(...)`. Compose freely rather than reaching for string concatenation.

```csharp
using Spectre.Console;
using Spectre.Console.Rendering;   // IRenderable lives here

IRenderable content = new Panel(new Rows(
    new Markup("[bold]Build[/] complete"),
    new BarChart().AddItem("passed", 42, Color.Green).AddItem("failed", 3, Color.Red)));
AnsiConsole.Write(content);
```

## `Layout` — split the screen into regions

```csharp
using Spectre.Console;

var layout = new Layout("root")
    .SplitColumns(
        new Layout("left"),
        new Layout("right").SplitRows(new Layout("top"), new Layout("bottom")));

layout["left"].Update(new Panel("navigation").Expand());
layout["right"]["top"].Update(new Markup("[green]main[/]"));
layout["right"]["bottom"].Update(new Text("status bar"));
layout["left"].Ratio(1);
layout["right"].Ratio(2);

AnsiConsole.Write(layout);
```

* Address regions by name through the indexer (`layout["left"]`), then `Update(renderable)`.
* `Ratio`, `Size`, and `MinimumSize` control sizing; combine with a `Live` display for a full TUI dashboard.

---

## Static `AnsiConsole` vs injected `IAnsiConsole`

The static `AnsiConsole` is a convenience facade over a default `IAnsiConsole` (`AnsiConsole.Console`). For anything beyond a small script, **inject `IAnsiConsole`** — it is the seam that makes output testable and swappable.

```csharp
using Microsoft.Extensions.DependencyInjection;
using Spectre.Console;

// Registration (app composition root):
var services = new ServiceCollection();
services.AddSingleton<IAnsiConsole>(AnsiConsole.Console);

// Consumption — depend on the interface, never the static facade:
public sealed class Reporter(IAnsiConsole console)
{
    public void Report(string status) =>
        console.MarkupLineInterpolated($"status: [green]{status}[/]");
}
```

All the extension methods (`Write`, `MarkupLine`, `Status`, `Progress`, `Live`, `Prompt`, `Ask`, `Confirm`) hang off `IAnsiConsole`, so injected code reads identically to static code.

You can also build a bespoke console with `AnsiConsole.Create(new AnsiConsoleSettings { ... })` — useful to force a color system or point output at a specific writer.

---

## Testing with `TestConsole`

The **`Spectre.Console.Testing`** package provides `TestConsole` (an `IAnsiConsole`) that captures output and can feed scripted input. Pass it wherever your code expects `IAnsiConsole`.

### Capturing rendered output

```csharp
using Spectre.Console;
using Spectre.Console.Testing;

var console = new TestConsole();
console.Write(new Panel("[green]done[/]"));

// Inspect the rendered text:
string all = console.Output;                 // full captured string
var lines = console.Lines;                    // IReadOnlyList<string>, one entry per rendered line
```

### Driving a prompt in a test

```csharp
using Spectre.Console;
using Spectre.Console.Testing;

var console = new TestConsole().Interactive();   // mark as interactive
console.Input.PushTextWithEnter("Alice");        // scripted keystrokes

string name = console.Prompt(new TextPrompt<string>("Name?"));
// name == "Alice"
```

* `TestConsole().Interactive()` flips the capability so gated prompt code runs.
* `console.Input` (`TestConsoleInput`) queues input: `PushTextWithEnter`, `PushText`, `PushKey(ConsoleKey.DownArrow)`, `PushCharacter`.
* Force dimensions/encoding with `.Width(n)`, `.Height(n)`, `.SupportsAnsi(true)`, `.SupportsUnicode(true)`, `.Colors(ColorSystem.TrueColor)`.

---

## Non-tty / CI behavior

* Spectre auto-detects capabilities: piped/redirected output disables ANSI and interactivity. Read the truth from `AnsiConsole.Profile.Capabilities.Interactive` and `AnsiConsole.Profile.Out.IsTerminal`.
* **Static output** (`Table`, `Panel`, `MarkupLine`, …) is safe everywhere — it just renders without color/animation when unsupported.
* **Interactive features** (prompts + live displays) must be gated (see [prompts.md](prompts.md)); provide a non-interactive fallback path for CI.

## Performance notes

* Building a very large `Table` and rendering once is fine; avoid re-rendering the whole table inside a tight `Live` loop — mutate and `Refresh()` instead, and cap how often you refresh.
* Reuse a single `IAnsiConsole` rather than creating consoles per call.

---
*Verified against Spectre.Console v0.57.2 DLL surface (2026-07-14). `IRenderable`, `Layout`, `AnsiConsole`/`IAnsiConsole`, `AnsiConsoleSettings`, and the `Spectre.Console.Testing` `TestConsole`/`TestConsoleInput` types were extracted from the assembly surface and compile-tested against the pinned 0.57.2 package.*
