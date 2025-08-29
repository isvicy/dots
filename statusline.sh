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

# Calculate estimated token usage from cost
token_display=""
if [[ "$total_cost" != "0" && "$total_cost" != "null" ]]; then
    # Claude Sonnet 4 pricing: $3/1M input tokens, $15/1M output tokens
    # Estimate using average price assuming ~65% input, 35% output tokens
    # Average price per token: (0.65 * 3 + 0.35 * 15) / 1000000 = $7.2e-6
    avg_price_per_token=0.0000072
    
    # Calculate estimated total tokens
    estimated_tokens=$(echo "$total_cost / $avg_price_per_token" | bc -l)
    
    # Format token count
    if (( $(echo "$estimated_tokens >= 1000000" | bc -l) )); then
        # Display in millions (M)
        token_millions=$(echo "scale=1; $estimated_tokens / 1000000" | bc -l)
        token_display=" ${token_millions}M tok"
    elif (( $(echo "$estimated_tokens >= 1000" | bc -l) )); then
        # Display in thousands (K)
        token_thousands=$(echo "scale=1; $estimated_tokens / 1000" | bc -l)
        token_display=" ${token_thousands}K tok"
    else
        # Display raw count for small numbers
        token_count=$(printf "%.0f" "$estimated_tokens")
        token_display=" ${token_count} tok"
    fi
    
    # Add warning if exceeds 200k tokens
    if [[ "$exceeds_200k" == "true" ]]; then
        token_display="${token_display}!"
    fi
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

# Add token information with separator
if [[ -n "$token_display" ]]; then
    printf "\033[2m •%s\033[0m" "$token_display"
fi

# Add output style if not default with separator
if [[ "$output_style" != "default" ]]; then
    printf "\033[2m • [%s]\033[0m" "$output_style"
fi
