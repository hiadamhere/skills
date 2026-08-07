# ⏱️ Performance Budgets

A performance budget is a number you agreed to *before* writing the feature, measured on hardware you actually ship to. Without one, "is it fast enough?" is settled by whoever is most confident in the room, and regressions arrive one acceptable-looking change at a time.

Resolve the project's toolchain first ([version and sources](version-and-sources.md)).

> [!IMPORTANT]
> **This guide does not give you threshold numbers, and neither should anyone else.** A budget that did not come from your product's target devices, your user expectations, and your own baseline measurement is decoration. What follows is how to choose, measure, and hold budgets — the values are yours.

---

## 📐 What to put a budget on

| Dimension | Why it earns a budget | Measure on |
|---|---|---|
| **Cold start to interactive** | The first impression, and the hardest to fix late | Lowest-tier target device, Release, after a reboot |
| **Navigation transition** | Where jank is most visible and most reported | Same device, with realistic data volumes |
| **Scrolling / list frame time** | Virtualization and template cost surface here first | Longest list the product allows, not a demo list |
| **Memory after N navigations** | Catches leaks that inspection never will | Repeated navigate-in/out cycles, snapshot at start and end |
| **Package size / install footprint** | Affects install conversion and store limits | The produced artifact, with production trimming/AOT settings |
| **Time to first data** | Users judge the network path, not your cache design | Realistic latency, including a slow and an offline case |

Not every app needs all six. Choose the ones your product's failure stories actually come from, and leave the rest unbudgeted rather than pretending to track them.

## 🎯 Setting a budget honestly

1. **Measure the current state first.** A budget set before a baseline is a guess. Record the baseline with the device, OS, build configuration, and data volume alongside the number — a measurement without its conditions is not reproducible.
2. **Set the budget from the user's experience**, then check feasibility against the baseline. If the gap is large, the honest output is a plan, not a softer number.
3. **Budget the low-tier device, not the developer machine.** A desktop debug build is the least representative environment available to you.
4. **Write it down where the work happens** — in the repo, next to the code it governs. A budget in a document nobody opens is not a constraint.

> [!WARNING]
> **A debug build on a desktop target proves nothing about release performance on a phone.** Trimming, AOT, linker behavior, and platform runtime differences all move these numbers. Measure the configuration you ship, on the platform you ship it to, or do not claim the number.

## 🔍 Holding a budget

- **Re-measure on the same scenario, not a similar one.** Same device, same OS version, same data, same build configuration. Changing the scenario and the code at once tells you nothing.
- **Compare before and after in the same session** where possible. Absolute numbers drift between OS versions and background load; deltas survive that.
- **Treat a budget breach as a defect, not a discussion.** The moment a breach becomes negotiable, the budget has stopped doing its job.
- **Re-baseline deliberately after a framework or SDK upgrade** and record that you did. An upgrade can move every number at once; silently absorbing that is how a budget rots.

## 🏗️ Structural choices that decide performance early

These are architecture decisions, not tuning — they are cheap now and expensive later:

- **Virtualize any unbounded list, and give it bounded space.** A virtualized control inside an unbounded scrolling container cannot virtualize; it realizes everything.
- **Keep item templates shallow.** Per-item cost multiplies by the number of items and again by scroll velocity.
- **Keep startup work off the critical path.** Anything not needed for the first interactive frame is a candidate for deferral — but defer deliberately, since work moved into a later frame can simply relocate the jank.
- **Decide what is cached, who owns it, and when it is invalidated** while designing the data flow. Retrofitted caching is where correctness bugs and memory growth arrive together.
- **Prefer measuring to reasoning about layout cost.** Nested layout passes and measurement loops are not reliably visible by reading the markup.

## ✅ Review checklist

- Each budgeted dimension has a number, a device, a build configuration, and a data volume recorded with it.
- The baseline was measured before the budget was set.
- Numbers come from Release builds on target hardware, not debug desktop runs.
- Unbounded lists are virtualized and given bounded space.
- A breach is treated as a defect with an owner, not as a topic.
- Budgets were re-baselined after the last framework/SDK upgrade, and that is recorded.

---
*Reflects official .NET MAUI documentation and dotnet/maui engineering guidance (2026-08-06). Deliberately contains no threshold values: per this skill's Ground Truth, a performance claim is verified by before/after measurement under the same scenario on the target platform, never asserted from documentation or memory.*
