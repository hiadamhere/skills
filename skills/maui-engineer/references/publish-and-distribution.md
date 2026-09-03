# 📦 Publishing and Distribution

Publishing is where "it compiles" meets four different operating systems' opinions about identity, signing, and what code is allowed to run. The decisions here — distribution channels, signing chain, trimming/AOT posture — are architecture: they constrain the code you may write, and retrofitting them is release-week pain. Resolve the project's toolchain first ([version and sources](version-and-sources.md)).

> [!IMPORTANT]
> **Compiling is the first rung, not the result.** A shippable change is: it compiles → the produced artifact installs → it launches → permissions/entitlements work → it behaves under production trimming/AOT → the store accepts it. Each rung has its own failure modes; claim only the rungs you exercised.

---

## 🔏 Artifacts and signing, per platform

| Platform | Artifact | Signing reality |
|---|---|---|
| **Android** | APK (direct install) or AAB (Google Play requires AAB) | Your keystore, your responsibility forever — losing it means losing app identity. Keep passwords out of project files and logs (the signing properties accept indirection for this) |
| **iOS** | IPA | Apple Developer Program + distribution certificate + provisioning profile. Building requires Apple's toolchain — **a Mac is in your pipeline** (locally or as a paired build host), plan CI around it |
| **Mac Catalyst** | `.app` or `.pkg` | Provisioning profile for every channel; distribution **outside** the App Store additionally requires Apple notarization |
| **Windows** | MSIX (packaged) or plain folder/exe (unpackaged) | MSIX must be signed; a self-signed certificate only installs for users who trust it explicitly — real distribution wants a trusted-CA certificate. Choose packaged vs unpackaged early: identity, installer story, and some APIs differ |

Treat the **signing chain as infrastructure**: who owns each certificate/keystore, where it lives (a secret store, not the repo), when it expires, and which CI lane may use it. An expiring distribution certificate is an outage with a countdown; put renewal on a calendar, not in someone's memory.

## ✂️ Trimming and AOT are a posture, not a flag

What runs on each platform is decided for you in part — verify the current defaults for the project's .NET version rather than assuming:

- **iOS devices and ARM64 Mac Catalyst are AOT-compiled — the platform forbids JIT there.** The trap is that JIT *is* used in the x64 simulator and on x64 Mac Catalyst during development, so code depending on runtime code generation works all the way through your inner loop and fails on the hardware you ship. For genuinely dynamic paths the documented fallback is the Mono interpreter (`UseInterpreter`), which costs performance — reach for it deliberately, not as a default.
- **Trimming defaults are per platform, and not all of them key on Release.** Android and Mac Catalyst trim (partial mode) in Release builds, while iOS trims **any device build regardless of configuration** and does not trim simulator builds. So a trim-induced failure can appear in a Debug run on an iOS device and hide in a Release run on the simulator: reason about the *configuration matrix*, not the configuration name. Windows runs CoreCLR with its own compilation model.
- **NativeAOT is an opt-in step further** (documented stable on iOS/Mac Catalyst since .NET 9, experimental on Android): substantially smaller and faster-starting, in exchange for full trimming and a strict contract — no runtime assembly loading or emit, all XAML compiled, compiled bindings with explicit types throughout, and several dynamic-loading conveniences excluded. It is also produced only by an actual publish invocation, not an ordinary build. Adopting it is an architectural commitment the whole dependency tree must honor, not a build tweak.
- **The runtime landscape moves per .NET major** — Android's Release runtime is documented as changing across .NET 10→11, for instance. Re-verify defaults on every major upgrade instead of carrying beliefs forward.

> [!WARNING]
> **Trim and AOT failures are runtime failures on the shipped artifact — reflection-heavy code, serializers, and DI patterns that work all through development break in the published build.** Fix trim warnings instead of suppressing them, prefer trim-safe patterns (source-generated serialization, explicit registrations) in shared code, and put one publish-configuration smoke run per platform in the release lane so the first execution of the production artifact is not on a user's device.

Package size has real levers (per-ABI packaging, trimming posture, optional shrinkers on Android) — but treat size as a [performance budget](performance-budgets.md): measure the produced artifact, change one lever, measure again.

## 🏪 Store acceptance is the last independent gate

- Each store re-decides minimum OS targets, entitlement/permission justifications, privacy declarations, and review policies **on its own schedule** — current store policy is ground truth that no offline document can carry. Check it at release time.
- **Permissions and entitlements are product decisions with review consequences:** each one you declare must be justifiable in review and should map to a user-visible feature. An unused permission is a rejection risk carried for nothing.
- Plan for **staged rollout and rollback reality**: mobile stores do not un-ship a bad binary — users keep it until they update. The rollback story is a server-side switch or an expedited release, and it should be decided before the first release, not during the first incident.

## 🤖 CI for release artifacts

- **Scope publishing to the app project** (not the solution) and produce artifacts per platform lane; the iOS lane needs its Mac.
- **Secrets** (keystore, certificates, profile credentials) live in the CI secret store and reach the build through the platforms' documented indirection mechanisms — never in the repo, never echoed into logs.
- **The release lane publishes with production settings** — trimming/AOT posture, signing, the real package format — so what CI validates is what users install. A release lane that builds Debug-shaped artifacts validates nothing ([architecture](architecture.md) validation ladder, top rung).

## ✅ Review checklist

- Distribution channel and package format per platform are decided and recorded; packaged-vs-unpackaged on Windows was a choice, not a default.
- Every certificate/keystore has an owner, a storage location outside the repo, and an expiry reminder.
- The trimming/AOT posture per platform is stated in the repo; trim warnings are treated as defects; NativeAOT (if adopted) was verified against its documented constraints.
- A publish-configuration smoke run per platform exists in the release lane.
- Store requirements (targets, permissions, privacy declarations) were checked against current store policy for this release, and every declared permission maps to a feature.
- The rollback story is written down.

---
*Reflects official .NET MAUI deployment documentation (net-maui-10.0): per-platform publish/signing docs, the trimming and Native AOT deployment guides, and the runtimes/compilation matrix (2026-08-31). Exact MSBuild properties, defaults, and store policies must be resolved from the target project's SDK and current official/store documentation at release time.*
