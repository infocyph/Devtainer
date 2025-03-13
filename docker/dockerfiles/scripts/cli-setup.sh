#!/bin/bash

USERNAME="$2"

# Modify the .bashrc file for Oh My Bash configuration
sed -i '/^plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm)' "/home/${USERNAME}/.bashrc"
sed -i '/^#plugins=(/,/^)/c\plugins=(git bashmarks colored-man-pages npm xterm)' "/home/${USERNAME}/.bashrc"
sed -i 's/^#\?\s*OSH_THEME=.*/OSH_THEME="lambda"/' "/home/${USERNAME}/.bashrc"
sed -i 's/^#\?\s*DISABLE_AUTO_UPDATE=.*/DISABLE_AUTO_UPDATE="true"/' "/home/${USERNAME}/.bashrc"

printf 'cat << "EOF" | boxes -d parchment -a hcvc | lolcat\n%s\nEOF\n' "\
 _                    _ ____             _
| |    ___   ___ __ _| |  _ \  ___   ___| | __
| |   / _ \ / __/ _  | | | | |/ _ \ / __| |/ /
| |__| (_) | (_| (_| | | |_| | (_) | (__|   <
|_____\\___/ \\___\\__,_|_|____/ \\___/ \\___|_|\\_\\
----------------------------------------------
${1}" >> "/home/${USERNAME}/.bashrc"
rm -f -- "$0"
