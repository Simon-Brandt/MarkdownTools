#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-04-04

# Usage:
# bash create_markdown_toc.sh [--help | --usage | --version]
#                             [--add-titles]
#                             [--exclude-headers=HEADERS...]
#                             [--exclude-levels=LEVELS...]
#                             [--in-place]
#                             [--out-file=FILE]
#                             [--titles=TITLES]
#                             input_file

# Purpose: Extract Markdown headings from a file and convert them into a
# table of contents.

function header_to_title() {
    # Convert a header's characters to create a valid title.
    #
    # Arguments:
    # - $1: the header to create the title for
    #
    # Nonlocals:
    # - title: the created title

    local header

    # Remove the leading and trailing spaces, and the leading hashmarks
    # and spaces following them from the title.
    header="$1"
    title="${header}"
    title="${title##+( )}"  # Remove leading spaces.
    title="${title##+(#)}"  # Remove leading hashmarks.
    title="${title##+( )}"  # Remove leading spaces.
    title="${title%%+( )}"  # Remove trailing spaces.
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
    link="${link//[^[:alnum:] _-]/}"  # Remove any punctuation but "_" and "-".
    link="${link##+( )}"              # Remove leading spaces.
    link="${link%%+( )}"              # Remove trailing spaces.
    link="${link// /-}"               # Replace spaces with hyphens.
    link="${link@L}"                  # Make all characters lowercase.

    # Check if the link is unique, else, append an integer.
    if [[ -v links["${link}"] ]]; then
        (( links[${link}]++ ))
        link="${link}-${links[${link}]}"
    else
        links[${link}]=0
    fi
}

# Read and parse the arguments.
declare in_file
declare out_file
declare in_place
declare add_titles
declare -a toc_titles
declare -a excluded_headers
declare -a excluded_levels

# shellcheck disable=SC2190  # Indexed, not associative array.
args=(
    "id               | short_opts | long_opts       | val_names  | defaults          | choices | type | arg_no | arg_group            | notes | help                                            "
    "in_file          |            |                 | input_file |                   |         | file |      1 | Positional arguments |       | the input file from which to get the headers    "
    "out_file         | o          | out-file        | FILE       | ''                |         | file |      1 | Options              |       | the output file to write the TOC to             "
    "in_place         | i          | in-place        |            | false             |         | bool |      0 | Options              |       | act in-place, writing the TOC to the input file "
    "add_titles       | a          | add-titles      |            | true              |         | bool |      0 | Options              |       | add a title to each TOC                         "
    "toc_titles       | t          | titles          |            | Table of contents |         | str  |      + | Options              |       | the TOC titles to add to the TOCs               "
    "excluded_headers | e          | exclude-headers | HEADERS    | ''                |         | str  |      + | Options              |       | comma-separated list of header names to exclude "
    "excluded_levels  | l          | exclude-levels  | LEVELS     | 0                 |         | uint |      + | Options              |       | comma-separated list of header levels to exclude"
)
source argparser -- "$@"

# Check the values of the arguments which the argparser didn't check.
if [[ "${in_file}" == "-" ]]; then
    if [[ "${in_place}" == true ]]; then
        error_message="In-place operation on STDIN (-) is impossible."
        printf 'Error: %s\n' "${error_message}"
        exit 1
    elif [[ -z "${out_file}" ]]; then
        error_message="When operating on STDIN (-), an output file must be "
        error_message+="given."
        printf 'Error: %s\n' "${error_message}"
        exit 1
    fi
    in_file=/dev/stdin
fi

if [[ "${out_file}" != "''" && "${in_place}" == true ]]; then
    error_message="Operating in-place and writing to an output file are "
    error_message+="mutually exclusive."
    printf 'Error: %s\n' "${error_message}"
    exit 1
fi

# Get the excluded header levels and compute the included ones.
included_levels=( )
for included_level in 1 2 3 4 5 6; do
    for excluded_level in "${excluded_levels[@]}"; do
        if [[ "${included_level}" == "${excluded_level}" ]]; then
            continue 2
        fi
    done
    included_levels+=("${included_level}")
done

# Extract the headers from the input file.  These may start with
# hashmarks ("#") or can be underlined with equals signs ("=") or
# hyphens ("-").  In fenced or indented code blocks, denoted by three
# consecutive backticks or tildes, or four leading spaces, respectively,
# these characters lose their meaning and are not interpreted as header
# tokens.
shopt -s extglob

headers=( )
header_levels=( )
header_line_indices=( )

is_fenced_code_block_backtick=false
is_fenced_code_block_tilde=false
is_indented_code_block=false
is_toc_block=false

toc_level=1
toc_levels=( )
toc_starts=( )
toc_ends=( )

prev_line=""

mapfile -t lines < "${in_file}"
for i in "${!lines[@]}"; do
    line="${lines[i]}"
    if [[ "${is_fenced_code_block_backtick}" == true ]]; then
        # The line lies within a fenced code block and may only end it
        # by three backticks.
        if [[ "${line}" == "\`\`\`"* ]]; then
            is_fenced_code_block_backtick=false
        fi
    elif [[ "${is_fenced_code_block_tilde}" == true ]]; then
        # The line lies within a fenced code block and may only end it
        # by three tildes.
        if [[ "${line}" == "~~~"* ]]; then
            is_fenced_code_block_tilde=false
        fi
    elif [[ "${is_indented_code_block}" == true ]]; then
        # The line lies within an indented code block and may only end
        # it by less than four leading spaces.
        if [[ "${line}" != "    "* ]]; then
            is_indented_code_block=false
        fi
    elif [[ "${is_toc_block}" == true ]]; then
        # The line lies within the table-of-contents block and may only
        # end it by the </toc> comment.
        if [[ "${line}" == "<!-- </toc> -->" ]]; then
            is_toc_block=false
            toc_ends+=("${i}")
        fi
    elif [[ "${line}" == "\`\`\`"* ]]; then
        # The line starts a fenced code block using backticks.
        is_fenced_code_block_backtick=true
    elif [[ "${line}" == "~~~"* ]]; then
        # The line starts a fenced code block using tildes.
        is_fenced_code_block_tilde=true
    elif [[ "${line}" == "    "[^*+-]* && -z "${prev_line}" ]]; then
        # The line starts an indented code block.
        is_indented_code_block=true
    elif [[ "${line}" == "<!-- <toc> -->" ]]; then
        # The line denotes the start of the table of contents for later
        # in-place addition.
        is_toc_block=true
        toc_starts+=("${i}")
        toc_levels+=("${toc_level}")
    elif [[ "${line}" == *( )+(\#)+( )* ]]; then
        # The line is a header, starting with hashmarks, followed by at
        # least one space.  Count the hashmarks, after having removed
        # the leading spaces.
        headers+=("${line}")
        header_line_indices+=("${i}")

        header_level=0
        line="${line##+( )}"
        while [[ "${line:header_level:1}" == "#" ]]; do
            (( header_level++ ))
        done
        header_levels+=("${header_level}")

        (( toc_level = header_level + 1 ))
    elif [[ "${line}" == *( )+(=) && "${prev_line}" == *( )[^=\ ]* ]]; then
        # The line consists of equals signs, but the previous line
        # doesn't start with an equals sign and thus is a first-level
        # header.
        headers+=("# ${prev_line}")
        header_line_indices+=("${i}")

        header_level=1
        header_levels+=("${header_level}")

        (( toc_level = header_level + 1 ))
    elif [[ "${line}" == *( )+(-) && "${prev_line}" == *( )[^-\ ]* ]]; then
        # The line consists of hyphens, but the previous line doesn't
        # start with a hyphen and thus is a second-level header.
        headers+=("## ${prev_line}")
        header_line_indices+=("${i}")

        header_level=2
        header_levels+=("${header_level}")

        (( toc_level = header_level + 1 ))
    fi
    prev_line="${line}"
done

# Create the tables of contents.
tocs=( )
for i in "${!toc_levels[@]}"; do
    # Get all headers with the same or higher level, starting from the
    # current table of content's end line index.
    toc_level="${toc_levels[i]}"
    toc_end="${toc_ends[i]}"
    toc_headers=( )
    toc_header_levels=( )
    for j in "${!headers[@]}"; do
        if (( "${header_line_indices[j]}" > toc_end )); then
            if (( "${header_levels[j]}" < toc_level )); then
                break
            fi
            toc_headers+=("${headers[j]}")
            toc_header_levels+=("${header_levels[j]}")
        fi
    done

    # Possibly, add the current table of contents' header to the array.
    # The actual header is added afterwards, such that the indentation
    # of the list items in the table of contents can be correctly
    # computed, without interfering with the header.
    if [[ "${add_titles}" == true ]]; then
        printf -v toc_header '%*s' "${toc_level}" ""
        toc_header="${toc_header// /#} ${toc_titles[j]:-"${toc_titles[0]}"}"
        toc_headers=("${toc_header}" "${toc_headers[@]}")

        toc_header_levels=("${toc_level}" "${toc_header_levels[@]}")
    fi

    # Create the current table of contents, converting all headers
    # belonging to it to valid hyperlinks.
    toc_lines=( )
    declare -A links
    for j in "${!toc_headers[@]}"; do
        # Get the header level.  If it shall be excluded, skip it.
        for excluded_level in "${excluded_levels[@]}"; do
            if [[ "${toc_header_levels[j]}" == "${excluded_level}" ]]; then
                continue 2
            fi
        done

        # Convert the header to a title suitable for the table of
        # contents.
        header="${toc_headers[j]}"
        header_to_title "${header}"

        # If the header name shall be excluded, skip it.
        for excluded_header in "${excluded_headers[@]}"; do
            if [[ "${title}" == "${excluded_header}" ]]; then
                continue 2
            fi
        done

        # Create the required list item indentation per header level.
        (( count = "${toc_header_levels[j]}" * 2 ))
        printf -v indentation '%*s' "${count}" ""

        # Convert the header's characters to create a valid link.
        header_to_link "${header}"

        # Add the resultant line to the table of contents.
        toc_line="${indentation}- [${title}](#${link})"
        toc_lines+=("${toc_line}")
    done
    unset links

    # Get the common indentation depth of all table of contents' lines,
    # and strip this.
    common_indentation=12  # Maximum possible indentation for header level h6.
    for toc_line in "${toc_lines[@]}"; do
        stripped_line="${toc_line##+( )}"
        (( count = "${#toc_line}" - "${#stripped_line}" ))

        if (( count < common_indentation )); then
            common_indentation="${count}"
        fi
    done

    printf -v indentation '%*s' "${common_indentation}" ""

    for j in "${!toc_lines[@]}"; do
        toc_lines[j]="${toc_lines[j]##"${indentation}"}"
    done

    # Possibly, add now the current table of contents' header, including
    # a trailing blank line (using an empty string in the array).
    if [[ "${add_titles}" == true ]]; then
        toc_lines=("${toc_header}" "" "${toc_lines[@]}")
    fi

    # Join the table of contents lines by newline characters and append
    # it to the previous tables of contents.
    tocs+=("$(printf '%s\n' "${toc_lines[@]}")")
done

if [[ "${in_place}" == true ]] && (( "${#tocs[@]}" > 0 )); then
    # Replace the tables of contents' lines in the Markdown file.  Add
    # the new tables of contents between the retrieved start and end
    # lines, thereby replacing their contents (i.e., the previous tables
    # of contents).  Finally, join the (now sparse) array of lines and
    # write it back to the input file.
    for i in "${!tocs[@]}"; do
        lines[toc_starts[i]]+=$'\n'
        lines[toc_starts[i]]+="${tocs[i]}"

        for (( j = "${toc_starts[i]}" + 1; j < "${toc_ends[i]}"; j++ )); do
            unset 'lines[j]'
        done
    done

    printf '%s\n' "${lines[@]}" > "${in_file}"
else
    # Write the lines to the output file.
    if [[ -n "${toc_lines[0]}" ]]; then
        printf '%s\n' "${toc_lines[0]}"
    fi > "${out_file}"
fi
