#!/usr/bin/env bash
# Cloning and stowing the dotfile repos. Requires lib/log.sh.

# Returns non-zero on failure instead of letting set -e end the run: a dirty
# tree, a branch with no upstream or a network blip must cost the user one
# repo's update, not the shell, services and report phases after it.
df_clone_or_pull() {
    local url="$1" dest="$2"
    if [ -d "$dest/.git" ]; then
        log_info "updating $dest"
        run git -C "$dest" pull --ff-only && return 0
        log_warn "could not update $dest; using it as it is"
        return 1
    fi
    log_step "cloning $url into $dest"
    run git clone "$url" "$dest" && return 0
    log_warn "could not clone $url; its dotfiles will not be linked"
    return 1
}

# Whether stow is available. stow is a paru package (core.txt), so on a fresh
# machine where paru failed to build it there is none. A seam: the real run
# asks PATH; the tests force the answer to exercise the no-stow path.
df_stow_available() { command -v stow >/dev/null 2>&1; }

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

# Every file and symlink stow would link from one package, relative to the
# package, leaving out whatever .stow-local-ignore (or stow's built-in list)
# excludes -- a path stow will never link is not a conflict, and moving it
# only takes the user's data out of the way for nothing. Asks stow's own Perl
# module, so the answer is stow's rather than an imitation of its rules. With
# no stow installed yet (a dry run on a fresh machine) it falls back to every
# file, which over-reports but never misses one.
_df_stow_paths() { # <repo> <pkg>
    local repo="$1" pkg="$2"
    if ! perl -MStow -e 1 2>/dev/null; then
        (cd "$repo/$pkg" && find . -mindepth 1 \( -type f -o -type l \) | sed 's|^\./||')
        return 0
    fi
    perl -MStow -MFile::Find -e '
        my ($repo, $pkg) = @ARGV;
        my $stow = Stow->new(dir => $repo, target => "/");
        my $root = "$repo/$pkg";
        find({ no_chdir => 1, wanted => sub {
            return if $_ eq $root;
            (my $rel = $_) =~ s{^\Q$root\E/}{};
            if ($stow->ignore($repo, $pkg, $rel)) { $File::Find::prune = 1; return; }
            print "$rel\n" if -l $_ || -f $_;
        } }, $root);
    ' "$repo" "$pkg"
}

# How many paths were actually moved aside. The backup directory is shared
# with the loader-entry backup in phase_microcode, so its existence proves
# nothing about dotfiles -- a caller that tests `[ -d "$BACKUP_DIR" ]` sends
# the reader looking for files that were never moved.
DF_BACKED_UP=0

# Move aside anything stow would refuse to overwrite.
df_backup_conflicts() {
    local repo="$1" target="$2" backup="$3"
    local pkg rel dst real_repo
    real_repo="$(readlink -f "$repo")"
    for pkg in $(_df_packages "$repo"); do
        while IFS= read -r rel; do
            dst="$target/$rel"
            # Anything that already resolves into the repo is our own work;
            # leave it. That includes a plain file reached through a folded
            # parent: a stow run without --no-folding (the README's own
            # command) links ~/.config/i3 as a whole directory, so
            # ~/.config/i3/config is not itself a symlink -- and moving it
            # moves the repo's file out of the repo. stow --restow unfolds
            # such a directory by itself. The trailing slash keeps a sibling
            # like ~/.dotfiles-backup-* from passing as "inside the repo".
            if [ -e "$dst" ] || [ -L "$dst" ]; then
                [[ "$(readlink -f "$dst")" == "$real_repo"/* ]] && continue
                # A symlink the repo itself carries, reached through a folded
                # parent, can be broken (its target is on another machine).
                # readlink -f then says nothing useful about it, but its
                # directory still resolves into the repo -- it IS the repo's.
                [[ "$(readlink -f "$(dirname "$dst")")" == "$real_repo"/* ]] && continue
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
        done < <(_df_stow_paths "$repo" "$pkg")
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
