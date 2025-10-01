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
# Last Modification: 2025-10-01

# Usage:
# bash split_sections.sh [--help | --usage | --version]
#                        [--to-files]
#                        [--to-headings]
#                        input_file

# Purpose: Split the Markdown file by section in different files.

# Read and parse the arguments.
declare in_file
declare link_to_files
declare link_to_headings
declare remove_dirs
declare remove_files

ARGPARSER_ALLOW_ARG_INTERMIXING=true

# shellcheck disable=SC2190  # Indexed, not associative array.
args=(
    "id               | short_opts | long_opts   | val_names  | defaults | type | arg_no | arg_group            | help                                                                 "
    "in_file          |            |             | input_file |          | file |      1 | Positional arguments | the input Markdown file                                              "
    "link_to_files    | f          | to-files    |            | false    | bool |      0 | Options              | use the filename as link text on section ends                        "
    "link_to_headings | h          | to-headings |            | false    | bool |      0 | Options              | use the first heading as link text on section ends                   "
    "remove_dirs      |            | rm-dirs     |            | false    | bool |      0 | Options              | remove all (sub-)directories from the CWD, for a clean start         "
    "remove_files     |            | rm-files    |            | false    | bool |      0 | Options              | remove all files in the CWD, except for input_file, for a clean start"
)
source argparser -- "$@"

# Source the functions and categorize the lines.
if [[ "${BASH_SOURCE[0]}" == */* ]]; then
    directory="${BASH_SOURCE[0]%/*}"
else
    directory="."
fi

source "${directory}/functions.sh"
source "${directory}/categorize_lines.sh" "${in_file}"
mapfile -t lines < "${in_file}"

# Possibly, remove the directories and/or all files other than the input
# file in the CWD.
if [[ "${in_file}" == */* ]]; then
    file_dir="${in_file%/*}"
else
    file_dir="."
fi

if [[ "${remove_dirs}" == true ]]; then
    for dir in "${file_dir}"/*; do
        if [[ -d "${dir}" ]]; then
            rm --recursive "${dir}"
        fi
    done
fi

if [[ "${remove_files}" == true ]]; then
    for file in "${file_dir}"/*; do
        if [[ -f "${file}" && "${file}" != "${in_file}" ]]; then
            rm "${file}"
        fi
    done
fi

# If the first line starts a comment block, extract it to prepend it to
# each file after splitting.  This comment may e.g. include a license
# note, which must occur in any split file.  Ignore any other comment
# block.
file_comment=""
i=0
while [[ "${categories[i]}" == "comment block" ]]; do
    file_comment+="${lines[i]}"
    file_comment+=$'\n'
    (( i++ ))
done

# Get the sections (as filenames) of all headings.  Since upon
# splitting, they move to different files (perhaps even in different
# directories), the links in the Markdown file won't work correctly,
# anymore.  Thus, get all headings and convert their characters to
# links.  Since these are unique by definition, they can be used as keys
# of an associative array, mapping all headings to their sections.  This
# array can then be used to modify the hyperlinks, below.  Additionally,
# save the first heading for each section to link to them in each
# section's end.
shopt -s extglob

declare -A heading_files
declare -A links
declare -A section_headings
file=""
sections=( )
for i in "${!lines[@]}"; do
    line="${lines[i]}"
    if [[ "${categories[i]}" == "section block" ]]; then
        # Get the current section.
        if [[ "${line}" =~ ^"<!-- <section file=\""(.*)"\"> -->"$ ]]; then
            file="${BASH_REMATCH[1]}"
            sections+=("${file}")
        fi
    elif [[ "${categories[i]}" == "heading"* ]]; then
        # Convert the heading's characters to create a valid link.
        heading="${line}"
        heading_to_link "${heading}"
        heading_files[${link}]="${file}"

        # Add the heading to the array.
        if [[ ! -v "section_headings[${file}]" ]]; then
            section_headings[${file}]="${heading}"
        fi
    fi
done

# Split the file by section.
file=""
section_index=-1
for i in "${!lines[@]}"; do
    line="${lines[i]}"
    if [[ "${categories[i]}" == "toc block" \
        || "${categories[i]}" == "hyperlink" ]]
    then
        # The line contains at least one hyperlink (possibly as part of
        # a table of contents).  If a file is "open" (i.e., the section
        # should move to a file), replace all hyperlinks by the new link
        # targets and append the line to the currently opened file.
        if [[ -n "${file}" ]]; then
            update_hyperlinks "${line}" "${file}"
            printf '%s\n' "${line}" >> "${file}"
        fi
    elif [[ "${line}" =~ ^"<!-- <section file=\""(.*)"\"> -->"$ ]]; then
        # The line denotes the start of the section block and contains a
        # filename.  If the filename contains a slash, it is interpreted
        # as directory component.  Create this directory, if necessary.
        file="${BASH_REMATCH[1]}"

        if [[ "${file}" == */* ]]; then
            mkdir --parents "${file%/*}"
        fi

        # If a leading comment block was given, write it to the file.
        # The redirection syntax intentionally overwrites the file's
        # contents, if it exists, since the new contents will be
        # appended, below, thus keeping the old contents, else.
        if [[ -n "${file_comment}" ]]; then
            printf '%s\n' "${file_comment}"
        fi > "${file}"

        (( section_index++ ))
    elif [[ "${line}" == "<!-- </section> -->" ]]; then
        # The line denotes the end of the section block.  Add a
        # hyperlink to the previous and next sections, then reset the
        # filename, meaning afterwards not to write to a file.

        # shellcheck disable=SC2094  # Only writing to file and using filename.
        {
            printf '\n'
            if (( section_index == 0 )); then
                # The section is the first, so print only the link to
                # the next section.
                section="${sections[section_index + 1]}"
                get_link_text "${section}" "${file}"

                printf '[%s&nbsp;&#129094;](%s)\n' "${link_text}" \
                    "${section}"
            elif (( section_index == "${#sections[@]}" - 1 )); then
                # The section is the last, so print only the link to
                # the previous section.
                section="${sections[section_index - 1]}"
                get_link_text "${section}" "${file}"

                printf '[&#129092;&nbsp;%s](%s)\n' "${link_text}" \
                    "${section}"
            else
                # The section is in-between, so print the links to the
                # previous and next sections.
                section="${sections[section_index - 1]}"
                get_link_text "${section}" "${file}"

                printf '[&#129092;&nbsp;%s](%s)\n' "${link_text}" \
                    "${section}"

                for (( j = 0; j < 10; j++ )); do
                    printf '&nbsp;'
                done

                section="${sections[section_index + 1]}"
                get_link_text "${section}" "${file}"

                printf '[%s&nbsp;&#129094;](%s)\n' "${link_text}" \
                    "${section}"
            fi
        } >> "${file}"

        file=""
    else
        # The line contains the section's content.  Append it to the
        # currently opened file.
        if [[ -n "${file}" ]]; then
            printf '%s\n' "${line}" >> "${file}"
        fi
    fi
done
