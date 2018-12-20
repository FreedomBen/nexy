#!/usr/bin/env bash

declare -rx color_restore='\033[0m'
declare -rx color_black='\033[0;30m'
declare -rx color_red='\033[0;31m'
declare -rx color_green='\033[0;32m'
declare -rx color_brown='\033[0;33m'
declare -rx color_blue='\033[0;34m'
declare -rx color_purple='\033[0;35m'
declare -rx color_cyan='\033[0;36m'
declare -rx color_light_gray='\033[0;37m'
declare -rx color_dark_gray='\033[1;30m'
declare -rx color_light_red='\033[1;31m'
declare -rx color_light_green='\033[1;32m'
declare -rx color_yellow='\033[1;33m'
declare -rx color_light_blue='\033[1;34m'
declare -rx color_light_purple='\033[1;35m'
declare -rx color_light_cyan='\033[1;36m'
declare -rx color_white='\033[1;37m'

echo -e "${color_cyan}Deleting all stopped containers...${color_restore}";
while read -r line; do
		ID="$(echo $line | awk '{print $1}')";
		IMAGE="$(echo $line | awk '{print $2}')";
		COMMAND="$(echo $line | awk '{print $3}')";
		if [[ $line =~ postgres ]]; then
				if [[ $1 =~ .f ]]; then
						echo -e "${color_green}Container ID '$ID' is postgres image but you have forced delete.Deleting...${color_restore}";
						docker rm "$ID";
				else
						echo -e "${color_yellow}Container ID '$ID' is postgres image.  NOT deleting.  To force, re-run with -f or --force${color_restore}";
				fi;
		else
				echo -e "${color_cyan}Deleting Container ID: $ID, Image: $IMAGE, Command: $COMMAND${color_restore}";
				docker rm "$ID";
		fi;
done < <(docker ps -a | grep -E 'Exited|Created');
echo -e "${color_cyan}Done${color_restore}"
