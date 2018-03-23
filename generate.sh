#!/bin/bash

# Copyright 2017 GRAIL, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Generates a compile_commands.json file at $(bazel info workspace) for
# libclang based tools.

# This is inspired from
# https://github.com/google/kythe/blob/master/tools/cpp/generate_compilation_database.sh

set -e
#set -v

readonly ASPECTS_DIR="$(dirname "$0")"
readonly ASPECTS_FILE="${ASPECTS_DIR}/aspects.bzl"
readonly OUTPUT_GROUPS="compdb_files"

readonly WORKSPACE="$(bazel info workspace)"
readonly WORKSPACE_BASE="$(basename ${WORKSPACE})"
readonly EXEC_ROOT="$(bazel info execution_root)"
readonly COMPDB_FILE="${ASPECTS_DIR}/compile_commands.json"

while getopts "h" args; do
    case $args in
        h)
            echo "Usage: $0 [list of space separated bazel targets e.g. //:rae]"
            exit 0
            ;;
    esac
done

if [[ $0 == ./* ]]; then
    echo "Call me like this: `echo $0 | cut -c 3-`"
    exit 0
fi

# Clean any previously generated files.
find "${EXEC_ROOT}" -name '*.compile_commands.json' -delete

# shellcheck disable=SC2046
echo "Analyzing targets:"
if (( $# < 1 )); then
    readonly QUERY_CMD=(
        bazel query
        'kind("cc_(library|binary|test)", //...)'
    )

    echo $("${QUERY_CMD[@]}")
    bazel build \
          --aspects="${ASPECTS_FILE}"%compilation_database_aspect \
          --output_groups="${OUTPUT_GROUPS}" \
            $("${QUERY_CMD[@]}")
else
    echo "$@"
    bazel build \
          --aspects="${ASPECTS_FILE}"%compilation_database_aspect \
          --output_groups="${OUTPUT_GROUPS}" \
          "$@"
fi

echo "[" > "${COMPDB_FILE}"
find "${EXEC_ROOT}" -name '*.compile_commands.json' -exec bash -c 'cat "$1" && echo ,' _ {} \; \
  >> "${COMPDB_FILE}"
sed -i.bak -e '/^,$/d' -e '$s/,$//' "${COMPDB_FILE}"  # Hygiene to make valid json
sed -i.bak -e "s|__WORKSPACE_ROOT__|${WORKSPACE}/bazel-${WORKSPACE_BASE}|" "${COMPDB_FILE}"  # Replace workspace_root marker
rm "${COMPDB_FILE}.bak"
echo "]" >> "${COMPDB_FILE}"

ln -f -s "${COMPDB_FILE}" "${WORKSPACE}/"
# ln -f -s "${COMPDB_FILE}" "${EXEC_ROOT}/"
