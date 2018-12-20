#!/usr/bin/env bash

declare -rx color_restore='\033[0m'
declare -rx color_cyan='\033[0;36m'

echo -e "${color_cyan}Deleting all orphaned volumes...${color_restore}";
docker volume ls -qf dangling=true | xargs -r docker volume rm
echo -e "${color_cyan}Done${color_restore}"
