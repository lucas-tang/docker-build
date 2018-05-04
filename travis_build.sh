#!/bin/sh
set -ex

if [ "x$TRAVIS_BRANCH" = "xmaster" ]; then
  export TAG="latest";
else
  export TAG="devel";
fi
BUILD=true PUSH=false TAG=$TAG ./build.sh

if [ "$TRAVIS_PULL_REQUEST" = "false" ]; then
  # Push image
  docker login -u="$DOCKER_USER" -p="$DOCKER_PASS"
  BUILD=false PUSH=true TAG=$TAG ./build.sh
fi
