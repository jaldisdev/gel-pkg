#!/usr/bin/env bash

echo "export PATH=${SCCACHE_LINKS}:"'$PATH'
echo "export RUSTC_WRAPPER=${SCCACHE}"
echo "export ACTIONS_RESULTS_URL=$(cat /run/secrets/ACTIONS_RESULTS_URL)"
echo "export ACTIONS_RUNTIME_TOKEN=$(cat /run/secrets/ACTIONS_RUNTIME_TOKEN)"
