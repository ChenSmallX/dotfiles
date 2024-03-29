# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH
export PATH="${HOME}/.local/bin:${PATH}"

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    git
    zsh-completions
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# #####
# custom functions
# ##### begin #####

# get route ip and print to screen
# almost use in proxy $(gw):port
function gw {
    if command -v route >> /dev/null; then
        route -n | grep -E '^0' | awk '{print $2}'
        return 0
    else
        echo "route command not exist, please check!"
        return 1
    fi
}

# get custom proxy port
# use by create a file under the ~ folder which
# contains the proxy port and named to '.proxy_port'
function proxy_port {
    local p_port=''

    if [ -f ~/.proxy_port ]; then
        # ~/.proxy_port file exist
        p_port="$(cat ~/.proxy_port)"
    else
        echo "the proxy port flag file not exist, please edit it."
        touch ~/.proxy_port
        return 1
    fi

    if [ -z "${p_port}" ]; then
        echo "the ~/.proxy_port file is empty, please edit it"
        return 1
    fi

    echo "${p_port}"
    return 0
}

alias proxy_addr="echo http://$(gw):$(proxy_port)"

# Check it is in Windows Subsystem Linux
function isWsl {
    uname -a | grep -E "[M|m]icrosoft" > /dev/null
    if [ $? -eq 0 ]; then
        return 0
    fi
    return 1
}

isWsl
if [ $? -eq 0 ]; then
# Start of isWsl, find the end if Wsl to search "End of isWsl"
    alias wsl="wsl.exe"

    # Checks to see if we are in a windows path or a linux(WSL) path
    function isWinDir {
      case $PWD/ in
        /mnt/*) return $(true);;
        *) return $(false);;
      esac
    }

    # git command wrap
    # Determine whether to use git.exe in windows or git in linux(WSL)
    REAL_GIT=$(which git)
    function git {
      if isWinDir; then
        git.exe "$@"
      else
        "${REAL_GIT}" "$@"
      fi
    }

    # Vscode launch command wrap
    # Determine whether to use code.exe in windows or code in linux(WSL)
    REAL_CODE=$(which code)
    function code {
      if isWinDir; then
        cmd.exe /c code.cmd $(wslpath -w "$@")
      else
        #"/mnt/c/Users/陈可/AppData/Local/Programs/Microsoft VS Code/bin/code" "$@"
        "${REAL_CODE}" "$@"
      fi
    }

    # create command "open" and "start" to open
    # a path in linux(WSL) by windows exploere.exe
    # usage:
    #     open <path>
    #     start <path>
    # eg. open .                                # open the dir
    # eg. open /home/yourname/.ssh/id_rsa.pub   # open the file by a software
    #                                           #   which bind to this type
    # eg. start /etc/                           # open the dir
    function open {
      explorer.exe $(wslpath -w "$@")
      return 0
    }
    alias start="open"

    # recollect RAM in WSL2 vm.
    alias vmfree="sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches' && echo done!"
    alias iftop="sudo TERM=xterm iftop"
    alias proxy="export http_proxy=$(proxy_addr); export https_port=$(proxy_addr)"

# End of isWsl
else
# for common linux
    alias proxy="export http_proxy=127.0.0.1:$(proxy_port); export https_port=127.0.0.1:$(proxy_port)"
fi

alias unproxy="unset http_proxy https_proxy all_proxy"

# Golang
export PATH=$PATH:/usr/local/go/bin

