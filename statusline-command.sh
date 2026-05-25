#!/usr/bin/env bash

readonly input="$(cat)"

# Single jq parse — avoids spawning jq per field
mapfile -t _p < <(jq -r '
  (.workspace.current_dir // ""),
  (.model.display_name // ""),
  (.effort.level // .effortLevel // .config.effortLevel // ""),
  (.context_window.used_percentage // ""),
  (.context_window.total_input_tokens // 0),
  (.context_window.total_output_tokens // 0),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.five_hour.resets_at // ""),
  (.rate_limits.seven_day.used_percentage // ""),
  (.rate_limits.seven_day.resets_at // "")
' <<< "$input")

_cwd="${_p[0]}"
_model_name="${_p[1]}"
_effort="${_p[2],,}"
_ctx_pct="${_p[3]}"
_tin="${_p[4]:-0}"
_tout="${_p[5]:-0}"
_rate5_pct="${_p[6]}"
_rate5_reset="${_p[7]}"
_rate7_pct="${_p[8]}"
_rate7_reset="${_p[9]}"

# Effort fallback from settings.json
if [[ -z "$_effort" ]] && [ -r "$HOME/.claude/settings.json" ]; then
    _effort="$(jq -r '(.effort.level // .effortLevel // empty)' "$HOME/.claude/settings.json" 2>/dev/null)"
    _effort="${_effort,,}"
fi

function current_dir() {
    local cwd="${_cwd}" bg=238
    [[ "$cwd" =~ ^"$HOME" ]] && cwd="${cwd/$HOME\//\~\/}"
    echo "\033[38;5;${bg}m"$''"\033[48;5;${bg}m\033[38;5;231m"$'\U0001F4C2'" ${cwd}\033[0m\033[38;5;${bg}m"$''"\033[0m"
}

function model() {
    local model="${_model_name}" effort="${_effort}" bg fg=231 effort_bg effort_icon

    case "$effort" in
        low)    effort_bg=22;  effort_icon=$'\U0001F7E2' ;;
        medium) effort_bg=130; effort_icon=$'\U0001F7E1' ;;
        high)   effort_bg=124; effort_icon=$'\U0001F7E0' ;;
        xhigh)  effort_bg=124; effort_icon=$'\U0001F534' ;;
        max)    effort_bg=54;  effort_icon=$'\U0001F7E3' ;;
        *)      effort_bg=240; effort_icon=$'⚪' ;;
    esac

    case "$model" in
        Opus*)   bg=125 ;;
        Sonnet*) bg=33  ;;
        Haiku*)  bg=22  ;;
        *)       bg=240 ;;
    esac

    local label
    case "$model" in
        Opus*)      label="Opus" ;;
        Sonnet*1M*) label="Sonnet(1M)" ;;
        Sonnet*)    label="Sonnet" ;;
        Haiku*)     label="Haiku" ;;
        *)          label="${model}" ;;
    esac

    if [ -n "$effort" ] && [ "$effort" != "null" ]; then
        label="${label}\033[38;5;${bg}m\033[48;5;${effort_bg}m"$''"\033[38;5;${fg}m${effort_icon} ${effort^}\033[0m\033[38;5;${effort_bg}m"$''
    else
        label="${label}\033[0m\033[38;5;${bg}m"$''
    fi

    echo -e "\033[38;5;${bg}m"$''"\033[48;5;${bg}m\033[38;5;${fg}m"$'\U0001F916'" ${label}\033[0m"
}

function git_info() {
    local cwd="${_cwd}"

    _g() { GIT_OPTIONAL_LOCKS=0 command git -C "$cwd" -c core.useBuiltinFSMonitor=false "$@"; }

    # not a git repository
    _g rev-parse --git-dir > /dev/null 2>&1 || return

    local tmp
    tmp=$(mktemp -d -p /dev/shm)
    trap "rm -rf '$tmp'" RETURN

    # Round 1: parallel rev-parse + symbolic-ref
    _g rev-parse --git-dir              > "$tmp/git_dir"             2>/dev/null &
    _g rev-parse --is-bare-repository   > "$tmp/is_bare"             2>/dev/null &
    _g rev-parse --is-inside-git-dir    > "$tmp/is_inside_git_dir"   2>/dev/null &
    _g rev-parse --is-inside-work-tree  > "$tmp/is_inside_work_tree" 2>/dev/null &
    _g rev-parse --short HEAD           > "$tmp/short_hash"          2>/dev/null &
    _g symbolic-ref HEAD                > "$tmp/symbolic_ref"        2>/dev/null &
    wait

    local git_dir is_bare is_inside_git_dir is_inside_work_tree short_hash
    git_dir=$(cat "$tmp/git_dir")
    is_bare=$(cat "$tmp/is_bare")
    is_inside_git_dir=$(cat "$tmp/is_inside_git_dir")
    is_inside_work_tree=$(cat "$tmp/is_inside_work_tree")
    short_hash=$(cat "$tmp/short_hash")

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
        head=$(cat "$tmp/symbolic_ref")
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

    # Round 2: parallel status/count calls
    local count_dirty=0 count_added=0 count_stash=0 count_untracked=0
    local count_upstream_left=0 count_upstream_right=0
    local conflict=false
    if [ "$is_inside_work_tree" = true ]; then
        _g diff --name-only --no-ext-diff                     > "$tmp/dirty"     2>/dev/null &
        _g diff --name-only --no-ext-diff --cached            > "$tmp/added"     2>/dev/null &
        _g rev-list --walk-reflogs --count refs/stash         > "$tmp/stash"     2>/dev/null &
        _g ls-files --others --exclude-standard               > "$tmp/untracked" 2>/dev/null &
        _g rev-list --count --left-right '@{upstream}...HEAD' > "$tmp/upstream"  2>/dev/null &
        _g ls-files --unmerged                                > "$tmp/unmerged"  2>/dev/null &
        wait

        count_dirty=$(wc -l < "$tmp/dirty"); count_dirty=${count_dirty//[[:space:]]/}
        count_added=$(wc -l < "$tmp/added"); count_added=${count_added//[[:space:]]/}
        count_stash=$(cat "$tmp/stash" 2>/dev/null)
        [[ -z "$count_stash" || ! "$count_stash" =~ ^[0-9]+$ ]] && count_stash=0
        count_untracked=$(wc -l < "$tmp/untracked"); count_untracked=${count_untracked//[[:space:]]/}
        local up
        up=$(cat "$tmp/upstream" 2>/dev/null)
        if [ -n "$up" ]; then
            count_upstream_left="${up%$'\t'*}"
            count_upstream_right="${up#*$'\t'}"
        fi
        [ -s "$tmp/unmerged" ] && conflict=true
    fi

    # Powerline characters (mirroring ~/.zshrc.d/promptor/functions/git config)
    local ch_branch=$'' ch_tag=$'' ch_hash=$'ⵌ'
    local ch_sep=$'│' ch_sep_prompt=$''
    local ch_up_left=$'⭣' ch_up_right=$'⭡'

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
        [ -n "$info" ] && info="${info}${ch_sep_prompt}"
        if [ "$is_bare" = true ]; then info="${info}BARE"; else info="${info}.GIT"; fi
    fi
    if [ -n "$rebase_action" ]; then
        [ -n "$info" ] && info="${info}${ch_sep_prompt}"
        info="${info}${rebase_action}"
    fi
    if [ "$conflict" = true ]; then
        [ -n "$info" ] && info="${info}${ch_sep_prompt}"
        info="${info}CONFLICT"
    fi
    if [ -n "$branch" ]; then
        [ -n "$info" ] && info="${info}${ch_sep_prompt}"
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

    printf "\033[38;5;%sm"$''"\033[48;5;%sm\033[38;5;%sm"$'\U0001F516'" %s\033[0m\033[38;5;%sm"$''"\033[0m" \
        "$bg" "$bg" "$fg" "$info" "$bg"
}

function fmt_tokens() {
    local n=$1
    [[ -z "$n" || ! "$n" =~ ^[0-9]+$ ]] && { echo "0"; return; }
    if [[ "$n" -ge 1000000 ]]; then
        printf "%d.%02dM" $((n/1000000)) $(((n%1000000)/10000))
    elif [[ "$n" -ge 1000 ]]; then
        printf "%d.%01dk" $((n/1000)) $(((n%1000)/100))
    else
        printf "%d" "$n"
    fi
}

function context() {
    local used_pct="${_ctx_pct}" tin="${_tin}" tout="${_tout}" bg=240 bg_in_out=231 fg=231 fg_in_out=232

    [[ -z "$used_pct" || "$used_pct" == "null" ]] && return

    if [[ "$used_pct" -ge 60 ]]; then
        bg="124"
    elif [[ "$used_pct" -ge 40 ]]; then
        bg="130"
    else
        bg="22"
    fi

    local out="\033[38;5;${bg}m"$''"\033[48;5;${bg}m\033[38;5;${fg}m"$'\U0001F4CA'" ${used_pct}%"

    [[ -z "$tin" || "$tin" == "null" ]] && tin=0
    [[ -z "$tout" || "$tout" == "null" ]] && tout=0

    if [[ "$tin" -gt 0 || "$tout" -gt 0 ]]; then
        local tin_fmt tout_fmt
        tin_fmt=$(fmt_tokens "$tin")
        tout_fmt=$(fmt_tokens "$tout")
        out+="\033[38;5;${bg}m\033[48;5;${bg_in_out}m"$''"\033[38;5;${fg_in_out}m"$''"${tout_fmt}"
        out+="\033[38;5;${fg_in_out}m"$''"\033[38;5;${fg_in_out}m"$''"${tin_fmt}"
        out+="\033[0m\033[38;5;${bg_in_out}m"$''"\033[0m"
    else
        out+="\033[0m\033[38;5;${bg}m"$''"\033[0m"
    fi

    echo -ne "$out"
}

function session_usage() {
    local pct="${_rate5_pct}" week="${_rate7_pct}"
    local timestamp_pct="${_rate5_reset}" timestamp_week="${_rate7_reset}"
    local fg=231 bg_pct fg_week=232 bg_week=81
    local timestamp timestamp_m timestamp_pct_full timestamp_week_full

    if [[ -z "$pct" || "$pct" == "null" ]] && [[ -z "$week" || "$week" == "null" ]]; then
        return
    fi

    [[ -z "$pct" || "$pct" == "null" ]] && pct=0
    [[ -z "$week" || "$week" == "null" ]] && week=0

    timestamp=$(date +%s)

    [[ -z "$timestamp_pct" || "$timestamp_pct" == "null" ]] && timestamp_pct="${timestamp}"
    [[ -z "$timestamp_week" || "$timestamp_week" == "null" ]] && timestamp_week="${timestamp}"

    timestamp_pct_full=$timestamp_pct
    timestamp_pct=$(( timestamp_pct - timestamp ))
    if [[ "${timestamp_pct}" -lt 60 ]]; then
        if [[ "${timestamp_pct}" -lt 0 ]]; then
            timestamp_pct=0
        fi
        timestamp_pct="${timestamp_pct}s"
    else
        timestamp_pct=$(( timestamp_pct / 60 ))
        if [[ "${timestamp_pct}" -lt 60 ]]; then
            timestamp_pct="${timestamp_pct}m"
        else
            timestamp_m=$(( timestamp_pct % 60 ))
            timestamp_pct=$(( timestamp_pct / 60 ))
            timestamp_pct="${timestamp_pct}h$(printf "%02d" "${timestamp_m}")"
        fi
        timestamp_pct="${timestamp_pct}\033[38;5;231m"$''"\033[38;5;${fg}m$(date -d "@${timestamp_pct_full}" +"%Hh%M" 2>/dev/null)"
    fi

    timestamp_week_full=$timestamp_week
    timestamp_week=$(( timestamp_week - timestamp ))
    if [[ "${timestamp_week}" -lt 60 ]]; then
        if [[ "${timestamp_week}" -lt 0 ]]; then
            timestamp_week=0
        fi
        timestamp_week="${timestamp_week}s"
    else
        timestamp_week=$(( timestamp_week / 60 ))
        if [[ "${timestamp_week}" -lt 60 ]]; then
            timestamp_week="${timestamp_week}m"
            timestamp_week+="\033[38;5;232m"$''"\033[38;5;${fg_week}m$(date -d "@${timestamp_week_full}" +"%Hh%M" 2>/dev/null)"
        else
            timestamp_m="${timestamp_week}"
            timestamp_week=$(( timestamp_week / 60 ))
            if [[ "${timestamp_week}" -lt 24 ]]; then
                timestamp_m=$(( timestamp_m % 60 ))
                timestamp_week="${timestamp_week}h$(printf "%02d" "${timestamp_m}")"
                timestamp_week+="\033[38;5;232m"$''"\033[38;5;${fg_week}m$(date -d "@${timestamp_week_full}" +"%Hh%M" 2>/dev/null)"
            else
                timestamp_week="$(( timestamp_week / 24 ))d"
                timestamp_week+="\033[38;5;232m"$''"\033[38;5;${fg_week}m$(date -d "@${timestamp_week_full}" +"%A %Hh%M" 2>/dev/null)"
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
        out="\033[38;5;${bg_pct}m"$''"\033[48;5;${bg_pct}m\033[38;5;${fg}m"$'⏳'" "
        out+="${pct}%\033[38;5;231m"$''"\033[38;5;${fg}m${timestamp_pct}"
    fi

    if [[ -n "$week" ]]; then
        week=${week%.*}
        [[ -z "$week" || ! "$week" =~ ^[0-9]+$ ]] && week=0
        if [[ -n "$pct" ]]; then
            out+="\033[38;5;${bg_pct}m\033[48;5;${bg_week}m"$''"\033[38;5;${fg_week}m"
        else
            out="\033[38;5;${bg_week}m"$''"\033[48;5;${bg_week}m\033[38;5;${fg_week}m"$'⏳'" "
        fi
        out+="${week}%\033[38;5;232m"$''"\033[38;5;${fg_week}m${timestamp_week}\033[0m\033[38;5;${bg_week}m"$''
    else
        if [[ -n "$pct" ]]; then
            out+="\033[0m\033[38;5;${bg_pct}m"$''
        fi
    fi

    echo -ne "$out\033[0m"
}

printf '%b' "$(model)"
printf '%b' "$(context)"
printf '%b' "$(session_usage)"
printf '%b' "\n"
printf '%b' "$(current_dir)"
printf '%b' "$(git_info)"
