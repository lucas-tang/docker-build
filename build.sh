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
  TAG_COMMIT="$(git describe --always --dirty --tags || echo 0.1)"
  ARCH_TAG_COMMIT="${TAG_COMMIT}-${DOCKER_ARCH}"
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
  echo "BUILDING DOCKER $REPO:$ARCH_TAG_COMMIT"

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
  docker build -t $REPO:$ARCH_TAG --cache-from $REPO:$ARCH_TAG --build-arg BASE=$BASE --build-arg arch=$QEMU_ARCH .

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

  if [ -n "$TAG_COMMIT" ] ; then
    for arch in $ARCHS; do
      echo
      echo "Pull ${REPO}:${TAG_COMMIT}-${arch}"
      docker pull ${REPO}:${TAG_COMMIT}-${arch} || ( echo "Skipping push of manifest ${REPO}:${TAG}"; exit 0 )

      echo
      echo "Add ${REPO}:${TAG_COMMIT}-${arch} to manifest ${REPO}:${TAG_COMMIT}"
      docker manifest create --amend ${REPO}:${TAG_COMMIT} ${REPO}:${TAG_COMMIT}-${arch}
      docker manifest annotate       ${REPO}:${TAG_COMMIT} ${REPO}:${TAG_COMMIT}-${arch} --arch ${arch}
    done

    echo
    echo "Push manifest ${REPO}:${TAG_COMMIT}"
    docker manifest push ${REPO}:${TAG}
  fi

fi
