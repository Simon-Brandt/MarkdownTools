#!/bin/bash

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
# Last Modification: 2025-07-29

# Usage:
# source categorize_lines.sh input_file

# Purpose: Categorize a Markdown file's lines to headings, table of
# contents (TOC) lines, include directives, and sections.  Add these
# categories to the indexed array ${categories}.

# Extract the headings, TOC lines, include directives, and sections from
# the input file.  The headings may start with hashmarks ("#") or can be
# underlined with equals signs ("=") or hyphens ("-").  In fenced or
# indented code blocks, denoted by three consecutive backticks or
# tildes, or four leading spaces, respectively, these characters lose
# their meaning and are not interpreted as the respective tokens.
shopt -s extglob

block=""
categories=( )
in_file="$1"
include_nestedness=0

# If the include nestedness is greater than zero, only increment or
# decrement it, depending on the line's contents, then unset it.
# Don't include the actual requested file or command output, which
# would need to be done separately for the file which is about to be
# included.  This prevents infinite regression, when file A includes
# file B, and vice versa.


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
    elif [[ "${block}" == "comment block" ]]; then
        # The line lies within a comment block and may only end it by
        # "-->".
        if [[ "${line}" == *"-->"* ]]; then
            block=""
        fi
        categories+=("comment block")
    elif [[ "${block}" == "verbatim include block" ]]; then
        # The line lies within a verbatim include block and may only end
        # it by the </include> comment, and only for the top-most
        # include block, where there is no nestedness.  When another
        # (nested) include blocks starts, increment the nestedness as
        # appropriate.
        if [[ "${line}" == "<!-- <include file=\""*"\" lang=\""*"\"> -->" \
            || "${line}" == "<!-- <include command=\""*"\" lang=\""*"\"> -->" \
            || "${line}" == "<!-- <include file=\""*"\"> -->" \
            || "${line}" == "<!-- <include command=\""*"\"> -->" ]]
        then
            (( include_nestedness++ ))
        elif [[ "${line}" == "<!-- </include> -->" ]]; then
            (( include_nestedness-- ))
            if (( include_nestedness == 0 )); then
                block=""
            fi
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
    elif [[ "${line}" == *"<!--"* && "${line}" != *"-->"* ]]; then
        # The line starts a comment block.
        block="comment block"
        categories+=("comment block")
    elif [[ "${line}" == "<!-- <include file=\""*"\" lang=\""*"\"> -->" \
        || "${line}" == "<!-- <include command=\""*"\" lang=\""*"\"> -->" ]]
    then
        # The line denotes the start of the top-most verbatim include
        # block and contains a filename or command, and a language
        # specification.
        block="verbatim include block"
        categories+=("${block}")
        (( include_nestedness++ ))
    elif [[ "${line}" == "<!-- <include file=\""*"\"> -->" \
        || "${line}" == "<!-- <include command=\""*"\"> -->" ]]
    then
        # The line denotes the start of the normal include block and
        # contains a filename or command.  Only categorize it as include
        # block if it's the top-most one to prevent infinite regression
        # upon inclusion,, when file A includes file B, and vice versa.
        if (( include_nestedness == 0 )); then
            block="normal include block"
            categories+=("${block}")
        else
            categories+=("other")
        fi
        (( include_nestedness++ ))
    elif [[ "${line}" == "<!-- </include> -->" ]]; then
        # The line denotes the end of a normal include block.  Again,
        # only categorize it as ended include block if it's the top-most
        # one.
        (( include_nestedness-- ))
        if (( include_nestedness == 0 )); then
            block=""
            categories+=("normal include block")
        else
            categories+=("other")
        fi
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
    elif [[ "${line}" == "<!-- </toc> -->" ]]; then
        # The line denotes the end of the table of contents.
        block=""
        categories+=("toc block")
    elif [[ "${line}" == "<!-- <figure file=\""*"\" caption=\""*"\"> -->" ]]
    then
        # The line denotes a figure caption and contains a filename and
        # caption text.
        block="figure"
        categories+=("${block}")
    elif [[ "${line}" == "<!-- <table caption=\""*"\"> -->" ]]
    then
        # The line denotes a table caption and contains a caption text.
        block="table"
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
    elif [[ "${line}" =~ \[[^\]]*?\]\([^\)\#]*?(\#[^\)]*?)?\) ]]; then
        # The line contains at least one hyperlink.
        categories+=("hyperlink")
    else
        categories+=("other")
    fi
    prev_line="${line}"
done
