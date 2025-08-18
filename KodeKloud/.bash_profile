eval "$(starship init bash)"
# Colors
black="\[$(tput setaf 0)\]"
red="\[$(tput setaf 1)\]"
green="\[$(tput setaf 2)\]"
yellow="\[$(tput setaf 3)\]"
blue="\[$(tput setaf 4)\]"
magenta="\[$(tput setaf 5)\]"
cyan="\[$(tput setaf 6)\]"
white="\[$(tput setaf 7)\]"
# Title bar - "user@host: ~"
title="\u@\h: \w"
titlebar="\[\033]0;""\007\]"
# Git branch
git_branch() {   git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)\ /'; }
# Clear attributes
clear_attributes="\[$(tput sgr0)\]"

export PS1="${cyan}(admin${green}@${cyan}localhost) ${magenta}\W ${green}#${clear_attributes} "
source /etc/profile.d/bash_completion.sh
source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
termwidth="$(tput cols)"

# Adjust the spacing for the "Welcome to ..." and "All rights ..." lines.

left_align() {
  local padding="$(printf '%0.1s' \ {1..500})"
  local padding_percentage="$1"
  local padding_width=$((termwidth*padding_percentage/100))
  printf '%*.*s %s %*.*s\n' "$padding_width" "$padding_width" "$padding" "$2" 0 "$((termwidth-1-${#2}-padding_width))" "$padding"
}

left_align 6 "Welcome to the KodeKloud Hands-On lab"
figlet -w ${termwidth} -f slant KODEKLOUD | lolcat
left_align 10 "All rights reserved"
source /root/.bashrc 2>/dev/null
