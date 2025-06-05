#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-06-05

# Usage:
# bash categorize_lines.sh [--help | --usage | --version] input_file

# Purpose: Categorize a Markdown file's lines to headers, table of
# contents (TOC) lines, and include directives.  Write these categories
# to STDOUT.

# Read and parse the arguments.
declare in_file

# shellcheck disable=SC2190  # Indexed, not associative array.
args=(
    "id      | val_names  | type | arg_no | arg_group            | help                   "
    "in_file | input_file | file |      1 | Positional arguments | the input Markdown file"
)
source argparser -- "$@"

# Extract the headers, TOC lines, and include directives, from the input
# file.  The headers may start with hashmarks ("#") or can be underlined
# with equals signs ("=") or hyphens ("-").  In fenced or indented code
# blocks, denoted by three consecutive backticks or tildes, or four
# leading spaces, respectively, these characters lose their meaning and
# are not interpreted as the respective tokens.
shopt -s extglob

block=""
categories=( )

mapfile -t lines < "${in_file}"
for i in "${!lines[@]}"; do
    line="${lines[i]}"
    if [[ "${block}" == "fenced code block backtick" ]]; then
        # The line lies within a fenced code block and may only end it
        # by three backticks.
        if [[ "${line}" == "\`\`\`"* ]]; then
            block=""
        fi
        categories+=("fenced code block backtick")
    elif [[ "${block}" == "fenced code block tilde" ]]; then
        # The line lies within a fenced code block and may only end it
        # by three tildes.
        if [[ "${line}" == "~~~"* ]]; then
            block=""
        fi
        categories+=("fenced code block tilde")
    elif [[ "${block}" == "indented code block" ]]; then
        # The line lies within an indented code block and may only end
        # it by less than four leading spaces.
        if [[ "${line}" != "    "* ]]; then
            block=""
        fi
        categories+=("indented code block")
    elif [[ "${block}" == "include block" ]]; then
        # The line lies within an include block and may only end it by
        # the </include> comment.
        if [[ "${line}" == "<!-- </include> -->" ]]; then
            block=""
        fi
        categories+=("include block")
    elif [[ "${block}" == "section block" ]]; then
        # The line lies within a section block and may only end it by
        # the </section> comment.
        if [[ "${line}" == "<!-- </section> -->" ]]; then
            block=""
        fi
        categories+=("section block")
    elif [[ "${block}" == "toc block" ]]; then
        # The line lies within a table of contents and may only end it
        # by the </toc> comment.
        if [[ "${line}" == "<!-- </toc> -->" ]]; then
            block=""
        fi
        categories+=("toc block")
    elif [[ "${line}" == "\`\`\`"* ]]; then
        # The line starts a fenced code block using backticks.
        block="fenced code block backtick"
        categories+=("${block}")
    elif [[ "${line}" == "~~~"* ]]; then
        # The line starts a fenced code block using tildes.
        block="fenced code block tilde"
        categories+=("${block}")
    elif [[ "${line}" == "    "[^*+-]* && -z "${prev_line}" ]]; then
        # The line starts an indented code block.
        block="indented code block"
        categories+=("indented code block")
    elif [[ "${line}" == "<!-- <include file=\""*"\"> -->" \
        || "${line}" == "<!-- <include command=\""*"\"> -->" \
        || "${line}" == "<!-- <include> -->" ]]
    then
        # The line denotes the start of the include block and may
        # contain a filename or command.
        block="include block"
        categories+=("${block}")
    elif [[ "${line}" == "<!-- <section file=\""*"\"> -->" ]]; then
        # The line denotes the start of the section block and contains a
        # filename.
        block="section block"
        categories+=("${block}")
    elif [[ "${line}" == "<!-- <toc title=\""*"\"> -->" \
        || "${line}" == "<!-- <toc> -->" ]]
    then
        # The line denotes the start of the table of contents and may
        # contain a title.
        block="toc block"
        categories+=("${block}")
    elif [[ "${line}" == *( )+(\#)+( )* ]]; then
        # The line is a header, starting with hashmarks, followed by at
        # least one space.  Count the hashmarks, after having removed
        # the leading spaces.
        header_level=0
        header="${line##+( )}"
        while [[ "${header:header_level:1}" == "#" ]]; do
            (( header_level++ ))
        done

        categories+=("header ${header_level}")
    elif [[ ("${line}" == *( )+(=) && "${prev_line}" == *( )[^=\ ]*) ]]; then
        # The line consists of equals signs, but the previous line
        # doesn't start with an equals sign and thus is a first-level
        # header.
        categories[-1]="header 1"
        categories+=("other")
    elif [[ ("${line}" == *( )+(-) && "${prev_line}" == *( )[^-\ ]*) ]]; then
        # The line consists of hyphens, but the previous line doesn't start
        # with a hyphen and thus is a second-level header.
        categories[-1]="header 2"
        categories+=("other")
    elif [[ "${line}" =~ \[([^\]]*?)\]\(\#[^\)]*?\) ]]; then
        # The line contains at least one hyperlink.
        categories+=("hyperlink")
    else
        categories+=("other")
    fi
    prev_line="${line}"
done

# Output the categories.
printf '%s\n' "${categories[@]}"
