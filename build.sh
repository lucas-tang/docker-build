#!/bin/bash
set -e

#Usually set from the outside
DOCKER_ARCH_ACTUAL="$(docker version -f '{{.Server.Arch}}')"
: ${DOCKER_ARCH:="$DOCKER_ARCH_ACTUAL"}
# QEMU_ARCH #Not set means no qemu emulation
: ${TAG:="latest"}
: ${BUILD:="true"}
: ${PUSH:="true"}
: ${MANIFEST:="false"}

#good defaults
: ${CONFIG_FILE:="./build.config"}
test -e ${CONFIG_FILE} && . ${CONFIG_FILE}
: ${BASE:="alpine"}
: ${REPO:="angelnu/test"}
: ${DOCKER_BUILD_FOLDER:="."}
: ${DOCKERFILE:="Dockerfile"}

#Base image for docker
declare BASE_STR="BASE_$DOCKER_ARCH"
BASE="${!BASE_STR}"

#Tag for architecture
TAG_COMMIT="$(git describe --always --dirty --tags || echo 0.1)"
ARCH_TAG_COMMIT="${TAG_COMMIT}-$TAG-${DOCKER_ARCH}"
: ${ARCH_TAG:="${TAG}-${DOCKER_ARCH}"}

#Qemu binary
: ${QEMU_VERSION:="v3.0.0"}
QEMU_ARCH_amd64=amd64
QEMU_ARCH_arm64=aarch64
QEMU_ARCH_arm=arm
declare QEMU_ARCH_STR="QEMU_ARCH_$DOCKER_ARCH"
QEMU_ARCH="${!QEMU_ARCH_STR}"

###############################

if [ "$BUILD" = true ] ; then
  echo "BUILDING DOCKER $REPO:$ARCH_TAG_COMMIT"

  #Change Directory
  if [ -n "$DOCKER_FOLDER" ] ; then
    cd $DOCKER_FOLDER
  fi

  #Prepare qemu
  mkdir -p qemu
  cd qemu

  if [ "x$DOCKER_ARCH" = "x$DOCKER_ARCH_ACTUAL" ]; then
    echo "Building without qemu"
    touch qemu-"$QEMU_ARCH"-static
  else
    # Prepare qemu
    echo "Building docker for arch $DOCKER_ARCH using qemu arch $QEMU_ARCH"
    if [ ! -f qemu-"$QEMU_ARCH"-static ]; then
      docker run --rm --privileged multiarch/qemu-user-static:register --reset
      curl -L -o qemu-"$QEMU_ARCH"-static.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/"$QEMU_VERSION"/qemu-"$QEMU_ARCH"-static.tar.gz
      tar xzf qemu-"$QEMU_ARCH"-static.tar.gz
      rm qemu-"$QEMU_ARCH"-static.tar.gz
    fi
  fi
  cd ..

  #Build docker
  echo "Building $REPO:$ARCH_TAG using base image $BASE and qemu arch $QEMU_ARCH"
  docker pull $REPO:$ARCH_TAG || true
  docker pull $BASE || true
  docker build -t $REPO:$ARCH_TAG --cache-from $REPO:$ARCH_TAG --build-arg BASE=$BASE --build-arg arch=$QEMU_ARCH -f $DOCKERFILE ${DOCKER_BUILD_FOLDER}

  if [ -n "$TAG_COMMIT" ] ; then
    echo "Tag alias: $REPO:$ARCH_TAG_COMMIT"
    docker tag $REPO:$ARCH_TAG $REPO:$ARCH_TAG_COMMIT
  fi
fi

##############################

if [ "$PUSH" = true ] ; then
  echo "PUSHING TO DOCKER: $REPO:$ARCH_TAG"
  docker push $REPO:$ARCH_TAG

  if [ -n "$TAG_COMMIT" ] ; then
    echo "PUSHING ALIAS TO DOCKER: $REPO:${ARCH_TAG_COMMIT}"
    docker push $REPO:${ARCH_TAG_COMMIT}
  fi
fi

###############################

if [ "$MANIFEST" = true ] ; then
  echo "PUSHING MANIFEST for ${REPO}:${TAG}"
  ./build/build_manifest.sh "${REPO}:${TAG}"

  if [ -n "$TAG_COMMIT" ] ; then
    echo "PUSHING MANIFEST for ${REPO}:${TAG_COMMIT}"
    ./build/build_manifest.sh "${REPO}:${TAG_COMMIT}" || exit 0 #Skipping push of manifest ${REPO}:${TAG}
  fi

fi
