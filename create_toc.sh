#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-06-26

# Usage:
# bash create_toc.sh [--help | --usage | --version]
#                    [--add-titles]
#                    [--exclude-headings=HEADINGS...]
#                    [--exclude-levels=LEVELS...]
#                    [--in-place | --out-file=FILE]
#                    [--titles=TITLES]
#                    input_file

# Purpose: Extract Markdown headings from a file and convert them into a
# table of contents.

# Read and parse the arguments.
declare in_file
declare out_file
declare in_place
declare add_titles
declare -a toc_titles
declare number_headings
declare -a excluded_headings
declare -a excluded_levels

# shellcheck disable=SC2190  # Indexed, not associative array.
args=(
    "id                | short_opts | long_opts        | val_names  | defaults          | type | arg_no | arg_group            | help                                              "
    "in_file           |            |                  | input_file |                   | file |      1 | Positional arguments | the input file from which to get the headings     "
    "out_file          | o          | out-file         | FILE       | ''                | file |      1 | Options              | the output file to write the TOC to               "
    "in_place          | i          | in-place         |            | false             | bool |      0 | Options              | act in-place, writing the TOC to the input file   "
    "add_titles        | a          | add-titles       |            | true              | bool |      0 | Options              | add a title to each TOC                           "
    "toc_titles        | t          | titles           |            | Table of contents | str  |      + | Options              | the TOC titles to add to the TOCs                 "
    "number_headings   | n          | number-headings  |            | true              | bool |      0 | Options              | number the headings, in a \"1.2.3.4.5.6.\" fashion"
    "excluded_headings | e          | exclude-headings | HEADINGS   | ''                | str  |      + | Options              | comma-separated list of heading names to exclude  "
    "excluded_levels   | l          | exclude-levels   | LEVELS     | 0                 | uint |      + | Options              | comma-separated list of heading levels to exclude "
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

# Source the functions and categorize the lines.
if [[ "${BASH_SOURCE[0]}" == */* ]]; then
    directory="${BASH_SOURCE[0]%/*}"
else
    directory="."
fi

source "${directory}/functions.sh"
source "${directory}/categorize_lines.sh" "${in_file}"
mapfile -t lines < "${in_file}"

# Get the excluded heading levels and compute the included ones.
included_levels=( )
for included_level in 1 2 3 4 5 6; do
    for excluded_level in "${excluded_levels[@]}"; do
        if [[ "${included_level}" == "${excluded_level}" ]]; then
            continue 2
        fi
    done
    included_levels+=("${included_level}")
done

# Get the table-of-contents blocks, headings, and hyperlinks.
shopt -s extglob

headings=( )
heading_levels=( )
heading_line_indices=( )
hyperlinks=( )
hyperlink_line_indices=( )

is_toc_block=false
toc_level=1
toc_levels=( )
toc_starts=( )
toc_ends=( )

for i in "${!lines[@]}"; do
    if [[ "${categories[i]}" != "toc block" \
        && "${categories[i]}" != "heading"* \
        && "${categories[i]}" != "hyperlink" \
        && "${is_toc_block}" == false ]]
    then
        continue
    fi

    line="${lines[i]}"
    if [[ "${categories[i]}" == "toc block" ]]; then
        is_toc_block=true

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
            # The line denotes the end of the table of contents.
            toc_ends+=("${i}")
            is_toc_block=false
        fi
    elif [[ "${categories[i]}" == "heading"* && "${is_toc_block}" == false ]]
    then
        # The line is a heading.  Get the heading level and prepend as
        # many hashmarks as the heading level to the hashmark-stripped
        # heading to set ATX and setext headings to the same (ATX)
        # style.
        heading_line_indices+=("${i}")
        heading_level="${categories[i]##* }"
        heading_levels+=("${heading_level}")
        (( toc_level = heading_level + 1 ))

        heading="${line##+( )}"
        heading="${heading##+(\#)}"
        for (( j = 1; j <= heading_level; j++ )); do
            heading="#${heading}"
        done
        headings+=("${heading}")
    elif [[ "${categories[i]}" == "hyperlink" && "${is_toc_block}" == false  ]]
    then
        # The line contains at least one hyperlink. Extract it, then
        # shorten the line and try to match the pattern on the remainder
        # of the line.
        remainder="${line}"
        while [[ "${remainder}" =~ \[[^\]]*?\]\(\#[^\)]*?\) ]]; do
            hyperlink="${BASH_REMATCH[0]}"
            hyperlinks+=("${hyperlink}")
            remainder="${remainder#*"${hyperlink}"}"
            hyperlink_line_indices+=("${i}")
        done
    fi
done

# Create the links for the currently old (unmodified) headings.  Since
# the numbering may change, so does the link, which then needs to be
# updated, below.  To this end, store the old links in an indexed array.
declare -A links
old_heading_links=( )
for heading in "${headings[@]}"; do
    heading_to_link "${heading}"
    old_heading_links+=("${link}")
done
unset links

# Generate numbers for the headings.
numbers=( )
heading_level_counts=( )
prev_heading_level=0
for i in "${!headings[@]}"; do
    # Get the heading level.  If it shall be excluded, skip it.
    heading_level="${heading_levels[i]}"
    for excluded_level in "${excluded_levels[@]}"; do
        if [[ "${heading_level}" == "${excluded_level}" ]]; then
            numbers+=("")
            continue 2
        fi
    done

    # If the heading level is lower than the previous one, reset the
    # count in the previous level.  Increment the current level's count.
    if (( heading_level < prev_heading_level )); then
        for (( j = heading_level + 1; j <= prev_heading_level; j++ )); do
            (( heading_level_counts[j] = 0 ))
        done
    fi
    (( heading_level_counts[heading_level]++ ))

    # Generate the number in a "1.2.3.4.5.6." fashion, depending on the
    # heading level (i.e., only use as many numbers as the heading
    # level).  Don't assign numbers for skipped (excluded) levels.
    number=""
    for included_level in "${included_levels[@]}"; do
        if (( included_level <= heading_level )); then
            number+="${heading_level_counts[included_level]:-1}."
        fi
    done
    numbers+=("${number}")
    prev_heading_level="${heading_level}"
done

# Add the numbers to the headings, possibly replacing the previous
# number.
if [[ "${number_headings}" == true ]]; then
    for i in "${!headings[@]}"; do
        if [[ -n "${numbers[i]}" \
            && ("${headings[i]}" =~ ^(#+)( )([[:digit:]]+\.)+( )(.*) \
                || "${headings[i]}" =~ ^(#+)( )(.*)) ]]
        then
            headings[i]="${BASH_REMATCH[1]} ${numbers[i]} ${BASH_REMATCH[-1]}"
        fi
    done
fi

# Create the links for the new (modified) headings and store them in an
# indexed array.
declare -A links
new_heading_links=( )
for heading in "${headings[@]}"; do
    heading_to_link "${heading}"
    new_heading_links+=("${link}")
done
unset links

# Map the old heading links to the new heading links for later
# replacement in the hyperlinks.  Since the old links may have already
# been numbered or are still unnumbered, save also an unnumbered
# version.
declare -A numbered_replacement_links
declare -A unnumbered_replacement_links
for i in "${!old_heading_links[@]}"; do
    old_heading_link="${old_heading_links[i]}"
    numbered_replacement_links[${old_heading_link}]="${new_heading_links[i]}"

    old_heading_link="${old_heading_links[i]#+([[:digit:]])-}"
    unnumbered_replacement_links[${old_heading_link}]="${new_heading_links[i]}"
done

# Create the tables of contents.
tocs=( )
for i in "${!toc_levels[@]}"; do
    # Get all headings with the same or higher level, starting from the
    # current table of content's end line index.
    toc_level="${toc_levels[i]}"
    toc_end="${toc_ends[i]}"
    toc_headings=( )
    toc_heading_levels=( )
    for j in "${!headings[@]}"; do
        if (( "${heading_line_indices[j]}" > toc_end )); then
            if (( "${heading_levels[j]}" < toc_level )); then
                break
            fi
            toc_headings+=("${headings[j]}")
            toc_heading_levels+=("${heading_levels[j]}")
        fi
    done

    # Possibly, add the current table of contents' heading to the array.
    # The actual heading is added afterwards, such that the indentation
    # of the list items in the table of contents can be correctly
    # computed, without interfering with the heading.
    if [[ "${add_titles}" == true ]]; then
        printf -v toc_heading '%*s' "${toc_level}" ""
        toc_heading="${toc_heading// /#} ${toc_titles[i]:-"${toc_titles[0]}"}"
        toc_headings=("${toc_heading}" "${toc_headings[@]}")

        toc_heading_levels=("${toc_level}" "${toc_heading_levels[@]}")
    fi

    # Create the current table of contents, converting all headings
    # belonging to it to valid hyperlinks.
    toc_lines=( )
    declare -A links
    for j in "${!toc_headings[@]}"; do
        # Get the heading level.  If it shall be excluded, skip it.
        for excluded_level in "${excluded_levels[@]}"; do
            if [[ "${toc_heading_levels[j]}" == "${excluded_level}" ]]; then
                continue 2
            fi
        done

        # Convert the heading to a title suitable for the table of
        # contents.
        heading="${toc_headings[j]}"
        heading_to_title "${heading}"

        # If the heading name shall be excluded, skip it.
        for excluded_heading in "${excluded_headings[@]}"; do
            if [[ "${title}" == "${excluded_heading}" ]]; then
                continue 2
            fi
        done

        for toc_title in "${toc_titles[@]}"; do
            if [[ "${title}" == "${toc_title}"* ]]; then
                continue 2
            fi
        done

        # Create the required list item indentation per heading level
        # and set the list marker.
        if [[ "${number_headings}" == true ]]; then
            marker="1."
            (( count = "${toc_heading_levels[j]}" * 3 ))
        else
            marker="-"
            (( count = "${toc_heading_levels[j]}" * 2 ))
        fi
        printf -v indentation '%*s' "${count}" ""

        # Convert the heading's characters to create a valid link.
        heading_to_link "${heading}"

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
    # the heading level h6, which is 18 for numbered and 12 for bulleted
    # lists.
    if [[ "${number_headings}" == true ]]; then
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

    # Possibly, add now the current table of contents' heading,
    # including a trailing blank line (using an empty string in the
    # array).
    if [[ "${add_titles}" == true ]]; then
        toc_lines=("${toc_heading}" "" "${toc_lines[@]}")
    fi

    # Join the table of contents lines by newline characters and append
    # it to the previous tables of contents.
    tocs+=("$(printf '%s\n' "${toc_lines[@]}")")
done

# Write the lines to the output.
if [[ "${in_place}" == true ]] && (( "${#tocs[@]}" > 0 )); then
    # Possibly, replace the (now correctly numbered) headings and their
    # corresponding hyperlinks in the Markdown file.
    if [[ "${number_headings}" == true ]]; then
        # Replace the headings.
        i=0
        for j in "${heading_line_indices[@]}"; do
            lines[j]="${headings[i]}"
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
