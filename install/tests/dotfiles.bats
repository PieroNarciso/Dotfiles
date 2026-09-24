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

@test "df_backup_conflicts moves a foreign symlink so stow can then succeed" {
    echo "not from repo" > "$TEST_TMPDIR/elsewhere"
    ln -s "$TEST_TMPDIR/elsewhere" "$FAKE_HOME/.zshrc"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ "$status" -eq 0 ]
    [ ! -e "$FAKE_HOME/.zshrc" ] && [ ! -L "$FAKE_HOME/.zshrc" ]
    [ -L "$TEST_TMPDIR/backup/.zshrc" ]
    [ "$(readlink "$TEST_TMPDIR/backup/.zshrc")" = "$TEST_TMPDIR/elsewhere" ]
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_stow_repo '$REPO' '$FAKE_HOME'"
    [ "$status" -eq 0 ]
    [ -L "$FAKE_HOME/.zshrc" ]
    [ "$(cat "$FAKE_HOME/.zshrc")" = "from repo" ]
}

@test "df_backup_conflicts moves a broken symlink rather than leaving it behind" {
    ln -s "$TEST_TMPDIR/does-not-exist" "$FAKE_HOME/.zshrc"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ "$status" -eq 0 ]
    [ ! -e "$FAKE_HOME/.zshrc" ] && [ ! -L "$FAKE_HOME/.zshrc" ]
    [ -L "$TEST_TMPDIR/backup/.zshrc" ]
    [ "$(readlink "$TEST_TMPDIR/backup/.zshrc")" = "$TEST_TMPDIR/does-not-exist" ]
}

@test "df_backup_conflicts still leaves a symlink pointing into the repo alone" {
    ln -s "$REPO/home/.zshrc" "$FAKE_HOME/.zshrc"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ "$status" -eq 0 ]
    [ -L "$FAKE_HOME/.zshrc" ]
    [ "$(readlink "$FAKE_HOME/.zshrc")" = "$REPO/home/.zshrc" ]
    [ ! -e "$TEST_TMPDIR/backup/.zshrc" ] && [ ! -L "$TEST_TMPDIR/backup/.zshrc" ]
}

@test "df_backup_conflicts gives a repeated backup of the same path a numeric suffix" {
    echo "first" > "$FAKE_HOME/.zshrc"
    bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    echo "second" > "$FAKE_HOME/.zshrc"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_TMPDIR/backup/.zshrc")" = "first" ]
    [ "$(cat "$TEST_TMPDIR/backup/.zshrc.1")" = "second" ]
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

@test "df_backup_conflicts backs up a conflict whose repo-side source is itself a symlink" {
    # A symlink tracked inside the stow package (e.g. a dotfile that is itself
    # a symlink in git) must still be walked as a source, not skipped by a
    # find that only matches -type f.
    ln -s "$REPO/home/.zshrc" "$REPO/config/.config/linked-in-repo"
    mkdir -p "$FAKE_HOME/.config"
    echo "pre-existing, not ours" > "$FAKE_HOME/.config/linked-in-repo"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ "$status" -eq 0 ]
    [ ! -e "$FAKE_HOME/.config/linked-in-repo" ]
    [ "$(cat "$TEST_TMPDIR/backup/.config/linked-in-repo")" = "pre-existing, not ours" ]
}

@test "_df_packages ignores top-level directories with no dotfile in them" {
    mkdir -p "$REPO/docs/superpowers" "$REPO/install/lib"
    echo "not a dotfile" > "$REPO/docs/superpowers/plan.md"
    echo "not a dotfile" > "$REPO/install/lib/log.sh"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        _df_packages '$REPO'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"config"* ]]
    [[ "$output" == *"home"* ]]
    [[ "$output" != *"docs"* ]]
    [[ "$output" != *"install"* ]]
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

@test "a second repo can stow into .config after the first one claimed it" {
    # The VM run died here. Stow folds a whole directory into one symlink when
    # the target does not exist yet, so on a fresh machine the first repo turns
    # ~/.config into a link to its own tree. The second repo then finds .config
    # owned by a different stow dir and aborts the run -- taking the shell,
    # services and report phases with it. A developer's own machine never sees
    # it: ~/.config is already a real directory there, so stow descends instead
    # of folding.
    # Mirror the real split: only the nvim repo ships .config/nvim, so the one
    # thing the two repos share is the .config directory itself.
    rm -rf "$REPO/config/.config/nvim"
    mkdir -p "$REPO/config/.config/hypr"
    echo "repo hypr" > "$REPO/config/.config/hypr/hyprland.lua"
    local NVIM="$TEST_TMPDIR/nvim-repo"
    mkdir -p "$NVIM/nvim-config/.config/nvim"
    echo "nvim repo" > "$NVIM/nvim-config/.config/nvim/init.lua"

    bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_stow_repo '$REPO' '$FAKE_HOME'"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_stow_repo '$NVIM' '$FAKE_HOME'"

    [ "$status" -eq 0 ]
    [[ "$output" != *"not owned by stow"* ]]
    # Both repos reachable through a real .config, not a folded symlink.
    [ ! -L "$FAKE_HOME/.config" ]
    [ -d "$FAKE_HOME/.config" ]
    [ "$(cat "$FAKE_HOME/.config/nvim/init.lua")" = "nvim repo" ]
    # The first repo's own .config content survives the second repo's stow.
    [ "$(cat "$FAKE_HOME/.config/hypr/hyprland.lua")" = "repo hypr" ]
    [ "$(cat "$FAKE_HOME/.zshrc")" = "from repo" ]
}

@test "DF_BACKED_UP stays 0 when the backup dir exists but nothing was moved" {
    # phase_microcode backs loader entries into the same directory and runs
    # first, so on a fresh laptop $BACKUP_DIR exists before phase_dotfiles
    # ever looks at it. A caller testing `[ -d "$BACKUP_DIR" ]` then tells the
    # operator their dotfiles were moved aside when none were, and the
    # checklist sends them digging through it.
    mkdir -p "$TEST_TMPDIR/backup/loader-entries"
    echo "an entry" > "$TEST_TMPDIR/backup/loader-entries/arch.conf"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'; \
        echo \"COUNT=\$DF_BACKED_UP\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"COUNT=0"* ]]
}

@test "DF_BACKED_UP counts every file actually moved aside" {
    echo "pre-existing" > "$FAKE_HOME/.zshrc"
    mkdir -p "$FAKE_HOME/.config/nvim"
    echo "old nvim" > "$FAKE_HOME/.config/nvim/init.lua"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'; \
        echo \"COUNT=\$DF_BACKED_UP\""
    [[ "$output" == *"COUNT=2"* ]]
}

@test "an absolute symlink in a package does not abort the whole run" {
    # mason and packer write absolute symlinks into .local/share/nvim
    # (-> /home/piero/...). Those are gitignored, so a fresh clone never has
    # them -- the VM run that "found" this was fed a copy of the working tree
    # -- but a working tree that does (this desktop, re-running bootstrap)
    # makes stow refuse with "All operations aborted", and the unguarded
    # `run stow` took the entire bootstrap down under set -e.
    mkdir -p "$REPO/bad/.config/bad"
    ln -s /etc/hostname "$REPO/bad/.config/bad/absolute-link"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_stow_repo '$REPO' '$FAKE_HOME'; echo RETURNED=\$?"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RETURNED=0"* ]]
}

@test "the local package does not stow generated nvim state" {
    # .local/share/nvim is mason/packer output, not configuration, and it is
    # where every absolute symlink in this working tree lives (untracked).
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    [ -f "$REPO_ROOT/local/.stow-local-ignore" ]
    grep -q 'share/nvim' "$REPO_ROOT/local/.stow-local-ignore"
    # And no absolute symlink outside that ignored subtree, which the ignore
    # file would not protect against.
    local stray
    stray="$(find "$REPO_ROOT" -type l -not -path '*/.git/*' \
        -not -path "$REPO_ROOT/local/.local/share/nvim/*" \
        -exec sh -c 'case "$(readlink "$1")" in /*) echo "$1";; esac' _ {} \; )"
    [ -z "$stray" ] || { echo "absolute symlinks outside the ignored subtree:"; echo "$stray"; false; }
}

@test "df_backup_conflicts leaves a repo file reached through a folded directory alone" {
    # Stow without --no-folding (the README's command, and this desktop's
    # state) links ~/.config/nvim as a whole directory. The leaf is then a
    # regular file inside the repo, and moving it empties the repo.
    mkdir -p "$FAKE_HOME/.config"
    ln -s ../../repo/config/.config/nvim "$FAKE_HOME/.config/nvim"  # relative, as stow makes it
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'; echo moved=\$DF_BACKED_UP"
    [ "$status" -eq 0 ]
    [[ "$output" == *"moved=0"* ]]
    [ "$(cat "$REPO/config/.config/nvim/init.lua")" = "repo nvim" ]
    [ ! -e "$TEST_TMPDIR/backup/.config/nvim/init.lua" ]
}

@test "a folded directory is unfolded by the stow that follows the backup" {
    mkdir -p "$FAKE_HOME/.config"
    ln -s ../../repo/config/.config/nvim "$FAKE_HOME/.config/nvim"  # relative, as stow makes it
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup' && \
        df_stow_repo '$REPO' '$FAKE_HOME'"
    [ "$status" -eq 0 ]
    [ ! -L "$FAKE_HOME/.config/nvim" ]
    [ -L "$FAKE_HOME/.config/nvim/init.lua" ]
    [ "$(cat "$FAKE_HOME/.config/nvim/init.lua")" = "repo nvim" ]
}

@test "a symlink into a sibling of the repo is not mistaken for the repo" {
    # "$repo"* also matched ~/.dotfiles-backup-*, so a link into an old
    # backup was treated as ours and left for stow to trip over.
    mkdir -p "$REPO-backup"
    echo "old" > "$REPO-backup/.zshrc"
    ln -s "$REPO-backup/.zshrc" "$FAKE_HOME/.zshrc"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'"
    [ "$status" -eq 0 ]
    [ ! -L "$FAKE_HOME/.zshrc" ]
    [ -L "$TEST_TMPDIR/backup/.zshrc" ]
}

@test "df_clone_or_pull warns and returns non-zero instead of ending the run" {
    git -C "$TEST_TMPDIR" init -q noupstream
    run bash -c "set -euo pipefail; source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        f() { df_clone_or_pull 'unused' '$TEST_TMPDIR/noupstream' || echo returned=\$?; echo reached; }; f"
    [ "$status" -eq 0 ]
    [[ "$output" == *"could not update"* ]]
    [[ "$output" == *"returned=1"* ]]
    [[ "$output" == *"reached"* ]]
}

@test "a failed clone warns, links nothing for that repo, and the run goes on" {
    run bash -c "set -euo pipefail; source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_clone_or_pull '$TEST_TMPDIR/does-not-exist' '$TEST_TMPDIR/clone' || echo returned=\$?; echo reached"
    [ "$status" -eq 0 ]
    [[ "$output" == *"could not clone"* ]]
    [[ "$output" == *"returned=1"* ]]
    [ ! -e "$TEST_TMPDIR/clone" ]
}

@test "a broken symlink the repo carries, reached through a folded directory, stays in the repo" {
    # readlink -f says nothing useful about a dangling link, so the "resolves
    # into the repo" test missed it and the repo's own link was moved out.
    ln -s /nonexistent/on-this-machine/target "$REPO/config/.config/nvim/dangling"
    mkdir -p "$FAKE_HOME/.config"
    ln -s ../../repo/config/.config/nvim "$FAKE_HOME/.config/nvim"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'; echo moved=\$DF_BACKED_UP"
    [ "$status" -eq 0 ]
    [[ "$output" == *"moved=0"* ]]
    [ -L "$REPO/config/.config/nvim/dangling" ]
}

@test "a path the package's .stow-local-ignore excludes is never moved aside" {
    # stow will never link it, so it is not a conflict; moving it only takes
    # the user's own data (here: nvim's generated state) out of the way.
    mkdir -p "$REPO/local/.local/share/nvim" "$REPO/local/.local/bin"
    printf '%s\n' '^/\.local/share/nvim$' > "$REPO/local/.stow-local-ignore"
    echo repo-state > "$REPO/local/.local/share/nvim/shada"
    echo repo-bin > "$REPO/local/.local/bin/tool"
    mkdir -p "$FAKE_HOME/.local/share/nvim" "$FAKE_HOME/.local/bin"
    echo mine > "$FAKE_HOME/.local/share/nvim/shada"
    echo old-tool > "$FAKE_HOME/.local/bin/tool"
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_backup_conflicts '$REPO' '$FAKE_HOME' '$TEST_TMPDIR/backup'; echo moved=\$DF_BACKED_UP"
    [ "$status" -eq 0 ]
    [ "$(cat "$FAKE_HOME/.local/share/nvim/shada")" = "mine" ]
    [ ! -e "$FAKE_HOME/.local/bin/tool" ]
    [ "$(cat "$TEST_TMPDIR/backup/.local/bin/tool")" = "old-tool" ]
    [[ "$output" == *"moved=1"* ]]
    # And stow itself is then happy with what is left.
    run bash -c "source '$INSTALL_DIR/lib/log.sh'; source '$INSTALL_DIR/lib/dotfiles.sh'; \
        df_stow_repo '$REPO' '$FAKE_HOME'"
    [ "$status" -eq 0 ]
    [ -L "$FAKE_HOME/.local/bin/tool" ]
}
