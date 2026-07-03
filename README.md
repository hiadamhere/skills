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

## 🚀 Multi-Agent Skill Installer

Use the dynamic installer scripts to deploy catalog skills globally to your local agent configuration folders.

### Quick Start (Local Run)

#### On Windows (PowerShell):
```powershell
irm https://raw.githubusercontent.com/hiadamhere/skills/main/install.ps1 | iex
```

#### On macOS/Linux (Bash):
```bash
curl -fsSL https://raw.githubusercontent.com/hiadamhere/skills/main/install.sh | bash
```

---
Distributed under the MIT License.
