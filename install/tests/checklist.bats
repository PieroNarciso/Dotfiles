#!/usr/bin/env bats
# The Step 5 credential check is the one command in this repo whose failure is
# silent by construction: every way it can break looks exactly like "clean".
# It is prose, not code, so nothing else in the suite runs it -- these tests
# extract the real block out of the markdown and exercise every branch.

load test_helper

setup() {
    setup_tmpdir
    CHECKLIST="$INSTALL_DIR/LAPTOP-CHECKLIST.md"
    MNT="$TEST_TMPDIR/mnt"
    mkdir -p "$MNT/root" "$MNT/var/log/archinstall"
    # These tests execute text pulled out of a document. Sandbox $HOME so a
    # runaway extraction cannot reach the real one.
    export HOME="$TEST_TMPDIR/home"; mkdir -p "$HOME"
    cd "$TEST_TMPDIR"
}
teardown() { teardown_tmpdir; }

# Pull a block verbatim out of the checklist, then point it at the fixture
# instead of the real /mnt. If the checklist changes, these tests change with
# it -- which is the point.
#
# The validation is not optional. `sed -n '/a/,/b/p'` runs to END OF FILE
# whenever its end anchor stops matching, and these tests pipe the result
# into `bash -c`. The rest of this checklist contains `sudo reboot` and a
# real `~/.dotfiles/install/bootstrap.sh` invocation -- so a one-word edit to
# the document could turn the test suite into something that stows dotfiles
# over the developer's home directory and reboots the machine. Refuse to
# return anything unless the block ended where it was supposed to.
_extract_block() { # <start-regex> <end-regex> <max-lines>
    local out
    out="$(sed -n "/$1/,/$2/p" "$CHECKLIST")"
    [ -n "$out" ] || { echo "EXTRACTION FAILED: start anchor never matched" >&2; return 1; }
    printf '%s\n' "$out" | tail -n1 | grep -qE "$2" || {
        echo "EXTRACTION FAILED: end anchor never matched; sed ran to EOF" >&2
        return 1
    }
    [ "$(printf '%s\n' "$out" | wc -l)" -le "$3" ] || {
        echo "EXTRACTION FAILED: block longer than $3 lines" >&2
        return 1
    }
    printf '%s\n' "$out" | sed -e 's/^  //' -e "s#/mnt#$MNT#g"
}

extract_check() {
    _extract_block '^  pass=\$(python3' '^  unset pass canary$' 40
}

@test "the extraction finds the check at all" {
    run extract_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"encryption_password"* ]]
    [[ "$output" == *"canary"* ]]
}

@test "clean: the passphrase is nowhere under /mnt" {
    echo '{"encryption_password": "correct-horse-battery"}' > creds.json
    echo 'INFO - Setting password for piero' > "$MNT/var/log/archinstall/install.log"
    run bash -c "$(extract_check)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean: passphrase not found"* ]]
    # The canary must not be left behind on the installed system.
    [ ! -e "$MNT/root/.creds-check-canary" ]
}

@test "LEAK: the passphrase really is on the installed disk" {
    echo '{"encryption_password": "correct-horse-battery"}' > creds.json
    echo 'luks pass = correct-horse-battery' > "$MNT/var/log/archinstall/install.log"
    run bash -c "$(extract_check)"
    [[ "$output" == *"LEAK:"* ]]
    [[ "$output" != *"clean:"* ]]
}

@test "STOP: an unreadable creds.json is not reported as clean" {
    # Wrong directory, missing key, malformed JSON -- the empty-pattern case.
    # GNU grep with an empty pattern file matches nothing and exits 1, which
    # is byte-identical to a clean result.
    echo '{"no_such_key": "x"}' > creds.json
    run bash -c "$(extract_check)"
    [[ "$output" == *"STOP:"* ]]
    [[ "$output" != *"clean:"* ]]
    [[ "$output" != *"LEAK:"* ]]
}

@test "STOP: an unmounted or wrong /mnt is not reported as clean" {
    # The empty-haystack case: the search runs, finds nothing, and means
    # nothing. Without the canary this prints "clean" and the operator
    # reboots believing a check happened.
    echo '{"encryption_password": "correct-horse-battery"}' > creds.json
    rm -rf "$MNT"
    run bash -c "$(extract_check)"
    [[ "$output" == *"STOP:"* ]]
    [[ "$output" == *"canary"* ]]
    [[ "$output" != *"clean:"* ]]
}

@test "the check never puts the passphrase in a process's argv" {
    # `ps` on a multi-user machine would show it. The value has to reach grep
    # through a pipe from a shell builtin, never as an argument.
    run extract_check
    [[ "$output" == *'printf '*'"$pass"'*'| grep'* ]]
    [[ "$output" != *'grep -rlF "$pass"'* ]]
    [[ "$output" != *"grep -r '\$pass'"* ]]
}

# The SECOND search in Step 5 — for a stray creds.json / install-config.json
# on the installed disk — had none of the first one's guards: its stated
# "Expected: nothing" is exactly what an unmounted /mnt produces.
extract_find_check() {
    local out
    out="$(sed -n '/^  unset pass canary$/,$p' "$CHECKLIST" \
        | sed -n '/^  canary="creds-check-canary/,/^  unset canary found$/p')"
    [ -n "$out" ] || { echo "EXTRACTION FAILED: start anchor never matched" >&2; return 1; }
    printf '%s\n' "$out" | tail -n1 | grep -q '^  unset canary found$' || {
        echo "EXTRACTION FAILED: end anchor never matched; sed ran to EOF" >&2
        return 1
    }
    [ "$(printf '%s\n' "$out" | wc -l)" -le 40 ] || {
        echo "EXTRACTION FAILED: block longer than 40 lines" >&2
        return 1
    }
    printf '%s\n' "$out" | sed -e 's/^  //' -e "s#/mnt#$MNT#g"
}

@test "the second search is extracted and is not the first one" {
    run extract_find_check
    [ "$status" -eq 0 ]
    [[ "$output" == *"install-config.json"* ]]
    [[ "$output" != *"encryption_password"* ]]
}

@test "second search, clean: no config or credential file on the disk" {
    run bash -c "$(extract_find_check)"
    [ "$status" -eq 0 ]
    [[ "$output" == *"clean: no config or credential file"* ]]
    [ ! -e "$MNT/root/.creds-check-canary" ]
}

@test "second search, LEAK: a stray creds.json on the installed disk" {
    echo '{"encryption_password":"x"}' > "$MNT/root/creds.json"
    run bash -c "$(extract_find_check)"
    [[ "$output" == *"LEAK:"* ]]
    [[ "$output" == *"creds.json"* ]]
    [[ "$output" != *"clean:"* ]]
}

@test "second search, STOP: an unmounted /mnt is not reported as clean" {
    rm -rf "$MNT"
    run bash -c "$(extract_find_check)"
    [[ "$output" == *"STOP:"* ]]
    [[ "$output" != *"clean:"* ]]
}

@test "no checklist command reads the ESP without sudo" {
    # archinstall mounts the ESP dmask=0077, so /boot is mode 700 and
    # root-owned on every machine this toolkit installs. The developer's
    # desktop is dmask=0022 and reads it fine as the user -- which has now
    # masked this same defect twice: once in lib/boot.sh (D4), and once in
    # the very step added to catch an unbootable machine. This test is the
    # structural guard, not another round of remembering.
    local offenders
    offenders="$(grep -nE '^[[:space:]]+(cat|ls|grep|find|head|tail|stat|file|cp|bootctl)[^|#]*[[:space:]]/boot(/|[[:space:]]|$)' "$CHECKLIST" \
        | grep -vE '(sudo|^\s*[0-9]+:[[:space:]]*#)' || true)"
    if [ -n "$offenders" ]; then
        echo "unprivileged ESP reads in the checklist:"
        echo "$offenders"
    fi
    [ -z "$offenders" ]
}

@test "a runaway extraction is refused instead of executed" {
    # The whole reason the extractors validate: with the end anchor gone, sed
    # returns the remaining ~270 lines of the checklist, and these tests feed
    # their output straight to `bash -c`. That text contains `sudo reboot`.
    run _extract_block '^  pass=\$(python3' '^  unset pass canary-NO-SUCH-ANCHOR$' 40
    [ "$status" -ne 0 ]
    [[ "$output" == *"EXTRACTION FAILED"* ]]
    [[ "$output" != *"reboot"* ]]
    [[ "$output" != *"bootstrap.sh"* ]]
}

@test "the extracted block never contains a destructive command" {
    # Belt and braces: whatever the anchors do, what we execute must be the
    # credential check and nothing else.
    run extract_check
    [ "$status" -eq 0 ]
    [[ "$output" != *"reboot"* ]]
    [[ "$output" != *"bootstrap.sh"* ]]
    [[ "$output" != *"cryptsetup"* ]]
    [[ "$output" != *"archinstall"* ]]
    run extract_find_check
    [ "$status" -eq 0 ]
    [[ "$output" != *"reboot"* ]]
    [[ "$output" != *"bootstrap.sh"* ]]
}
