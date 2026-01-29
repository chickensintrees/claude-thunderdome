#!/bin/bash
# work-loop.sh - Non-interactive runner for Claude Code work loop
# Usage: ./runner/work-loop.sh [--watch] [--once]

set -e

# Configuration
WORK_DIR="do-work"
REQUESTS_DIR="$WORK_DIR/requests"
IN_PROGRESS_DIR="$WORK_DIR/in-progress"
ARCHIVE_DIR="$WORK_DIR/archive"
ERRORS_DIR="$WORK_DIR/errors"
POLL_INTERVAL=5
LOCK_FILE="$WORK_DIR/.work-loop.lock"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
RESET='\033[0m'

# Parse arguments
WATCH_MODE=false
ONCE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --watch)
            WATCH_MODE=true
            shift
            ;;
        --once)
            ONCE_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: work-loop.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --watch    Continuous mode, poll for new requests"
            echo "  --once     Process one request then exit"
            echo "  --help     Show this help"
            echo ""
            echo "Directories:"
            echo "  do-work/requests/     Pending work"
            echo "  do-work/in-progress/  Currently executing"
            echo "  do-work/archive/      Completed"
            echo "  do-work/errors/       Failed"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Single instance check using directory move semantics
acquire_lock() {
    if ! mkdir "$LOCK_FILE" 2>/dev/null; then
        # Check if lock is stale (older than 1 hour)
        if [[ -d "$LOCK_FILE" ]]; then
            lock_age=$(($(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0)))
            if [[ $lock_age -gt 3600 ]]; then
                echo -e "${YELLOW}Removing stale lock (${lock_age}s old)${RESET}"
                rmdir "$LOCK_FILE" 2>/dev/null || true
                mkdir "$LOCK_FILE"
                return 0
            fi
        fi
        echo -e "${RED}Another work-loop is running. Exiting.${RESET}"
        exit 1
    fi
    trap release_lock EXIT
}

release_lock() {
    rmdir "$LOCK_FILE" 2>/dev/null || true
}

# Initialize directories
init_dirs() {
    mkdir -p "$REQUESTS_DIR" "$IN_PROGRESS_DIR" "$ARCHIVE_DIR" "$ERRORS_DIR"
}

# Check for requests
get_next_request() {
    ls -1 "$REQUESTS_DIR"/*.md 2>/dev/null | head -1
}

# Check for in-progress (crash recovery)
check_in_progress() {
    local in_progress=$(ls -1 "$IN_PROGRESS_DIR"/*.md 2>/dev/null | head -1)
    if [[ -n "$in_progress" ]]; then
        echo -e "${YELLOW}Found incomplete request: $(basename "$in_progress")${RESET}"
        echo -e "${YELLOW}Moving to errors (was interrupted)${RESET}"

        # Append interruption note
        echo "" >> "$in_progress"
        echo "---" >> "$in_progress"
        echo "## Execution Interrupted" >> "$in_progress"
        echo "" >> "$in_progress"
        echo "**Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$in_progress"
        echo "**Reason:** Work loop was interrupted or crashed" >> "$in_progress"

        mv "$in_progress" "$ERRORS_DIR/"
    fi
}

# Process a single request
process_request() {
    local request_file="$1"
    local filename=$(basename "$request_file")

    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}Processing:${RESET} $filename"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${RESET}"

    # Move to in-progress
    mv "$request_file" "$IN_PROGRESS_DIR/"
    local working_file="$IN_PROGRESS_DIR/$filename"

    # Extract intent for display
    local intent=$(grep -A1 "^## Intent" "$working_file" | tail -1 | head -c 80)
    echo -e "${GRAY}Intent:${RESET} $intent"
    echo ""

    # Invoke Claude Code with the request
    # The skill context:fork ensures fresh sub-agent
    echo -e "${GRAY}Spawning sub-agent...${RESET}"

    if claude --print "Process this request file and complete all tasks. Stop when 'Done When' criteria are met. Request file: $working_file" 2>&1; then
        # Success
        echo ""
        echo -e "${GREEN}Completed:${RESET} $filename"
        mv "$working_file" "$ARCHIVE_DIR/"
        return 0
    else
        # Failure
        echo ""
        echo -e "${RED}Failed:${RESET} $filename"

        # Append failure note
        echo "" >> "$working_file"
        echo "---" >> "$working_file"
        echo "## Execution Failed" >> "$working_file"
        echo "" >> "$working_file"
        echo "**Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$working_file"
        echo "**Reason:** Sub-agent returned non-zero exit code" >> "$working_file"

        mv "$working_file" "$ERRORS_DIR/"
        return 1
    fi
}

# Main loop
main() {
    echo -e "${GREEN}╔═══════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║         WORK LOOP INITIALIZED         ║${RESET}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${RESET}"
    echo ""

    acquire_lock
    init_dirs
    check_in_progress

    local processed=0
    local failed=0

    while true; do
        local next_request=$(get_next_request)

        if [[ -z "$next_request" ]]; then
            if $WATCH_MODE; then
                echo -e "${GRAY}Queue empty. Waiting for requests... (Ctrl+C to stop)${RESET}"
                sleep $POLL_INTERVAL
                continue
            else
                break
            fi
        fi

        if process_request "$next_request"; then
            ((processed++))
        else
            ((failed++))
        fi

        if $ONCE_MODE; then
            break
        fi
    done

    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}Work loop complete${RESET}"
    echo -e "  Processed: $processed"
    echo -e "  Failed: $failed"
    echo -e "  Remaining: $(ls -1 "$REQUESTS_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${RESET}"
}

main "$@"
