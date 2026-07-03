#!/bin/bash
# install.sh - Cross-agent skill installer for macOS/Linux
# Usage: 
#   Local (cloned):   ./install.sh [--mode copy|link]
#   Remote (one-line): curl -fsSL https://raw.githubusercontent.com/hiadamhere/skills/main/install.sh | bash

MODE=""

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -m|--mode) MODE="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

GITHUB_USER="hiadamhere"
GITHUB_REPO="skills" # public catalog repo (remote mode fetches published files only)
BRANCH="main"
RAW_BASE_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/skills"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"

# Check if running locally or remotely
if [ -d "$SKILLS_DIR" ]; then
    IS_REMOTE=false
else
    IS_REMOTE=true
fi

# 1. Handle Remote vs Local Setup
if [ "$IS_REMOTE" = true ]; then
    echo "Running in REMOTE mode (fetching files from GitHub)..."
    if [ "$MODE" = "link" ]; then
        echo "Warning: Symlink mode is not available in remote execution. Defaulting to Copy (Download) mode."
    fi
    MODE="copy"
else
    echo "Running in LOCAL mode (using cloned repository files)..."
    # Prompt for mode if not specified
    if [ -z "$MODE" ]; then
        echo "============================================="
        echo "    AI Agent Custom Skill Installer          "
        echo "============================================="
        echo "How would you like to install the skills?"
        echo "[1] Copy Mode (Self-contained: files copied, safe to move/delete repo later)"
        echo "[2] Symlink Mode (Recommended: live updates from 'git pull')"
        
        while true; do
            read -p "Select option (1 or 2): " choice
            case $choice in
                1) MODE="copy"; break ;;
                2) MODE="link"; break ;;
                *) echo "Invalid choice. Please enter 1 or 2." ;;
            esac
        done
    fi
fi

# Convert mode to lowercase
MODE=$(echo "$MODE" | tr '[:upper:]' '[:lower:]')

if [ "$MODE" != "copy" ] && [ "$MODE" != "link" ]; then
    echo "Error: Invalid mode. Must be 'copy' or 'link'." >&2
    exit 1
fi

echo -e "\nStarting installation in $MODE mode..."

# 2. Ensure global directories exist
GEMINI_SKILLS_DIR="$HOME/.gemini/config/skills"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CODEX_DIR="$HOME/.codex"

mkdir -p "$GEMINI_SKILLS_DIR"
mkdir -p "$CLAUDE_SKILLS_DIR"
mkdir -p "$CODEX_DIR"

# Manifest is retrieved dynamically from skills.json

deploy_folder() {
    local src="$1"
    local dest="$2"
    
    # Remove existing destination if it exists
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        rm -rf "$dest"
    fi
    
    if [ "$MODE" = "link" ]; then
        ln -s "$src" "$dest"
        echo "✔ Linked: $(basename "$dest")"
    else
        cp -r "$src" "$dest"
        echo "✔ Copied: $(basename "$dest")"
    fi
}

download_file() {
    local url="$1"
    local dest="$2"
    
    mkdir -p "$(dirname "$dest")"
    if curl -fsSL "$url" -o "$dest"; then
        echo "✔ Downloaded: $(basename "$dest")"
    else
        echo "Error: Failed to download $url to $dest" >&2
    fi
}

# 3. Main Deploy Logic
if [ "$IS_REMOTE" = true ]; then
    MANIFEST_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/skills.json"
    files_json=$(curl -fsSL "$MANIFEST_URL")
    if [ -n "$files_json" ]; then
        FILES_TO_DOWNLOAD=$(echo "$files_json" | python3 -c "import sys, json; data = json.load(sys.stdin); print('\n'.join([f for s in data['skills'] for f in s['files']]))" 2>/dev/null)
        if [ -n "$FILES_TO_DOWNLOAD" ]; then
            echo "Downloading files in parallel..."
            pids=()
            while read -r file; do
                [ -z "$file" ] && continue
                url="$RAW_BASE_URL/$file"
                download_file "$url" "$GEMINI_SKILLS_DIR/$file" &
                pids+=($!)
                download_file "$url" "$CLAUDE_SKILLS_DIR/$file" &
                pids+=($!)
            done <<< "$FILES_TO_DOWNLOAD"
            
            # Wait for all background downloads to finish
            for pid in "${pids[@]}"; do
                wait "$pid"
            done
        else
            echo "Error: Failed to parse skills.json or python3 is missing." >&2
            exit 1
        fi
    else
        echo "Error: Failed to download manifest from $MANIFEST_URL" >&2
        exit 1
    fi
else
    # Local installation
    for skill in "$SKILLS_DIR"/*/; do
        [ -d "$skill" ] || continue
        skill_name=$(basename "$skill")
        deploy_folder "$skill" "$GEMINI_SKILLS_DIR/$skill_name"
        deploy_folder "$skill" "$CLAUDE_SKILLS_DIR/$skill_name"
    done
fi

# 4. Process OpenAI Codex CLI
MSAF_SKILL="$SKILLS_DIR/msaf-architect/SKILL.md"
CODEX_AGENTS_FILE="$CODEX_DIR/AGENTS.md"

# Clear existing block if re-running
if [ -f "$CODEX_AGENTS_FILE" ]; then
    # Use perl to delete any existing imported section
    perl -i -0777 -pe 's/# --- Imported from msaf-architect skill.*//s' "$CODEX_AGENTS_FILE"
fi

if [ "$IS_REMOTE" = true ]; then
    skill_url="$RAW_BASE_URL/msaf-architect/SKILL.md"
    body=$(curl -fsSL "$skill_url")
else
    if [ -f "$MSAF_SKILL" ]; then
        body=$(cat "$MSAF_SKILL")
    fi
fi

if [ -n "$body" ]; then
    echo -e "\n\n# --- Imported from msaf-architect skill ($MODE Mode) ---" >> "$CODEX_AGENTS_FILE"
    echo "$body" >> "$CODEX_AGENTS_FILE"
    echo "✔ OpenAI Codex: Updated global AGENTS.md"
fi

echo -e "\nDone! All skills successfully installed in $MODE mode."
