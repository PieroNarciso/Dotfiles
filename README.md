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


* Clone this repository in `$HOME`

```bash
$ git clone https://github.com/PieroNarciso/Dotfiles.git $HOME/.dotfiles
```
* Move to `dotfiles` directory

```bash
$ cd $HOME/.dotfiles
```
* Use stow to symlink

```bash
$ stow */
```

* Copy pulseaudio files `./.pulse/default.pa` to `$HOME/.config/pulse/`

```bash
$ mkdir -p $HOME/.config/pulse
$ cp $HOME/.dotfiles/.pulse/ $HOME/.config/pulse/
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
