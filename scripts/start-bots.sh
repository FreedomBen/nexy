#!/usr/bin/env bash

# if we're not in the docker container, run the container

is_docker_user ()
{
  whoami | grep 'docker' >/dev/null 2>&1
}

if is_docker_user; then
  . <(aescrypt -d nexy.aes -o -) || echo 'Doh password was wrong'
  slackbot-frd start
else
  echo ""
  echo "Looks like you aren't in the docker container..."
  echo "I'll start it for you.  Once it starts, run this script inside it"
  echo ""
  echo "    ./scripts/start-bots.sh"
  echo ""
  echo "or use the alias:"
  echo ""
  echo "    start"
  echo ""
  if [ -d "scripts" ]; then
    ./scripts/run-container.sh
  elif [ -x "run-container.sh" ]; then
    ./run-container.sh
  else
    "Oh no, you must be in a weird working directory. Try from the project root"
  fi
fi
