# Dotfiles
![Preview](https://i.imgur.com/GUPLgzh.png)

# Install

Full machine setup, from the Arch ISO onwards, lives in `install/`:

- `install/archinstall/` — stage 0, the base system. Two configs, one plain and
  one with an encrypted root. See `install/archinstall/README.md`.
- `install/bootstrap.sh` — stage 1, everything after the first login: packages,
  dotfiles, services, version managers. Run `--dry-run` first.
- `install/packages/` — the package groups, one file per group.
- `install/pkg-audit.sh` — reports drift between the group files and what is
  actually installed. Run it after installing something new.

Design notes: `docs/superpowers/specs/2026-09-21-arch-laptop-bootstrap-design.md`

## Just the dotfiles, on a machine that already exists

```bash
git clone https://github.com/PieroNarciso/Dotfiles.git ~/.dotfiles
cd ~/.dotfiles && stow --restow --target="$HOME" config home local scripts tmux vim Xresources
```

The neovim config is a separate repo:

```bash
git clone https://github.com/PieroNarciso/nvim-config.git ~/.nvim-config
cd ~/.nvim-config && stow --restow --target="$HOME" nvim-config nvim-home
```

# i3 / BSPWM

## Configuration for keyboard

Create this file in `/etc/X11/xorg.conf.d/00-keyboard.conf`

```bash
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "us,us"
        Option "XkbModel" "pc105"
        Option "XkbVariant" ",altgr-intl"
        Option "XkbOptions" "grp:win_space_toggle,caps:escape"
EndSection
```
## Configuration for Mouse Acceleration

Create file in `/etc/X11/xorg.conf.d/50-mouse-accelaration.conf`

```bash
Section "InputClass"
	Identifier "Logitech G403"
	Driver "libinput"
	MatchIsPointer "yes"
	Option "AccelProfile" "flat"
	Option "AccelSpeed" "0"
EndSection
```
