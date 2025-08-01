#!/bin/bash

set -ex

trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

dest="artifacts"
if [ -n "${PKG_PLATFORM}" ]; then
    dest+="/${PKG_PLATFORM}"
fi
if [ -n "${PKG_PLATFORM_VERSION}" ]; then
    dest+="-${PKG_PLATFORM_VERSION}"
fi

dist="${PKG_PLATFORM_VERSION}"

export DEBIAN_FRONTEND="noninteractive"

apt-get update
apt-get install -y curl gnupg apt-transport-https jq

mkdir -p /usr/local/share/keyrings
curl --proto '=https' --tlsv1.2 -sSf \
    -o /usr/local/share/keyrings/gel-keyring.gpg \
    https://packages.geldata.com/keys/gel-keyring.gpg
echo deb [signed-by=/usr/local/share/keyrings/gel-keyring.gpg] \
    https://packages.geldata.com/apt "${dist}" main \
    > "/etc/apt/sources.list.d/gel.list"
if [ -n "${PKG_SUBDIST}" ]; then
    echo deb [signed-by=/usr/local/share/keyrings/gel-keyring.gpg] \
        https://packages.geldata.com/apt "${dist}" "${PKG_SUBDIST}" \
        > "/etc/apt/sources.list.d/gel-${PKG_SUBDIST}.list"
fi

try=1
while [ $try -le 30 ]; do
    apt-get update && apt-get install -y gel-cli && break || true
    try=$(( $try + 1 ))
    echo "Retrying in 10 seconds (try #${try})" >&2
    sleep 10
done

if ! type gel >/dev/null; then
    echo "could not install gel-cli" >&2
    exit $s
fi

if ! type edgedb; then
    ln -s gel /usr/bin/edgedb
fi

slot=
deb=
for pack in ${dest}/*.tar; do
    if [ -e "${pack}" ]; then
        slot=$(tar -xOf "${pack}" "build-metadata.json" \
               | jq -r ".version_slot")
        deb=$(tar -xOf "${pack}" "build-metadata.json" \
              | jq -r ".contents | keys[]" \
              | grep "^gel-server.*\\.deb$" \
              || true)
        if [ -n "${deb}" ]; then
            break
        fi
        deb=$(tar -xOf "${pack}" "build-metadata.json" \
              | jq -r ".contents | keys[]" \
              | grep "^edgedb-server.*\\.deb$" \
              || true)
        if [ -n "${deb}" ]; then
            break
        fi
    fi
done

if [ -z "${deb}" ]; then
    echo "${dest} does not seem to contain an {edgedb|gel}-server .deb" >&2
    exit 1
fi

if [ -z "${slot}" ]; then
    echo "could not determine version slot from build metadata" >&2
    exit 1
fi

machine=$(uname -m)
tmpdir=$(mktemp -d)
tar -x -C "${tmpdir}" -f "${pack}" "${deb}"
apt-get install -y "${tmpdir}/${deb}"
rm -rf "${tmpdir}"

if [[ $deb == *gel-server* ]]; then
    user="gel"
    server="gel-server-${slot}"
else
    user="edgedb"
    server="edgedb-server-${slot}"
fi

"$server" --version

if [ -n "${PKG_TEST_JOBS}" ]; then
    dash_j="-j${PKG_TEST_JOBS}"
else
    dash_j=""
fi
test_dir="/usr/share/${server}/tests"
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

cmd="/usr/lib/${machine}-linux-gnu/${server}/bin/python3 \
     -m edb.tools --no-devmode test \
     ${test_dir} ${test_select} \
     -e cqa_ -e tools_ ${test_exclude} \
     --verbose ${dash_j}"

if [ "$1" == "bash" ]; then
    echo su "$user" -c "$cmd"
    exec /bin/bash
else
    su "$user" -c "$cmd"
    echo "Success!"
fi
