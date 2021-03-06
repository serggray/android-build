#!/bin/bash

ANDROID_PACKAGE_ROOT="$(cd $(dirname "$0") && pwd)"

if [ "$1" = all ]; then
  cd "$ANDROID_PACKAGE_ROOT/.."
  PACKAGES='zlib openssl curl libevent transmission' ./build.sh
  exit $?
elif [ "$1" = allnodep ]; then
  cd "$ANDROID_PACKAGE_ROOT/.."
  PACKAGES='transmission' ./build.sh
  exit $?
fi

TRANSMISSION_GIT_URL='https://github.com/serggray/transmission.git'
BRANCH_NAME='transmissionsrv'
LIBS='libtransmission/libtransmission.a
        third-party/*/lib/libdht.a
        third-party/*/lib/libb64.a
        third-party/*/lib/libnatpmp.a
        third-party/*/lib/libminiupnpc.a'

. "$ANDROID_PACKAGE_ROOT/../common-package.sh"

if [ -d "$HOME/src/transmission" ]; then
  cd "$HOME/src/transmission"
elif [ -d "$ANDROID_DOWNLOADS_DIR/transmission" ]; then
  cd "$ANDROID_DOWNLOADS_DIR/transmission"
else
    git clone -b "$BRANCH_NAME" "$TRANSMISSION_GIT_URL" "$ANDROID_DOWNLOADS_DIR/transmission"
    cd "$ANDROID_DOWNLOADS_DIR/transmission"
    git submodule update --init
fi

git clean -fd && git reset --hard
git checkout $BRANCH_NAME

[ -f "$ANDROID_PACKAGE_PATCHES_DIR/dev.patch" ] && patch -p1 < "$ANDROID_PACKAGE_PATCHES_DIR/dev.patch"

build_opts="$build_opts -DENABLE_TESTS=OFF -DENABLE_DAEMON=OFF -DINSTALL_DOC=OFF"

if [ "$ANDROID_NDK_ARCH" = 'arm' ] || [ "$ANDROID_NDK_ARCH" = 'x86' ]; then
  build_opts="$build_opts -DENABLE_UTP=OFF"
else
  LIBS="$LIBS third-party/*/lib/libutp.a"
fi

cmake_build $build_opts
make_concurrent transmission

mkdir -p "$ANDROID_INSTALL_ROOT/usr/include/libtransmission" "$ANDROID_INSTALL_ROOT/usr/lib" "$ANDROID_INSTALL_ROOT/usr/share"
cp -v $LIBS "$ANDROID_INSTALL_ROOT/usr/lib"
cd ..
cp -v libtransmission/*.h "$ANDROID_INSTALL_ROOT/usr/include/libtransmission"
cp -v build/libtransmission/*.h "$ANDROID_INSTALL_ROOT/usr/include/libtransmission"
rsync -av --exclude='*.am' --exclude='*.in' --exclude='*.scss' web "$ANDROID_INSTALL_ROOT/usr/share/transmission"

WEB_CONTROL_URL="https://github.com/ronggang/twc-release/raw/master/src.tar.gz"
WEB_CONTROL_DIR="$ANDROID_BUILD_ROOT/$ANDROID_PACKAGE_NAME/web-control"

mkdir -p "$WEB_CONTROL_DIR"
wget -O - "$WEB_CONTROL_URL" | tar -xz -C "$WEB_CONTROL_DIR"
mv -v "$WEB_CONTROL_DIR/index.html" "$WEB_CONTROL_DIR/index.webcontrol.html"
cp -rv "$WEB_CONTROL_DIR/"* "$ANDROID_INSTALL_ROOT/usr/share/transmission/web/"
cp -v "$ANDROID_INSTALL_ROOT/usr/share/transmission/web/index.html" "$ANDROID_INSTALL_ROOT/usr/share/transmission/web/index.original.html"

rm -f "$ANDROID_INSTALL_ROOT/usr/share/transmission/web/checksum.sha1"
dir_checksum "$ANDROID_INSTALL_ROOT/usr/share/transmission/web"\
           > "$ANDROID_INSTALL_ROOT/usr/share/transmission/web/checksum.sha1"
