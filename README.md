# Dotfiles
![Preview](https://i.imgur.com/GUPLgzh.png)

# Requirements
Requirements packages are in `Packages-Desktop` (**Arch Linux**)

Some packages are from the [AUR](https://wiki.archlinux.org/index.php/Arch_User_Repository)

To make it straitforward install the packages with a `AUR helper` (`paru`, `yay`)
```bash
$ paru -S --needed - < Packages-Desktop
```

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
$ dotfiles checkout --force
```

* Flah showUntrackedFile to `no`.

```bash
$ dotfiles config --local status.showUntrackedFiles no
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
