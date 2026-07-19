# 🎨 Markup & Color

Spectre renders styled text from an inline **markup** string: `[style]…[/]`. Styles combine a foreground color, an optional `on` background, and decorations.

```csharp
using Spectre.Console;

AnsiConsole.Markup("[bold red]Error:[/] disk full\n");
AnsiConsole.MarkupLine("[green]OK[/] · [yellow]warn[/] · [blue on white] info [/]");
AnsiConsole.MarkupLine("[underline #ff8700]hex color + decoration[/]");
```

* `Markup(string)` writes without a trailing newline; `MarkupLine(string)` appends one.
* Styles stack space-separated inside one tag: `[bold italic red on grey19]…[/]`.
* Colors accept named (`red`, `green`, `grey`), hex (`#ff8700`), `rgb(…)`, and 0–255 palette forms.

---

## ⚠️ Escaping — the #1 markup bug

Any `[` or `]` in **interpolated or user-supplied** text is treated as markup and will throw or corrupt output. Escape it:

```csharp
using Spectre.Console;

string userInput = "array[0] = [redacted]";
AnsiConsole.MarkupLine($"You typed: [grey]{Markup.Escape(userInput)}[/]");   // safe

// Prefer the interpolated helpers, which escape the holes for you:
AnsiConsole.MarkupLineInterpolated($"You typed: [grey]{userInput}[/]");
```

* `Markup.Escape(string)` → doubles brackets so they render literally.
* `Markup.Remove(string)` → strips markup, yielding plain text (useful for logging).
* `AnsiConsole.MarkupLineInterpolated` / `MarkupInterpolated` escape interpolation holes automatically — the safest option for dynamic text.

---

## The `Markup` renderable

For composition (inside a `Table`, `Panel`, …) use the `Markup` widget rather than the write helpers:

```csharp
using Spectre.Console;

var cell = new Markup("[bold]hi[/]");
var fromValues = Markup.FromInterpolated($"count = [green]{42}[/]");   // escapes the hole
AnsiConsole.Write(new Panel(cell));
AnsiConsole.Write(fromValues);
```

---

## Color and Style as values

`Color`, `Style`, and `Decoration` are value types in `Spectre.Console.Ansi`. Build a `Style` explicitly when you don't want to hand-write markup:

```csharp
using Spectre.Console;

var style = new Style(
    foreground: Color.Green,
    background: Color.Black,
    decoration: Decoration.Bold | Decoration.Underline);

AnsiConsole.Write(new Text("styled text", style));

// Parse from / render to markup:
Style parsed = Style.Parse("bold red on white");
string markup = style.ToMarkup();
```

* `Color` exposes named statics (`Color.Green`, `Color.Red`, `Color.Yellow`, `Color.Grey`, `Color.Aqua`, `Color.Default`, …) and constructors from RGB bytes.
* `Decoration` is a `[Flags]` enum: `Bold`, `Dim`, `Italic`, `Underline`, `Invert`, `Conceal`, `SlowBlink`, `RapidBlink`, `Strikethrough`, `None`.

---

## Emoji & text shaping

* Emoji shortcodes render inside markup: `AnsiConsole.MarkupLine(":check_mark: done");` — `Emoji.Known` holds the catalog, and `Emoji.Replace(text)` substitutes shortcodes in arbitrary strings.
* On a `Text` (or column) control wrapping with `Justify` (`Left`/`Right`/`Center`) and `Overflow` (`Fold`/`Crop`/`Ellipsis`).

```csharp
using Spectre.Console;

var t = new Text("a very long line that may not fit", new Style(Color.Grey))
{
    Justification = Justify.Right,
    Overflow = Overflow.Ellipsis,
};
AnsiConsole.Write(t);
```

---
*Verified against Spectre.Console v0.57.2 DLL surface (2026-07-14). `Markup`, `Style`, `Color`, `Decoration`, `Text`, `Justify`, `Overflow`, and the escape/interpolation helpers were extracted from the `Spectre.Console` / `Spectre.Console.Ansi` assembly surface and compile-tested against the pinned 0.57.2 package.*
