#!/bin/bash

set -e

RVER="$1"

if [ -z "$RVER" ]; then
    RVER=devel
fi

echo "::group:: Setup on $os"

BASE=$(pwd)

os=`uname -s | tr '[:upper:]' '[:lower:]'`
osver=`uname -r | sed -n 's:^\([0-9]*\.[0-9]*\).*:\1:p'`
arch=`uname -m`

echo
echo " System: $os$osver $arch"
echo

if clang --version >/dev/null 2>&1; then
  CC=clang
  CXX=clang++
else
  CC=gcc
  CXX=g++
fi

echo -n "CC =$CC: "
$CC --version | head -n2
echo -n "CXX=$CXX: "
$CXX --version | head -n2

if [ $os = darwin ]; then
  echo " Removing /usr/local .."
  sudo mkdir /usr/local/.disabled
  sudo mv /usr/local/* /usr/local/.disabled
fi

prefix=/opt/R/$arch
sudo mkdir -p $prefix
sudo chown $USER $prefix

export PATH=/opt/R/$prefix/bin:$PATH

if [ $os = linux ]; then
  ## sadly, GNU tar is brain-dead as it can't even figure out compression, need BSD tar
  ## also need Fortran and make sure X11 libs are present
  sudo apt-get install -y libarchive-tools libxt-dev gfortran
  tar --version
  bsdtar --version
fi
echo '::endgroup::'
echo "::group:: Building recipes"

git clone https://github.com/R-macos/recipes.git

cd recipes
PREFIX=`echo $prefix | sed 's:^/*::'` NOSUDO=1 perl scripts/mkmk.pl

## on macOS add system stubs and XQuartz
if [ $os = darwin ]; then
  echo "Installing XQuartz ..."
  curl -sSL https://github.com/R-macos/XQuartz/releases/download/XQuartz-2.8.1/XQuartz-2.8.1.tar.xz \
   | sudo tar fxj - -C / && sudo sh /opt/X11/libexec/postinstall
  export PKG_CONFIG_PATH=/$PREFIX/lib/pkgconfig:$BASE/`pwd`/stubs/pkgconfig-darwin:/usr/lib/pkgconfig:/opt/X11/lib/pkgconfig
else
  export PKG_CONFIG_PATH=/$PREFIX/lib/pkgconfig:/usr/lib/pkgconfig
fi

NOSUDO=1 PATH=/$PREFIX/bin:$PATH CFLAGS=-I/$PREFIX/include LDFLAGS=-L/$PREFIX/lib make -C build r-base-dev

echo '::endgroup::'
#echo "::group:: building R-$RVER"
#echo '::endgroup::'

exit 0
