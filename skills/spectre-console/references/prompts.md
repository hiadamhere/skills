# ⌨️ Prompts

Spectre offers four interactive prompts: free-text (`TextPrompt<T>`), yes/no (`ConfirmationPrompt`), single-choice (`SelectionPrompt<T>`), and multi-choice (`MultiSelectionPrompt<T>`). Run them via `AnsiConsole.Prompt(...)` or the `Ask`/`Confirm` shortcuts.

> [!WARNING]
> **Every prompt needs a real terminal.** With redirected stdin, in CI, or in a hosted (non-tty) process, prompts throw or block forever. **Always gate** on capability first — this is the single most common source of hangs:
> ```csharp
> if (!(AnsiConsole.Profile.Capabilities.Interactive && AnsiConsole.Profile.Out.IsTerminal))
>     return fallbackValue;   // read from args/env/defaults instead
> ```

---

## Text prompts (and the `Ask` shortcut)

```csharp
using Spectre.Console;

// Shortcut: typed free-text with conversion built in.
int age = AnsiConsole.Ask<int>("Your [green]age[/]?");

// Full control via TextPrompt<T>:
string name = AnsiConsole.Prompt(
    new TextPrompt<string>("Project [green]name[/]?")
        .DefaultValue("my-app")
        .ShowDefaultValue()
        .Validate(n => string.IsNullOrWhiteSpace(n)
            ? ValidationResult.Error("[red]Name cannot be empty[/]")
            : ValidationResult.Success()));

// Masked secret input:
string pw = AnsiConsole.Prompt(new TextPrompt<string>("Password?").Secret());

// Optional input:
string note = AnsiConsole.Prompt(new TextPrompt<string>("Note?").AllowEmpty());
```

## Confirmation

```csharp
using Spectre.Console;

bool proceed = AnsiConsole.Confirm("Deploy to [red]production[/]?", defaultValue: false);

// Or the widget for finer control:
bool ok = AnsiConsole.Prompt(new ConfirmationPrompt("Continue?") { DefaultValue = true });
```

## Single selection

```csharp
using Spectre.Console;

string env = AnsiConsole.Prompt(
    new SelectionPrompt<string>()
        .Title("Choose an [green]environment[/]")
        .PageSize(10)
        .MoreChoicesText("[grey](scroll for more)[/]")
        .EnableSearch()
        .AddChoices("dev", "staging", "production"));
```

* `AddChoiceGroup(parent, children)` builds a grouped list.
* `UseConverter(x => x.Name)` controls how non-string `T` values are displayed.

## Multi selection

```csharp
using Spectre.Console;
using System.Collections.Generic;

List<string> features = AnsiConsole.Prompt(
    new MultiSelectionPrompt<string>()
        .Title("Select [green]features[/]")
        .PageSize(10)
        .Required()                                   // at least one must be picked
        .InstructionsText("[grey](space to toggle, enter to accept)[/]")
        .AddChoices("logging", "metrics", "tracing", "auth"));
```

Returns the chosen items as a `List<T>`. Use `.NotRequired()` to allow an empty selection.

---

## Custom types

Prompts are generic. For a non-string `T`, supply a converter so items render readably:

```csharp
using Spectre.Console;

var choice = AnsiConsole.Prompt(
    new SelectionPrompt<Server>()
        .Title("Pick a server")
        .UseConverter(s => $"{s.Name} ({s.Region})")
        .AddChoices(servers));
```

---

## Injected console

Prompts also run through an injected `IAnsiConsole`, which is what makes them testable (feed keystrokes via a `TestConsole` — see [layout-and-testing.md](layout-and-testing.md)):

```csharp
using Spectre.Console;

public string PickName(IAnsiConsole console) =>
    console.Prompt(new TextPrompt<string>("Name?").DefaultValue("anon"));
```

---
*Verified against Spectre.Console v0.57.2 DLL surface (2026-07-14). `TextPrompt`, `ConfirmationPrompt`, `SelectionPrompt`, `MultiSelectionPrompt`, their fluent extensions, `ValidationResult`, and the `Ask`/`Confirm`/`Prompt` entry points were extracted from the `Spectre.Console` assembly surface and compile-tested against the pinned 0.57.2 package.*
