# MAUI App Architecture

The structural decisions to make while planning a .NET MAUI app, and how to keep them honest with evidence. Resolve the project's toolchain first ([version and sources](version-and-sources.md)).

## Ownership split

Classify where a concern (or a failure) lives before designing or editing:

| Boundary | Typical signals | First checks |
| --- | --- | --- |
| SDK/workload | missing targets, packs, manifests, restore errors | `global.json`, `dotnet --info`, workload list, target frameworks |
| Build/package | generated manifest, resource, linker, signing errors | `obj` assets, binlog, platform project properties |
| Binding/state | binding diagnostics, stale UI, wrong command state | binding context, data type, notification lifetime, UI thread |
| Layout/render | clipping, measurement loops, wrong insets | constraints, nested scrolling, safe area, font scale, orientation |
| Handler/native | platform-only behavior or regression | handler mapper, native view lifetime, target-specific logs |
| Lifecycle/navigation | duplicate loads, leaks, lost state | subscriptions, cancellation, activation/background transitions |

## Layering

- Keep domain and application logic independent of pages and native controls.
- Put device services behind narrow interfaces and register platform implementations in app startup.
- Keep view models unaware of concrete navigation pages where the existing architecture permits it.
- Treat lifecycle callbacks as re-entrant. Guard initialization, cancel obsolete work, and unsubscribe symmetrically.
- Model offline behavior explicitly: cache ownership, freshness, retries, conflict policy, and user-visible state.

## XAML, bindings, and layout

- Prefer compiled bindings with an explicit data type. Fix binding diagnostics rather than suppressing them.
- Keep resource keys and theme variants centralized; plan for both themes and runtime theme changes.
- Avoid deeply nested layouts and unnecessary bindable-property churn in scrolling item templates.
- Use a virtualized collection for large/unbounded lists. Give it bounded space and stable item identity.
- Design for safe areas, keyboard occlusion, RTL, text scaling, screen readers, and pointer/keyboard input where the target platforms support them.

## Platform work

- Start with MAUI cross-platform APIs, then reach for platform folders, partial classes, handlers, or dependency-injected services when native behavior is genuinely required.
- Tie permission request timing to a user action and handle denied/restricted states.
- Treat Android activity recreation, iOS scene transitions, Mac Catalyst windowing, and Windows activation as distinct runtime paths.
- Do not place server credentials in the app. Assume binaries and bundled resources are inspectable.

## Validation ladder

1. Restore the pinned toolchain.
2. Build the affected target framework/configuration.
3. Run pure unit tests, then platform-aware tests.
4. Launch on each affected platform and capture logs.
5. Exercise lifecycle, theme, orientation/window resize, text scale, connectivity, and accessibility states relevant to the change.
6. For release changes, publish/install/launch the actual artifact with trimming/AOT/signing settings representative of production.

Report which rungs ran and which remain unverified.

---
*Reflects official .NET MAUI documentation and dotnet/maui engineering guidance (2026-07-23); version-specific APIs must still be resolved from the target project.*
