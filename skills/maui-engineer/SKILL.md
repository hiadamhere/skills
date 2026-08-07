---
name: maui-engineer
description: Version-aware architecture and planning guidance for .NET MAUI apps. Use when planning, structuring, or architecting a .NET MAUI application — target platforms, SDK/workload/package strategy, project layout, Shell/stack navigation and deep links, MVVM and DI lifetimes, state and offline data, platform-abstraction boundaries, performance budgets, accessibility, and publish/signing constraints. Resolve the project SDK, target frameworks, workloads, and MAUI package versions before giving API guidance.
---

# 📱 .NET MAUI Architect

This skill embeds the architectural decisions and up-front knowledge needed to **plan and architect a .NET MAUI app well** — the choices you must get right before writing feature code, and the evidence that keeps them honest. Work from the project's resolved toolchain, not a generic MAUI tutorial.

> [!IMPORTANT]
> A successful Windows (or XAML-preview) build does **not** prove Android, iOS, or Mac Catalyst behavior. Architect for every target platform you intend to ship, and treat one desktop build as evidence for that desktop only.

---

## Instructions

Reach for this skill when planning a new MAUI app or making a structural decision on an existing one (project layout, navigation model, state/data flow, platform boundaries, performance or publishing strategy).

1. **Resolve the ground before advising.** Read repository instructions, the solution/project files, `global.json`, `Directory.Build.*`, and any central package files. Run `scripts/inspect-maui.ps1 -Path <repo>` (PowerShell 7) for a reviewable JSON snapshot of SDK, workloads, target frameworks, and MAUI package versions — or collect the same facts with `dotnet --info`, `dotnet workload list`, and project inspection. Full policy: [version and sources](references/version-and-sources.md).
2. **Identify the target platforms.** The platform set drives most architectural decisions (navigation shell, lifecycle handling, native capability boundaries, packaging).
3. **Preserve the project's current SDK/package strategy** unless the user explicitly asks for an upgrade. Never solve an application design question by bumping every workload.
4. **Make the architecture decisions** using the reference that matches the question:

| Decision | Reference |
|---|---|
| Ownership split, layering, XAML/binding/layout, platform boundaries, validation ladder | [architecture](references/architecture.md) |
| Navigation model, deep links and back stack, MVVM boundaries, DI lifetimes | [navigation and MVVM](references/navigation-and-mvvm.md) |
| What to budget, how to set and hold a number, structural performance choices | [performance budgets](references/performance-budgets.md) |
| What counts as verified, and where to resolve versions from | [version and sources](references/version-and-sources.md) |

---

## Architecture defaults

- Keep domain and application logic independent of pages and native controls; put device capabilities behind narrow interfaces registered in app startup (DI), not service-located from pages/view models.
- Prefer compiled bindings with explicit data types; treat binding warnings as defects, not noise.
- Keep constructors cheap. Move navigation-sensitive work into lifecycle-aware, cancellable operations; treat lifecycle callbacks as re-entrant and unsubscribe symmetrically.
- Use virtualized collection controls for unbounded data and give them bounded space; do not nest them in unbounded scrolling containers.
- Model offline behavior explicitly up front: cache ownership, freshness, retries, conflict policy, and user-visible state.
- Preserve safe areas, keyboard behavior, accessibility names/order, dynamic text, theme resources, and reduced-motion expectations from the start — retrofitting them is expensive.
- Keep server secrets out of app binaries and bundled resources (assume both are inspectable); reserve platform secure storage for appropriate user/device credentials.

---

## Constraints

- **Pick one primary navigation model** and treat the others as exceptions within it. A page reachable by deep link must construct its state from its parameters alone — otherwise it works in manual testing and fails on cold start.
- **A performance claim needs a before/after measurement** on the target platform in a Release build. Never quote a threshold that did not come from this project's own baseline.
- **Do not infer native behavior from a single desktop target or a XAML preview.** Validate runtime behavior on every affected platform; for UI decisions capture device/OS, orientation/window size, theme, and font scale.
- **Do not label a change an optimization from intuition.** For performance architecture, set and measure budgets — startup, allocation, layout, scrolling, package size — before and after.
- **Do not treat compilation as shippability.** For publish/signing, distinguish compiling from installability, launchability, permissions/entitlements, trimming/AOT, and store acceptance.
- **Do not solve an SDK/workload mismatch by changing application architecture**, and do not solve an application bug by upgrading workloads unless evidence shows the toolchain is the cause.

---

## Ground Truth

This is an **architecture and planning** skill: its guidance is methodology cross-checked against official .NET MAUI documentation and the `dotnet/maui` repository — **not** a pinned DLL API surface. It deliberately avoids asserting version-specific API signatures.

Ground truth for any concrete API, platform behavior, performance number, or packaging claim is **the consuming project's resolved SDK, target frameworks, workloads, NuGet assets, compiler output, platform logs, and executable tests**, cross-checked with the matching official Microsoft source/docs — resolved per project, never from model memory. See [version and sources](references/version-and-sources.md) for what counts as verified.

*Reflects official .NET MAUI documentation and dotnet/maui engineering guidance (2026-07-23). Resolve exact API signatures and platform behavior from the target project's SDK/workloads.*
