# 🔎 Version and Source Policy

## 📋 Resolve before advising

Collect (or run `scripts/inspect-maui.ps1 -Path <repo>` for a JSON snapshot of all of it):

- SDK selection from `global.json` and `dotnet --version`;
- target frameworks and `UseMaui` from project/imported properties;
- explicit and centrally managed MAUI package versions — including `MauiVersion` / `PackageVersion` pins in `Directory.Build.props` / `Directory.Packages.props`, which the script reads too;
- installed workloads and manifests, and any workload-set pin;
- target platform/OS floors and runtime identifiers, which are per-target-framework and so are reported with the condition that selects them;
- workload-set or SDK-band policy used by CI.

The snapshot is a *read* of what the repo declares, not an MSBuild evaluation: it does not resolve conditions, imports, or SDK defaults, so a floor the SDK supplies implicitly will not appear. Treat a disagreement between the snapshot and a real build as the build being right.

Do not assume the newest NuGet package is compatible with the project's SDK/workload band. Do not assume package version and workload version are interchangeable.

## 📌 How MAUI is versioned and pinned

- **Delivery is a workload plus NuGet packages.** The `Microsoft.Maui.Controls` package (referenced directly or via the `$(MauiVersion)` build property) is the package-version anchor; the workload provides the platform build tooling. Both must be within compatible bands — a package bumped past its SDK band is a build break with a confusing error.
- **Workload sets are the reproducibility mechanism** (SDK 8.0.400+): one version pins the whole workload group. A repo pins it in `global.json` (`sdk.workloadVersion`), whose presence alone switches the SDK to workload-set mode; the CLI equivalents are `dotnet workload config --update-mode workload-set` and version-pinned `install`/`update`. **An unpinned CI machine floats** — same repo, different day, different toolchain. Pin the SDK version and the workload set in the repo, and let upgrades be commits.

> [!WARNING]
> **A MAUI major's support window is much shorter than its .NET base.** The policy guarantees a .NET MAUI major a *minimum* of six months of servicing after its successor ships — and in practice the published dates have sat close to that floor, while the underlying .NET LTS runs for years. Concretely, as of 2026-08-31: MAUI 9 left support 2026-05-12 although .NET 9 itself is supported to 2026-11-10, and MAUI 10's listed end (2027-05-11) is well before .NET 10's LTS end (2028-11-14). **Plan the annual MAUI major upgrade as a scheduled project**; "we're on the LTS" is not the safety it suggests. Verify current dates on the official policy page at planning time — the guarantee is a floor, not a schedule.

- **Upgrades are toolchain events**: re-verify trimming/AOT defaults ([publishing](publish-and-distribution.md)), re-baseline [performance budgets](performance-budgets.md), and re-run the platform matrix — a major can change runtime and minimum platform versions.
- **Xamarin.Forms is out of support** (since 2024-05-01); for a migration, the documented route is the .NET Upgrade Assistant plus the official migration docs — expect real porting effort, not a mechanical conversion.

## 📚 Primary sources

- .NET MAUI docs: `https://learn.microsoft.com/dotnet/maui/` (match the `?view=net-maui-X.0` moniker to the project's major)
- Support policy and dates: `https://dotnet.microsoft.com/platform/support/policy/maui`
- Framework source/issues/releases: `https://github.com/dotnet/maui`
- Official focused skills: `https://github.com/dotnet/skills/tree/main/plugins/dotnet-maui`
- Experimental/broad skills and DevFlow: `https://github.com/dotnet/maui-labs/tree/main/plugins`

Match documentation to the project's major release and confirm signatures in the matching source/package when accuracy matters.

## 🧪 Context7

Context7's `/dotnet/maui` library is useful for discovering relevant documentation fragments, but its snapshot/version coverage can lag current servicing releases and retrieved examples may mix conceptual material with repository automation endpoints. Use it to locate terminology and likely docs, then verify against Microsoft Learn, the matching source tag, or a compile/run test. Do not use Context7 alone to justify an upgrade, API signature, platform entitlement, or release claim.

## ✅ What counts as verified

- **API shape:** matching reference assembly/source plus a targeted compile.
- **Platform behavior:** runtime execution on the affected target with logs/evidence.
- **Performance:** before/after measurement under the same scenario.
- **Packaging:** produced artifact installs and launches with production-relevant settings.
- **Store policy:** current official platform/store documentation.

---
*Reflects official .NET MAUI documentation, the .NET/.NET MAUI support policy pages, and the .NET SDK workload-sets documentation (2026-08-31); resolve exact signatures, versions, and support dates from the target project and the live policy pages.*
