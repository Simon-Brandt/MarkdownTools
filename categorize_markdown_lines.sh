#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-06-02

# Usage:
# bash categorize_markdown_lines.sh [--help | --usage | --version] input_file

# Purpose: Categorize a Markdown file's lines to headers, table of
# contents (TOC) lines, and include directives.

# Read and parse the arguments.
declare in_file

# shellcheck disable=SC2190  # Indexed, not associative array.
args=(
    "id      | short_opts | long_opts | val_names  | defaults | choices | type | arg_no | arg_group            | notes | help                   "
    "in_file |            |           | input_file |          |         | file |      1 | Positional arguments |       | the input Markdown file"
)
source argparser -- "$@"

# Extract the headers, TOC lines, and include directives, from the input
# file.  The headers may start with hashmarks ("#") or can be underlined
# with equals signs ("=") or hyphens ("-").  In fenced or indented code
# blocks, denoted by three consecutive backticks or tildes, or four
# leading spaces, respectively, these characters lose their meaning and
# are not interpreted as the respective tokens.
shopt -s extglob

is_fenced_code_block_backtick=false
is_fenced_code_block_tilde=false
is_indented_code_block=false
is_include_block=false
is_toc_block=false

categories=( )

mapfile -t lines < "${in_file}"
for i in "${!lines[@]}"; do
    line="${lines[i]}"
    if [[ "${is_fenced_code_block_backtick}" == true ]]; then
        # The line lies within a fenced code block and may only end it
        # by three backticks.
        if [[ "${line}" == "\`\`\`"* ]]; then
            is_fenced_code_block_backtick=false
        fi
        categories+=("fenced code block backtick")
    elif [[ "${is_fenced_code_block_tilde}" == true ]]; then
        # The line lies within a fenced code block and may only end it
        # by three tildes.
        if [[ "${line}" == "~~~"* ]]; then
            is_fenced_code_block_tilde=false
        fi
        categories+=("fenced code block tilde")
    elif [[ "${is_indented_code_block}" == true ]]; then
        # The line lies within an indented code block and may only end
        # it by less than four leading spaces.
        if [[ "${line}" != "    "* ]]; then
            is_indented_code_block=false
        fi
        categories+=("indented code block")
    elif [[ "${is_include_block}" == true ]]; then
        # The line lies within an include block and may only end it by
        # the </include> comment.
        if [[ "${line}" == "<!-- </include> -->" ]]; then
            is_include_block=false
        fi
        categories+=("include block")
    elif [[ "${is_toc_block}" == true ]]; then
        # The line lies within a table of contents and may only end it
        # by the </toc> comment.
        if [[ "${line}" == "<!-- </toc> -->" ]]; then
            is_toc_block=false
        fi
        categories+=("toc block")
    elif [[ "${line}" == "\`\`\`"* ]]; then
        # The line starts a fenced code block using backticks.
        is_fenced_code_block_backtick=true
        categories+=("fenced code block backtick")
    elif [[ "${line}" == "~~~"* ]]; then
        # The line starts a fenced code block using tildes.
        is_fenced_code_block_tilde=true
        categories+=("fenced code block tilde")
    elif [[ "${line}" == "    "[^*+-]* && -z "${prev_line}" ]]; then
        # The line starts an indented code block.
        is_indented_code_block=true
        categories+=("indented code block")
    elif [[ "${line}" == "<!-- <include file=\""*"\"> -->" ]]; then
        # The line denotes the start of the include block and contains a
        # filename.
        is_include_block=true
        categories+=("include block")
    elif [[ "${line}" == "<!-- <include command=\""*"\"> -->" ]]; then
        # The line denotes the start of the include block and contains a
        # command.
        is_include_block=true
        categories+=("include block")
    elif [[ "${line}" == "<!-- <include> -->" ]]; then
        # The line denotes the start of the include block.
        is_include_block=true
        categories+=("include block")
    elif [[ "${line}" == "<!-- <toc title=\""*"\"> -->" ]]; then
        # The line denotes the start of the table of contents and
        # contains a title.
        is_toc_block=true
        categories+=("toc block")
    elif [[ "${line}" == "<!-- <toc> -->" ]]; then
        # The line denotes the start of the table of contents.
        is_toc_block=true
        categories+=("toc block")
    elif [[ "${line}" == *( )+(\#)+( )* ]]; then
        # The line is a header, starting with hashmarks, followed by at
        # least one space.
        categories+=("header")
    elif [[ "${line}" == *( )+(=) && "${prev_line}" == *( )[^=\ ]* ]]; then
        # The line consists of equals signs, but the previous line
        # doesn't start with an equals sign and thus is a first-level
        # header.
        categories[-1]="header"
        categories+=("other")
    elif [[ "${line}" == *( )+(-) && "${prev_line}" == *( )[^-\ ]* ]]; then
        # The line consists of hyphens, but the previous line doesn't
        # start with a hyphen and thus is a second-level header.
        categories[-1]="header"
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
