#!/bin/bash
set -e
cd $(dirname $0)

#Usually set from the outside
DOCKER_ARCH_ACTUAL="$(docker version -f '{{.Server.Arch}}')"
: ${DOCKER_ARCH:="$DOCKER_ARCH_ACTUAL"}
# QEMU_ARCH #Not set means no qemu emulation
: ${TAG:="latest"}
: ${BUILD:="true"}
: ${PUSH:="true"}
: ${MANIFEST:="false"}
: ${ARCHS:=""}

#good defaults
test -e ./build.config && . ./build.config
: ${BASE:="alpine"}
: ${REPO:="angelnu/test"}

#Base image for docker
declare BASE_STR="BASE_$DOCKER_ARCH"
BASE="${!BASE_STR}"

#Tag for architecture
if [ "x$TAG" = "xlatest" ]; then
  ALIAS_ARCH_TAG="${TAG}-${DOCKER_ARCH}"
  ORG_TAG="$TAG"
  TAG="$(git describe --always --dirty --tags || echo 0.1)"
fi
: ${ARCH_TAG:="${TAG}-${DOCKER_ARCH}"}

#Qemu binary
: ${QEMU_VERSION:="v2.11.1"}
QEMU_ARCH_amd64=amd64
QEMU_ARCH_arm64=aarch64
QEMU_ARCH_arm=arm
declare QEMU_ARCH_STR="QEMU_ARCH_$DOCKER_ARCH"
QEMU_ARCH="${!QEMU_ARCH_STR}"

###############################

if [ "$BUILD" = true ] ; then
  echo "BUILDING DOCKER $REPO:$ARCH_TAG"

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
  docker build -t $REPO:$ARCH_TAG --build-arg BASE=$BASE --build-arg arch=$QEMU_ARCH .

  if [ -n "$ALIAS_ARCH_TAG" ] ; then
    docker tag $REPO:$ARCH_TAG $REPO:${ALIAS_ARCH_TAG}
  fi

fi

##############################

if [ "$PUSH" = true ] ; then
  echo "PUSHING TO DOCKER: $REPO:$ARCH_TAG"
  docker push $REPO:$ARCH_TAG

  if [ -n "$ALIAS_ARCH_TAG" ] ; then
    echo "PUSHING TO DOCKER: $REPO:${ALIAS_ARCH_TAG}"
    docker push $REPO:${ALIAS_ARCH_TAG}
  fi
fi

###############################

if [ "$MANIFEST" = true ] ; then
  echo "PUSHING MANIFEST for $ARCHS"

  for arch in $ARCHS; do
    echo
    echo "Pull ${REPO}:${TAG}-${arch}"
    docker pull ${REPO}:${TAG}-${arch}

    echo
    echo "Add ${REPO}:${TAG}-${arch} to manifest ${REPO}:${TAG}"
    docker manifest create --amend ${REPO}:${TAG} ${REPO}:${TAG}-${arch}
    docker manifest annotate       ${REPO}:${TAG} ${REPO}:${TAG}-${arch} --arch ${arch}
  done

  echo
  echo "Push manifest ${REPO}:${TAG}"
  docker manifest push ${REPO}:${TAG}

  if [ -n "$ALIAS_ARCH_TAG" ] ; then
    for arch in $ARCHS; do
      echo
      echo "Pull ${REPO}:${ORG_TAG}-${arch}"
      docker pull ${REPO}:${ORG_TAG}-${arch}

      echo
      echo "Add ${REPO}:${ORG_TAG}-${arch} to manifest ${REPO}:${ORG_TAG}"
      docker manifest create --amend ${REPO}:${ORG_TAG} ${REPO}:${ORG_TAG}-${arch}
      docker manifest annotate       ${REPO}:${ORG_TAG} ${REPO}:${ORG_TAG}-${arch} --arch ${arch}
    done

    echo
    echo "Push manifest ${REPO}:${ORG_TAG}"
    docker manifest push ${REPO}:${ORG_TAG}
  fi

fi
