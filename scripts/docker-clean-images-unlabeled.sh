#!/usr/bin/env bash

declare -rx color_restore='\033[0m'
declare -rx color_cyan='\033[0;36m'

echo -e "${color_cyan}Deleting all unlabled images...${color_restore}";
docker rmi $(docker images | grep -iE '^<none>' | awk '{print $3}' | xargs)
echo -e "${color_cyan}Done${color_restore}"
