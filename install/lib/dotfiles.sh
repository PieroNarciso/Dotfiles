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
        done < <(find "$repo/$pkg" \( -type f -o -type l \))
    done
}

df_stow_repo() {
    local repo="$1" target="$2"
    local -a pkgs
    mapfile -t pkgs < <(_df_packages "$repo")
    [ "${#pkgs[@]}" -gt 0 ] || { log_warn "no stow packages in $repo"; return 0; }
    log_step "stowing ${#pkgs[@]} package(s) from $repo"
    run stow --restow --dir="$repo" --target="$target" "${pkgs[@]}"
}
