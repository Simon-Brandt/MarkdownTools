#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-06-05

# Usage:
# bash include_file.sh [--help | --usage | --version] input_file

# Purpose: Include a file in the Markdown file.

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
    directory="${BASH_SOURCE[0]%/*}/"
else
    directory=""
fi

mapfile -t categories < <(bash "${directory}categorize_lines.sh" "${in_file}")
mapfile -t lines < "${in_file}"

# Include the files and command outputs.
for i in "${!lines[@]}"; do
    if [[ "${categories[i]}" != "include block" ]]; then
        continue
    fi

    line="${lines[i]}"
    if [[
        "${line}" =~ ^"<!-- <include file=\""(.*)"\" lang=\""(.*)"\"> -->"$
    ]]
    then
        # The line denotes the start of the include block and contains a
        # filename and language specification.
        filename="${BASH_REMATCH[1]}"
        language="${BASH_REMATCH[2]}"

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

        lines[i]+=$'\n'
        lines[i]+="\`\`\`${language}"

        if [[ "${language}" == "console" ]]; then
            lines[i]+=$'\n'
            lines[i]+="\$ ${command}"
        fi

        lines[i]+=$'\n'
        lines[i]+="$(eval "${command}" 2>&1)"

        if [[ "${lines[i]}" =~ $'\n'"<!-- </include> -->"$ ]]; then
            lines[i]="${lines[i]//$'\n'/& }"
        fi

        lines[i]+=$'\n'
        lines[i]+="\`\`\`"
    elif [[ "${line}" =~ ^"<!-- <include command=\""(.*)"\"> -->"$ ]]; then
        # The line denotes the start of the include block and contains a
        # command.
        command="${BASH_REMATCH[1]}"
        lines[i]+=$'\n'
        lines[i]+="$(eval "${command}" 2>&1)"

        if [[ "${lines[i]}" =~ $'\n'"<!-- </include> -->"$ ]]; then
            lines[i]="${lines[i]//$'\n'/& }"
        fi
    elif [[ "${line}" != "<!-- </include> -->" ]]; then
        # The line contains the previously included file's contents and
        # does not denote the end of the include block.
        unset 'lines[i]'
    fi
done

# Join the (now sparse) array of lines and write it back to the input
# file, as if acting in-place.
printf '%s\n' "${lines[@]}" > "${in_file}"
