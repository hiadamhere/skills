# CLAUDE.md

Guidelines for running and configuring the public AI Agent Skills Catalog.

## 🚀 Commands

### Installation
* **Run local installation script (Windows):**
  ```powershell
  .\install.ps1
  ```
* **Run local installation script (Bash):**
  ```bash
  ./install.sh
  ```

## 📝 Guidelines
* **Repository Layout:**
  - `skills/` contains the raw skill packages (manifests + reference files).
  - `skills.json` defines the index of all publicly available skills.
* **Adding Skills:** Create a GitHub issue and link it to your Pull Request. Maintain the versioned reference schema under `references/`.
