# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi
# Load custom aliases
[ -f ~/dotfiles/aliases ] && source ~/dotfiles/aliases


# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
 
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

if ! grep -q "ssh-add ~/.ssh/ansible" ~/.bashrc; then
  cat << 'EOF' >> ~/.bashrc

# 🔑 SSH Agent Auto-Start for GitHub
eval \$(ssh-agent -s) >/dev/null
ssh-add ~/.ssh/ansible 2>/dev/null
