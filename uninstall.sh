#!/bin/bash
# uninstall.sh - Cross-agent skill uninstaller for macOS/Linux
# Usage:
#   ./uninstall.sh [--scope global|folder] [--path <target-folder>] [--skills msaf-architect]

SCOPE=""
TARGET_FOLDER=""
SKILLS=""

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s|--scope) SCOPE="$2"; shift ;;
        -p|--path) TARGET_FOLDER="$2"; shift ;;
        -k|--skills) SKILLS="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -n "$SCOPE" ]; then
    SCOPE=$(echo "$SCOPE" | tr '[:upper:]' '[:lower:]')
    if [ "$SCOPE" != "global" ] && [ "$SCOPE" != "folder" ]; then
        echo "Error: Invalid scope. Must be 'global' or 'folder'." >&2
        exit 1
    fi
fi

# 1. Determine Scope
if [ -z "$SCOPE" ]; then
    echo "============================================="
    echo "    AI Agent Custom Skill Uninstaller        "
    echo "============================================="
    echo "Select uninstallation scope:"
    echo "[1] Global (user profile: standard agent config folders)"
    echo "[2] Folder/Local (specific workspace: uninstalls from a custom repository/folder)"
    
    while true; do
        read -p "Select option (1 or 2): " choice
        case $choice in
            1) SCOPE="global"; break ;;
            2) SCOPE="folder"; break ;;
            *) echo "Invalid choice. Please enter 1 or 2." ;;
        esac
    done
fi

if [ "$SCOPE" = "folder" ]; then
    if [ -z "$TARGET_FOLDER" ]; then
        echo -e "\nUninstalling locally from a specific workspace folder..."
        read -p "Enter target folder path (default: .): " TARGET_FOLDER
        [ -z "$TARGET_FOLDER" ] && TARGET_FOLDER="."
    fi
    TARGET_FOLDER=$(cd "$TARGET_FOLDER" && pwd)
fi

# 2. Resolve target directories
if [ "$SCOPE" = "folder" ]; then
    AGENTS_SKILLS_DIR="$TARGET_FOLDER/.agents/skills"
    CLAUDE_SKILLS_DIR="$TARGET_FOLDER/.claude/skills"
else
    AGENTS_SKILLS_DIR="$HOME/.agents/skills"
    CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
fi

# 3. Discover installed skills
INSTALLED_SKILLS=""
if [ -d "$AGENTS_SKILLS_DIR" ]; then
    for d in "$AGENTS_SKILLS_DIR"/*/; do
        [ -d "$d" ] || continue
        INSTALLED_SKILLS+="$(basename "$d")"$'\n'
    done
fi
if [ -d "$CLAUDE_SKILLS_DIR" ]; then
    for d in "$CLAUDE_SKILLS_DIR"/*/; do
        [ -d "$d" ] || continue
        INSTALLED_SKILLS+="$(basename "$d")"$'\n'
    done
fi

# Unique list & remove empty
INSTALLED_SKILLS=$(echo "$INSTALLED_SKILLS" | sed '/^[[:space:]]*$/d' | sort -u)

if [ -z "$INSTALLED_SKILLS" ]; then
    echo "No skills found installed in this scope."
    exit 0
fi

# 4. Determine which skills to uninstall
SELECTED_SKILLS=()
if [ -n "$SKILLS" ]; then
    IFS=',' read -r -a array <<< "$SKILLS"
    for item in "${array[@]}"; do
        trimmed=$(echo "$item" | xargs)
        if echo "$INSTALLED_SKILLS" | grep -Fqx "$trimmed"; then
            SELECTED_SKILLS+=("$trimmed")
        fi
    done
else
    count=$(echo "$INSTALLED_SKILLS" | wc -l | xargs)
    if [ "$count" -gt 1 ]; then
        echo -e "\nInstalled Skills found in scope:"
        echo "[1] ALL"
        i=2
        while read -r skill; do
            [ -z "$skill" ] && continue
            echo "[$i] $skill"
            i=$((i+1))
        done <<< "$INSTALLED_SKILLS"
        
        read -p "Select skills to uninstall (comma-separated numbers, or press Enter for ALL): " skills_choice
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
                done <<< "$INSTALLED_SKILLS"
            else
                for idx in "${indices[@]}"; do
                    idx_trimmed=$(echo "$idx" | xargs)
                    line_num=$((idx_trimmed - 1))
                    skill_name=$(echo "$INSTALLED_SKILLS" | sed -n "${line_num}p")
                    if [ -n "$skill_name" ]; then
                        SELECTED_SKILLS+=("$skill_name")
                    fi
                done
            fi
        else
            while read -r skill; do
                [ -z "$skill" ] && continue
                SELECTED_SKILLS+=("$skill")
            done <<< "$INSTALLED_SKILLS"
        fi
    else
        while read -r skill; do
            [ -z "$skill" ] && continue
            SELECTED_SKILLS+=("$skill")
        done <<< "$INSTALLED_SKILLS"
    fi
fi

if [ ${#SELECTED_SKILLS[@]} -eq 0 ]; then
    echo "No skills selected for uninstallation."
    exit 0
fi

# 5. Remove the skills
for skill_name in "${SELECTED_SKILLS[@]}"; do
    agents_path="$AGENTS_SKILLS_DIR/$skill_name"
    claude_path="$CLAUDE_SKILLS_DIR/$skill_name"
    
    if [ -d "$agents_path" ] || [ -L "$agents_path" ]; then
        rm -rf "$agents_path"
        echo "✔ Uninstalled: $skill_name from Agents (Shared)"
    fi
    if [ -d "$claude_path" ] || [ -L "$claude_path" ]; then
        rm -rf "$claude_path"
        echo "✔ Uninstalled: $skill_name from Claude"
    fi
done

echo -e "\nDone! Selected skills successfully uninstalled."
