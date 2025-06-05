#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-06-05

# Usage:
# bash create_toc.sh [--help | --usage | --version]
#                    [--add-titles]
#                    [--exclude-headers=HEADERS...]
#                    [--exclude-levels=LEVELS...]
#                    [--in-place]
#                    [--out-file=FILE]
#                    [--titles=TITLES]
#                    input_file

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
declare number_headers
declare -a excluded_headers
declare -a excluded_levels

# shellcheck disable=SC2190  # Indexed, not associative array.
args=(
    "id               | short_opts | long_opts       | val_names  | defaults          | type | arg_no | arg_group            | help                                             "
    "in_file          |            |                 | input_file |                   | file |      1 | Positional arguments | the input file from which to get the headers     "
    "out_file         | o          | out-file        | FILE       | ''                | file |      1 | Options              | the output file to write the TOC to              "
    "in_place         | i          | in-place        |            | false             | bool |      0 | Options              | act in-place, writing the TOC to the input file  "
    "add_titles       | a          | add-titles      |            | true              | bool |      0 | Options              | add a title to each TOC                          "
    "toc_titles       | t          | titles          |            | Table of contents | str  |      + | Options              | the TOC titles to add to the TOCs                "
    "number_headers   | n          | number-headers  |            | true              | bool |      0 | Options              | number the headers, in a \"1.2.3.4.5.6.\" fashion"
    "excluded_headers | e          | exclude-headers | HEADERS    | ''                | str  |      + | Options              | comma-separated list of header names to exclude  "
    "excluded_levels  | l          | exclude-levels  | LEVELS     | 0                 | uint |      + | Options              | comma-separated list of header levels to exclude "
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

# Categorize the lines.
if [[ "${BASH_SOURCE[0]}" == */* ]]; then
    directory="${BASH_SOURCE[0]%/*}/"
else
    directory=""
fi

mapfile -t categories < <(bash "${directory}categorize_lines.sh" "${in_file}")
mapfile -t lines < "${in_file}"

# Get the table-of-contents blocks, headers, and hyperlinks.
shopt -s extglob

headers=( )
header_levels=( )
header_line_indices=( )
hyperlinks=( )
hyperlink_line_indices=( )

toc_level=1
toc_levels=( )
toc_starts=( )
toc_ends=( )

for i in "${!lines[@]}"; do
    if [[ "${categories[i]}" != "toc block" \
        && "${categories[i]}" != "header"* \
        && "${categories[i]}" != "hyperlink" ]]
    then
        continue
    fi

    line="${lines[i]}"
    if [[ "${categories[i]}" == "toc block" ]]; then
        if [[ "${line}" =~ ^"<!-- <toc title=\""(.*)"\"> -->"$ ]]; then
            # The line denotes the start of the table of contents for
            # later in-place addition and contains a title.  Extract
            # this and insert it between the titles set on the command
            # line, at the current index denoted by the element count of
            # ${toc_levels[@]} (which is the number of tables of
            # contents processed/found so far).
            toc_starts+=("${i}")
            toc_levels+=("${toc_level}")

            toc_title="${BASH_REMATCH[1]}"
            toc_titles=(
                "${toc_titles[@]::"${#toc_levels[@]}"}"
                "${toc_title}"
                "${toc_titles[@]:"${#toc_levels[@]}"}"
            )
        elif [[ "${line}" == "<!-- <toc> -->" ]]; then
            # The line denotes the start of the table of contents for
            # later in-place addition.
            toc_starts+=("${i}")
            toc_levels+=("${toc_level}")
        elif [[ "${line}" == "<!-- </toc> -->" ]]; then
            # The line denotes the end of the table-of-contents block.
            toc_ends+=("${i}")
        fi
    elif [[ "${categories[i]}" == "header"* ]]; then
        # The line is a header.  Get the header level and prepend as
        # many hashmarks as the header level to the hashmark-stripped
        # header to set ATX and setext headers to the same (ATX) style.
        header_line_indices+=("${i}")
        header_level="${categories[i]##* }"
        header_levels+=("${header_level}")
        (( toc_level = header_level + 1 ))

        header="${line##+( )}"
        header="${header##+(\#)}"
        for (( j = 1; j <= header_level; j++ )); do
            header="#${header}"
        done
        headers+=("${header}")
    elif [[ "${categories[i]}" == "hyperlink" ]]; then
        # The line contains at least one hyperlink. Extract it, then
        # shorten the line and try to match the pattern on the remainder
        # of the line.
        remainder="${line}"
        while [[ "${remainder}" =~ \[([^\]]*?)\]\(\#[^\)]*?\) ]]; do
            hyperlink="${BASH_REMATCH[0]}"
            hyperlinks+=("${hyperlink}")
            remainder="${remainder##*"${hyperlink}"}"
            hyperlink_line_indices+=("${i}")
        done
    fi
done

# Create the links for the currently old (unmodified) headers.  Since
# the numbering may change, so does the link, which then needs to be
# updated, below.  To this end, store the old links in an indexed array.
declare -A links
old_header_links=( )
for header in "${headers[@]}"; do
    header_to_link "${header}"
    old_header_links+=("${link}")
done
unset links

# Generate numbers for the headers.
numbers=( )
header_level_counts=( )
prev_header_level=0
for i in "${!headers[@]}"; do
    # Get the header level.  If it shall be excluded, skip it.
    header_level="${header_levels[i]}"
    for excluded_level in "${excluded_levels[@]}"; do
        if [[ "${header_level}" == "${excluded_level}" ]]; then
            numbers+=("")
            continue 2
        fi
    done

    # If the header level is lower than the previous one, reset the
    # count in the previous level.  Increment the current level's count.
    if (( header_level < prev_header_level )); then
        for (( j = header_level + 1; j <= prev_header_level; j++ )); do
            (( header_level_counts[j] = 0 ))
        done
    fi
    (( header_level_counts[header_level]++ ))

    # Generate the number in a "1.2.3.4.5.6." fashion, depending on the
    # header level (i.e., only use as many numbers as the header level).
    # Don't assign numbers for skipped (excluded) levels.
    number=""
    for included_level in "${included_levels[@]}"; do
        if (( included_level <= header_level )); then
            number+="${header_level_counts[included_level]:-1}."
        fi
    done
    numbers+=("${number}")
    prev_header_level="${header_level}"
done

# Add the numbers to the headers, possibly replacing the previous
# number.
if [[ "${number_headers}" == true ]]; then
    for i in "${!headers[@]}"; do
        if [[ -n "${numbers[i]}" \
            && ("${headers[i]}" =~ ^(#+)( )([[:digit:]]+\.)+( )(.*) \
                || "${headers[i]}" =~ ^(#+)( )(.*)) ]]
        then
            headers[i]="${BASH_REMATCH[1]} ${numbers[i]} ${BASH_REMATCH[-1]}"
        fi
    done
fi

# Create the links for the new (modified) headers and store them in an
# indexed array.
declare -A links
new_header_links=( )
for header in "${headers[@]}"; do
    header_to_link "${header}"
    new_header_links+=("${link}")
done
unset links

# Map the old header links to the new header links for later replacement
# in the hyperlinks.  Since the old links may have already been numbered
# or are still unnumbered, save also an unnumbered version.
declare -A numbered_replacement_links
declare -A unnumbered_replacement_links
for i in "${!old_header_links[@]}"; do
    old_header_link="${old_header_links[i]}"
    numbered_replacement_links[${old_header_link}]="${new_header_links[i]}"

    old_header_link="${old_header_links[i]#+([[:digit:]])-}"
    unnumbered_replacement_links[${old_header_link}]="${new_header_links[i]}"
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
        toc_header="${toc_header// /#} ${toc_titles[i]:-"${toc_titles[0]}"}"
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

        for toc_title in "${toc_titles[@]}"; do
            if [[ "${title}" == "${toc_title}"* ]]; then
                continue 2
            fi
        done

        # Create the required list item indentation per header level and
        # set the list marker.
        if [[ "${number_headers}" == true ]]; then
            marker="1."
            (( count = "${toc_header_levels[j]}" * 3 ))
        else
            marker="-"
            (( count = "${toc_header_levels[j]}" * 2 ))
        fi
        printf -v indentation '%*s' "${count}" ""

        # Convert the header's characters to create a valid link.
        header_to_link "${header}"

        # Add the resultant line to the table of contents.
        toc_line="${indentation}${marker} [${title}](#${link})"
        toc_lines+=("${toc_line}")
    done

    # Unset the associative array of the links, such that the following
    # tables of contents re-calculate it instead of again appending
    # numbers (and increasing them) to the links.
    unset links

    # Get the common indentation depth of all table of contents' lines,
    # and strip this.  Start with the mMaximum possible indentation for
    # the header level h6, which is 18 for numbered and 12 for bulleted
    # lists.
    if [[ "${number_headers}" == true ]]; then
        common_indentation=18
    else
        common_indentation=12
    fi

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

# Write the lines to the output.
if [[ "${in_place}" == true ]] && (( "${#tocs[@]}" > 0 )); then
    # Possibly, replace the (now correctly numbered) headers and their
    # corresponding hyperlinks in the Markdown file.
    if [[ "${number_headers}" == true ]]; then
        # Replace the headers.
        i=0
        for j in "${header_line_indices[@]}"; do
            lines[j]="${headers[i]}"
            (( i++ ))
        done

        # Replace the hyperlinks.  These may have already been numbered
        # or are still unnumbered, so use the replacement from the
        # respective associative array to replace the link in the
        # Markdown hyperlink.
        i=0
        for j in "${hyperlink_line_indices[@]}"; do
            old_hyperlink="${hyperlinks[i]}"
            old_link="${old_hyperlink##*\(#}"
            old_link="${old_link%)}"

            if [[ -n "${numbered_replacement_links["${old_link}"]}" ]]; then
                new_link="${numbered_replacement_links["${old_link}"]}"
            else
                new_link="${unnumbered_replacement_links["${old_link}"]}"
            fi

            new_hyperlink="${old_hyperlink%(*}(#${new_link})"
            lines[j]="${lines[j]/"${old_hyperlink}"/"${new_hyperlink}"}"

            (( i++ ))
        done
    fi

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
        printf '%s\n' "${toc_lines[0]}" > "${out_file}"
    fi
fi
