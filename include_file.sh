#!/usr/bin/env bash

###############################################################################
#                                                                             #
# Copyright 2025 Simon Brandt                                                 #
#                                                                             #
# Licensed under the Apache License, Version 2.0 (the "License");             #
# you may not use this file except in compliance with the License.            #
# You may obtain a copy of the License at                                     #
#                                                                             #
#     http://www.apache.org/licenses/LICENSE-2.0                              #
#                                                                             #
# Unless required by applicable law or agreed to in writing, software         #
# distributed under the License is distributed on an "AS IS" BASIS,           #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.    #
# See the License for the specific language governing permissions and         #
# limitations under the License.                                              #
#                                                                             #
###############################################################################

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-09-01

# Usage:
# bash include_file.sh [--help | --usage | --version] input_file

# Purpose: Include a file in the Markdown file.

# Remove the temporary file on regular exits.
trap 'rm --force "${tmpfile}"' EXIT

# Read and parse the arguments.
declare in_file

# shellcheck disable=SC2190  # Indexed, not associative array.
args=(
    "id      | val_names  | type | arg_no | arg_group            | help                   "
    "in_file | input_file | file |      1 | Positional arguments | the input Markdown file"
)
source argparser -- "$@"

# Categorize the lines.
if [[ "${BASH_SOURCE[0]}" == */* ]]; then
    directory="${BASH_SOURCE[0]%/*}"
else
    directory="."
fi

source "${directory}/categorize_lines.sh" "${in_file}"
mapfile -t lines < "${in_file}"

# Create a temporary file for storing intermediate files and command
# outputs when transforming Markdown hyperlinks.
tmpfile="$(mktemp)"

# Include the files and command outputs.
include_nestedness=0
is_normal_include_block=false
for i in "${!lines[@]}"; do
    # Only include files and command outputs for include block lines,
    # except when in a normal (non-verbatim) include block.
    if [[ "${categories[i]}" == "normal include block" ]]; then
        is_normal_include_block=true
    elif [[ "${categories[i]}" != *"include block" \
        && "${is_normal_include_block}" == false ]]
    then
        continue
    fi

    # If the include nestedness is greater than zero, only increment or
    # decrement it, depending on the line's contents, then unset it.
    # Don't include the actual requested file or command output, which
    # would need to be done separately for the file which is about to be
    # included.  This prevents infinite regression, when file A includes
    # file B, and vice versa.
    line="${lines[i]}"
    if (( "${include_nestedness}" > 0 )) \
        && [[ "${line}" =~ ^"<!-- <include "(.*)"> -->"$ ]]
    then
        (( include_nestedness++ ))
        unset 'lines[i]'
        continue
    elif (( "${include_nestedness}" > 1 )) \
        && [[ "${line}" == "<!-- </include> -->" ]]
    then
        (( include_nestedness-- ))
        unset 'lines[i]'
        continue
    fi

    # At this point, the include nestedness is guaranteed to be zero, so
    # include the file or command output as appropriate.
    if [[
        "${line}" =~ ^"<!-- <include file=\""(.*)"\" lang=\""(.*)"\"> -->"$
    ]]
    then
        # The line denotes the start of the include block and contains a
        # filename and language specification.
        filename="${BASH_REMATCH[1]}"
        language="${BASH_REMATCH[2]}"
        (( include_nestedness++ ))

        lines[i]+=$'\n'
        lines[i]+="\`\`\`${language}"

        lines[i]+=$'\n'
        lines[i]+="$(< "${filename}")"

        lines[i]+=$'\n'
        lines[i]+="\`\`\`"
    elif [[ "${line}" =~ ^"<!-- <include file=\""(.*)"\"> -->"$ ]]; then
        # The line denotes the start of the include block and contains a
        # filename.
        filename="${BASH_REMATCH[1]}"
        (( include_nestedness++ ))

        lines[i]+=$'\n'
        lines[i]+="$(< "${filename}")"
    elif [[
        "${line}" =~ ^"<!-- <include command=\""(.*)"\" lang=\""(.*)"\"> -->"$
    ]]
    then
        # The line denotes the start of the include block and contains a
        # command and language specification.
        command="${BASH_REMATCH[1]}"
        language="${BASH_REMATCH[2]}"
        (( include_nestedness++ ))

        lines[i]+=$'\n'
        lines[i]+="\`\`\`${language}"

        if [[ "${language}" == "console" ]]; then
            lines[i]+=$'\n'
            lines[i]+="\$ ${command}"
        fi

        lines[i]+=$'\n'
        lines[i]+="$(eval "${command}" 2>&1)"

        lines[i]+=$'\n'
        lines[i]+="\`\`\`"
    elif [[
        "${line}" =~ ^"<!-- <include command=\""(.*)"\" md-file=\""(.*)"\"> -->"$
    ]]
    then
        # The line denotes the start of the include block and contains a
        # command using a Markdown file.  Run the command, writing its
        # output to a temporary file.  Then, run a subshell categorizing
        # each line in the created Markdown file and updating all
        # hyperlinks to point to the correct target, since the including
        # file is likely in a different location than the file the
        # command ran over.  Finally, read the modified temporary file's
        # contents and append them to the input file's lines.
        command="${BASH_REMATCH[1]}"
        filename="${BASH_REMATCH[2]}"
        (( include_nestedness++ ))

        eval "${command}" > "${tmpfile}" 2>&1

        cat << EOF | bash
            source "${directory}/functions.sh"
            source "${directory}/categorize_lines.sh" "${tmpfile}"
            mapfile -t lines < "${tmpfile}"

            for i in "\${!lines[@]}"; do
                if [[ "\${categories[i]}" == "hyperlink" ]]; then
                    line="\${lines[i]}"
                    update_hyperlinks "\${line}" "${filename}"
                    lines[i]="\${line}"
                fi
            done

            printf '%s\n' "\${lines[@]}" > "${tmpfile}"
EOF
        command_output="$(< "${tmpfile}")"

        lines[i]+=$'\n'
        lines[i]+="${command_output}"
    elif [[ "${line}" =~ ^"<!-- <include command=\""(.*)"\"> -->"$ ]]; then
        # The line denotes the start of the include block and contains a
        # command.
        command="${BASH_REMATCH[1]}"
        (( include_nestedness++ ))

        lines[i]+=$'\n'
        lines[i]+="$(eval "${command}" 2>&1)"
    elif [[ "${line}" == "<!-- </include> -->" ]]; then
        # The line denotes the end of the include block.
        (( include_nestedness-- ))
        is_normal_include_block=false
    else
        # The line contains the previously included file's contents.
        unset 'lines[i]'
    fi
done

# Join the (now sparse) array of lines and write it back to the input
# file, as if acting in-place.
printf '%s\n' "${lines[@]}" > "${in_file}"
