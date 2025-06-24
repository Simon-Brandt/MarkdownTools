#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-06-24

# Usage:
# bash categorize_lines.sh [--help | --usage | --version] input_file

# Purpose: Categorize a Markdown file's lines to headings, table of
# contents (TOC) lines, include directives, and sections.  Write these
# categories to STDOUT.

# Extract the headings, TOC lines, include directives, and sections from
# the input file.  The headings may start with hashmarks ("#") or can be
# underlined with equals signs ("=") or hyphens ("-").  In fenced or
# indented code blocks, denoted by three consecutive backticks or
# tildes, or four leading spaces, respectively, these characters lose
# their meaning and are not interpreted as the respective tokens.
shopt -s extglob

block=""
categories=( )
: "${in_file:-}"

mapfile -t lines < "${in_file}"
for line in "${lines[@]}"; do
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
    elif [[ "${block}" == "toc block" ]]; then
        # The line lies within a table of contents and may only end it
        # by the </toc> comment.
        if [[ "${line}" == "<!-- </toc> -->" ]]; then
            block=""
        fi
        categories+=("toc block")
    elif [[ "${block}" == "verbatim include block" ]]; then
        # The line lies within a verbatim include block and may only end
        # it by the </include> comment.
        if [[ "${line}" == "<!-- </include> -->" ]]; then
            block=""
        fi
        categories+=("verbatim include block")
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
        categories+=("${block}")
    elif [[ "${line}" == "<!-- <include file=\""*"\" lang=\""*"\"> -->" \
        || "${line}" == "<!-- <include command=\""*"\" lang=\""*"\"> -->" ]]
    then
        # The line denotes the start of the verbatim include block and
        # contains a filename or command, and a langauge specification.
        block="verbatim include block"
        categories+=("${block}")
    elif [[ "${line}" == "<!-- <include file=\""*"\"> -->" \
        || "${line}" == "<!-- <include command=\""*"\"> -->" ]]
    then
        # The line denotes the start of the normal include block and
        # contains a filename or command.
        block="normal include block"
        categories+=("${block}")
    elif [[ "${line}" == "<!-- </include> -->" ]]; then
        # The line denotes the end of a normal include block.
        block=""
        categories+=("normal include block")
    elif [[ "${line}" == "<!-- <section file=\""*"\"> -->" ]]; then
        # The line denotes the start of the section block and contains a
        # filename.
        block="section block"
        categories+=("${block}")
    elif [[ "${line}" == "<!-- </section> -->" ]]; then
        # The line lies denotes the end of the section block.
        block=""
        categories+=("section block")
    elif [[ "${line}" == "<!-- <toc title=\""*"\"> -->" \
        || "${line}" == "<!-- <toc> -->" ]]
    then
        # The line denotes the start of the table of contents and may
        # contain a title.
        block="toc block"
        categories+=("${block}")
    elif [[ "${line}" == *( )+(\#)+( )* ]]; then
        # The line is a heading, starting with hashmarks, followed by at
        # least one space.  Count the hashmarks, after having removed
        # the leading spaces.
        heading_level=0
        heading="${line##+( )}"
        while [[ "${heading:heading_level:1}" == "#" ]]; do
            (( heading_level++ ))
        done

        categories+=("heading ${heading_level}")
    elif [[ ("${line}" == *( )+(=) && "${prev_line}" == *( )[^=\ ]*) ]]; then
        # The line consists of equals signs, but the previous line
        # doesn't start with an equals sign and thus is a first-level
        # heading.
        categories[-1]="heading 1"
        categories+=("other")
    elif [[ ("${line}" == *( )+(-) && "${prev_line}" == *( )[^-\ ]*) ]]; then
        # The line consists of hyphens, but the previous line doesn't start
        # with a hyphen and thus is a second-level heading.
        categories[-1]="heading 2"
        categories+=("other")
    elif [[ "${line}" =~ \[[^\]]*?\]\(\#[^\)]*?\) ]]; then
        # The line contains at least one hyperlink.
        categories+=("hyperlink")
    else
        categories+=("other")
    fi
    prev_line="${line}"
done
