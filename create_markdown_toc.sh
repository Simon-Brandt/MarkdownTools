#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-04-03

# Usage:
# bash create_markdown_toc.sh [--help | --usage | --version]
#                             [--add-title]
#                             [--exclude-headers=HEADERS...]
#                             [--exclude-levels=LEVELS...]
#                             [--in-place]
#                             [--out-file=FILE]
#                             [--title=TITLE]
#                             input_file

# Purpose: Extract Markdown headings from a file and convert them into a
# table of contents.

# Read and parse the arguments.
declare in_file
declare out_file
declare in_place
declare add_title
declare title
declare -a excluded_headers
declare -a excluded_levels

# shellcheck disable=SC2190  # Indexed, not associative array.
args=(
    "id               | short_opts | long_opts       | val_names  | defaults          | choices | type | arg_no | arg_group            | notes | help                                            "
    "in_file          |            |                 | input_file |                   |         | file |      1 | Positional arguments |       | the input file from which to get the headers    "
    "out_file         | o          | out-file        | FILE       | ''                |         | file |      1 | Options              |       | the output file to write the TOC to             "
    "in_place         | i          | in-place        |            | false             |         | bool |      0 | Options              |       | act in-place, writing the TOC to the input file "
    "add_title        | a          | add-title       |            | true              |         | bool |      0 | Options              |       | add a title to the TOC                          "
    "title            | t          | title           |            | Table of contents |         | str  |      1 | Options              |       | the name of the title to add to the TOC         "
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
is_fenced_code_block_backtick=false
is_fenced_code_block_tilde=false
is_indented_code_block=false
is_toc_block=false
toc_level=1
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
            toc_end="${i}"
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
        toc_start="${i}"
    elif [[ "${line}" == *( )+(\#)+( )* ]]; then
        # The line is a header, starting with hashmarks, followed by at
        # least one space.  Count the hashmarks.
        headers+=("${line}")

        if [[ ! -v toc_start ]]; then
            toc_level=0
            while [[ "${line:toc_level:1}" == "#" ]]; do
                (( toc_level++ ))
            done
        fi
    elif [[ "${line}" == *( )+(=) && "${prev_line}" == *( )[^=\ ]* ]]; then
        # The line consists of equals signs, but the previous line
        # doesn't start with an equals sign and thus is a first-level
        # header.
        headers+=("# ${prev_line}")
        if [[ ! -v toc_start ]]; then
            toc_level=1
        fi
    elif [[ "${line}" == *( )+(-) && "${prev_line}" == *( )[^-\ ]* ]]; then
        # The line consists of hyphens, but the previous line doesn't
        # start with a hyphen and thus is a second-level header.
        headers+=("## ${prev_line}")

        if [[ ! -v toc_start ]]; then
            toc_level=2
        fi
    fi
    prev_line="${line}"
done

# Possibly, set the table of contents' header, including a trailing
# blank line (as empty string in the array).
if [[ "${add_title}" == true ]]; then
    printf -v header '%*s' "$((toc_level + 1))" ""
    header="${header// /#}"
    header+=" ${title}"
    headers=("${header}" "${headers[@]}")
    toc_lines=("${header}" "")
else
    toc_lines=( )
fi

# Convert the headers to valid hyperlinks.
declare -A links
for header in "${headers[@]}"; do
    # Count the leading hashmarks in the header.  If the header level
    # shall be excluded, skip it.
    level=0
    while [[ "${header:level:1}" == "#" ]]; do
        (( level++ ))
    done

    for excluded_level in "${excluded_levels[@]}"; do
        if [[ "${level}" == "${excluded_level}" ]]; then
            continue 2
        fi
    done

    # Create the required list item indentation per header level.
    for i in "${!included_levels[@]}"; do
        if [[ "${level}" == "${included_levels[i]}" ]]; then
            break
        fi
    done

    (( count = i * 2 ))
    printf -v indentation '%*s' "${count}" ""
    indentation="${indentation}- "

    # Remove the leading and trailing spaces, and the leading hashmarks
    # and spaces following them from the title.
    title="${header}"
    title="${title##+( )}"  # Remove leading spaces.
    title="${title##+(#)}"  # Remove leading hashmarks.
    title="${title##+( )}"  # Remove leading spaces.
    title="${title%%+( )}"  # Remove trailing spaces.

    # If the header name shall be excluded, skip it.
    for excluded_header in "${excluded_headers[@]}"; do
        if [[ "${title}" == "${excluded_header}" ]]; then
            continue 2
        fi
    done

    # Convert the header's characters to create a valid link.
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

    # Add the resultant line to the table of contents.
    toc_lines+=("${indentation}[${title}](#${link})")
done

# Join the table of contents lines by newline characters.
toc_lines=("$(printf '%s\n' "${toc_lines[@]}")")

if [[ "${in_place}" == true && -v toc_start ]]; then
    # Replace the table of contents lines in the Markdown file.  Add
    # the new table of contents between the retrieved start and end
    # lines, thereby replacing their contents (i.e., the previous table
    # of contents).  Finally, join the (now sparse) array of lines and
    # write it back to the input file.
    if [[ -n "${toc_lines[0]}" ]]; then
        lines[toc_start]+=$'\n'
        lines[toc_start]+="${toc_lines[0]}"
    fi

    for (( i = toc_start + 1; i < toc_end; i++ )); do
        unset 'lines[i]'
    done
    printf '%s\n' "${lines[@]}" > "${in_file}"
else
    # Write the lines to the output file.
    if [[ -n "${toc_lines[0]}" ]]; then
        printf '%s\n' "${toc_lines[0]}"
    fi > "${out_file}"
fi
