#!/bin/bash

set -e
# set -x

SCRIPT_DIR="$(readlink -f $(dirname $0))"
DEP_DIR="${SCRIPT_DIR}/dep"
ENV_DIR="${SCRIPT_DIR}/env"

OH_MY_ZSH_SRC="${DEP_DIR}/.oh-my-zsh"
OH_MY_ZSH_DST="${ENV_DIR}/.oh-my-zsh"

P10K_SRC="${DEP_DIR}/powerlevel10k"
P10K_DST="${ENV_DIR}/.oh-my-zsh/custom/themes/powerlevel10k"

ZSH_PLUGIN_AUTO_SUGGESTIONS_SRC="${DEP_DIR}/zsh-autosuggestions"
ZSH_PLUGIN_AUTO_SUGGESTIONS_DST="${ENV_DIR}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

ZSH_PLUGIN_COMPLETIONS_SRC="${DEP_DIR}/zsh-completions"
ZSH_PLUGIN_COMPLETIONS_DST="${ENV_DIR}/.oh-my-zsh/custom/plugins/zsh-completions"

ZSH_PLUGIN_SYNTAX_SRC="${DEP_DIR}/zsh-syntax-highlighting"
ZSH_PLUGIN_SYNTAX_DST="${ENV_DIR}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"

install_cmd=
required_tools="zsh vim curl wget git"

# create a soft link if it's not exist
# $1 src_path
# $2 dst_path
function softlink()
{
    src=$1
    dst=$2

    rm -rf "${dst}"
    mkdir -p $(dirname ${dst})
    # if [ -e "${dst}" ]; then
    #     echo "The $(basename ${dst}) is already exist, skip."
    #     return
    # fi
    ln -s "${src}" "${dst}"
    echo "prepare $(basename ${dst}) succeed!"
}

# install required tools
function get_install_cmd()
{
    # is linux
    if [ $(uname -s) = "Linux" ]; then

        type apt > /dev/null
        if [ $? -eq 0 ]; then
            # ubuntu-like destro
            install_cmd="sudo apt install -y"
            return 0
        fi

        type yum > /dev/null
        if [ $? -eq 0 ]; then
            # radhat-like destro
            install_cmd="sudo yum install -y"
            return 0
        fi

        echo "cannot identify the os type..."
        exit 1

    # is macOS
    elif [ $(uname -s) = "Darwin" ]; then
        type brew > /dev/null
        if [ $? -eq 0 ]; then
            install_cmd="brew install"
            return 0
        else
            echo "Not found Homebrew package manager, please use the command to install the Homebrew below:"
            echo "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            echo "Or install the required tools manually:"
            echo "${required_tools}"
            exit 1
        fi

    else
        echo "cannot identify the os type..."
        exit 1
    fi
}

function install_required_tools()
{
    get_install_cmd
    if [ $? -eq 0 ]; then
        echo "Install the required tools? (Enter to continue / Ctrl-C to cancel)"
        echo -n "${install_cmd} ${required_tools} "
        read
        ${install_cmd} ${required_tools}
    fi
}

for tool in ${required_tools}; do
    echo -n "Checking the required tool: ${tool}..."
    sleep 0.2
    type ${tool} > /dev/null
    if [ $? -eq 0 ]; then
        echo "OK!"
    else
        echo "FAILED!"
        install_required_tools
        break
    fi
    sleep 0.2
done

echo "All the required tools satisfied!"
echo ""

# prepare for this repo
echo -n 'Fetch the dependencies...'
sleep 0.2
git submodule init
git submodule update
git submodule foreach git checkout -- .
git submodule foreach git pull origin master
echo ' Done!'
echo ""

# combine the dependencies
echo "Put oh-my-zsh... "
softlink "${OH_MY_ZSH_SRC}" "${OH_MY_ZSH_DST}"
sleep 0.2
echo "Put oh-my-zsh OK!"
echo ""

echo "Put powerlevel10k... "
softlink "${P10K_SRC}" "${P10K_DST}"
sleep 0.2
echo "Put powerlevel10k OK!"
echo ""

echo "Put zsh plugins... "
softlink "${ZSH_PLUGIN_AUTO_SUGGESTIONS_SRC}" "${ZSH_PLUGIN_AUTO_SUGGESTIONS_DST}"
softlink "${ZSH_PLUGIN_COMPLETIONS_SRC}" "${ZSH_PLUGIN_COMPLETIONS_DST}"
softlink "${ZSH_PLUGIN_SYNTAX_SRC}" "${ZSH_PLUGIN_SYNTAX_DST}"
sleep 0.2
echo "Put zsh plugins OK!"
echo ""

echo "Switching the default SHELL to zsh now."
echo "It may need you to input your passcode.(Enter to continue / Ctrl-C to cancel)"
read
chsh -s $(which zsh)
