# 🧠 AI Agent Skills Catalog

A curated collection of master-level agent skills, guidelines, and reference materials for Google Antigravity, Claude Code, OpenAI Codex, Aider, and Cline.

🌐 **Browse the interactive catalog page: [hiadamhere.github.io/skills](https://hiadamhere.github.io/skills/)** — explore the MSAF Architect skill visually, right in your browser.

---

## 📂 Available Skills

### 🏛️ `msaf-architect` (Microsoft Agent Framework C# Architect)
Master architecture guidelines, execution models, and API mappings for building multi-agent systems using the Microsoft Agent Framework.

> [!IMPORTANT]
> **API Ground-Truth Alignment**
> Tutorials and LLM training data describe Microsoft Agent Framework APIs that **were never shipped** (e.g. a `WorkflowSuspendedException` suspend pattern) and cause compiler failures.
>
> Every claim in this skill is **verified against the actual v1.10.0 / v1.11.0 / v1.12.0 / v1.13.0 assemblies from NuGet** — reflection surface extraction plus compile tests against the pinned packages. Reference documents carry per-version verification stamps, and an automated gate rejects any unverified API identifier before release. The latest guidance targets **v1.13** (composable/disposable agent skills and the renamed `AgentFileStore` contract).

### 🎨 `spectre-console` (Spectre.Console Terminal-UI Expert)
Verified, version-matched guidance for building rich .NET terminal UIs with [Spectre.Console](https://spectreconsole.net/): tables, panels, trees, markup & color, live displays (`Status`/`Progress`/`Live`), and interactive prompts — plus the terminal-gating discipline that keeps interactive features from hanging in CI or hosted contexts.

> [!IMPORTANT]
> **API Ground-Truth Alignment**
> Every type, method, and property is **verified against the actual Spectre.Console v0.57.2 assemblies** (`Spectre.Console`, `Spectre.Console.Ansi`, `Spectre.Console.Testing`) — reflection surface extraction plus compile tests against the pinned package. The same automated gate rejects any unverified API identifier before release.

---

## 🚀 Installing the Skills

Three ways to install — pick whichever fits your setup.

### 1. With `spm` (recommended) — installs into every coding agent

**[`spm`](https://www.npmjs.com/package/@hiadamhere/spm)** (Skill & Plugin Manager) is a package manager for AI-agent skills. It installs this catalog into **all** your coding agents — Claude Code, Codex, Cursor, Cline, Aider, GitHub Copilot, and more — from the command line.

**Install `spm`** (choose one — no repo clone required):
```bash
npm install -g @hiadamhere/spm     # Node — self-contained, no .NET required
dotnet tool install -g spm          # …or the .NET global tool
```

**Install every skill from this catalog:**
```bash
spm install hiadamhere/skills
```
> Don't want a global install? Run it once with npx: `npx @hiadamhere/spm install hiadamhere/skills`

**Or subscribe to the catalog** to keep it updated and install skills by name:
```bash
spm catalog add hiadamhere https://github.com/hiadamhere/skills.git
spm catalog sync
spm list                      # browse available skills
spm search table              # find one
spm install spectre-console   # install a single skill
spm uninstall spectre-console # remove it
```

### 2. One-line remote install — no package manager needed

No Node or .NET? A self-contained script deploys all catalog skills to your user-level agent config folders (`~/.agents/skills` for Codex/Gemini, `~/.claude/skills` for Claude Code):

#### On Windows (PowerShell):
```powershell
irm https://raw.githubusercontent.com/hiadamhere/skills/main/install.ps1 | iex
```

#### On macOS/Linux (Bash):
```bash
curl -fsSL https://raw.githubusercontent.com/hiadamhere/skills/main/install.sh | bash
```

### 3. Local / workspace install (clone) — copy or symlink, per-skill, custom scope

Clone the repo and run the installer with flags for finer control:

*   **Mode:** Copy files or Symlink (recommended for automatic updates via `git pull`).
*   **Scope:** **Global** (user-profile) or **Folder** (workspace-level — copies into `<folder>/.agents/skills/` and `<folder>/.claude/skills/`).
*   **Skills:** Multi-select specific skills; interactive runs present a menu with `ALL` as the first choice.

#### Windows (PowerShell):
```powershell
# Interactive (prompts for mode, scope, target folder, and skills)
.\install.ps1
# Non-interactive copy of specific skills to a workspace
.\install.ps1 -Mode Copy -Scope Folder -Path C:\MyProject -Skills msaf-architect
# Uninstall
.\uninstall.ps1 -Scope Folder -Path C:\MyProject -Skills msaf-architect
```

#### macOS/Linux (Bash):
```bash
# Interactive
./install.sh
# Non-interactive symlink of specific skills to a workspace
./install.sh --mode link --scope folder --path /path/to/my-project --skills msaf-architect
# Uninstall
./uninstall.sh --scope folder --path /path/to/my-project --skills msaf-architect
```

---
Distributed under the MIT License.
