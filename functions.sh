#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-06-16

# Usage:
# source functions.sh

# Purpose: Define common functions for the scripts.

function heading_to_title() {
    # Convert a heading's characters to create a valid title.
    #
    # Arguments:
    # - $1: the heading to create the title for
    #
    # Nonlocals:
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
    # Nonlocals:
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
    # Nonlocals:
    # - traversed_path: the traversed filepath

    local directories_end
    local directories_start
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
