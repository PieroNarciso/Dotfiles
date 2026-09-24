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
