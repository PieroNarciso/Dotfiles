export QT_QPA_PLATFORMTHEME=qt5ct

PATH="$HOME/.node_modules/bin:$PATH"
export npm_config_prefix=~/.node_modules
export BAT_THEME=gruvbox-dark
export TDESKTOP_USE_GTK_FILE_DIALOG=1


if command -v pyenv 1>/dev/null 2>&1; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
fi

if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
