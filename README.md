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
> Every claim in this skill is **verified against the actual v1.10.0 / v1.11.0 / v1.12.0 assemblies from NuGet** — reflection surface extraction plus compile tests against the pinned packages. Reference documents carry per-version verification stamps, and an automated gate rejects any unverified API identifier before release.

---

## 🚀 Multi-Agent Skill Installer & Uninstaller

Deploy catalog skills to your local agent configuration folders either globally (user-wide) or locally (project-wide).

### 1. Global Installation (Quick Start)

Runs the installer and deploys all catalog skills globally to standard user-level agent config paths (`~/.agents/skills` for Codex/Gemini, and `~/.claude/skills` for Claude Code):

#### On Windows (PowerShell):
```powershell
irm https://raw.githubusercontent.com/hiadamhere/skills/main/install.ps1 | iex
```

#### On macOS/Linux (Bash):
```bash
curl -fsSL https://raw.githubusercontent.com/hiadamhere/skills/main/install.sh | bash
```

### 2. Local/Workspace Installation & Selection

If you clone the repository locally, you can run the scripts with parameters to configure installation scope and select specific skills:

*   **Mode:** Copy files or Symlink files (recommended for automatic updates via `git pull`).
*   **Scope:** Deploy **Global** (user-profile) or **Folder** (workspace-level). Workspace-level copies skills into `<folder>/.agents/skills/` (shared by Codex and Gemini) and `<folder>/.claude/skills/`.
*   **Skills:** Multi-select specific skills. By default, running interactively presents a menu with `ALL` as the first choice, or you can specify skill names on the CLI.

#### Windows (PowerShell) Examples:
```powershell
# Interactive run (prompts for mode, scope, target folder, and skills selection)
.\install.ps1

# Non-interactive copy of specific skills to a local project workspace
.\install.ps1 -Mode Copy -Scope Folder -Path C:\MyProject -Skills msaf-architect
```

#### macOS/Linux (Bash) Examples:
```bash
# Interactive run
./install.sh

# Non-interactive symlink of specific skills to a local project workspace
./install.sh --mode link --scope folder --path /path/to/my-project --skills msaf-architect
```

### 3. Uninstalling Skills

You can cleanly remove catalog skills from either global or workspace-level folders using the uninstaller scripts:

#### Windows (PowerShell):
```powershell
# Interactive uninstall
.\uninstall.ps1

# Non-interactive uninstall of specific skills from a workspace folder
.\uninstall.ps1 -Scope Folder -Path C:\MyProject -Skills msaf-architect
```

#### macOS/Linux (Bash):
```bash
# Interactive uninstall
./uninstall.sh

# Non-interactive uninstall from a workspace folder
./uninstall.sh --scope folder --path /path/to/my-project --skills msaf-architect
```

---
Distributed under the MIT License.
