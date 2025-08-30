#!/usr/bin/env bash
set -e

# make sure dirs exist
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.cache/pomo"

# copy binary
cp ./pomo "$HOME/.local/bin/pomo"
chmod +x "$HOME/.local/bin/pomo"

# copy vars
cp ./vars "$HOME/.cache/pomo/vars"

echo "✅ Installed pomo to $HOME/.local/bin/pomo"
echo "✅ Vars at $HOME/.cache/pomo/vars"
echo "Try: pomo start 25m && pomo show"

