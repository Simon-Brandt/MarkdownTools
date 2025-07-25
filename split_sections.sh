#!/bin/bash

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
# Last Modification: 2025-07-25

# Usage:
# bash split_sections.sh [--help | --usage | --version]
#                        [--to-files]
#                        [--to-headings]
#                        input_file

# Purpose: Split the Markdown file by section in different files.

function get_link_text() {
    # Set the link text as either the heading, the section, or both.
    # Surround the section with backticks as Markdown code formatting.
    #
    # Arguments:
    # - $1: the section to create the link text for
    # - $2: the current file
    #
    # Globals:
    # - link_text: the created link text
    # - link_to_files: whether to use the section's filename for the
    #   link text (read-only)
    # - link_to_headings: whether to use the first heading for the link
    #   text (read-only)
    # - section: the section's traversed filepath
    # - section_headings: the associative array of all sections' first
    #   headings (read-only)

    local file

    section="$1"
    file="$2"

    # Get the first heading in the given section, and the full filepath
    # from the current file to the section's file
    heading="${section_headings[${section}]##+(#) }"
    traverse_path "${file}" "${section}"
    section="${traversed_path}"

    if [[ "${link_to_files}" == true \
        && "${link_to_headings}" == true ]]
    then
        link_text="${heading} (\`${section}\`)"
    elif [[ "${link_to_files}" == true ]]; then
        link_text="\`${section}\`"
    elif [[ "${link_to_headings}" == true ]]; then
        link_text="${heading}"
    else
        link_text=""
    fi
}

# Read and parse the arguments.
declare in_file
declare link_to_files
declare link_to_headings

# shellcheck disable=SC2190  # Indexed, not associative array.
args=(
    "id               | short_opts | long_opts   | val_names  | defaults | type | arg_no | arg_group            | help                                              "
    "in_file          |            |             | input_file |          | file |      1 | Positional arguments | the input Markdown file                           "
    "link_to_files    | f          | to-files    |            | false    | bool |      0 | Options              | use the filename as link text on section ends     "
    "link_to_headings | h          | to-headings |            | false    | bool |      0 | Options              | use the first heading as link text on section ends"
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
        # a table of contents).  Extract it, then shorten the line and
        # try to match the pattern on the remainder of the line.  Ignore
        # hyperlinks to the Web, using "http://" or "https://" as
        # prefix.
        hyperlinks=( )
        remainder="${line}"
        while [[ "${remainder}" =~ \[[^\]]*?\]\([^\)\#]*?(\#[^\)]*?)?\) ]]; do
            hyperlink="${BASH_REMATCH[0]}"

            if [[ ! "${hyperlink}" =~ https?:// ]]; then
                hyperlinks+=("${hyperlink}")
            fi

            remainder="${remainder#*"${hyperlink}"}"
        done

        # If a file is "open" (i.e., the section should move to a file),
        # replace all hyperlinks by the new link targets and append the
        # line to the currently opened file.
        if [[ -z "${file}" ]]; then
            continue
        fi

        for hyperlink in "${hyperlinks[@]}"; do
            link="${hyperlink#*]\(}"
            link="${link%)}"

            if [[ "${link::1}" == "#" ]]; then
                # The link points to a heading in the source file.
                # Update it to point to the target file.
                traverse_path "${file}" "${heading_files[${link#*\#}]}"
                line="${line/"#${link#*\#}"/"${traversed_path}#${link#*\#}"}"
            elif [[ "${link}" =~ "#" ]]; then
                # The link points to a heading in another file.  Update
                # it to the correct path between this file and the
                # target file.
                traverse_path "${file}" "${link%%\#*}"
                line="${line/"${link%%\#*}"/"${traversed_path}"}"
            else
                # The link points to another file.  Update it to the
                # correct path between this file and the target file.
                traverse_path "${file}" "${link}"
                line="${line/"${link}"/"${traversed_path}"}"
            fi
        done

        printf '%s\n' "${line}" >> "${file}"
    elif [[ "${line}" =~ ^"<!-- <section file=\""(.*)"\"> -->"$ ]]; then
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
