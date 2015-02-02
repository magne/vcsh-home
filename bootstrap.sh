#!/bin/sh
#
# This is the *vcsh-home* bootstrap file.
#
# This script will initialize the home directory of a new machine with the versioned configuration.
#
# Three software packages are required (available from ubuntu repository, etc.):
#
#   * git
#   * mr
#   * vcsh
#   * zsh
#

# The most important line in any shell script.
set -e


# A few useful functions

# *log*: a wrapper of echo to print stuff in a more colorful way
log() {
    ECHO_ARGS=''
    test "$1" = '-n' && {
        ECHO_ARGS='-n'
        shift
    }
    echo -e $ECHO_ARGS "$(tput sgr0)$(tput setaf 2)>$(tput bold)<$(tput sgr0) $*"
}

# *warn*: a wrapper of echo to print stuff in a more colorful way, warning
warn() {
    ECHO_ARGS=''
    test "$1" = '-n' && {
        ECHO_ARGS='-n'
        shift
    }
    echo -e $ECHO_ARGS "$(tput sgr0)$(tput setaf 3)>$(tput bold)<$(tput sgr0) $*"
}

# *check_cmd*: check for a command and fail if not present
check_cmd() {
    command -v $1 > /dev/null && {
        echo "   $1"
    } || {
        echo ""
        warn "$1 is not available"
        echo
        exit 1
    }
}

# First, check for the precense of essential tools (get, mr, vcsh, zsh)
log "Checking needed commands:$(tput bold)"
check_cmd git
check_cmd mr
check_cmd vcsh
check_cmd zsh

# Next, we'll prepare for the initial bootstrap. It is basically :
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

# * Look at ``HOOK_D`` and ``HOOK_A`` variable if already defined
test -z "$HOOK_D" && HOOK_D=$XDG_CONFIG_HOME/vcsh/hooks-enabled
test -z "$HOOK_A" && HOOK_A=$XDG_CONFIG_HOME/vcsh/hooks-available
log "Preparing bootstrap:\n   Available hooks : $HOOK_A\n   Enabled hooks   : $HOOK_D"

# * Create folder if not present
test -d $HOOK_D || mkdir -p $HOOK_D
test -d $HOOK_A || mkdir -p $HOOK_A

# * Write initial vcsh hooks (to enable sparseCheckout and to ignore README)
log "Writing initial hooks: $(tput bold)"

# vcsh hook for enabling [sparseCheckout](http://www.kernel.org/pub/software/scm/git/docs/git-read-tree.html#_sparse_checkout).
# > "Sparse checkout" allows populating the working directory sparsely. It uses the skip-worktree bit (see git-update-index(1))
# > to tell Git whether a file in the working directory is worth looking at.
#
# This is very useful for the vcsh-enabled repository. I can document them with
# a README file so that other people can know what it does, but I don't want
# them to conflict when beeing used.
name="pre-upgrade.00-checkSparseCheckout"
cat > $HOOK_A/$name << HOOK
#!/bin/sh
if ! test "\$(git config core.sparseCheckout)" = "true"; then
    git config core.sparseCheckout true
fi
HOOK
ln -sfn $HOOK_A/$name $HOOK_D/$name
chmod +x $HOOK_A/$name
echo "   $name"

# vcsh hook for excluding README{,.md} using git sparseCheckout
name="pre-upgrade.01-defaultSparseCheckout"
cat > $HOOK_A/$name << HOOK
#!/bin/sh
if ! test \$(grep $name \$GIT_DIR/info/sparse-checkout >/dev/null 2>&1); then
    cat >> \$GIT_DIR/info/sparse-checkout << EOF
# from $name
*
EOF
fi
HOOK
chmod +x $HOOK_A/$name
ln -sfn $HOOK_A/$name $HOOK_D/$name
echo "   $name"

# vcsh hook for excluding README{,.md} using git sparseCheckout
name="pre-upgrade.02-READMEsparseCheckout"
cat > $HOOK_A/$name << HOOK
#!/bin/sh
if ! test \$(grep $name \$GIT_DIR/info/sparse-checkout >/dev/null 2>&1); then
    cat >> \$GIT_DIR/info/sparse-checkout << EOF
# from $name
!README
!README.md
EOF
fi
HOOK
chmod +x $HOOK_A/$name
ln -sfn $HOOK_A/$name $HOOK_D/$name
echo "   $name"

# vcsh hook for excluding .gitignore using git sparseCheckout
name="pre-upgrade.02-.gitignoreSparseCheckout"
cat > $HOOK_A/$name << HOOK
#!/bin/sh
if ! test \$(grep $name \$GIT_DIR/info/sparse-checkout >/dev/null 2>&1); then
    cat >> \$GIT_DIR/info/sparse-checkout << EOF
# from $name
!.gitignore
EOF
fi
HOOK
chmod +x $HOOK_A/$name
ln -sfn $HOOK_A/$name $HOOK_D/$name
echo "   $name"

# vcsh hook for moving existing files out of the way temporarily (unclobber).
name="pre-merge-unclobber"
cat > $HOOK_A/$name << "HOOK"
#!/bin/bash

# This code does amost exactly what the native vcsh sanity checking code
# does except that on finding a potential merge conflict, it moves existing
# files out of the way temporarily. Merging (part of `vcsh clone`) happens
# cleanly, and a post-merge hook can be used to figure out what to do with
# the now-renamed files.

for object in $(git ls-tree -r origin/master | awk '{print $4}'); do
    [ -e "$object" ] && mv "$object" "$object.vcsh-unclobber" 
done
HOOK
chmod +x $HOOK_A/$name
ln -sfn $HOOK_A/$name $HOOK_D/$name
echo "   $name"

# vcsh hook for moving existing files back (unclobber).
name="post-merge-unclobber"
cat > $HOOK_A/$name << "HOOK"
#!/bin/sh

# This finds objects that the pre-merge script moved out of the way to
# avoid conflicts when running `vcsh clone` and moves them back to their
# original places. The result is that the Git repository gets checked out
# without error and the pre-existing files end up back in the working
# directory. Git and thus vcsh now see these as un-staged changes to the
# working branch and you can deal with them as usual.

find . -name '*.vcsh-unclobber' -execdir rename .vcsh-unclobber '' {} \;
HOOK
chmod +x $HOOK_A/$name
ln -sfn $HOOK_A/$name $HOOK_D/$name
echo "   $name"

echo "$(tput sgr0)"

for dot in .bashrc .bash_profile .bash_logout .zshrc .zprofile .zshenv .zlogin .zlogout .vim .vimrc; do
    test -e $HOME/$dot && ! test -e $HOME/$dot.orig && mv $HOME/$dot $HOME/$dot.orig
done

# * Clone the vcsh-home repository
log "Cloning vcsh-home"
vcsh clone git@github.com:magne/vcsh-home.git vcsh-home

# * Clone the sh-config repository
log "Getting sh-config first"
vcsh clone git@github.com:magne/sh-config.git sh-config

# Running mr in interactive mode on the most important one
# Update in a new shell (benefits from the sh-config)
log "Updating everything in a new shell: $SHELL"
test -z "$SKIP_MRI" && $SHELL -c "mr -i -d $HOME update"

# Explain to the user how to add configuration
log "That's it, Your home is now configured. You can add or remove configuration using vcsh."
