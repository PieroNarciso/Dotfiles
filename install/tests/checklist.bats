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
    cd "$TEST_TMPDIR"
}
teardown() { teardown_tmpdir; }

# Pull the block verbatim out of the checklist, then point it at the fixture
# instead of the real /mnt. If the checklist changes, these tests change with
# it -- which is the point.
extract_check() {
    sed -n '/^  pass=\$(python3/,/^  unset pass canary$/p' "$CHECKLIST" \
        | sed -e 's/^  //' -e "s#/mnt#$MNT#g"
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
    sed -n '/^  unset pass canary$/,$p' "$CHECKLIST" \
        | sed -n '/^  canary="creds-check-canary/,/^  unset canary found$/p' \
        | sed -e 's/^  //' -e "s#/mnt#$MNT#g"
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
