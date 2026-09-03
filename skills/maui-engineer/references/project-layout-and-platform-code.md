# 🗂️ Project Layout and Platform Code

Where code lives is an architecture decision in MAUI, because the single-project model gives you four places to put platform behavior and no compiler error for choosing badly. Decide the boundaries before the first platform-specific bug forces them ad hoc. Resolve the project's toolchain first ([version and sources](version-and-sources.md)).

---

## 🧱 The single project, and what goes where

A MAUI app is one project that multi-targets every platform TFM. Within it:

| Location | Compiled for | Use for |
|---|---|---|
| Root (`/`, feature folders) | Every target | Cross-platform UI, view models, services — the default home for everything |
| `Platforms/<OS>/` | That platform only | Platform bootstrap, manifests/entitlements, platform implementations of your interfaces |
| `#if ANDROID` (etc.) blocks | That platform only | Two-line divergences inside otherwise shared code — and nothing larger |
| Separate class libraries | What you choose | Domain and application logic you want compiled without platform TFMs at all |

**Put domain logic in a library that has no platform TFMs.** A plain-TFM library cannot reference a page, a handler, or a platform API even by accident, and it is what your unit tests will load ([testing strategy](testing-strategy.md)). Inside the app project, discipline is by convention; across a project boundary, it is enforced by the compiler.

## 🪜 The escalation ladder for platform behavior

Reach for each step only when the previous one genuinely cannot express the need:

1. **Cross-platform MAUI/Essentials API.** Most device capabilities are already abstracted.
2. **Handler mapping adjustment.** Small tweaks to how a control maps to its native view. **Decide the scope deliberately:** a mapping appended to a control type applies to every instance of that type in the app — scope customizations to a derived control (or an instance check) unless app-wide is truly intended.
3. **Partial classes / `Platforms/` implementations of your own interface.** The default for platform *services*: one interface in shared code, one implementation per platform folder, registered in DI at startup.
4. **A custom handler or native view.** The expensive step — you now own measurement, lifecycle, and disposal on that platform. Take it for genuinely native UI, not for styling.

> [!WARNING]
> **`#if` blocks are the fastest layout decision to regret.** They do not show up in project structure, they multiply with each platform, and they turn shared files into files that merely look shared. Keep them to a few lines; the moment an `#if` block grows a second responsibility, move it behind an interface into `Platforms/`.

## 🎨 Resources are a pipeline, not files

Fonts, images, splash, and raw assets declared once in the project are transformed into per-platform assets at build time. Architectural consequences:

- **One source of truth per asset.** Hand-placing per-platform copies (a drawable here, an asset catalog entry there) forks the pipeline; from then on every asset change is a multi-platform chore that will be done inconsistently.
- **Prefer vector sources** where the pipeline supports them, so density variants are generated rather than maintained.
- **App icon and splash are build-time decisions** with per-platform constraints (shape masking, background color, safe zones); verify them on real launchers/home screens per platform, not in the IDE preview.

## 🧵 Startup is the composition root

App startup (the `MauiProgram` builder) is the one place that knows every concrete type: fonts, handlers, DI registrations, configuration. Keep it that way:

- **Registration order should read as documentation** — group by layer (platform services, domain services, view models, pages), not by the order features were added.
- **No work in startup that can fail slowly.** Network calls, migrations, or large reads in the composition root are cold-start cost on every platform and a crash-before-first-frame risk. Register lazily; do the work in a lifecycle-aware operation with visible progress ([performance budgets](performance-budgets.md)).
- **Configuration lives in code or bundled non-secret files.** Anything bundled ships in an inspectable binary — the secrets rule from the body applies here.

## ✅ Review checklist

- Domain/application logic sits in a plain-TFM library the app project references — not in the app project "for now".
- Every platform divergence can be pointed to: it is a handler mapping, a `Platforms/` implementation, or a named small `#if` — and someone chose which.
- Handler customizations have a deliberate scope (derived control vs app-wide), stated where they are applied.
- Each asset has exactly one source in the project; no hand-maintained per-platform copies.
- Startup reads as a table of contents and completes without I/O on the critical path.

---
*Reflects official .NET MAUI documentation and dotnet/maui engineering guidance (2026-08-31). Exact single-project mechanics, resource pipeline behavior, and handler APIs must be resolved from the target project's SDK and matching documentation — this guide asserts structure and tradeoffs, not signatures.*
