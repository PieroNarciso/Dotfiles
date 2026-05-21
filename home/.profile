export QT_QPA_PLATFORMTHEME=qt5ct
export GTK_THEME=Arc:dark
export XDG_CURRENT_DESKTOP=gtk
export ANDROID_HOME="$HOME/Android/Sdk"

PATH="$HOME/.node_modules/bin:$PATH"
# export npm_config_prefix=~/.node_modules
export BAT_THEME=gruvbox-dark
export TDESKTOP_USE_GTK_FILE_DIALOG=1

if [ -d "$HOME/Android/Sdk/cmdline-tools" ]; then
    CMD_TOOLS_ANDROID_PATH="$HOME/Android/Sdk/cmdline-tools/latest/bin"
    export PATH="$CMD_TOOLS_ANDROID_PATH:$PATH"
fi

if [ -d "$HOME/Android/Sdk/emulator" ]; then
    EMULATOR_PATH="$HOME/Android/Sdk/emulator"
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

if [ -d "$HOME/.cargo/bin" ] ; then
    PATH="$HOME/.cargo/bin:$PATH"
fi

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/piero/.lmstudio/bin"
# End of LM Studio CLI section

