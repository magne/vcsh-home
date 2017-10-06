#!/bin/bash

# Nice logging
log() {
    printf "\n$(tput sgr0)$(tput setaf 7)$(tput bold)> $*$(tput sgr0)\n"
}
write() {
    printf "$(tput sgr0)$*$(tput sgr0)"
}

# Check for a command and report failure if not present
cmd_err=0
check_cmd() {
    command -v $1 > /dev/null && {
        write "   $(tput setaf 2)$1\n"
    } || {
        write "   $(tput setaf 3)$1 not available\n"
        cmd_err=1
    }
}

download() {
    test -z "$FORCE_DOWNLOAD" && command -v $1 > /dev/null && {
        write "   $(tput setaf 2)$1 already at $(command -v $1)\n"
    } || {
        write "   $(tput setaf 7)Downloading $1"
        test -d $HOME/bin || mkdir -p $HOME/bin
        if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
            PATH="$HOME/bin:$PATH"
        fi
        curl -s -L -o "$HOME/bin/$1" "$2" && {
            chmod 0755 "$HOME/bin/$1"
            write "$(tput cr)\e[K   $(tput setaf 2)$1\n"
        } || {
            write "$(tput cr)\e[K   $(tput setaf 3)Failed to download $1 from $2\n"
            exit 1
        }
    }
}

# First, check for the presence of essential tools (git, ...)
log "Checking needed commands:"
check_cmd git
check_cmd ssh
check_cmd curl

[ $cmd_err -eq 0 ] || {
    write "$(tput setaf 1)Missing commands\n"
    exit 1
}

# Download scripts
log "Download scripts:"
download mr 'http://source.myrepos.branchable.com/?p=source.git;a=blob_plain;f=mr;hb=HEAD'
download vcsh 'https://raw.githubusercontent.com/RichiH/vcsh/master/vcsh'

# Check for github access
log "Checking valid passwordless ssh authentication against github"
write "   $(tput setaf 7)Checking ..."
ssh_out="$(ssh -T -n -o BatchMode=yes -o StrictHostKeyChecking=no git@github.com 2>&1)"
case $? in
    1) write "$(tput cr)\e[K   $(tput setaf 2)Authentication OK\n" ;;
    255) write "$(tput cr)\e[K   $(tput setaf 3)Public key authentication failed - $ssh_out\n"; exit 1 ;;
    *) write "$(tput cr)\e[K   $(tput setaf 1)Unknown error - $ssh_out\n"; exit 1 ;;
esac

# Next, we'll prepare for the initial bootstrap. It is basically:
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

# Clone the vcsh-home repository
log "Cloning the vcsh-home repository"
vcsh clone git@github.com:magne/vcsh-home.git mr || exit 1

# Running mr in interactive mode on the most important one
# Update in a new shell (benefits from the sh-config)
log "Updating everything in a new shell: $SHELL"
test -z "$SKIP_MRI" && mr -i -d $HOME update

# Explain to the user how to add configuration
log "That's it, Your home is now configured. You can add or remove configuration using vcsh."
