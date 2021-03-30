export QT_QPA_PLATFORMTHEME=qt5ct

PATH="$HOME/.node_modules/bin:$PATH"
export npm_config_prefix=~/.node_modules

if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
