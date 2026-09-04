# 💾 Data, State, and Offline

Where state lives — and what happens to it on process death, reinstall, backup restore, and a new device — is an architecture decision made once and paid for on every platform. Decide it before the first feature caches something "temporarily". Resolve the project's toolchain first ([version and sources](version-and-sources.md)).

---

## 🗄️ Choosing a store

| Store | For | The catch |
|---|---|---|
| **Preferences** | Small scalar settings (the documented types are simple primitives, strings, and dates) | Designed for *small* text; platform stores impose their own limits (Windows caps key length and value size). Not for secrets, not for objects serialized "just this once" |
| **SecureStorage** | Tokens, credentials — small secrets | Backed by platform security stores (Keychain, encrypted preferences, DPAPI-style protection). See the backup/restore traps below |
| **FileSystem — cache directory** | Re-creatable data: downloaded images, staged responses | **The OS may clear it.** Anything the app cannot re-create does not belong here |
| **FileSystem — app data directory** | Files the app owns and must keep | Participates in platform backup/sync — see below |
| **Local database (SQLite)** | Structured, queryable, growing data | You own schema migration from day one. The official tutorial route is the third-party SQLite.NET ORM; an ADO.NET provider is the documented alternative — pick one deliberately and wrap it behind your repository interface |

**Decide per datum, not per app.** The classic failure is one store stretched over every need: preferences holding serialized object graphs, or a database holding two booleans.

> [!WARNING]
> **Backup and restore is a data-lifecycle path your architecture must survive, not an edge case.** Platform auto-backup can restore preferences and app-data files onto a reinstall or a *different device* — but restored **SecureStorage** entries may be undecryptable there (the encryption key did not travel), and on iOS, Keychain entries can *outlive an uninstall*. Consequences to design for: treat every SecureStorage read as fallible (recover by re-authenticating, not by crashing); never assume a fresh install has empty state; decide explicitly whether your app-data files should be excluded from backup.

## 🧠 In-memory state

- **Give app-level state one owner.** A singleton state service (or a small number of them) that view models observe beats state smeared across view models that message each other into consistency.
- **Messaging is for decoupling, not for data flow.** A message bus carrying the actual data turns state into "whatever arrived last"; send *notifications of change*, let the owner hold the truth.
- **Android process death is a normal lifecycle event.** The OS reclaims backgrounded apps routinely; the user returns expecting their place. State that must survive it has to be persisted and restored by design — deep-linked/restored pages rebuilding from parameters ([navigation and MVVM](navigation-and-mvvm.md)) is half of this; the other half is deciding *which* state is worth persisting at all.
- **Sign-out is a state event, not a navigation event.** Enumerate what it clears: singletons holding per-user state, caches, the database, SecureStorage, in-flight operations. The list is the test.

## 🌐 Offline and sync

The body's rule stands: model offline behavior explicitly up front — cache ownership, freshness, retries, conflict policy, user-visible state. Making that concrete:

- **Pick online-first or offline-first per flow, on purpose.** Online-first with a spinner is honest for rarely-offline flows; offline-first (local database as source of truth, sync in the background) is a different architecture, not a cache setting — choose it where the product genuinely requires working offline.
- **A cache without an invalidation owner is a bug factory.** For each cached thing: who writes it, what marks it stale, and what the user sees while it is stale.
- **Conflict policy is a product decision — extract it from the product owner early.** Last-write-wins, server-wins, or merge: any is implementable; discovering the requirement after users have lost edits is the expensive path.
- **Surface sync state to the user** (pending, syncing, failed-retrying) rather than pretending the network is reliable. Silent sync failure is data loss with a delay.

## 🗃️ Local database discipline

- **Version the schema from the first release** and write migrations forward-only. The install base you must migrate is every version you ever shipped, on devices you cannot touch.
- **Test the upgrade path with real prior-version data**, not just a fresh install — fresh installs are the one case that always works.
- **Keep database access behind a repository interface** in shared code; it is what makes the domain testable on a plain test host ([testing strategy](testing-strategy.md)) and keeps the ORM choice reversible.

## ✅ Review checklist

- Every persisted datum has a named store chosen from the table, and secrets are only in SecureStorage.
- SecureStorage reads are treated as fallible with a defined recovery path; fresh-install state is not assumed empty.
- Cache-directory contents are fully re-creatable; backup participation of app-data files is a recorded decision.
- App-level state has named owners; sign-out clears an enumerated list.
- Offline flows are classified online-first or offline-first; each cache has an invalidation owner; conflict policy came from the product owner.
- The database schema is versioned, migrations are forward-only, and upgrades are tested against real prior-version data.

---
*Reflects official .NET MAUI documentation (net-maui-10.0) on preferences, secure storage, file-system helpers, and local databases (2026-08-31). Exact store limits, backing stores, and APIs must be resolved from the target project's SDK and the matching official documentation.*
