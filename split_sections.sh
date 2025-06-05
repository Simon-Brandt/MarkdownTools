#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-06-05

# Usage:
# bash include_file.sh [--help | --usage | --version] input_file

# Purpose: Split the Markdown file by section in different files.

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

# Split the file by section.
for i in "${!lines[@]}"; do
    if [[ "${categories[i]}" != "section block" ]]; then
        continue
    fi

    line="${lines[i]}"
    if [[ "${line}" =~ ^"<!-- <section file=\""(.*)"\"> -->"$ ]]; then
        # The line denotes the start of the section block and contains a
        # filename.  If the filename contains a slash, it is interpreted
        # as directory component.  Create this directory.  If the file
        # already exists, remove it since the contents will be appended,
        # below, thus keeping the old contents.
        file="${BASH_REMATCH[1]}"

        if [[ "${file}" == */* ]]; then
            mkdir --parents "${file%/*}"
        fi

        if [[ -e "${file}" ]]; then
            rm "${file}"
        fi
    elif [[ "${line}" == "<!-- </section> -->" ]]; then
        # The line denotes the end of the section block.  Reset the
        # filename, meaning currently not to write to a file.
        file=""
    else
        # The line contains the section's content.  Append it to the
        # currently opened file.
        if [[ -n "${file}" ]]; then
            printf '%s\n' "${line}" >> "${file}"
        fi
    fi
done
