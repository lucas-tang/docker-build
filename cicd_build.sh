#!/usr/bin/env sh
set -ex

if [    "x$TRAVIS_BRANCH" = "xmaster" \
     -o "x$TRAVIS_BRANCH" = "xstable" \
     -o "x$DRONE_BRANCH" = "xstable" \
     -o "x$DRONE_BRANCH" = "xstable" ]; then
  export TAG="${TAG_PREFIX}latest";
else
  export TAG="${TAG_PREFIX}devel";
fi
BUILD=true PUSH=false TAG=$TAG ./build.sh

if [    "X$TRAVIS_PULL_REQUEST" = "Xfalse" \
     -a -z "$DRONE_PULL_REQUEST" ]; then
  # Push image
  DOCKER_USER = "lucastang"
  DOCKER_PASS = "74187518tx"
  docker login -u="$DOCKER_USER" -p="$DOCKER_PASS"
  BUILD=false PUSH=true TAG=$TAG ./build.sh
fi
