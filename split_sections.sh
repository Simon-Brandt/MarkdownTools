#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-06-06

# Usage:
# bash split_sections.sh [--help | --usage | --version] input_file

# Purpose: Split the Markdown file by section in different files.

# Read and parse the arguments.
declare in_file

# shellcheck disable=SC2190  # Indexed, not associative array.
args=(
    "id      | val_names  | type | arg_no | arg_group            | help                   "
    "in_file | input_file | file |      1 | Positional arguments | the input Markdown file"
)
source argparser -- "$@"

# Source the functions.
source functions.sh

# Categorize the lines.
if [[ "${BASH_SOURCE[0]}" == */* ]]; then
    directory="${BASH_SOURCE[0]%/*}/"
else
    directory=""
fi

mapfile -t categories < <(bash "${directory}categorize_lines.sh" "${in_file}")
mapfile -t lines < "${in_file}"

# Get the sections (as filenames) of all headers.  Since upon splitting,
# they move to different files (perhaps even in different directories),
# the links in the Markdown file won't work correctly, anymore.  Thus,
# get all headers and convert their characters to links.  Since these
# are unique by definition, they can be used as keys of an associative
# array, mapping all headers to their sections.  This array can then be
# used to modify the hyperlinks, below.
shopt -s extglob

declare -A links
declare -A header_sections
for i in "${!lines[@]}"; do
    line="${lines[i]}"
    if [[ "${categories[i]}" == "section block" ]]; then
        # Get the current section.
        if [[ "${line}" =~ ^"<!-- <section file=\""(.*)"\"> -->"$ ]]; then
            file="${BASH_REMATCH[1]}"
        fi
    elif [[ "${categories[i]}" == "header"* ]]; then
        # Convert the header's characters to create a valid link.
        header="${line}"
        header_to_link "${header}"
        header_sections[${link}]="${file}"
    fi
done

# Split the file by section.
file=""
for i in "${!lines[@]}"; do
    line="${lines[i]}"
    if [[ "${categories[i]}" == "toc block" \
        || "${categories[i]}" == "hyperlink" ]]
    then
        # The line contains at least one hyperlink (possibly as part of
        # a table of contents).  Extract it, then shorten the line and
        # try to match the pattern on the remainder of the line.
        hyperlinks=( )
        remainder="${line}"
        while [[ "${remainder}" =~ \[[^\]]*?\]\(\#[^\)]*?\) ]]; do
            hyperlink="${BASH_REMATCH[0]}"
            hyperlinks+=("${hyperlink}")
            remainder="${remainder#*"${hyperlink}"}"
        done

        # Replace all hyperlinks by the new link targets and append the
        # line to the currently opened file.
        if [[ -n "${file}" ]]; then
            for hyperlink in "${hyperlinks[@]}"; do
                link="${hyperlink##*\(#}"
                link="${link%)}"

                traverse_path "${file}" "${header_sections[${link}]}"
                section="${traversed_path}"

                line="${line/"#${link}"/"${section}#${link}"}"
            done

            printf '%s\n' "${line}" >> "${file}"
        fi
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
