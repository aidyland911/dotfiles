# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Load custom aliases and functions
[ -f ~/dotfiles/aliases ] && source ~/dotfiles/aliases
[ -f ~/dotfiles/functions ] && source ~/dotfiles/functions

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment if you don't like systemctl's auto-paging:
# export SYSTEMD_PAGER=

# User specific aliases and functions
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# 🔑 SSH Agent Auto-Start for GitHub
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(ssh-agent -s) >/dev/null
    ssh-add ~/.ssh/ansible 2>/dev/null
fi

# Colorized man pages
export LESS_TERMCAP_mb=$(printf '\e[1;31m')
export LESS_TERMCAP_md=$(printf '\e[1;31m')
export LESS_TERMCAP_me=$(printf '\e[0m')
export LESS_TERMCAP_se=$(printf '\e[0m')
export LESS_TERMCAP_so=$(printf '\e[1;33;44m')
export LESS_TERMCAP_ue=$(printf '\e[0m')
export LESS_TERMCAP_us=$(printf '\e[4;1;32m')

# Pretty man pages via bat when installed; otherwise colorized less
if command -v bat >/dev/null 2>&1; then
    export MANPAGER="sh -c 'sed -u -e \"s/\\x1B\[[0-9;]*m//g; s/.\x08//g\" | bat -p -lman'"
else
    export MANPAGER='less -R'
fi
export PATH=$PATH:/usr/local/bin

# Homebrew (only when installed, e.g. by the Ubuntu Ansible playbook)
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
