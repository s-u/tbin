#!/bin/bash

set -e

RVER="$1"

if [ -z "$RVER" ]; then
    RVER=devel
fi

BASE=$(pwd)

os=`uname -s | tr '[:upper:]' '[:lower:]'`
osver=`uname -r | sed -n 's:^\([0-9]*\.[0-9]*\).*:\1:p'`
arch=`uname -m`

echo "::group:: Setup on $os"

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
  ## also need Fortran and make sure X11 libs are present (both should be there already)
  sudo apt-get install -y libarchive-tools libxt-dev gfortran
  sudo mv /usr/bin/tar /usr/bin/gnutar
  sudo ln -s /usr/bin/bsdtar /usr/bin/tar
fi
echo '::endgroup::'
echo "::group:: Building recipes"

echo "Checking out recipes ..."
git clone https://github.com/R-macos/recipes.git

cd recipes
echo "Create recipes build ..."
PREFIX=`echo $prefix | sed 's:^/*::'` NOSUDO=1 perl scripts/mkmk.pl

## on macOS add system stubs and XQuartz
if [ $os = darwin ]; then
  echo "Installing XQuartz ..."
  curl -sSL https://github.com/R-macos/XQuartz/releases/download/XQuartz-2.8.1/XQuartz-2.8.1.tar.xz \
   | sudo tar fxj - -C / && sudo sh /opt/X11/libexec/postinstall
  echo "Installing GNU Fortran ..."
  curl -sSL https://github.com/R-macos/gfortran-for-macOS/releases/download/8.2/gfortran-8.2-Mojave.tar.xz \
   | sudo tar fxz - -C /
  export PKG_CONFIG_PATH=$prefix/lib/pkgconfig:$BASE/`pwd`/stubs/pkgconfig-darwin:/usr/lib/pkgconfig
else
  export PKG_CONFIG_PATH=$prefix/lib/pkgconfig:/usr/lib/pkgconfig
fi

for dir in $prefix/include $prefix/lib; do if [ ! -e $dir ]; then mkdir -p $dir; fi; done

## Only for Darwin now until we know more about what's missing on Linux
if [ $os = darwin ]; then
echo "Start recipes build ..."
NOSUDO=1 PATH=$prefix/bin:$PATH CFLAGS=-I$prefix/include LDFLAGS=-L$prefix/lib make -C build r-base-dev
fi

echo '::endgroup::'
echo "::group:: building R-$RVER"

cd "$BASE"
mkdir R-build
cd R-build
curl -sSL https://stat.ethz.ch/R/daily/R-devel.tar.bz2 | tar fxj -
cd R-devel
tools/rsync-recommended

cd "$BASE/R-build"
mkdir obj
../R-devel/configure --enable-R-shilb --prefix=$prefix && make -j8 && make check

echo '::endgroup::'

exit 0
