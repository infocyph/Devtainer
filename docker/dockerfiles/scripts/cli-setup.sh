#!/bin/bash

if [[ -z "$1" ]]; then
  echo "Usage: $0 <container_slug>"
  exit 1
fi

# Install Oh My Bash unattended
curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh | bash -s -- --unattended

# Modify the .bashrc file for Oh My Bash configuration
sed -i '/^plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm)' "/home/${USERNAME}/.bashrc"
sed -i '/^#plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm)' "/home/${USERNAME}/.bashrc"
sed -i 's/^#\\?OSH_THEME=.*/OSH_THEME="lambda"/' "/home/${USERNAME}/.bashrc"
sed -i 's/^#\\?DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE=true/' "/home/${USERNAME}/.bashrc"

# Append ASCII banner to .bashrc using printf, with the last line from parameter
printf 'cat << "EOF" | boxes -d parchment -a hcvc | lolcat\n%s\nEOF\n' "\
 _                    _ ____             _
| |    ___   ___ __ _| |  _ \  ___   ___| | __
| |   / _ \ / __/ _  | | | | |/ _ \ / __| |/ /
| |__| (_) | (_| (_| | | |_| | (_) | (__|   <
|_____\\___/ \\___\\__,_|_|____/ \\___/ \\___|_|\\_\\
----------------------------------------------
${1}
" >> "/home/${USERNAME}/.bashrc"
rm -f -- "$0"
