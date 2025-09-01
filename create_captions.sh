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
# bash create_captions.sh [--help | --usage | --version] input_file

# Purpose: Create figure and table captions for a Markdown file.

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

# Get the table-of-contents blocks, headings, and hyperlinks.
figure_index=0
table_index=0
is_caption=false
for i in "${!lines[@]}"; do
    if [[ "${categories[i]}" == "figure" || "${categories[i]}" == "table" ]]
    then
        is_caption=true
    elif [[ "${is_caption}" == false ]]; then
        continue
    fi

    line="${lines[i]}"
    if [[
        "${line}" =~ ^"<!-- <figure file=\""(.*)"\" caption=\""(.*)"\"> -->"$
    ]]
    then
        # The line denotes a figure caption and contains a filename and
        # caption text.  Extract these and add the caption to the
        # figure.  End the caption (not within the image's alt text) in
        # a period, if it doesn't end in a punctuation mark (".:!?").
        file="${BASH_REMATCH[1]}"
        figure_caption="${BASH_REMATCH[2]}"
        (( figure_index++ ))

        lines[i]+=$'\n'
        lines[i]+="![${figure_caption}](${file})"

        if [[ "${figure_caption}" =~ [^.:!?]$ ]]; then
            figure_caption+="."
        fi

        lines[i]+=$'\n'
        lines[i]+="*Fig. ${figure_index}: ${figure_caption}*"
    elif [[ "${line}" =~ ^"<!-- <table caption=\""(.*)"\"> -->"$ ]]; then
        # The line denotes a table caption and contains a caption text.
        # Extract this and add the caption to the table.  End the
        # caption in a period, if it doesn't end in a punctuation mark
        # (".:!?").
        table_caption="${BASH_REMATCH[1]}"
        (( table_index++ ))

        if [[ "${table_caption}" =~ [^.:!?]$ ]]; then
            table_caption+="."
        fi

        lines[i]+=$'\n'
        lines[i]+="*Tab. ${table_index}: ${table_caption}*"
    elif [[ -z "${line}" ]]; then
        # The line is empty and ends a figure or table caption.
        is_caption=false
    else
        # The line contains the previously added caption.
        unset 'lines[i]'
    fi
done

# Join the (now sparse) array of lines and write it back to the input
# file, as if acting in-place.
printf '%s\n' "${lines[@]}" > "${in_file}"
