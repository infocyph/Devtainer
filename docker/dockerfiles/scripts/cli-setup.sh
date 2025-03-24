#!/bin/bash

USERNAME="$1"

# Modify the .bashrc file for Oh My Bash configuration
sed -i '/^plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm)' "/home/${USERNAME}/.bashrc"
sed -i '/^#plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm)' "/home/${USERNAME}/.bashrc"
sed -i 's/^#\?\s*OSH_THEME=.*/OSH_THEME="lambda"/' "/home/${USERNAME}/.bashrc"
sed -i 's/^#\?\s*DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE="true"/' "/home/${USERNAME}/.bashrc"

# Define an array of alias commands
aliases=(
  'alias ll="ls -la"'
)

# Append each alias to .bashrc if it isn't already present
for alias_cmd in "${aliases[@]}"; do
  if ! grep -qF "$alias_cmd" "/home/${USERNAME}/.bashrc"; then
    echo "$alias_cmd" >> "/home/${USERNAME}/.bashrc"
  fi
done

rm -f -- "$0"
