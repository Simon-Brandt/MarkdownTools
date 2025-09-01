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
# source functions.sh

# Purpose: Define common functions for the scripts.

function heading_to_title() {
    # Convert a heading's characters to create a valid title.
    #
    # Arguments:
    # - $1: the heading to create the title for
    #
    # Globals:
    # - title: the created title

    local heading

    # Remove the leading and trailing spaces, the leading hashmarks and
    # the spaces following them, as well as possibly the number, from
    # the title.
    heading="$1"
    title="${heading}"
    if [[ "${title}" =~ ^(#+)( )([[:digit:]]+\.)+( )(.*) \
        || "${title}" =~ ^(#+)( )(.*) ]]
    then
        title="${BASH_REMATCH[-1]}"
    fi
    title="${title%%+( )}"
}

function heading_to_link() {
    # Convert a heading's characters to create a valid link.
    #
    # Arguments:
    # - $1: the heading to create the link for
    #
    # Globals:
    # - link: the created link
    # - links: the associative array of all links created, yet

    local heading

    # Create the link according to the specification.
    heading="$1"
    link="${heading}"
    link="${link##+(#)}"              # Remove leading hashmarks.
    link="${link##+( )}"              # Remove leading spaces.
    link="${link%%+( )}"              # Remove trailing spaces.
    link="${link//[^[:alnum:] _-]/}"  # Remove any punctuation but "_" and "-".
    link="${link// /-}"               # Replace spaces with hyphens.
    link="${link@L}"                  # Make all characters lowercase.

    # Check if the link is unique, else, append an integer.

    # shellcheck disable=SC2004  # Associative from caller (sourcer).
    if [[ -v links["${link}"] ]]; then
        (( links[${link}]++ ))
        link="${link}-${links[${link}]}"
    else
        links[${link}]=0
    fi
}

function traverse_path() {
    # Traverse the directory structure between two filepaths.  These may
    # be given as absolute paths or relative to the same stem directory.
    # If either is absolute, the traversed filepath is the ending path.
    #
    # Arguments:
    # - $1: the filepath where to start the traversal
    # - $2: the filepath where to end the traversal
    #
    # Globals:
    # - traversed_path: the traversed filepath

    local directories_end
    local directories_start
    local i
    local start
    local end

    # Trim the possibly included trailing slash off both paths.
    start="${1%/}"
    end="${2%/}"

    # Return the empty string if both paths are identical, or the ending
    # path if either is given as absolute path (with a leading slash).
    if [[ "${start}" == "${end}" ]]; then
        traversed_path=""
        return
    elif [[ "${start::1}" == "/" || "${end::1}" == "/" ]]; then
        traversed_path="${end}"
        return
    fi

    # Read both paths into indexed array by component, slash-delimited.
    # Remove each common component, until the first difference, then
    # re-read the arrays to remove the empty indices for the loops
    # below.
    IFS="/" read -r -a directories_start <<< "${start}"
    IFS="/" read -r -a directories_end <<< "${end}"

    i=0
    while [[ "${directories_start[i]}" == "${directories_end[i]}" ]]; do
        unset 'directories_start[i]'
        unset 'directories_end[i]'
        (( i++ ))
    done
    directories_start=("${directories_start[@]}")
    directories_end=("${directories_end[@]}")

    # Traverse the directory structure.  For each component in the
    # starting path (without the now removed common components),
    # excluding the last one (which is the filename of the starting
    # file), go upwards by one directory.  Then, for each component in
    # the ending path, excluding the last one, go down by one directory.
    # Finally, add the filename of the ending file.
    traversed_path=""
    for (( i = 0; i < "${#directories_start[@]}" - 1; i++ )); do
        traversed_path+="../"
    done
    for (( i = 0; i < "${#directories_end[@]}" - 1; i++ )); do
        traversed_path+="${directories_end[i]}/"
    done
    traversed_path+="${directories_end[-1]}"
}

function update_hyperlinks() {
    # Update all hyperlinks in the line to point to the correct target
    # when a file has moved.
    #
    # Arguments:
    # - $1: the line whose hyperlinks to update
    # - $2: the current file
    #
    # Globals:
    # - heading_files: the file each heading has moved to (optional,
    #   only used when the calling script splits files by section)
    # - line: The line whose hyperlinks to update

    local file
    local link
    local -a links
    local remainder
    local traversed_path

    line="$1"
    file="$2"

    # The line contains at least one hyperlink (possibly as part of a
    # table of contents).  Extract it, then shorten the line and try to
    # match the pattern on the remainder of the line.  Ignore hyperlinks
    # to the Web, using "http://" or "https://" as prefix.
    links=( )
    remainder="${line}"
    while [[ "${remainder}" =~ \[[^\]]*?\]\([^\)\#]*?(\#[^\)]*?)?\) ]]; do
        link="${BASH_REMATCH[0]}"

        if [[ ! "${link}" =~ https?:// ]]; then
            links+=("${link}")
        fi

        remainder="${remainder#*"${link}"}"
    done

    # For each hyperlink, extract the link part and update it in-place.
    # In order to prevent the replacement from replacing the link text,
    # instead of the link itself, when both are identical, replace the
    # surrounding parentheses as well, just by themselves.
    for link in "${links[@]}"; do
        link="${link#*]\(}"
        link="${link%)}"

        if [[ "${link::1}" == "#" ]]; then
            # The link points to a heading in the source file.  Update
            # it to point to the target file.

            # shellcheck disable=SC2154  # Global variables are set by caller.
            if [[ "${heading_files@a}" =~ "A" ]]; then
                traverse_path "${file}" "${heading_files[${link#*\#}]}"
                line="${line/"(#${link#*\#})"/"(${traversed_path}#${link#*\#})"}"
            fi
        elif [[ "${link}" =~ "#" ]]; then
            # The link points to a heading in another file.  Update it
            # to the correct path between this file and the target file.
            traverse_path "${file}" "${link%%\#*}"
            line="${line/"(${link%%\#*})"/"(${traversed_path})"}"
        else
            # The link points to another file.  Update it to the correct
            # path between this file and the target file.
            traverse_path "${file}" "${link}"
            line="${line/"(${link})"/"(${traversed_path})"}"
        fi
    done
}

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
    # from the current file to the section's file.

    # shellcheck disable=SC2154  # Global variables are set by caller.
    heading="${section_headings[${section}]##+(#) }"
    traverse_path "${file}" "${section}"
    section="${traversed_path}"

    # shellcheck disable=SC2034  # Global variable is used by caller.
    # shellcheck disable=SC2154  # Global variables are set by caller.
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
