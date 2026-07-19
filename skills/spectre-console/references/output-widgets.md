# 📦 Output Widgets

All widgets implement `IRenderable` and are printed with `AnsiConsole.Write(renderable)` (or `console.Write(...)` on an injected `IAnsiConsole`). They compose: any widget can contain another.

> [!WARNING]
> The Spectre.Console API family is pre-1.0. Every identifier below is verified against the **v0.57.2** surface; fluent method names differ in other minors.

---

## Table

The workhorse widget. Columns and rows are added through fluent extension methods; borders/titles are properties.

```csharp
using Spectre.Console;

var table = new Table();
table.Border = TableBorder.Rounded;          // TableBorder.Rounded | Square | Minimal | Ascii | Markdown | Heavy …
table.Title = new TableTitle("[yellow]Users[/]");
table.Caption = new TableTitle("2 rows");
table.Expand = true;                          // fill available width

table.AddColumn("Name");
table.AddColumn(new TableColumn("Age").Centered());   // TableColumn carries per-column config
table.AddRow("Alice", "30");
table.AddRow("Bob", "25");

AnsiConsole.Write(table);
```

* `AddColumn`, `AddColumns`, `AddRow`, `AddEmptyRow` are extensions that return the `Table` for chaining.
* A cell can itself be a renderable: `table.AddRow(new Markup("[red]!!![/]"), new Panel("nested"))` (the `AddRow(params IRenderable[])` overload).

## Grid

A lighter, border-less table for aligned key/value layouts.

```csharp
using Spectre.Console;

var grid = new Grid();
grid.AddColumn();
grid.AddColumn();
grid.AddRow("[bold]Version[/]", "0.57.2");
grid.AddRow("[bold]Mode[/]", "Release");
AnsiConsole.Write(grid);
```

## Panel

A bordered box around any renderable.

```csharp
using Spectre.Console;

var panel = new Panel("[green]Deployment succeeded[/]")
{
    Header = new PanelHeader("Status"),
    Border = BoxBorder.Rounded,               // BoxBorder.Rounded | Square | Heavy | Double | Ascii | None
    Padding = new Padding(2, 1),              // (horizontal, vertical)
    Expand = false,
};
AnsiConsole.Write(panel);
```

## Tree

Hierarchical output. `AddNode` returns the created `TreeNode`, which itself has `AddNode`.

```csharp
using Spectre.Console;

var tree = new Tree("[bold]solution/[/]");
var src = tree.AddNode("[blue]src/[/]");
src.AddNode("Program.cs");
src.AddNode("Widgets.cs");
tree.AddNode("README.md");
AnsiConsole.Write(tree);
```

## Rule (horizontal divider)

```csharp
using Spectre.Console;

AnsiConsole.Write(new Rule("[yellow]Section[/]") { Justification = Justify.Left });
```

## Columns & Rows

Lay renderables out side-by-side (`Columns`) or stacked (`Rows`).

```csharp
using Spectre.Console;

AnsiConsole.Write(new Columns(new Panel("Left"), new Panel("Right")));
AnsiConsole.Write(new Rows(new Text("first line"), new Text("second line")));
```

## Padder & Align

Indent or position a renderable within the available width.

```csharp
using Spectre.Console;

AnsiConsole.Write(new Padder(new Text("indented 4"), new Padding(4, 0, 0, 0)));
AnsiConsole.Write(Align.Center(new Panel("centered"), VerticalAlignment.Middle));
```

## TextPath

Renders a filesystem path, shortening the middle to fit.

```csharp
using Spectre.Console;

AnsiConsole.Write(new TextPath("C:/src/project/src/Widgets/Table.cs"));
```

## FigletText (banners)

```csharp
using Spectre.Console;

AnsiConsole.Write(new FigletText("Spectre").Color(Color.Green));
```

## BarChart

```csharp
using Spectre.Console;

var chart = new BarChart()
    .Width(60)
    .Label("[green bold]Quarterly sales[/]")
    .AddItem("Q1", 120, Color.Green)
    .AddItem("Q2", 80, Color.Yellow)
    .AddItem("Q3", 54, Color.Red);
AnsiConsole.Write(chart);
```

Other charts follow the same shape: `BreakdownChart` (`.AddItem`), and `Calendar` (`new Calendar(2026, 7)`).

---
*Verified against Spectre.Console v0.57.2 DLL surface (2026-07-14). Every type, property, and fluent extension shown was extracted from the `Spectre.Console` / `Spectre.Console.Ansi` assembly surface and compile-tested against the pinned 0.57.2 package.*
