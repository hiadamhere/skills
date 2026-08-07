# 🔎 Version and Source Policy

## Resolve before advising

Collect:

- SDK selection from `global.json` and `dotnet --version`;
- target frameworks and `UseMaui` from project/imported properties;
- explicit and centrally managed MAUI package versions;
- installed workloads and manifests;
- target platform/OS versions and runtime identifiers;
- workload-set or SDK-band policy used by CI.

Do not assume the newest NuGet package is compatible with the project's SDK/workload band. Do not assume package version and workload version are interchangeable.

## Primary sources

- .NET MAUI docs: `https://learn.microsoft.com/dotnet/maui/`
- Framework source/issues/releases: `https://github.com/dotnet/maui`
- Official focused skills: `https://github.com/dotnet/skills/tree/main/plugins/dotnet-maui`
- Experimental/broad skills and DevFlow: `https://github.com/dotnet/maui-labs/tree/main/plugins`

Match documentation to the project's major release and confirm signatures in the matching source/package when accuracy matters.

## Context7

Context7's `/dotnet/maui` library is useful for discovering relevant documentation fragments, but its snapshot/version coverage can lag current servicing releases and retrieved examples may mix conceptual material with repository automation endpoints. Use it to locate terminology and likely docs, then verify against Microsoft Learn, the matching source tag, or a compile/run test. Do not use Context7 alone to justify an upgrade, API signature, platform entitlement, or release claim.

## What counts as verified

- **API shape:** matching reference assembly/source plus a targeted compile.
- **Platform behavior:** runtime execution on the affected target with logs/evidence.
- **Performance:** before/after measurement under the same scenario.
- **Packaging:** produced artifact installs and launches with production-relevant settings.
- **Store policy:** current official platform/store documentation.

---
*Reflects official .NET MAUI repositories/documentation and Context7 library metadata (2026-07-23); resolve exact signatures and versions from the target project.*
