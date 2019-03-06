#!/usr/bin/env sh
set -e
cd $(dirname $0)

#Usually set from the outside
: ${TARGET:="$1"} #Something like bla/bla:latest
: ${ARCHS:="amd64 arm arm64"}

for arch in $ARCHS; do

  #TARGET_ARCH
  TARGET_ARCH=""${TARGET}-${arch}""

  #SOURCE_ARCH
  declare SOURCE_STR="SOURCE_$arch"
  SOURCE_ARCH="${!SOURCE_STR}"
  : ${SOURCE_ARCH:="$TARGET_ARCH"}

  #Pull source
  echo
  echo "Pull ${SOURCE_ARCH}"
  docker pull ${SOURCE_ARCH}

  #Push arch docker
  if [ "x${SOURCE_ARCH}" != "x${TARGET_ARCH}" ]; then
    echo
    echo "Pushing ${TARGET_ARCH}"
    docker tag ${SOURCE_ARCH} ${TARGET_ARCH}
    docker push ${TARGET_ARCH}
  fi

  #Add arch docker to manifest
  echo
  echo "Add ${TARGET_ARCH} to manifest ${TARGET}"
  docker manifest create --amend ${TARGET} ${TARGET_ARCH}
  docker manifest annotate       ${TARGET} ${TARGET_ARCH} --arch ${arch}
done

echo
echo "Push manifest ${TARGET}"
docker manifest push ${TARGET}
