# Dotfiles Install

* Make an alias in your .zshrc or .bashrc file.

```bash
$ alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
```

* Ignore the directory of your repository

```bash
$ echo ".dotfiles" >> .gitignore
```

* Clone this repository in a `bare` repository.

```bash
git clone --bare https://github.com/PieroNarciso/Dotfiles.git $HOME/.dotfiles
```

* Checkout the content from the bare repository to your `$HOME` directory. If you get an error with a list of files. Make a backup of those, remove them and re-run the command.

```bash
$ dotfiles checkout
```

* Flah showUntrackedFile to `no`.

```bash
$ dotfiles config --local status.showUntrackedFiles no
```

# i3

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
