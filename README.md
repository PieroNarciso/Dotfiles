# Dotfiles Install

* Make an alias in your .zshrc or .bashrc file.

```bash
$ alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
```

* Ignore the directory of your repository

```bash
$ echo ".dotfiles" >> .gitignore
```

* Clone this this repository in a `bare` repository.

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
