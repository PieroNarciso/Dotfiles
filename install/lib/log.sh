#!/usr/bin/env bash
# Logging and command execution helpers.
# Everything goes to stderr so callers can still capture stdout.

if [ -t 2 ]; then
    _C_RESET=$'\033[0m'; _C_BLUE=$'\033[1;34m'; _C_YELLOW=$'\033[1;33m'
    _C_RED=$'\033[1;31m'; _C_GREEN=$'\033[1;32m'
else
    _C_RESET=''; _C_BLUE=''; _C_YELLOW=''; _C_RED=''; _C_GREEN=''
fi

log_info()  { printf '%s==>%s %s\n' "$_C_BLUE"   "$_C_RESET" "$*" >&2; }
log_step()  { printf '%s::%s  %s\n' "$_C_GREEN"  "$_C_RESET" "$*" >&2; }
log_warn()  { printf '%swarn:%s %s\n' "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
log_error() { printf '%serror:%s %s\n' "$_C_RED"  "$_C_RESET" "$*" >&2; }

die() { log_error "$*"; exit 1; }

# run <command> [args...] — honours DRY_RUN=1 by printing the command instead.
run() {
    if [ "${DRY_RUN:-0}" = "1" ]; then
        printf 'DRY-RUN: %s\n' "$*" >&2
        return 0
    fi
    "$@"
}
