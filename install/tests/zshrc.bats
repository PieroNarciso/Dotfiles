#!/usr/bin/env bats

# The shipped home/.zshrc is a stow-linked config, not sourced by any other
# test, so a typo in it (e.g. the `cp -i` safety alias) went uncaught. This
# sources it in a throwaway HOME under a real zsh and checks the alias.

load test_helper

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "home/.zshrc defines the interactive cp safety alias" {
    command -v zsh >/dev/null 2>&1 || skip "needs zsh"
    run env HOME="$TEST_TMPDIR" zsh -c "source '$INSTALL_DIR/../home/.zshrc'; alias cp"
    [ "$status" -eq 0 ]
    [[ "$output" == *"cp='cp -i'"* ]]
}
