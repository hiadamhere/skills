#!/bin/bash
# install.sh - Cross-agent skill installer for macOS/Linux
# Usage: 
#   Local (cloned):   ./install.sh [--mode copy|link]
#   Remote (one-line): curl -fsSL https://raw.githubusercontent.com/hiadamhere/skills/main/install.sh | bash

MODE=""
SCOPE=""
TARGET_FOLDER=""
SKILLS=""

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -m|--mode) MODE="$2"; shift ;;
        -s|--scope) SCOPE="$2"; shift ;;
        -p|--path) TARGET_FOLDER="$2"; shift ;;
        -k|--skills) SKILLS="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

GITHUB_USER="hiadamhere"
GITHUB_REPO="skills" # public catalog repo (remote mode fetches published files only)
BRANCH="main"
# RAW_BASE_URL is built below from $REF -- a pinned commit SHA for remote installs.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"

# Check if running locally or remotely
if [ -d "$SKILLS_DIR" ]; then
    IS_REMOTE=false
else
    IS_REMOTE=true
fi

# Resolve the ref to install from. Remote installs pin to a single commit SHA so
# a push landing mid-install can't serve a manifest from one commit and files
# from another. Fall back to the branch ref on any API failure (rate limit /
# missing python3) so the install still proceeds.
REF="$BRANCH"
if [ "$IS_REMOTE" = true ]; then
    commit_json=$(curl -fsSL -H "User-Agent: skills-installer" "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/commits/$BRANCH" 2>/dev/null)
    resolved_sha=$(echo "$commit_json" | python3 -c "import sys, json; print(json.load(sys.stdin).get('sha',''))" 2>/dev/null)
    if [ -n "$resolved_sha" ]; then
        REF="$resolved_sha"
        echo "Pinned to commit ${REF:0:7} for a consistent snapshot."
    else
        echo "Warning: could not resolve '$BRANCH' to a commit SHA; falling back to '$BRANCH' refs (install may not be a consistent snapshot)." >&2
    fi
fi
RAW_BASE_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$REF/skills"

# 1. Handle Remote vs Local Setup
if [ "$IS_REMOTE" = true ]; then
    echo "Running in REMOTE mode (fetching files from GitHub)..."
    if [ "$MODE" = "link" ]; then
        echo "Warning: Symlink mode is not available in remote execution. Defaulting to Copy (Download) mode."
    fi
    MODE="copy"
    SCOPE="global"
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
    
    # Prompt for scope if not specified
    if [ -z "$SCOPE" ]; then
        echo -e "\nSelect installation scope:"
        echo "[1] Global (user profile: standard agent config folders)"
        echo "[2] Folder/Local (specific workspace: installs inside a custom repository/folder)"
        
        while true; do
            read -p "Select option (1 or 2): " choice
            case $choice in
                1) SCOPE="global"; break ;;
                2) SCOPE="folder"; break ;;
                *) echo "Invalid choice. Please enter 1 or 2." ;;
            esac
        done
    fi
fi

# Convert parameters to lowercase
MODE=$(echo "$MODE" | tr '[:upper:]' '[:lower:]')
SCOPE=$(echo "$SCOPE" | tr '[:upper:]' '[:lower:]')

if [ "$MODE" != "copy" ] && [ "$MODE" != "link" ]; then
    echo "Error: Invalid mode. Must be 'copy' or 'link'." >&2
    exit 1
fi

if [ "$SCOPE" != "global" ] && [ "$SCOPE" != "folder" ]; then
    echo "Error: Invalid scope. Must be 'global' or 'folder'." >&2
    exit 1
fi

if [ "$SCOPE" = "folder" ]; then
    if [ -z "$TARGET_FOLDER" ]; then
        echo -e "\nInstalling locally to a specific workspace folder..."
        read -p "Enter target folder path (default: .): " TARGET_FOLDER
        [ -z "$TARGET_FOLDER" ] && TARGET_FOLDER="."
    fi
    mkdir -p "$TARGET_FOLDER"
    TARGET_FOLDER=$(cd "$TARGET_FOLDER" && pwd)
fi

echo -e "\nStarting installation in $MODE mode ($SCOPE scope)..."

# 2. Resolve directories and ensure they exist
if [ "$SCOPE" = "folder" ]; then
    AGENTS_SKILLS_DIR="$TARGET_FOLDER/.agents/skills"
    CLAUDE_SKILLS_DIR="$TARGET_FOLDER/.claude/skills"
else
    AGENTS_SKILLS_DIR="$HOME/.agents/skills"
    CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
fi

mkdir -p "$AGENTS_SKILLS_DIR"
mkdir -p "$CLAUDE_SKILLS_DIR"

# Manifest is retrieved dynamically from skills.json or read locally
if [ "$IS_REMOTE" = true ]; then
    MANIFEST_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$REF/skills.json"
    files_json=$(curl -fsSL "$MANIFEST_URL")
    if [ -z "$files_json" ]; then
        echo "Error: Failed to download manifest from $MANIFEST_URL" >&2
        exit 1
    fi
else
    files_json=$(cat "$REPO_DIR/skills.json")
fi

# 3. Determine Available Skills
if [ -n "$files_json" ]; then
    AVAILABLE_SKILLS=$(echo "$files_json" | python3 -c "import sys, json; data = json.load(sys.stdin); print('\n'.join([s['name'] for s in data['skills']]))" 2>/dev/null)
    if [ -z "$AVAILABLE_SKILLS" ]; then
        # Fallback to local directory scanning if python3 fails or in local mode
        AVAILABLE_SKILLS=""
        for skill in "$SKILLS_DIR"/*/; do
            [ -d "$skill" ] || continue
            AVAILABLE_SKILLS+="$(basename "$skill")"$'\n'
        done
    fi
fi

# Trim empty lines
AVAILABLE_SKILLS=$(echo "$AVAILABLE_SKILLS" | sed '/^[[:space:]]*$/d')

# Parse selected skills
SELECTED_SKILLS=()
if [ -n "$SKILLS" ]; then
    IFS=',' read -r -a array <<< "$SKILLS"
    for item in "${array[@]}"; do
        trimmed=$(echo "$item" | xargs)
        # Verify it exists in AVAILABLE_SKILLS
        if echo "$AVAILABLE_SKILLS" | grep -Fqx "$trimmed"; then
            SELECTED_SKILLS+=("$trimmed")
        fi
    done
    if [ ${#SELECTED_SKILLS[@]} -eq 0 ]; then
        echo "Error: None of the specified skills '$SKILLS' are available in the catalog." >&2
        exit 1
    fi
else
    # Prompt if more than 1 skill is available
    count=$(echo "$AVAILABLE_SKILLS" | wc -l | xargs)
    if [ "$count" -gt 1 ]; then
        echo -e "\nAvailable Skills in Catalog:"
        echo "[1] ALL"
        i=2
        while read -r skill; do
            [ -z "$skill" ] && continue
            echo "[$i] $skill"
            i=$((i+1))
        done <<< "$AVAILABLE_SKILLS"
        
        read -p "Select skills to install (comma-separated numbers, or press Enter for ALL): " skills_choice
        if [ -n "$skills_choice" ]; then
            IFS=',' read -r -a indices <<< "$skills_choice"
            is_all=false
            for idx in "${indices[@]}"; do
                idx_trimmed=$(echo "$idx" | xargs)
                if [ "$idx_trimmed" = "1" ]; then
                    is_all=true
                    break
                fi
            done
            if [ "$is_all" = true ]; then
                while read -r skill; do
                    [ -z "$skill" ] && continue
                    SELECTED_SKILLS+=("$skill")
                done <<< "$AVAILABLE_SKILLS"
            else
                for idx in "${indices[@]}"; do
                    idx_trimmed=$(echo "$idx" | xargs)
                    line_num=$((idx_trimmed - 1))
                    skill_name=$(echo "$AVAILABLE_SKILLS" | sed -n "${line_num}p")
                    if [ -n "$skill_name" ]; then
                        SELECTED_SKILLS+=("$skill_name")
                    fi
                done
            fi
        else
            while read -r skill; do
                [ -z "$skill" ] && continue
                SELECTED_SKILLS+=("$skill")
            done <<< "$AVAILABLE_SKILLS"
        fi
    else
        while read -r skill; do
            [ -z "$skill" ] && continue
            SELECTED_SKILLS+=("$skill")
        done <<< "$AVAILABLE_SKILLS"
    fi
fi

# Manifest is retrieved dynamically from skills.json

deploy_folder() {
    local src="$1"
    local dest="$2"
    local label="$3"
    
    # Remove existing destination if it exists
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        rm -rf "$dest"
    fi
    
    if [ "$MODE" = "link" ]; then
        ln -s "$src" "$dest"
        echo "✔ Linked: $(basename "$dest") -> $label"
    else
        cp -r "$src" "$dest"
        echo "✔ Copied: $(basename "$dest") -> $label"
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

# 4. Main Deploy Logic
if [ "$IS_REMOTE" = true ]; then
    # Remote installation: construct files to download only for selected skills
    selected_skills_joined=$(printf ",%s" "${SELECTED_SKILLS[@]}")
    selected_skills_joined=${selected_skills_joined:1}
    
    FILES_TO_DOWNLOAD=$(echo "$files_json" | python3 -c "import sys, json; data = json.load(sys.stdin); sel = '$selected_skills_joined'.split(','); print('\n'.join([f for s in data['skills'] if s['name'] in sel for f in s['files']]))" 2>/dev/null)
    
    if [ -n "$FILES_TO_DOWNLOAD" ]; then
        echo "Downloading files in parallel..."
        pids=()
        while read -r file; do
            [ -z "$file" ] && continue
            url="$RAW_BASE_URL/$file"
            download_file "$url" "$AGENTS_SKILLS_DIR/$file" &
            pids+=($!)
            download_file "$url" "$CLAUDE_SKILLS_DIR/$file" &
            pids+=($!)
        done <<< "$FILES_TO_DOWNLOAD"
        
        # Wait for all background downloads to finish
        for pid in "${pids[@]}"; do
            wait "$pid"
        done
    else
        echo "Error: Failed to parse files from skills.json or python3 is missing." >&2
        exit 1
    fi
else
    # Local installation
    for skill_name in "${SELECTED_SKILLS[@]}"; do
        skill="$SKILLS_DIR/$skill_name"
        if [ -d "$skill" ]; then
            deploy_folder "$skill" "$AGENTS_SKILLS_DIR/$skill_name" "Agents (Shared)"
            deploy_folder "$skill" "$CLAUDE_SKILLS_DIR/$skill_name" "Claude"
        fi
    done
fi

# Record what was installed so uninstall/upgrade (and a future --check-updates)
# can reason about it: the exact commit, how it was installed, and which skills.
installed_sha="local"
[ "$IS_REMOTE" = true ] && installed_sha="$REF"
skills_json_arr=""
for s in "${SELECTED_SKILLS[@]}"; do
    esc=$(printf '%s' "$s" | sed 's/\\/\\\\/g; s/"/\\"/g')
    skills_json_arr+="\"$esc\","
done
skills_json_arr="[${skills_json_arr%,}]"
marker="{\"markerVersion\":1,\"sha\":\"$installed_sha\",\"ref\":\"$BRANCH\",\"remote\":$IS_REMOTE,\"mode\":\"$MODE\",\"scope\":\"$SCOPE\",\"date\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"skills\":$skills_json_arr}"
printf '%s\n' "$marker" > "$AGENTS_SKILLS_DIR/.installed.json"
printf '%s\n' "$marker" > "$CLAUDE_SKILLS_DIR/.installed.json"

echo -e "\nDone! All selected skills successfully installed in $MODE mode."
