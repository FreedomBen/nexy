#!/usr/bin/env sh

color_restore='\033[0m'
color_black='\033[0;30m'
color_red='\033[0;31m'
color_green='\033[0;32m'

if [ -d 'dotfiles' ]; then
  cd dotfiles
fi

for src in tmux.conf bashrc; do
  dest="$HOME/.${src}"
  if [ -f "$src" ]; then
    if cp "$src" "$dest"; then
      echo -e "${color_green}Copied '$src' to '$dest'${color_restore}"
    fi
  else
    echo -e "${color_red}Oh no, couldn't find file '$src'. Make sure you're in the right directory${color_restore}"
  fi
done
