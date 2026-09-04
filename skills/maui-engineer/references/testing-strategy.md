# 🧪 Testing Strategy

What is testable in a MAUI app is decided by the architecture, not by the test framework — by the time you are choosing a UI-automation tool, the important decisions have already been made. Design the seams first. Resolve the project's toolchain first ([version and sources](version-and-sources.md)).

---

## 🔺 The pyramid, MAUI-shaped

| Layer | Runs on | Should hold |
|---|---|---|
| **Domain / application tests** | Plain .NET test host, every CI run | The bulk. Business rules, state machines, data mapping — anything in your plain-TFM libraries |
| **View-model tests** | Plain .NET test host | Command behavior, busy/error states, navigation *requests* (against the navigation interface, not real navigation) |
| **Platform/device tests** | Emulator/simulator/device | Your `Platforms/` implementations: storage, permissions wrappers, platform service behavior |
| **UI automation** | Emulator/simulator/device, few lanes | A handful of critical journeys (launch, sign-in, the money path) — not feature coverage |
| **Manual matrix** | Real devices | What automation is worst at: lifecycle, theme change, font scale, RTL, screen readers, interruptions |

The pyramid inverts by accident: every view-model test that needs a page type, and every domain test that needs the app project, silently migrates upward to a slower, flakier layer. **The cheapest test-infrastructure investment in a MAUI app is keeping types testable on a plain .NET test host.**

## 🧩 The seams that make it testable

- **A plain-TFM class library for domain logic** is the first seam ([project layout](project-layout-and-platform-code.md)); a test project referencing it needs no MAUI workload at all.
- **View models reference no page, control, or platform type** ([navigation and MVVM](navigation-and-mvvm.md)) — this rule *is* the testability of the second layer. The test asserts "the view model asked to navigate to X with parameter Y", against your interface.
- **Abstract time, dispatching, and connectivity** where logic depends on them. A view model that calls a static device API directly is untestable off-device; the same call behind an interface is a one-line fake.
- **Test app-project types sparingly.** If the app project must be referenced by tests, the officially documented pattern is adding a plain TFM to its `TargetFrameworks` (with the app's `OutputType` conditioned to the platform TFMs) so a plain test project can reference it — but treat the need as a hint that the type belongs in a library. The official unit-testing doc recommends xUnit; any mainstream framework works, since the point of this layer is that nothing MAUI-specific is loaded.

## 📱 Platform and UI layers — spend deliberately

- **Device tests earn their cost only for code that genuinely touches the platform** (your storage, permission, notification implementations). Testing pure logic on an emulator is paying device-lane prices for test-host work. Know the tooling reality before committing: this layer has no first-class official story — the official docs point at device runners maintained largely as community tooling — so a big device-test suite is an infrastructure adoption, not a checkbox.
- **UI automation is a budget, not a goal.** The officially documented route is Appium with the per-platform drivers; legacy hosted options have retired (App Center Test shut down in 2025), so assume you run and own the device lanes. Each automated journey costs real maintenance across every platform lane; pick the journeys whose manual re-testing cost exceeds that, and stop. Assign stable `AutomationId`s to the elements those journeys touch — retrofitting selectors is the expensive half of UI test maintenance.
- **The manual matrix is a designed artifact.** Lifecycle (background/foreground, Android process death), theme and font-scale changes, offline transitions, screen-reader passes — enumerate them per release in the repo, with the device/OS combinations, rather than trusting memory ([architecture](architecture.md) validation ladder).

> [!WARNING]
> **A flaky lane is a failing lane, and it is worse than no lane at all** — it trains the team to merge on red, which is the habit that lets a real failure through. Quarantine or delete tests that cannot be made deterministic, and treat "it's just flaky" as a defect report rather than an explanation.

## ✅ Review checklist

- Domain and view-model tests run on a plain .NET test host with no emulator in the loop.
- The navigation interface has a fake; navigation behavior is asserted as requests, not as page transitions.
- Device-test lanes contain only platform-touching code; UI automation covers a named, small set of journeys with stable identifiers.
- No test lane is red-and-ignored.
- The manual matrix exists in the repo and names lifecycle, accessibility, and theme cases per target platform.

---
*Reflects official .NET MAUI documentation — the unit-testing and Appium UI-testing docs — and dotnet/maui engineering guidance (2026-08-31). Exact runner/tooling choices and their current state must be resolved against the target project's toolchain and live official documentation; this guide asserts the strategy and the seams.*
