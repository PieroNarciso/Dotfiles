#!/usr/bin/env bash
# Cloning and stowing the dotfile repos. Requires lib/log.sh.

df_clone_or_pull() {
    local url="$1" dest="$2"
    if [ -d "$dest/.git" ]; then
        log_info "updating $dest"
        run git -C "$dest" pull --ff-only
    else
        log_step "cloning $url into $dest"
        run git clone "$url" "$dest"
    fi
}

# Every top-level directory holding at least one dotfile is a stow package.
# A directory with no dot-entry is repo tooling (install/, docs/) and must
# never be stowed into $HOME.
_df_packages() {
    local repo="$1" d
    for d in "$repo"/*/; do
        d="${d%/}"
        [ -d "$d" ] || continue
        compgen -G "$d/.*" > /dev/null || continue
        basename "$d"
    done | sort
}

# How many paths were actually moved aside. The backup directory is shared
# with the loader-entry backup in phase_microcode, so its existence proves
# nothing about dotfiles -- a caller that tests `[ -d "$BACKUP_DIR" ]` sends
# the reader looking for files that were never moved.
DF_BACKED_UP=0

# Move aside anything stow would refuse to overwrite.
df_backup_conflicts() {
    local repo="$1" target="$2" backup="$3"
    local pkg src rel dst
    for pkg in $(_df_packages "$repo"); do
        while IFS= read -r src; do
            rel="${src#"$repo/$pkg/"}"
            dst="$target/$rel"
            # A symlink already pointing into the repo is our own work; leave it.
            if [ -L "$dst" ] && [[ "$(readlink -f "$dst")" == "$repo"* ]]; then
                continue
            fi
            # Anything else that exists must move, INCLUDING a symlink that
            # points somewhere else: stow refuses to adopt a target it does
            # not own and aborts the whole package, which under set -e kills
            # the bootstrap at the dotfiles phase. -e is false for a broken
            # symlink, so test -L as well or those get left behind too.
            [ -e "$dst" ] || [ -L "$dst" ] || continue
            # Never clobber an earlier backup of the same relative path.
            local dest="$backup/$rel"
            local i=1
            while [ -e "$dest" ] || [ -L "$dest" ]; do
                dest="$backup/$rel.$i"
                i=$((i + 1))
            done
            log_warn "backing up existing $dst"
            run mkdir -p "$(dirname "$dest")"
            run mv "$dst" "$dest"
            DF_BACKED_UP=$((DF_BACKED_UP + 1))
        done < <(find "$repo/$pkg" \( -type f -o -type l \))
    done
}

df_stow_repo() {
    local repo="$1" target="$2"
    local -a pkgs
    mapfile -t pkgs < <(_df_packages "$repo")
    [ "${#pkgs[@]}" -gt 0 ] || { log_warn "no stow packages in $repo"; return 0; }
    log_step "stowing ${#pkgs[@]} package(s) from $repo"
    # --no-folding: without it stow replaces a whole directory with one symlink
    # when the target does not exist yet, so on a fresh machine the first repo
    # turns ~/.config into a link into its own tree and the second repo aborts
    # with "existing target is not owned by stow". Real directories with
    # symlinked leaves let both repos share ~/.config.
    # Guarded for the same reason chsh and the service enables are: stow
    # aborts the entire invocation on one bad package ("All operations
    # aborted"), and under set -e that took the whole bootstrap down with it
    # -- losing the shell change, the services, the microcode entry and the
    # manual-steps report, none of which depend on stow succeeding.
    if ! run stow --restow --no-folding --dir="$repo" --target="$target" "${pkgs[@]}"; then
        log_warn "stow failed for $repo; dotfiles are NOT linked"
        log_warn "fix the reported conflict, then: stow --restow --no-folding --dir=$repo --target=$target ${pkgs[*]}"
        return 0
    fi
}
