#!/bin/bash

set -eEx

trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

dest="artifacts"
if [ -n "${PKG_PLATFORM}" ]; then
    dest="${dest}/${PKG_PLATFORM}"
fi
if [ -n "${PKG_PLATFORM_VERSION}" ]; then
    dest="${dest}-${PKG_PLATFORM_VERSION}"
fi

cliurl="https://packages.geldata.com/dist/${PKG_PLATFORM_VERSION}-apple-darwin"

tarball=
for pack in ${dest}/*.tar; do
    if [ -e "${pack}" ]; then
        tarball=$(tar -xOf "${pack}" "build-metadata.json" \
                  | jq -r ".installrefs[]" \
                  | grep ".tar.gz$")
        if [ -n "${tarball}" ]; then
            break
        fi
    fi
done

if [ -z "${tarball}" ]; then
    echo "${dest} does not contain a valid build tarball" >&2
    exit 1
fi

workdir=$(mktemp -d)

function finally {
  rm -rf "$workdir"
}
trap finally EXIT ERR

mkdir "${workdir}/bin"
curl --proto '=https' --tlsv1.2 -sSfL  -o "${workdir}/bin/gel" \
    "${cliurl}/gel-cli"
chmod +x "${workdir}/bin/gel"
ln -s gel "${workdir}/bin/edgedb"

gtar -xOf "${pack}" "${tarball}" | gtar -xzf- --strip-components=1 -C "$workdir"

if [ "$1" == "bash" ]; then
    cd "$workdir"
    exec /bin/bash
fi

export PATH="${workdir}/bin/:${PATH}"

if [ -n "${PKG_TEST_JOBS}" ]; then
    dash_j="--jobs=${PKG_TEST_JOBS}"
else
    dash_j=""
fi
test_dir="${workdir}/share/tests"
test_files="$test_dir"
if [ -n "$(trim "${PKG_TEST_FILES}")" ]; then
    # ${PKG_TEST_FILES} is specificaly used outside the quote so that it
    # can contain a glob.
    test_files=$(cd "$test_dir" && realpath $PKG_TEST_FILES)
fi
test_select=""
if [ -n "${PKG_TEST_SELECT}" ]; then
    for pattern in $PKG_TEST_SELECT; do
      test_select="$test_select --include=${pattern}"
    done
fi
test_exclude=""
if [ -n "${PKG_TEST_EXCLUDE}" ]; then
    for pattern in $PKG_TEST_EXCLUDE; do
      test_exclude="$test_exclude --exclude=${pattern}"
    done
fi

"${workdir}/bin/python3" \
    -m edb.tools --no-devmode test \
    ${test_files} ${test_select} \
    --exclude="cqa_" --exclude="tools_" ${test_exclude} \
    --verbose ${dash_j}
