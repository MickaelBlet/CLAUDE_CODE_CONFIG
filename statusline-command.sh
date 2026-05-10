#!/usr/bin/env bash

# Read JSON input from stdin
readonly input="$(cat)"

# echo "$input" > ~/.test-statusline.json

function current_dir() {
    local cwd bg=238
    cwd="$(echo "$input" | jq -r '.workspace.current_dir')"
    [[ "$cwd" =~ ^"$HOME" ]] && cwd="${cwd/$HOME\//\~\/}"
    echo "\033[38;5;${bg}m"$'\uE0B6'"\033[48;5;${bg}m\033[38;5;231m"$'\U0001F4C2'" ${cwd}\033[0m\033[38;5;${bg}m"$'\uE0B4'"\033[0m"
}

function model() {
    local model effort bg fg=231 effort_bg effort_icon
    model="$(echo "$input" | jq -r '.model.display_name')"

    # Effort level: prefer stdin input, fall back to ~/.claude/settings.json
    effort="$(echo "$input" | jq -r '(.effort.level // .effortLevel // .config.effortLevel // empty)' 2>/dev/null)"
    if [[ -z "$effort" || "$effort" == "null" ]] && [ -r "$HOME/.claude/settings.json" ]; then
        effort="$(jq -r '.effort.level // .effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)"
    fi
    effort="${effort,,}"

    # Color by effort: low=green, medium=orange, high=red; fallback by model tier
    case "$effort" in
        low)    effort_bg=22;  effort_icon=$'\U0001F7E2' ;;
        medium) effort_bg=130; effort_icon=$'\U0001F7E1' ;;
        high)   effort_bg=124; effort_icon=$'\U0001F7E0' ;;
        xhigh)  effort_bg=124; effort_icon=$'\U0001F534' ;;
        max)    effort_bg=54;  effort_icon=$'\U0001F7E3' ;;
        *)      effort_bg=240; effort_icon=$'\u26AA' ;;
    esac

    case "$model" in
        Opus*)   bg=125 ;;
        Sonnet*) bg=33  ;;
        Haiku*)  bg=22  ;;
        *)       bg=240 ;;
    esac

    local label="${model}"
    if [ -n "$effort" ] && [ "$effort" != "null" ]; then
        label="${label} \033[38;5;${bg}m\033[48;5;${effort_bg}m"$'\uE0B0'"\033[38;5;${fg}m${effort_icon} ${effort^}\033[0m\033[38;5;${effort_bg}m"$'\uE0B4'
    else
        label="${label}\033[0m\033[38;5;${bg}m"$'\uE0B4'
    fi

    echo -e "\033[38;5;${bg}m"$'\uE0B6'"\033[48;5;${bg}m\033[38;5;${fg}m"$'\U0001F916'" ${label}\033[0m"
}

function git_info() {
    local cwd
    cwd="$(echo "$input" | jq -r '.workspace.current_dir')"

    _g() { GIT_OPTIONAL_LOCKS=0 command git -C "$cwd" -c core.useBuiltinFSMonitor=false "$@"; }

    # not a git repository
    _g rev-parse --git-dir > /dev/null 2>&1 || return

    local git_dir is_bare is_inside_git_dir is_inside_work_tree short_hash
    git_dir=$(_g rev-parse --git-dir 2>/dev/null)
    is_bare=$(_g rev-parse --is-bare-repository 2>/dev/null)
    is_inside_git_dir=$(_g rev-parse --is-inside-git-dir 2>/dev/null)
    is_inside_work_tree=$(_g rev-parse --is-inside-work-tree 2>/dev/null)
    short_hash=$(_g rev-parse --short HEAD 2>/dev/null)

    # In-progress action detection (rebase/merge/cherry-pick/revert/bisect)
    local rebase_action="" rebase_num="" rebase_total="" branch=""
    if [ -d "$git_dir/rebase-merge" ]; then
        [ -r "$git_dir/rebase-merge/head-name" ] && IFS=$'\r\n' read -r branch < "$git_dir/rebase-merge/head-name"
        [ -r "$git_dir/rebase-merge/msgnum" ]    && IFS=$'\r\n' read -r rebase_num < "$git_dir/rebase-merge/msgnum"
        [ -r "$git_dir/rebase-merge/end" ]       && IFS=$'\r\n' read -r rebase_total < "$git_dir/rebase-merge/end"
        rebase_action="REBASE"
    elif [ -d "$git_dir/rebase-apply" ]; then
        [ -r "$git_dir/rebase-apply/next" ] && IFS=$'\r\n' read -r rebase_num < "$git_dir/rebase-apply/next"
        [ -r "$git_dir/rebase-apply/last" ] && IFS=$'\r\n' read -r rebase_total < "$git_dir/rebase-apply/last"
        if [ -f "$git_dir/rebase-apply/rebasing" ]; then
            [ -r "$git_dir/rebase-apply/head-name" ] && IFS=$'\r\n' read -r branch < "$git_dir/rebase-apply/head-name"
            rebase_action="REBASE"
        elif [ -f "$git_dir/rebase-apply/applying" ]; then
            rebase_action="REBASE-APPLYING"
        else
            rebase_action="REBASE/APPLYING"
        fi
    elif [ -f "$git_dir/MERGE_HEAD" ]; then
        rebase_action="MERGE"
    elif [ -f "$git_dir/CHERRY_PICK_HEAD" ]; then
        rebase_action="CHERRY-PICK"
    elif [ -f "$git_dir/REVERT_HEAD" ]; then
        rebase_action="REVERT"
    elif [ -f "$git_dir/BISECT_LOG" ]; then
        rebase_action="BISECT"
    fi
    [ -n "$rebase_num" ] && [ -n "$rebase_total" ] && rebase_action="$rebase_action $rebase_num/$rebase_total"

    # Resolve branch / detached
    local detached=false hashed=false
    if [ -z "$branch" ]; then
        local head
        head=$(_g symbolic-ref HEAD 2>/dev/null)
        if [ -z "$head" ]; then
            detached=true
            branch=$(_g describe --tags HEAD 2>/dev/null)
            if [ -z "$branch" ]; then
                hashed=true
                branch="${short_hash}..."
            fi
            branch="($branch)"
        else
            branch="$head"
        fi
    fi
    branch="${branch##refs/heads/}"

    # Counts
    local count_dirty=0 count_added=0 count_stash=0 count_untracked=0
    local count_upstream_left=0 count_upstream_right=0
    local conflict=false
    if [ "$is_inside_work_tree" = true ]; then
        count_dirty=$(_g diff --name-only --no-ext-diff 2>/dev/null | wc -l)
        count_added=$(_g diff --name-only --no-ext-diff --cached 2>/dev/null | wc -l)
        count_stash=$(_g rev-list --walk-reflogs --count refs/stash 2>/dev/null || echo 0)
        count_untracked=$(_g ls-files --others --exclude-standard 2>/dev/null | wc -l)
        local up
        up=$(_g rev-list --count --left-right '@{upstream}...HEAD' 2>/dev/null)
        if [ -n "$up" ]; then
            count_upstream_left="${up%$'\t'*}"
            count_upstream_right="${up#*$'\t'}"
        fi
        [ -n "$(_g ls-files --unmerged 2>/dev/null)" ] && conflict=true
    fi

    # Powerline characters (mirroring ~/.zshrc.d/promptor/functions/git config)
    local ch_branch=$'\uE0A0' ch_tag=$'\uF02B' ch_hash=$'\u2D4C'
    local ch_sep=$'\u2502' ch_sep_prompt=$'\uE0B1'
    local ch_up_left=$'\u2B63' ch_up_right=$'\u2B61'

    # Build info string
    local info=""
    _add() { [ -n "$info" ] && info="${info}${ch_sep}"; info="${info}$1"; }
    [ "$count_dirty" -gt 0 ]     && _add "${count_dirty}M"
    [ "$count_added" -gt 0 ]     && _add "${count_added}A"
    [ "$count_untracked" -gt 0 ] && _add "${count_untracked}U"
    [ "$count_stash" -gt 0 ]     && _add "${count_stash}S"
    if [ "$count_upstream_left" -gt 0 ] && [ "$count_upstream_right" -gt 0 ]; then
        _add "${ch_up_left}${count_upstream_left}${ch_up_right}${count_upstream_right}"
    elif [ "$count_upstream_left" -gt 0 ]; then
        _add "${ch_up_left}${count_upstream_left}"
    elif [ "$count_upstream_right" -gt 0 ]; then
        _add "${ch_up_right}${count_upstream_right}"
    fi

    if [ "$is_inside_git_dir" = true ]; then
        [ -n "$info" ] && info="${info} ${ch_sep_prompt} "
        if [ "$is_bare" = true ]; then info="${info}BARE"; else info="${info}.GIT"; fi
    fi
    if [ -n "$rebase_action" ]; then
        [ -n "$info" ] && info="${info} ${ch_sep_prompt} "
        info="${info}${rebase_action}"
    fi
    if [ "$conflict" = true ]; then
        [ -n "$info" ] && info="${info} ${ch_sep_prompt} "
        info="${info}CONFLICT"
    fi
    if [ -n "$branch" ]; then
        [ -n "$info" ] && info="${info} ${ch_sep_prompt} "
        info="${info}${branch}"
        if [ "$detached" = true ]; then
            if [ "$hashed" = true ]; then info="${info}${ch_hash}"; else info="${info}${ch_tag}"; fi
        else
            info="${info} ${ch_branch}"
        fi
    fi

    # Color selection (sequence: conflict dirty added untracked detached remote)
    local bg=240 fg=231
    if [ "$conflict" = true ] || [ "$is_inside_git_dir" = true ]; then
        bg=124; fg=231
    elif [ "$count_dirty" -gt 0 ]; then
        bg=226; fg=232
    elif [ "$count_added" -gt 0 ]; then
        bg=207; fg=232
    elif [ "$count_untracked" -gt 0 ]; then
        bg=214; fg=232
    elif [ "$detached" = true ]; then
        bg=97; fg=231
    elif [ "$count_upstream_left" -eq 0 ] && [ "$count_upstream_right" -eq 0 ]; then
        bg=118; fg=232
    fi

    printf "\033[38;5;%sm"$'\uE0B6'"\033[48;5;%sm\033[38;5;%sm"$'\U0001F516'" %s\033[0m\033[38;5;%sm"$'\uE0B4'"\033[0m" \
        "$bg" "$bg" "$fg" "$info" "$bg"
}

function context_length() {
    # Extract context window usage percentage
    local used_pct bg=240 fg=231
    used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
    if [[ -n "$used_pct" ]]; then
        # Color based on usage: green <50, yellow 50-79, red >=80
        if [[ "$used_pct" -ge 60 ]]; then
            bg="124"
        elif [[ "$used_pct" -ge 40 ]]; then
            bg="130"
        else
            bg="22"
        fi
        echo -ne "\033[38;5;${bg}m"$'\uE0B6'"\033[48;5;${bg}m\033[38;5;231m"$'\U0001F4CA'" ${used_pct}%\033[0m\033[38;5;${bg}m"$'\uE0B4'"\033[0m"
    fi
}

function session_usage() {
    local pct week timestamp_pct timestamp_pct_full timestamp timestamp_m timestamp_week timestamp_week_full fg=231 bg_pct bg_week=33 tmp
    pct=$(echo "$input" | jq -r '(.rate_limits.five_hour.used_percentage // empty)? // empty' 2>/dev/null)
    week=$(echo "$input" | jq -r '(.rate_limits.seven_day.used_percentage // empty)? // empty' 2>/dev/null)

    if [[ -z "$pct" || "$pct" == "null" ]] && [[ -z "$week" || "$week" == "null" ]]; then
        # Force refresh by toggling refreshInterval in settings.json if no rate limit info is available
        tmp=$(mktemp)
        jq '.statusLine.refreshInterval = 1' "$HOME/.claude/settings.json" > "$tmp" && mv "$tmp" "$HOME/.claude/settings.json"
        sleep 1.1
        tmp=$(mktemp)
        jq '.statusLine.refreshInterval = 30' "$HOME/.claude/settings.json" > "$tmp" && mv "$tmp" "$HOME/.claude/settings.json"
        return
    fi

    [[ -z "$pct" || "$pct" == "null" ]] && pct=0
    [[ -z "$week" || "$week" == "null" ]] && week=0

    timestamp_pct=$(echo "$input" | jq -r '(.rate_limits.five_hour.resets_at // empty)? // empty' 2>/dev/null)
    timestamp_week=$(echo "$input" | jq -r '(.rate_limits.seven_day.resets_at // empty)? // empty' 2>/dev/null)

    timestamp=$(date +%s)

    [[ -z "$timestamp_pct" || "$timestamp_pct" == "null" ]] && timestamp_pct="${timestamp}"
    [[ -z "$timestamp_week" || "$timestamp_week" == "null" ]] && timestamp_week="${timestamp}"

    timestamp_pct_full=$timestamp_pct
    timestamp_pct=$(echo "${timestamp_pct}-${timestamp}" | bc)
    if [[ "${timestamp_pct}" -lt 100 ]]; then
        if [[ "${timestamp_pct}" -lt 0 ]]; then
            timestamp_pct=0
        fi
        timestamp_pct="${timestamp_pct}s"
    else
        timestamp_pct=$(echo "${timestamp_pct}/60" | bc)
        if [[ "${timestamp_pct}" -lt 100 ]]; then
            timestamp_pct="${timestamp_pct}m"
        else
            timestamp_m="${timestamp_pct}"
            timestamp_m=$(echo "${timestamp_pct}%60" | bc)
            timestamp_pct=$(echo "${timestamp_pct}/60" | bc)
            timestamp_pct="${timestamp_pct}h$(printf "%02d" "${timestamp_m}")"
        fi
        timestamp_pct="${timestamp_pct}\033[38;5;232m"$'\u2502'"\033[38;5;${fg}m$(date -d "@${timestamp_pct_full}" +"%Hh%M" 2>/dev/null)"
    fi

    timestamp_week_full=$timestamp_week
    timestamp_week=$(echo "${timestamp_week}-${timestamp}" | bc)
    if [[ "${timestamp_week}" -lt 100 ]]; then
        if [[ "${timestamp_week}" -lt 0 ]]; then
            timestamp_week=0
        fi
        timestamp_week="${timestamp_week}s"
    else
        timestamp_week=$(echo "${timestamp_week}/60" | bc)
        if [[ "${timestamp_week}" -lt 100 ]]; then
            timestamp_week="${timestamp_week}m"
        else
            timestamp_week=$(echo "${timestamp_week}/60" | bc)
            if [[ "${timestamp_week}" -lt 24 ]]; then
                timestamp_m="${timestamp_week}"
                timestamp_m=$(echo "${timestamp_week}%60" | bc)
                timestamp_week=$(echo "${timestamp_week}/60" | bc)
                timestamp_week="${timestamp_week}h$(printf "%02d" "${timestamp_m}")"
            else
                timestamp_week="$(echo "${timestamp_week}/24" | bc)d\033[38;5;232m"$'\u2502'"\033[38;5;${fg}m$(date -d "@${timestamp_week_full}" +"%A %Hh%M" 2>/dev/null)"
            fi
        fi
    fi

    bg_pct=240
    local out=""
    if [[ -n "$pct" ]]; then
        pct=${pct%.*}
        [[ -z "$pct" || ! "$pct" =~ ^[0-9]+$ ]] && pct=0
        if [[ "$pct" -ge 80 ]]; then
            bg_pct="124"
        elif [[ "$pct" -ge 50 ]]; then
            bg_pct="130"
        else
            bg_pct="22"
        fi
        out="\033[38;5;${bg_pct}m"$'\uE0B6'"\033[48;5;${bg_pct}m\033[38;5;${fg}m"$'\u23F3'" "
        out+="${pct}%\033[38;5;232m"$'\u2502'"\033[38;5;${fg}m${timestamp_pct}"
    fi

    if [[ -n "$week" ]]; then
        week=${week%.*}
        [[ -z "$week" || ! "$week" =~ ^[0-9]+$ ]] && week=0
        if [[ -n "$pct" ]]; then
            out+=" \033[38;5;${bg_pct}m\033[48;5;${bg_week}m"$'\uE0B0'" \033[38;5;${fg}m"
        else
            out="\033[38;5;${bg_week}m"$'\uE0B6'"\033[48;5;${bg_week}m\033[38;5;${fg}m"$'\u23F3'" "
        fi
        out+="${week}%\033[38;5;232m"$'\u2502'"\033[38;5;${fg}m${timestamp_week}\033[0m\033[38;5;${bg_week}m"$'\uE0B4'
    else
        if [[ -n "$pct" ]]; then
            out+="\033[0m\033[38;5;${bg_pct}m"$'\uE0B4'
        fi
    fi

    echo -ne "$out\033[0m"
}

printf '%b' "$(model)"
printf '%b' "$(context_length)"
printf '%b' "$(session_usage)"
printf '%b' "\n"
printf '%b' "$(current_dir)"
printf '%b' "$(git_info)"