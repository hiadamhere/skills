# ⏳ Live Displays: Status, Progress, Live

Three widgets animate a region of the console: **`Status`** (a spinner + message), **`Progress`** (task bars), and **`Live`** (re-render any renderable in place).

> [!IMPORTANT]
> **Exclusive console control.** While a live display runs, it owns the output region. **Do not** write to the console directly or start a second live display from inside the callback — mutate through the supplied *context* (`StatusContext` / `ProgressContext` / `LiveDisplayContext`) instead. Live displays also require an interactive terminal (see [terminal gating](prompts.md)); in non-tty/CI they degrade or throw.

---

## Status — spinner + message

```csharp
using Spectre.Console;

AnsiConsole.Status()
    .Spinner(Spinner.Known.Dots)
    .SpinnerStyle(new Style(Color.Green))
    .Start("Connecting…", ctx =>
    {
        // …first unit of work…
        ctx.Status = "Fetching data…";      // update the message
        ctx.Spinner = Spinner.Known.Star;   // swap the spinner mid-flight
        ctx.Refresh();
        // …next unit of work…
    });
```

Async variant — return a `Task` from the callback:

```csharp
using Spectre.Console;
using System.Threading.Tasks;

await AnsiConsole.Status().StartAsync("Working…", async ctx =>
{
    await Task.Delay(500);
    ctx.Status = "Almost there…";
    await Task.Delay(500);
});
```

`Spinner.Known` exposes the catalog (`Dots`, `Star`, `Line`, `Ascii`, `Dots2`…`Dots14`, `Sand`, …).

---

## Progress — one or more task bars

```csharp
using Spectre.Console;

AnsiConsole.Progress()
    .AutoClear(false)          // keep the finished bars on screen
    .HideCompleted(false)
    .Columns(new ProgressColumn[]
    {
        new TaskDescriptionColumn(),
        new ProgressBarColumn(),
        new PercentageColumn(),
        new RemainingTimeColumn(),
        new SpinnerColumn(),
    })
    .Start(ctx =>
    {
        var download = ctx.AddTask("[green]Downloading[/]");   // MaxValue defaults to 100
        var install  = ctx.AddTask("[green]Installing[/]", autoStart: false);

        while (!ctx.IsFinished)
        {
            download.Increment(2.5);
            if (download.Value >= 50 && !install.IsStarted)
                install.StartTask();
            install.Increment(1.0);
            // …pace the loop / await real work…
        }
    });
```

* `ctx.AddTask(description)` → a `ProgressTask`. Drive it with `Increment(double)` or set `Value` / `MaxValue` directly; read `IsFinished`, `Percentage`, `IsStarted`.
* The loop condition `!ctx.IsFinished` is the idiomatic pump — it's `true` until every task reaches its `MaxValue`.
* Default columns are used if you don't call `.Columns(...)`.

---

## Live — re-render any renderable in place

Use when you're updating a whole widget (e.g. a growing `Table`) rather than a percentage.

```csharp
using Spectre.Console;

var table = new Table().AddColumn("Step").AddColumn("Result");

AnsiConsole.Live(table).Start(ctx =>
{
    foreach (var step in new[] { "build", "test", "pack" })
    {
        table.AddRow(step, "[green]ok[/]");
        ctx.Refresh();                       // repaint after each mutation
        // …await the next step…
    }
});
```

* `ctx.Refresh()` repaints the current target; `ctx.UpdateTarget(newRenderable)` swaps in a different renderable entirely.
* `Live(...)` config: `.AutoClear(bool)`, `.Overflow(VerticalOverflow.Ellipsis)`, `.Cropping(VerticalOverflowCropping.Top)`.

---

## Injected-console form

All three are extension methods on `IAnsiConsole`, so injected code uses the identical fluent chain:

```csharp
using Spectre.Console;

public async Task RunAsync(IAnsiConsole console)
{
    await console.Status().StartAsync("Working…", async _ => await Task.Delay(200));
}
```

---
*Verified against Spectre.Console v0.57.2 DLL surface (2026-07-14). `Status`, `Progress`, `Live` and their context types, the `ProgressColumn` set, and `Spinner.Known` were extracted from the `Spectre.Console` assembly surface and compile-tested against the pinned 0.57.2 package.*
