#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "mkdockerfile.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM centos:8
RUN /bin/echo -e '#!/bin/bash\n\
\n\
set -ex\n\
\n\
trim() {\n\
    printf '\''%s'\'' "$1" | sed '\''s/^[[:space:]]*//;s/[[:space:]]*$//'\''\n\
}\n\
\n\
dest="artifacts"\n\
if [ -n "${PKG_PLATFORM}" ]; then\n\
    dest+="/${PKG_PLATFORM}"\n\
fi\n\
if [ -n "${PKG_PLATFORM_VERSION}" ]; then\n\
    dest+="-${PKG_PLATFORM_VERSION}"\n\
fi\n\
\n\
source /etc/os-release\n\
\n\
curl -fL https://packages.geldata.com/rpm/gel-rhel.repo \\\n\
    >/etc/yum.repos.d/gel.repo\n\
\n\
if [ "${VERSION_ID}" = "7" ]; then\n\
    # EPEL needed for jq on CentOS 7\n\
    yum install -y \\\n\
        "https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"\n\
fi\n\
\n\
try=1\n\
while [ $try -le 30 ]; do\n\
    yum makecache \\\n\
    && yum install --enablerepo=gel,gel-nightly --verbose -y gel-cli jq \\\n\
    && break || true\n\
    try=$(( $try + 1 ))\n\
    echo "Retrying in 10 seconds (try #${try})"\n\
    sleep 10\n\
done\n\
\n\
if ! type gel >/dev/null; then\n\
    echo "could not install gel-cli" >&2\n\
    exit $s\n\
fi\n\
\n\
if ! type edgedb; then\n\
    ln -s gel /usr/bin/edgedb\n\
fi\n\
\n\
slot=\n\
rpm=\n\
for pack in ${dest}/*.tar; do\n\
    if [ -e "${pack}" ]; then\n\
        slot=$(tar -xOf "${pack}" "build-metadata.json" \\\n\
               | jq -r ".version_slot")\n\
        rpm=$(tar -xOf "${pack}" "build-metadata.json" \\\n\
              | jq -r ".contents | keys[]" \\\n\
              | grep "^gel-server.*\\.rpm$" \\\n\
              || true)\n\
        if [ -n "${rpm}" ]; then\n\
            break\n\
        fi\n\
        rpm=$(tar -xOf "${pack}" "build-metadata.json" \\\n\
              | jq -r ".contents | keys[]" \\\n\
              | grep "^edgedb-server.*\\.rpm$" \\\n\
              || true)\n\
        if [ -n "${rpm}" ]; then\n\
            break\n\
        fi\n\
    fi\n\
done\n\
\n\
if [ -z "${rpm}" ]; then\n\
    echo "${dest} does not seem to contain an {edgedb|gel}-server .rpm" >&2\n\
    exit 1\n\
fi\n\
\n\
if [ -z "${slot}" ]; then\n\
    echo "could not determine version slot from build metadata" >&2\n\
    exit 1\n\
fi\n\
\n\
tmpdir=$(mktemp -d)\n\
tar -x -C "${tmpdir}" -f "${pack}" "${rpm}"\n\
yum install -y "${tmpdir}/${rpm}"\n\
rm -rf "${tmpdir}"\n\
\n\
if [[ $rpm == *gel-server* ]]; then\n\
    user="gel"\n\
    server="gel-server-${slot}"\n\
else\n\
    user="edgedb"\n\
    server="edgedb-server-${slot}"\n\
fi\n\
\n\
"$server" --version\n\
\n\
if [ -n "${PKG_TEST_JOBS}" ]; then\n\
    dash_j="-j${PKG_TEST_JOBS}"\n\
else\n\
    dash_j=""\n\
fi\n\
test_dir="/usr/share/${server}/tests"\n\
test_files="$test_dir"\n\
if [ -n "$(trim "${PKG_TEST_FILES}")" ]; then\n\
    # ${PKG_TEST_FILES} is specificaly used outside the quote so that it\n\
    # can contain a glob.\n\
    test_files=$(cd "$test_dir" && realpath $PKG_TEST_FILES)\n\
fi\n\
test_select=""\n\
if [ -n "${PKG_TEST_SELECT}" ]; then\n\
    for pattern in $PKG_TEST_SELECT; do\n\
      test_select="$test_select --include=${pattern}"\n\
    done\n\
fi\n\
test_exclude=""\n\
if [ -n "${PKG_TEST_EXCLUDE}" ]; then\n\
    for pattern in $PKG_TEST_EXCLUDE; do\n\
      test_exclude="$test_exclude --exclude=${pattern}"\n\
    done\n\
fi\n\
\n\
cmd="/usr/lib64/${server}/bin/python3 \\\n\
     -m edb.tools --no-devmode test \\\n\
     ${test_files} ${test_select} \\\n\
     -e cqa_ -e tools_ ${test_exclude} \\\n\
     --verbose ${dash_j}"\n\
\n\
if [ "$1" == "bash" ]; then\n\
    echo su "$user" -c "$cmd"\n\
    exec /bin/bash\n\
else\n\
    su "$user" -c "$cmd"\n\
    echo "Success!"\n\
fi\n\' >/entrypoint.sh

RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# rpm on centos 7 iterates over all fds up to the limit, which is
# extremely slow. Force it to be small with ulimit.
#
# We need to disable the mirrorlist and explicitly set up a
# baseurl. Switch to the archive.kernel.org mirror while we are at it.
RUN ulimit -n 1024 \
    && sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* \
    && sed -i 's|# \?baseurl=http://mirror.centos.org|baseurl=https://archive.kernel.org/centos-vault/|g' /etc/yum.repos.d/CentOS-* \
    && yum update -y
