#!/bin/bash

# Claude Code Status Line Script
# Provides contextual information for development workflow

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // ""')
cwd=$(echo "$input" | jq -r '.cwd // ""')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // ""')
output_style=$(echo "$input" | jq -r '.output_style.name // "default"')
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
exceeds_200k=$(echo "$input" | jq -r '.exceeds_200k_tokens // false')
total_lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
total_lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# Use cwd and replace home directory with ~
display_path="$cwd"
if [[ -n "$cwd" && "$cwd" == "$HOME"* ]]; then
    display_path="~${cwd#$HOME}"
fi

# Get git info if in a git repository
git_info=""
if [[ -n "$current_dir" ]] && cd "$current_dir" 2>/dev/null; then
    if git rev-parse --git-dir >/dev/null 2>&1; then
        branch=$(git branch --show-current 2>/dev/null)
        if [[ -n "$branch" ]]; then
            # Check for uncommitted changes
            if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                git_info=" ${branch}*"
            else
                git_info=" ${branch}"
            fi
        fi
    fi
fi

# Format cost display
cost_display=""
if [[ "$total_cost" != "0" && "$total_cost" != "null" ]]; then
    cost_display=" \$$(printf "%.2f" "$total_cost")"
fi

# Build line changes display
line_changes_display=""
if [[ "$total_lines_added" != "0" || "$total_lines_removed" != "0" ]]; then
    line_changes_display=" +${total_lines_added} -${total_lines_removed}"
fi

# Build status line with colors in order: Model name → Path → Git branch → Code changes → Token count
printf "\033[2m%s\033[0m" "$model_name"

# Add path with separator
if [[ -n "$display_path" ]]; then
    printf "\033[2m • %s\033[0m" "$display_path"
fi

# Add git branch with separator
if [[ -n "$git_info" ]]; then
    printf "\033[2m •%s\033[0m" "$git_info"
fi

# Add line changes information with separator
if [[ -n "$line_changes_display" ]]; then
    printf "\033[2m •%s\033[0m" "$line_changes_display"
fi

# Add cost information with separator
if [[ -n "$cost_display" ]]; then
    printf "\033[2m •%s\033[0m" "$cost_display"
fi

# Add output style if not default with separator
if [[ "$output_style" != "default" ]]; then
    printf "\033[2m • [%s]\033[0m" "$output_style"
fi

# Add context usage progress bar at the far right
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [[ -n "$used_pct" ]]; then
    # Round to integer
    used_int=$(printf "%.0f" "$used_pct")

    # Build a 10-character progress bar using ASCII-friendly chars
    filled=$(( used_int * 10 / 100 ))
    bar=""
    for (( i = 0; i < 10; i++ )); do
        if (( i < filled )); then
            bar="${bar}▓"
        else
            bar="${bar}▁"
        fi
    done

    # Compute absolute token counts from percentage and total context window size
    total_tokens=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
    abs_display=""
    if [[ -n "$total_tokens" && "$total_tokens" != "0" ]]; then
        used_tokens=$(printf "%.0f" "$(echo "scale=0; $total_tokens * $used_pct / 100" | bc -l)")
        used_k=$(printf "%.1f" "$(echo "scale=1; $used_tokens / 1000" | bc -l)")
        total_k=$(printf "%.1f" "$(echo "scale=1; $total_tokens / 1000" | bc -l)")
        abs_display="(${used_k}k/${total_k}k)"
    fi

    printf "\033[2m • %s %d%%%s\033[0m" "$bar" "$used_int" "$abs_display"
fi
