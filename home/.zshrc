#######################
## OUTPUT TO CONSOLE ##
#######################
echo $USER@$HOST $(uname -srm)
# neofetch


################
## COMPLETION ##
################
autoload -Uz compinit
compinit
setopt COMPLETE_ALIASES

HISTFILE=~/.zhistory
HISTSIZE=2000
SAVEHIST=2000

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' rehash true
# Speed up  Completions
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache-on
zstyle ':completion:*' cache-path ~/.zsh/cache
zstyle ':completion:*' menu select
zmodload zsh/complist
WORDCHARS=${WORDCHARS//\/[&.;]}


#####################
## OPTIONS SECTION ##
#####################
setopt correct
setopt extendedglob
setopt nocaseglob
setopt rcexpandparam
setopt numericglobsort
setopt nobeep
setopt appendhistory
setopt histignorealldups
setopt autocd


##################
## KEY BINDINGS ##
##################
typeset -g -A key

key[Home]="${terminfo[khome]}"
key[End]="${terminfo[kend]}"
key[Insert]="${terminfo[kich1]}"
key[Backspace]="${terminfo[kbs]}"
key[Delete]="${terminfo[kdch1]}"
key[Up]="${terminfo[kcuu1]}"
key[Down]="${terminfo[kcud1]}"
key[Left]="${terminfo[kcub1]}"
key[Right]="${terminfo[kcuf1]}"
key[PageUp]="${terminfo[kpp]}"
key[PageDown]="${terminfo[knp]}"
key[Shift-Tab]="${terminfo[kcbt]}"

# setup key accordingly
[[ -n "${key[Home]}"      ]] && bindkey -- "${key[Home]}"      beginning-of-line
[[ -n "${key[End]}"       ]] && bindkey -- "${key[End]}"       end-of-line
[[ -n "${key[Insert]}"    ]] && bindkey -- "${key[Insert]}"    overwrite-mode
[[ -n "${key[Backspace]}" ]] && bindkey -- "${key[Backspace]}" backward-delete-char
[[ -n "${key[Delete]}"    ]] && bindkey -- "${key[Delete]}"    delete-char
[[ -n "${key[Up]}"        ]] && bindkey -- "${key[Up]}"        up-line-or-history
[[ -n "${key[Down]}"      ]] && bindkey -- "${key[Down]}"      down-line-or-history
[[ -n "${key[Left]}"      ]] && bindkey -- "${key[Left]}"      backward-char
[[ -n "${key[Right]}"     ]] && bindkey -- "${key[Right]}"     forward-char
[[ -n "${key[PageUp]}"    ]] && bindkey -- "${key[PageUp]}"    beginning-of-buffer-or-history
[[ -n "${key[PageDown]}"  ]] && bindkey -- "${key[PageDown]}"  end-of-buffer-or-history
[[ -n "${key[Shift-Tab]}" ]] && bindkey -- "${key[Shift-Tab]}" reverse-menu-complete

# Finally, make sure the terminal is in application mode, when zle is
# active. Only then are the values from $terminfo valid.
if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
	autoload -Uz add-zle-hook-widget
	function zle_application_mode_start { echoti smkx }
	function zle_application_mode_stop { echoti rmkx }
	add-zle-hook-widget -Uz zle-line-init zle_application_mode_start
	add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
fi




#############
## ALIASES ##
#############
alias cp-'cp -i'
alias df='df -h'
alias free='free -m'
alias ll='ls -alhF'
alias mv='mv -i'
alias v='vim'
alias nv='nvim'


####################
## SUFFIX ALIASES ##
####################
alias -s {ts,html,py,js,md}=nvim


##################
## COLOR OUTPUT ##
##################
autoload -Uz colors
colors

alias ls='ls --color=auto'
alias diff='diff --color=auto'
alias grep='grep --color=auto'
alias ip='ip -color=auto'

export LESS=-R
export LESS_TERMCAP_mb=$'\E[1;31m'     # begin blink
export LESS_TERMCAP_md=$'\E[1;36m'     # begin bold
export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
export LESS_TERMCAP_so=$'\E[01;44;33m' # begin reverse video
export LESS_TERMCAP_se=$'\E[0m'        # reset reverse video
export LESS_TERMCAP_us=$'\E[1;32m'     # begin underline
export LESS_TERMCAP_ue=$'\E[0m'        # reset underline

#####################
## PLUGINS SECTION ##
#####################
[ -d "/usr/share/zsh/plugins/zsh-autosuggestions" ] \
    && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -d "/usr/share/zsh/plugins/zsh-history-substring-search" ] \
    && source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

if [ -d "/usr/share/zsh/plugins/zsh-syntax-highlighting" ] ; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
    ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=blue,underline
    ZSH_HIGHLIGHT_STYLES[precommand]=fg=blue,underline
    ZSH_HIGHLIGHT_STYLES[arg0]=fg=blue,bold
    ZSH_HIGHLIGHT_STYLES[default]=fg=011
    ZSH_HIGHLIGHT_STYLES[path]=fg=011
    ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=cyan
    ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=cyan
fi

## VIM MODE
bindkey -v
export KEYTIMEOUT=1

bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history


####################
## HISTORY SEARCH ##
####################
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

[[ -n "${key[Up]}"   ]] && bindkey -- "${key[Up]}"   up-line-or-beginning-search
[[ -n "${key[Down]}" ]] && bindkey -- "${key[Down]}" down-line-or-beginning-search

# Bind vim keys to history search
bindkey -M vicmd 'k' history-substring-search-up
bindkey -M vicmd 'j' history-substring-search-down


###########################
## OTHERS CONFIGURATIONS ##
###########################

# Init NVM
[[ -f "/usr/share/nvm/init-nvm.sh" ]] \
    && source /usr/share/nvm/init-nvm.sh

# FZF completion and keybindings
[ -f "/usr/share/fzf/completion.zsh" ] \
    && source /usr/share/fzf/completion.zsh
[ -f "/usr/share/fzf/key-bindings.zsh" ] \
    && source /usr/share/fzf/key-bindings.zsh

# GCloud Command Line Completion
[ -f "/opt/google-cloud-sdk/completion.zsh.inc" ] \
    && source /opt/google-cloud-sdk/completion.zsh.inc

# Set FZF default Command
if [ -f "/usr/bin/rg" ] ; then
    export FZF_DEFAULT_COMMAND='rg --hidden --files --glob "!.git"';
fi

# Set pyenv
if command -v pyenv 1>/dev/null 2>&1; then
    eval "$(pyenv init -)"
fi

# Set rbenv for ruby version manager
[ -f "$HOME/.rbenv/bin/rbenv" ] \
    && eval "$(~/.rbenv/bin/rbenv init - zsh)"

[ -f "$HOME/.rvm/scripts/rvm" ] \
    && source $HOME/.rvm/scripts/rvm

if command -v ruby 1>/dev/null 2>&1; then
    export GEM_HOME="$(ruby -e 'puts Gem.user_dir')"
    export PATH="$GEM_HOME/bin:$PATH"
fi

eval "$(starship init zsh)"
