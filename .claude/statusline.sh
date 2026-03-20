#!/bin/bash
set -f

input=$(cat)

if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

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

# ── Usage rate limits ───────────────────────────────────
green_c='\033[38;2;0;175;80m'
yellow_c='\033[38;2;230;200;0m'
orange_c='\033[38;2;255;176;85m'
red_c='\033[38;2;255;85;85m'
white_c='\033[38;2;140;140;140m'
dim_c='\033[2m'
reset_c='\033[0m'

color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then printf "$red_c"
    elif [ "$pct" -ge 70 ]; then printf "$yellow_c"
    elif [ "$pct" -ge 50 ]; then printf "$orange_c"
    else printf "$green_c"
    fi
}

build_bar() {
    local pct=$1 width=$2
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar_color
    bar_color=$(color_for_pct "$pct")
    local filled_str="" empty_str=""
    for ((i=0; i<filled; i++)); do filled_str+="●"; done
    for ((i=0; i<empty; i++)); do empty_str+="○"; done
    printf "${bar_color}${filled_str}${dim_c}${empty_str}${reset_c}"
}

format_reset_time() {
    local iso_str="$1" style="$2"
    [ -z "$iso_str" ] || [ "$iso_str" = "null" ] && return
    local stripped="${iso_str%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    stripped="${stripped%%-[0-9][0-9]:[0-9][0-9]}"
    local epoch=""
    if [[ "$iso_str" == *"Z"* ]] || [[ "$iso_str" == *"+00:00"* ]]; then
        epoch=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    else
        epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    fi
    [ -z "$epoch" ] && return
    local result=""
    case "$style" in
        time)
            result=$(date -j -r "$epoch" +"%l:%M%p" 2>/dev/null | sed 's/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
            ;;
        datetime)
            result=$(date -j -r "$epoch" +"%b %-d, %l:%M%p" 2>/dev/null | sed 's/  / /g; s/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
            ;;
    esac
    printf "%s" "$result"
}

get_oauth_token() {
    if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
        echo "$CLAUDE_CODE_OAUTH_TOKEN"
        return 0
    fi
    if command -v security >/dev/null 2>&1; then
        local blob
        blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [ -n "$blob" ]; then
            local token
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"
                return 0
            fi
        fi
    fi
    local creds_file="${HOME}/.claude/.credentials.json"
    if [ -f "$creds_file" ]; then
        local token
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            echo "$token"
            return 0
        fi
    fi
    echo ""
}

cache_file="/tmp/claude/statusline-usage-cache.json"
cache_max_age=180
mkdir -p /tmp/claude

needs_refresh=true
usage_data=""

if [ -f "$cache_file" ]; then
    cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null)
    now=$(date +%s)
    cache_age=$(( now - cache_mtime ))
    if [ "$cache_age" -lt "$cache_max_age" ]; then
        needs_refresh=false
        usage_data=$(cat "$cache_file" 2>/dev/null)
    fi
fi

if $needs_refresh; then
    token=$(get_oauth_token)
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        response=$(curl -s --max-time 5 \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-code/2.1.34" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        if [ -n "$response" ] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
            usage_data="$response"
            echo "$response" > "$cache_file"
        fi
    fi
    if [ -z "$usage_data" ] && [ -f "$cache_file" ]; then
        usage_data=$(cat "$cache_file" 2>/dev/null)
    fi
fi

if [ -n "$usage_data" ] && echo "$usage_data" | jq -e . >/dev/null 2>&1; then
    bar_width=10

    five_hour_pct=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f", $1}')
    five_hour_reset=$(format_reset_time "$(echo "$usage_data" | jq -r '.five_hour.resets_at // empty')" "time")
    five_hour_bar=$(build_bar "$five_hour_pct" "$bar_width")
    five_hour_pct_color=$(color_for_pct "$five_hour_pct")

    seven_day_pct=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f", $1}')
    seven_day_reset=$(format_reset_time "$(echo "$usage_data" | jq -r '.seven_day.resets_at // empty')" "datetime")
    seven_day_bar=$(build_bar "$seven_day_pct" "$bar_width")
    seven_day_pct_color=$(color_for_pct "$seven_day_pct")

    printf "\n"
    printf "${white_c}cur${reset_c} ${five_hour_bar} ${five_hour_pct_color}%3d%%${reset_c} ${dim_c}⟳${reset_c} ${white_c}${five_hour_reset}${reset_c}" "$five_hour_pct"
    printf "  "
    printf "${white_c}wk${reset_c} ${seven_day_bar} ${seven_day_pct_color}%3d%%${reset_c} ${dim_c}⟳${reset_c} ${white_c}${seven_day_reset}${reset_c}" "$seven_day_pct"
fi

exit 0
