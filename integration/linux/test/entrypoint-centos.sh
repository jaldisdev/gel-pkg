#!/bin/bash

set -ex

dest="artifacts"
if [ -n "${PKG_PLATFORM}" ]; then
    dest+="/${PKG_PLATFORM}"
fi
if [ -n "${PKG_PLATFORM_VERSION}" ]; then
    dest+="-${PKG_PLATFORM_VERSION}"
fi

source /etc/os-release

curl -fL https://packages.geldata.com/rpm/gel-rhel.repo \
    >/etc/yum.repos.d/gel.repo

if [ "${VERSION_ID}" = "7" ]; then
    # EPEL needed for jq on CentOS 7
    yum install -y \
        "https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
fi

try=1
while [ $try -le 30 ]; do
    yum makecache \
    && yum install --enablerepo=gel,gel-nightly --verbose -y gel-cli jq \
    && break || true
    try=$(( $try + 1 ))
    echo "Retrying in 10 seconds (try #${try})"
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
rpm=
for pack in ${dest}/*.tar; do
    if [ -e "${pack}" ]; then
        slot=$(tar -xOf "${pack}" "build-metadata.json" \
               | jq -r ".version_slot")
        rpm=$(tar -xOf "${pack}" "build-metadata.json" \
              | jq -r ".contents | keys[]" \
              | grep "^gel-server.*\\.rpm$" \
              || true)
        if [ -n "${rpm}" ]; then
            break
        fi
        rpm=$(tar -xOf "${pack}" "build-metadata.json" \
              | jq -r ".contents | keys[]" \
              | grep "^edgedb-server.*\\.rpm$" \
              || true)
        if [ -n "${rpm}" ]; then
            break
        fi
    fi
done

if [ -z "${rpm}" ]; then
    echo "${dest} does not seem to contain an {edgedb|gel}-server .rpm" >&2
    exit 1
fi

if [ -z "${slot}" ]; then
    echo "could not determine version slot from build metadata" >&2
    exit 1
fi

tmpdir=$(mktemp -d)
tar -x -C "${tmpdir}" -f "${pack}" "${rpm}"
yum install -y "${tmpdir}/${rpm}"
rm -rf "${tmpdir}"

if [[ $rpm == *gel-server* ]]; then
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
if [ -n "${PKG_TEST_FILES}" ]; then
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

cmd="/usr/lib64/${server}/bin/python3 \
     -m edb.tools --no-devmode test \
     ${test_files} ${test_select} \
     -e cqa_ -e tools_ ${test_exclude} \
     --verbose ${dash_j}"

if [ "$1" == "bash" ]; then
    echo su "$user" -c "$cmd"
    exec /bin/bash
else
    su "$user" -c "$cmd"
    echo "Success!"
fi
