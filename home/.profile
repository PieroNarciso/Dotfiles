export QT_QPA_PLATFORMTHEME=qt5ct

PATH="$HOME/.node_modules/bin:$PATH"
# export npm_config_prefix=~/.node_modules
export BAT_THEME=gruvbox-dark
export TDESKTOP_USE_GTK_FILE_DIALOG=1

if [ -d "$HOME/.android/sdk/cmdline-tools" ]; then
    CMD_TOOLS_ANDROID_PATH="$HOME/.android/sdk/cmdline-tools/5.0/bin"
    export PATH="$CMD_TOOLS_ANDROID_PATH:$PATH"
fi

if [ -d "$HOME/.android/sdk/emulator" ]; then
    EMULATOR_PATH="$HOME/.android/sdk/emulator"
    export PATH="$EMULATOR_PATH:$PATH"
fi

if [ -d "$HOME/go/bin" ]; then
    GO_PATH="$HOME/go/bin"
    export PATH="$PATH:$GO_PATH"
fi

if command -v pyenv 1>/dev/null 2>&1; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
fi

if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
