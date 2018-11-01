#!/bin/sh
set -ex

sudo apt-get update
sudo apt-get install "docker-ce=18.03*"

if [ "x$TRAVIS_BRANCH" = "xmaster" -o "x$TRAVIS_BRANCH" = "xstable" ]; then
  export TAG="${TAG_PREFIX}latest";
else
  export TAG="${TAG_PREFIX}devel";
fi
mkdir -p $HOME/.docker
echo '{"experimental": "enabled"}'>$HOME/.docker/config.json

if [ "$TRAVIS_PULL_REQUEST" = "false" ]; then
  docker login -u="$DOCKER_USER" -p="$DOCKER_PASS"
  ARCHS="arm amd64 arm64" BUILD=false PUSH=false TAG=$TAG MANIFEST=true ./build.sh
fi
