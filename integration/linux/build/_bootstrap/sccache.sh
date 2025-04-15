#!/usr/bin/env bash

set -ex

: ${SCCACHE_VERSION:=0.10.0}

source "${BASH_SOURCE%/*}/_helpers.sh"

SCCACHE_ARCH=

case "$(arch)" in
x86_64)
    SCCACHE_ARCH='x86_64'
    ;;
arm64)
    SCCACHE_ARCH='aarch64'
    ;;
aarch64)
    SCCACHE_ARCH='aarch64'
    ;;
esac

mkdir -p /usr/src/sccache
cd /usr/src

_server="https://github.com/mozilla/sccache/releases/download/v${SCCACHE_VERSION}"

if [ -n "${SCCACHE_ARCH}" ]; then
    _artifact="sccache-v${SCCACHE_VERSION}-${SCCACHE_ARCH}-unknown-linux-musl.tar.gz"
    $WGET -O sccache.tar.gz "${_server}/${_artifact}"
    $WGET -O sccache.tar.gz.sha256 "${_server}/${_artifact}.sha256"

    echo "$(cat sccache.tar.gz.sha256) sccache.tar.gz" | sha256sum --check --status -

    mkdir -p "sccache"
    tar -xzf "sccache.tar.gz" -C "sccache" --strip-components=1 --no-same-owner
    mv sccache/sccache /usr/local/bin/
    rm -f "sccache.tar.gz"
    rm -f "sccache.tar.gz.sha256"
    rm -rf "sccache"
else
    cargo install "sccache@${SCCACHE_VERSION}" --no-default-features --festures=gha --locked --root="/usr/local"
fi

mkdir -p "$SCCACHE_LINKS"
cd "$SCCACHE_LINKS"

ln "$SCCACHE" c++
ln "$SCCACHE" c99
ln "$SCCACHE" cc
if type clang >/dev/null; then
    ln "$SCCACHE" clang
    ln "$SCCACHE" clang++
    clang_mach=$(clang -dumpmachine)
    ln "$SCCACHE" ${clang_mach}-clang
    ln "$SCCACHE" ${clang_mach}-clang++
fi
if type gcc >/dev/null; then
    ln "$SCCACHE" gcc
    ln "$SCCACHE" g++
    gcc_mach=$(gcc -dumpmachine)
    ln "$SCCACHE" ${gcc_mach}-gcc
    ln "$SCCACHE" ${gcc_mach}-g++
fi

sccache --show-stats
du -sh "$HOME/.cache/sccache"
