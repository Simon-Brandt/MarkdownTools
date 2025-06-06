#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-06-06

# Usage:
# source functions.sh

# Purpose: Define common functions for the scripts.

function header_to_title() {
    # Convert a header's characters to create a valid title.
    #
    # Arguments:
    # - $1: the header to create the title for
    #
    # Nonlocals:
    # - title: the created title

    local header

    # Remove the leading and trailing spaces, the leading hashmarks and
    # the spaces following them, as well as possibly the number, from
    # the title.
    header="$1"
    title="${header}"
    if [[ "${title}" =~ ^(#+)( )([[:digit:]]+\.)+( )(.*) \
        || "${title}" =~ ^(#+)( )(.*) ]]
    then
        title="${BASH_REMATCH[-1]}"
    fi
    title="${title%%+( )}"
}

function header_to_link() {
    # Convert a header's characters to create a valid link.
    #
    # Arguments:
    # - $1: the header to create the link for
    #
    # Nonlocals:
    # - link: the created link
    # - links: the associative array of all links created, yet

    local header

    # Create the link according to the specification.
    header="$1"
    link="${header}"
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
