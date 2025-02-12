#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-02-12

# Usage:
# bash create_markdown_toc \
#     [--in-place | --out-file=<out_file.md> ] \
#     <in_file.md>

# Purpose: Extract Markdown headings from a file and convert them into a
# table of contents.

# Read and parse the arguments.
shopt -s extglob
in_file=""
out_file=""
in_place=false
while (( "$#" > 0 )); do
    case "$1" in
        -i|--in-place)
            in_place=true
            shift
            ;;
        -i*|--in-place*)
            error_message="The option -i|--in-place is a flag and accepts no "
            error_message+="value."
            printf 'Error: %s\n' "${error_message}"
            exit 1
            ;;
        -o|--out-file)
            out_file="${2:-}"
            if [[ -z "${out_file}" ]]; then
                error_message="The option -o|--out-file requires a value."
                printf 'Error: %s\n' "${error_message}"
                exit 1
            fi
            shift 2
            ;;
        -o*)
            out_file="${1#-o}"
            if [[ -z "${out_file}" ]]; then
                error_message="The option -o|--out-file requires a value."
                printf 'Error: %s\n' "${error_message}"
                exit 1
            fi
            shift
            ;;
        --out-file=*)
            out_file="${1#--out-file}"
            out_file="${out_file#=}"
            if [[ -z "${out_file}" ]]; then
                error_message="The option -o|--out-file requires a value."
                printf 'Error: %s\n' "${error_message}"
                exit 1
            fi
            shift
            ;;
        -)
            in_file="-"
            shift
            ;;
        !(-)*)
            if [[ -n "${in_file}" ]]; then
                error_message="'Only use one positional argument, found $1."
                printf 'Error: %s\n' "${error_message}"
                exit 1
            fi
            in_file="$1"
            shift
            ;;
        *)
            error_message="Unknown option $1."
            printf 'Error: %s\n' "${error_message}"
            exit 1
            ;;
    esac
done

# Check the values of the arguments.
if [[ -z "${in_file}" ]]; then
    error_message="You must give the input file as positional argument."
    printf 'Error: %s\n' "${error_message}"
    exit 1
elif [[ "${in_file}" == "-" ]]; then
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

if [[ -n "${out_file}" && "${in_place}" == true ]]; then
    error_message="Operating in-place and writing to an output file are "
    error_message+="mutually exclusive."
    printf 'Error: %s\n' "${error_message}"
    exit 1
fi

# Extract the headers from the input file.  These may start with
# hashmarks ("#") or can be underlined with hyphens ("-") or equals
# signs ("="). In fenced or indented code blocks, denoted by three
# consecutive backticks or tildes, or four leading spaces, respectively,
# these characters lose their meaning and are not interpreted as header
# tokens.
headers=( )
is_fenced_code_block_backtick=false
is_fenced_code_block_tilde=false
is_indented_code_block=false
prev_line=""

mapfile -t lines < "${in_file}"
for i in "${!lines[@]}"; do
    line="${lines[i]}"
    if [[ "${is_indented_code_block}" == true ]]; then
        # The line lies within an indented code block and may only end
        # it by four leading spaces.
        if [[ "${line}" == "    "* ]]; then
            is_indented_code_block=false
        fi
    elif [[ "${is_fenced_code_block_backtick}" == true ]]; then
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
    elif [[ "${line}" == "    "* ]]; then
        # The line starts an indented code block.
        is_indented_code_block=true
    elif [[ "${line}" == "\`\`\`"* ]]; then
        # The line starts a fenced code block using backticks.
        is_fenced_code_block_backtick=true
    elif [[ "${line}" == "~~~"* ]]; then
        # The line starts a fenced code block using tildes.
        is_fenced_code_block_tilde=true
    elif [[ "${line}" == *( )+(\#)+( )* ]]; then
        # The line is a header, starting with hashmarks, followed by at
        # least one space.
        headers+=("${line}")
    elif [[ "${line}" == *( )+(=) && "${prev_line}" == *( )[^=\ ]* ]]; then
        # The line consists of equals signs, but the previous line
        # doesn't start with an equals sign and thus is a first-level
        # header.
        headers+=("## ${prev_line}")
    elif [[ "${line}" == *( )+(-) && "${prev_line}" == *( )[^-\ ]* ]]; then
        # The line consists of hyphens, but the previous line doesn't
        # start with a hyphen and thus is a second-level header.
        headers+=("## ${prev_line}")
    elif [[ "${line}" == *( )"<!-- <toc> -->"*( ) ]]; then
        # The line denotes the start of the table of contents for later
        # in-place addition.
        toc_start="${i}"
    elif [[ "${line}" == *( )"<!-- </toc> -->"*( ) ]]; then
        # The line denotes the end of the table of contents for later
        # in-place addition.
        toc_end="${i}"
    fi
    prev_line="${line}"
done

# Convert the headers to valid hyperlinks and write them to the output
# file.
toc_lines=( )
declare -A links
for header in "${headers[@]}"; do
    # Count the leading hashmarks in the header and convert them into
    # two spaces each, except the first one, to create the required list
    # item indentation per header level.  Since the printf format
    # specification adds a space more than required, strip it from the
    # indentation.
    i=0
    while [[ "${header:i:1}" == \# ]]; do
        (( i++ ))
    done
    (( count = (i - 1) * 2 ))
    printf -v indent '%*s ' "${count}" ""
    indent="${indent::-1}- "

    # Remove the leading and trailing spaces, and the leading hashmarks
    # and spaces following them from the title.
    title="${header}"
    title="${title##+( )}"  # Remove leading spaces.
    title="${title##+(#)}"  # Remove leading hashmarks.
    title="${title##+( )}"  # Remove leading spaces.
    title="${title%%+( )}"  # Remove trailing spaces.

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
    toc_lines+=("${indent}[${title}](#${link})")
done

# Join the table of contents lines by newline characters and strip the
# last of which.
toc_lines=("$(printf '%s\n' "${toc_lines[@]}")")
toc_lines[0]="${toc_lines[0]%\n}"

if [[ "${in_place}" == true ]]; then
    # Replace the table of contents lines in the Markdown file.  Add
    # the new table of contents between the retrieved start and end
    # lines, thereby replacing their contents (i.e., the previous table
    # of contents).  Finally, join the (now sparse) array of lines and
    # write it back to the input file.
    toc_lines=("$(printf '%s\n' "${toc_lines[@]}")")
    toc_lines[0]="${toc_lines[0]%\n}"
    lines[toc_start]+=$'\n'
    lines[toc_start]+="${toc_lines[0]}"
    for (( i = toc_start + 1; i < toc_end; i++ )); do
        unset 'lines[i]'
    done
    printf '%s\n' "${lines[@]}" > "${in_file}"
else
    # Write the lines to the output file.
    printf '%s\n' "${toc_lines[@]}" > "${out_file}"
fi
