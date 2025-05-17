# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Load custom aliases
[ -f ~/dotfiles/aliases ] && source ~/dotfiles/aliases

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

