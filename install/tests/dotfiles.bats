#!/usr/bin/env bats

load test_helper

setup() {
    setup_tmpdir
    FAKE_HOME="$TEST_TMPDIR/home"; mkdir -p "$FAKE_HOME"
    REPO="$TEST_TMPDIR/repo"
    mkdir -p "$REPO/home" "$REPO/config/.config/nvim"
    echo "from repo" > "$REPO/home/.zshrc"
    echo "repo nvim" > "$REPO/config/.config/nvim/init.lua"
}
teardown() { teardown_tmpdir; }

@test "df_backup_conflicts moves a colliding real file into the backup dir" {
    echo "pre-existing" > "$FAKE_HOME/.zshrc"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ "$status" -eq 0 ]
    [ ! -e "$FAKE_HOME/.zshrc" ]
    [ "$(cat "$TEST_TMPDIR/backup/.zshrc")" = "pre-existing" ]
}

@test "df_backup_conflicts preserves nested relative paths" {
    mkdir -p "$FAKE_HOME/.config/nvim"
    echo "old nvim" > "$FAKE_HOME/.config/nvim/init.lua"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ "$(cat "$TEST_TMPDIR/backup/.config/nvim/init.lua")" = "old nvim" ]
}

@test "df_backup_conflicts leaves symlinks that already point into the repo" {
    ln -s "$REPO/home/.zshrc" "$FAKE_HOME/.zshrc"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ -L "$FAKE_HOME/.zshrc" ]
    [ ! -e "$TEST_TMPDIR/backup/.zshrc" ]
}

@test "df_backup_conflicts never deletes anything" {
    echo "precious" > "$FAKE_HOME/.zshrc"
    bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ "$(cat "$TEST_TMPDIR/backup/.zshrc")" = "precious" ]
}

@test "df_stow_repo links every package into the target home" {
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_stow_repo '$REPO' '$FAKE_HOME'"
    [ "$status" -eq 0 ]
    [ -L "$FAKE_HOME/.zshrc" ]
    [ "$(cat "$FAKE_HOME/.zshrc")" = "from repo" ]
    [ "$(cat "$FAKE_HOME/.config/nvim/init.lua")" = "repo nvim" ]
}

@test "df_stow_repo is idempotent" {
    bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; df_stow_repo '$REPO' '$FAKE_HOME'"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; df_stow_repo '$REPO' '$FAKE_HOME'"
    [ "$status" -eq 0 ]
    [ -L "$FAKE_HOME/.zshrc" ]
}

@test "df_clone_or_pull clones when the destination is absent" {
    src="$TEST_TMPDIR/src"; mkdir -p "$src"
    git -C "$src" init -q; echo hi > "$src/f"; git -C "$src" add f
    git -C "$src" -c user.email=t@t -c user.name=t commit -qm init
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_clone_or_pull '$src' '$TEST_TMPDIR/clone'"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMPDIR/clone/f" ]
}

@test "df_clone_or_pull pulls when the destination already exists" {
    src="$TEST_TMPDIR/src"; mkdir -p "$src"
    git -C "$src" init -q; echo hi > "$src/f"; git -C "$src" add f
    git -C "$src" -c user.email=t@t -c user.name=t commit -qm init
    git clone -q "$src" "$TEST_TMPDIR/clone"
    echo more > "$src/g"; git -C "$src" add g
    git -C "$src" -c user.email=t@t -c user.name=t commit -qm second
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_clone_or_pull '$src' '$TEST_TMPDIR/clone'"
    [ "$status" -eq 0 ]
    [ -f "$TEST_TMPDIR/clone/g" ]
}
