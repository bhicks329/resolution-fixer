#!/usr/bin/env bash
# resolution-fixer.sh
# Monitors for incoming Screen Sharing connections and automatically sets
# the display to maximum HiDPI (Dynamic) resolution, then restores on disconnect.

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
LABEL="resolution-fixer"
LOG_FILE="$HOME/Library/Logs/${LABEL}.log"
CHECK_INTERVAL=2            # seconds between connection polls
CONNECT_DELAY=5             # seconds to wait after detection before changing resolution
RESTORE_ON_DISCONNECT=true  # set false to keep the new resolution after disconnect

# ── Logging ─────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# ── Find displayplacer ───────────────────────────────────────────────────────
find_displayplacer() {
    local candidates=(
        "/opt/homebrew/bin/displayplacer"   # Apple Silicon Homebrew
        "/usr/local/bin/displayplacer"      # Intel Homebrew
        "$(command -v displayplacer 2>/dev/null || true)"
    )
    for p in "${candidates[@]}"; do
        [[ -x "$p" ]] && { echo "$p"; return; }
    done
    log "ERROR: displayplacer not found. Run install.sh first."
    exit 1
}

DISPLAYPLACER=$(find_displayplacer)

# Compiled helper lives next to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DYNAMIC_RES_BIN="$SCRIPT_DIR/set-dynamic-resolution"

# ── Display helpers ──────────────────────────────────────────────────────────

# Returns the persistent display ID of the first active display.
get_display_id() {
    "$DISPLAYPLACER" list 2>/dev/null \
        | grep "^Persistent screen id:" \
        | head -1 \
        | awk '{print $4}'
}

# Returns the full displayplacer command string for the current arrangement,
# which is the last "displayplacer ..." line that the tool prints.
get_current_config() {
    "$DISPLAYPLACER" list 2>/dev/null \
        | grep '^displayplacer ' \
        | sed 's/^displayplacer //'
}

# Parses all mode lines for a given display ID from `displayplacer list` output
# and sets the display to the highest-resolution HiDPI (scaling:on) mode.
# Falls back to the highest non-HiDPI mode if none have scaling:on.
set_max_resolution() {
    local id="$1"
    local raw
    raw=$("$DISPLAYPLACER" list 2>/dev/null)

    local in_block=false
    local best_w=0 best_h=0
    local best_hz="" best_depth="" best_scaling="scaling:off"

    while IFS= read -r line; do
        # Detect start of this display's block
        if [[ "$line" == "Persistent screen id: ${id}" ]]; then
            in_block=true
            continue
        fi
        # Detect start of a different display's block — stop
        if [[ "$in_block" == true && "$line" == "Persistent screen id:"* ]]; then
            break
        fi
        if [[ "$in_block" == false ]]; then
            continue
        fi

        # Match mode lines:  "  mode N: res:WxH hz:HZ color_depth:D [scaling:on]"
        if [[ "$line" =~ res:([0-9]+)x([0-9]+)[[:space:]]hz:([0-9]+)[[:space:]]color_depth:([0-9]+) ]]; then
            local w="${BASH_REMATCH[1]}"
            local h="${BASH_REMATCH[2]}"
            local hz="${BASH_REMATCH[3]}"
            local depth="${BASH_REMATCH[4]}"
            local scaling="scaling:off"
            [[ "$line" == *"scaling:on"* ]] && scaling="scaling:on"

            # Pick highest resolution; prefer scaling:on as a tiebreaker at equal size
            if (( w > best_w || (w == best_w && h > best_h) )) \
               || { (( w == best_w && h == best_h )) && [[ "$scaling" == "scaling:on" ]]; }; then
                best_w=$w; best_h=$h; best_hz=$hz; best_depth=$depth; best_scaling=$scaling
            fi
        fi
    done <<< "$raw"

    if (( best_w == 0 )); then
        log "ERROR: Could not parse any display modes for $id"
        return 1
    fi

    local res_w=$best_w res_h=$best_h res_hz=$best_hz res_depth=$best_depth native_scaling=$best_scaling
    log "Best mode found: ${res_w}x${res_h} hz:${res_hz} ${native_scaling}"

    # Preserve the current origin and rotation from the existing config line
    local origin degree
    origin=$(echo "$raw" | grep '^displayplacer ' | grep -Eo 'origin:\(-?[0-9]+,-?[0-9]+\)' | head -1)
    degree=$(echo "$raw"  | grep '^displayplacer ' | grep -Eo 'degree:[0-9]+'                 | head -1)
    [[ "$origin" =~ ^origin:\(-?[0-9]+,-?[0-9]+\)$ ]] || origin="origin:(0,0)"
    [[ "$degree" =~ ^degree:[0-9]+$                 ]] || degree="degree:0"

    # Always try with scaling:on first (Dynamic resolution); fall back to the
    # mode's native scaling if displayplacer rejects the combination.
    local mode_str="id:${id} res:${res_w}x${res_h} hz:${res_hz} color_depth:${res_depth} enabled:true scaling:on ${origin} ${degree}"
    log "Applying (scaling:on): $mode_str"
    if ! "$DISPLAYPLACER" "$mode_str" 2>/dev/null; then
        log "scaling:on rejected for this mode — retrying with native ${native_scaling}"
        mode_str="id:${id} res:${res_w}x${res_h} hz:${res_hz} color_depth:${res_depth} enabled:true ${native_scaling} ${origin} ${degree}"
        log "Applying (${native_scaling}): $mode_str"
        "$DISPLAYPLACER" "$mode_str"
    fi

    # Enable Dynamic Resolution via the SkyLight private API —
    # the same toggle as "Dynamic resolution" in System Settings > Displays.
    if [[ -x "$DYNAMIC_RES_BIN" ]]; then
        log "Enabling dynamic resolution."
        "$DYNAMIC_RES_BIN" >> "$LOG_FILE" 2>&1 \
            || log "WARNING: set-dynamic-resolution failed (display may not support it)"
    else
        log "WARNING: set-dynamic-resolution binary not found — run install.sh to compile it"
    fi
}

# ── Connection detection ─────────────────────────────────────────────────────

is_screen_sharing_active() {
    # ESTABLISHED connection on port 5900 (macOS Screen Sharing / VNC)
    netstat -an 2>/dev/null \
        | grep -E '\.(5900)\s' \
        | grep -q 'ESTABLISHED'
}

# ── Main loop ────────────────────────────────────────────────────────────────
main() {
    mkdir -p "$(dirname "$LOG_FILE")"
    STATE_FILE=$(mktemp -t "${LABEL}.state.XXXXXXXX")
    trap 'rm -f "$STATE_FILE"' EXIT
    log "=== ${LABEL} started (PID $$, displayplacer: $DISPLAYPLACER) ==="
    log "State file: $STATE_FILE"

    local display_id
    display_id=$(get_display_id)

    if [[ -z "$display_id" ]]; then
        log "ERROR: No display detected. Exiting."
        exit 1
    fi
    log "Monitoring display: $display_id"

    local was_sharing=false
    local -a original_config=()

    while true; do
        if is_screen_sharing_active; then
            if [[ "$was_sharing" == false ]]; then
                log "Screen Sharing session detected — waiting ${CONNECT_DELAY}s for display to settle."
                original_config=()
                while IFS= read -r _arg; do
                    [[ -n "$_arg" ]] && original_config+=("$_arg")
                done < <(get_current_config | xargs -n1 printf '%s\n' 2>/dev/null || true)
                was_sharing=true
                echo "active" > "$STATE_FILE"
                sleep "$CONNECT_DELAY"
                log "Applying max resolution."
                set_max_resolution "$display_id" || log "WARNING: Failed to set max resolution."
            fi
        else
            if [[ "$was_sharing" == true ]]; then
                log "Screen Sharing session ended."
                was_sharing=false
                echo "idle" > "$STATE_FILE"

                if [[ "$RESTORE_ON_DISCONNECT" == true && "${#original_config[@]}" -gt 0 ]]; then
                    log "Restoring original resolution."
                    "$DISPLAYPLACER" "${original_config[@]}" \
                        || log "WARNING: Failed to restore original resolution."
                    original_config=()
                fi
            fi
        fi

        sleep "$CHECK_INTERVAL"
    done
}

main "$@"
