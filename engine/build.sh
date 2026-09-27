#!/usr/bin/env bash
# Builds the Stockfish engine the app runs for its bots.
#
# Stockfish 11, official release, UNMODIFIED, compiled as a standalone program for each
# Android CPU type. The app starts it as a separate process and talks to it with UCI text
# commands (see lib/engine/). Stockfish is GPL-3.0: its source is the official sf_11 tag
# downloaded below, and this script is how we build it. Nothing in Stockfish is changed.
#
# Why Stockfish 11: it is the last release with the classic evaluation, so it needs no
# neural-network file (Stockfish 17's is ~70 MB). About 1 MB per phone, and far stronger than
# any of our bots need.
#
# Usage: engine/build.sh   (needs the Android NDK; see NDK below)
set -euo pipefail
cd "$(dirname "$0")"

TAG=sf_11
NDK=${NDK:-$HOME/Library/Android/sdk/ndk/28.2.13676358}
TC=$(ls -d "$NDK"/toolchains/llvm/prebuilt/*/bin | head -1)
API=24

[ -d "Stockfish-$TAG" ] || {
  curl -fsSL --retry 10 -o "$TAG.tar.gz" "https://github.com/official-stockfish/Stockfish/archive/refs/tags/$TAG.tar.gz"
  tar xzf "$TAG.tar.gz"
}
SRC=$(ls "Stockfish-$TAG"/src/*.cpp "Stockfish-$TAG"/src/syzygy/*.cpp)

# Stockfish 11 targets C++11 (its own clamp() clashes with C++17's std::clamp).
FLAGS="-O3 -std=c++11 -DNDEBUG -DUSE_PTHREADS -fPIE -pie -static-libstdc++ -Wno-deprecated -Wno-deprecated-declarations"

build() { # abi compiler extra-flags
  mkdir -p "../android/app/src/main/jniLibs/$1"
  # Named lib*.so so Android installs it with the app's native libraries, where it may run.
  local out="../android/app/src/main/jniLibs/$1/libstockfish.so"
  "$TC/$2" $FLAGS $3 $SRC -o "$out" -lm
  "$TC/llvm-strip" "$out"
  echo "$1: $(du -h "$out" | cut -f1)"
}

build arm64-v8a "aarch64-linux-android$API-clang++" "-DIS_64BIT"
build armeabi-v7a "armv7a-linux-androideabi$API-clang++" "-mthumb -march=armv7-a -mfpu=neon"
build x86_64 "x86_64-linux-android$API-clang++" "-DIS_64BIT -DUSE_POPCNT -msse4.2 -mpopcnt"

# A copy for this computer, used by the automated tests of the engine wrapper.
mkdir -p host
clang++ $(echo "$FLAGS" | sed 's/-static-libstdc++//; s/-pie//') -DIS_64BIT $SRC -o host/stockfish -lm -lpthread
echo "host: $(du -h host/stockfish | cut -f1)"
