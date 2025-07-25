<!--
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
-->

# Markdown Tools

The Markdown Tools serve as simple, yet powerful means to extend the features of Markdown ([CommonMark](https://spec.commonmark.org/ "spec.commonmark.org") / [GitHub Flavored Markdown (GFM)](https://github.github.com/gfm/ "github.github.com &rightarrow; GFM") flavor). However, introducing additional syntax elements would mean that the ususal Markdown renderers would not recognize them and instead show the raw syntax (or, even worse, some differently interpreted version due to similarity with other constructs).

Instead, the Markdown Tools use special HTML comments to denote the start and end of blocks, which the Markdown parser simply ignores&mdash;they're comments, after all. In contrast, the Markdown Tools parser recognizes the special syntax in these comments and performs the required tasks to enhance the Markdown file (commonly in-place). This means that the rendering is unaffected, since the new features use standard Markdown constructs.

Since the HTML comments are kept in the modified file, it is possible to re-run the Markdown Tools parser anytime, despite its in-place modifications. By this, the Markdown Tools can be used in [pre-commit hooks](#4-pre-commit-hook) to update the Markdown file prior submission to a Version Control System (VCS), like GitHub.

<!-- <toc> -->
## Table of contents

1. [Features](#1-features)
1. [Installation](#2-installation)
   1. [Download](#21-download)
   1. [Dependencies](#22-dependencies)
   1. [License](#23-license)
1. [Usage](#3-usage)
   1. [Tables of contents (TOCs)](#31-tables-of-contents-tocs)
   1. [Figure and table captions](#32-figure-and-table-captions)
   1. [Include directives](#33-include-directives)
   1. [Include directive example](#34-include-directive-example)
   1. [Sections](#35-sections)
1. [Pre-commit hook](#4-pre-commit-hook)
<!-- </toc> -->

## 1. Features

The Markdown Tools currently add three features to Markdown:

- tables of contents (TOCs)
- file and command output inclusion
- splitting into separate files by section

These features may enhance *e.g.* README files, such as this one or the [Shell Argparser](https://github.com/Simon-Brandt/ShellArgparser.git "github.com &rightarrow; Simon-Brandt &rightarrow; ShellArgparser") documentation.

## 2. Installation

It is not necessary to *install* the Markdown Tools, since they are just several Bash scripts. You just need to download them into an arbitrary directory, like `/usr/local/bin`.

### 2.1. Download

The "installation" is as simple as cloning the repository in this very directory:

```bash
# Switch to the installation directory of your choice, e.g., /usr/local/bin.
cd /path/to/directory

# Clone the repository.
git clone https://github.com/Simon-Brandt/MarkdownTools.git
```

To be able to refer to the Markdown Tools directly by the scripts' names, without providing the entire path, you may want to add

```bash
PATH="/path/to/MarkdownTools:${PATH}"
```

(replace the `/path/to` with your actual path) to either of the following files (see `info bash` or `man bash`):

- `~/.profile` (local addition, for login shells)
- `~/.bashrc` (local addition, for non-login shells)
- `/etc/profile` (global addition, for login shells)
- `/etc/bash.bashrc` (global addition, for non-login shells)

> [!CAUTION]
> Be wary not to forget the final `${PATH}` component in the above command, or else you will override the [`PATH`](https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Variables.html#index-PATH "gnu.org &rightarrow; Bourne Shell Variables &rightarrow; PATH")) for all future shell sessions, meaning no other (non-builtin) command will be resolvable, anymore.

### 2.2. Dependencies

- Bash &geq; 4.0
- [`mkdir`](https://man7.org/linux/man-pages/man1/mkdir.1.html "man7.org &rightarrow; man pages &rightarrow; mkdir(1)")
- [`rm`](https://man7.org/linux/man-pages/man1/rm.1.html "man7.org &rightarrow; man pages &rightarrow; rm(1)")
- [Shell Argparser](https://github.com/Simon-Brandt/ShellArgparser.git "github.com &rightarrow; Simon-Brandt &rightarrow; ShellArgparser")

The Markdown Tools require Bash to run, since they use non-POSIX features like associative arrays. They are tested with Bash 5.2, precisely, with `GNU bash, Version 5.2.21(1)-release (x86_64-pc-linux-gnu)`. If you encounter errors for versions earlier than 5.2, please file an issue, such that the minimum requirement of &geq; 4.0 can be adjusted.

Almost all functionality is implemented using Bash builtins. However, Bash doesn't provide builtins for accessing the file system, apart from reading and writing files. Thus, you need to have both [`mkdir`](https://man7.org/linux/man-pages/man1/mkdir.1.html "man7.org &rightarrow; man pages &rightarrow; mkdir(1)") and [`rm`](https://man7.org/linux/man-pages/man1/rm.1.html "man7.org &rightarrow; man pages &rightarrow; rm(1)") installed and in your [`PATH`](https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Variables.html#index-PATH "gnu.org &rightarrow; Bourne Shell Variables &rightarrow; PATH").

For parsing the scripts' command line, the [Shell Argparser](https://github.com/Simon-Brandt/ShellArgparser.git "github.com &rightarrow; Simon-Brandt &rightarrow; ShellArgparser") is necessary. If you don't want to or can't introduce this non-standard dependency, you would need to modify the scripts to use other parsers, like [`getopt`](https://man7.org/linux/man-pages/man1/getopt.1.html "man7.org &rightarrow; man pages &rightarrow; getopt(1)").

### 2.3. License

The Markdown Tools are licensed under the terms and conditions of the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0 "apache.org &rightarrow; Licenses &rightarrow; Apache License, Version 2.0"). This applies to all source code files (shell scripts) and the documentation (this [README](README.md)), with the exception of [`example.sh`](example.sh) and [`example.md`](example.md), as well as the [`.shellcheckrc`](.shellcheckrc) and [`.gitignore`](.gitignore), which are all placed in the Public Domain.

The Apache License v2.0 allows running, modifying, and distributing the Markdown Tools, even in commercial settings, provided that the license is distributed along the source code or compiled objects. *(This is not legal advice. Read the [license](LICENSE) for the exact terms.)*

## 3. Usage

All feature extensions use a distinct HTML comment (the only comment Markdown supports), whose general format is:

```markdown
<!-- <feature key="value"> -->
<!-- </feature> -->
```

Despite intentionally looking like HTML tags inside comments, the feature tags are made up by the Markdown Tools and don't necessarily form valid HTML. Both tags must stand alone on separate lines, which must not contain any additional characters. Since the tags must be commented out using HTML syntax, they won't be shown in the rendered view.

The first line starts the respective feature block and possibly specifies several parameters, the last line ends the block. Usually, all lines in-between are replaced upon running the Markdown Tools, which facilitates the re-computation of the respective feature. Since the comment tags are kept, you can simply re-run the script to update *e.g.* the TOC, whenever you changed the file.

Note that for TOCs and included files, anything between these tags is *discarded*, since the script assumes that only the TOC or file content may be given, there. Section tags are kept, however, since they delimit the actual contents of your Markdown file.

Upon parsing the Markdown file, the Markdown Tools do their best to implement the rules of [GitHub Flavored Markdown (GFM)](https://github.github.com/gfm/ "github.github.com &rightarrow; GFM") to classify (categorize) the lines. Still, the standard is *not* fully implemented, mainly for performance reasons. The Markdown Tools support Markdown headings in ATX style (one to six hashmarks, `#`) or setext style (underlined with `=` or `-`), and respect fenced or indented code blocks. Therein, "headings" (or whatever looks like them, such as Bash comments) are simply ignored. This also holds for the Markdown Tools' special HTML comments, which can safely be given in code blocks.

### 3.1. Tables of contents (TOCs)

A table of contents (TOC) serves as quick overview for the user to see which topics a section deals with. The Markdown Tools' [`create_toc.sh`](create_toc.sh) script allows for the inclusion of as many TOCs as desired, to be able to summarize all headings within the current heading level. It extracts headings from the input Markdown file and converts them into a table of contents with valid hyperlinks.

Thereby, `create_toc.sh`

- generates valid, unique hyperlinks for each heading for clickable TOCs
- adds titles to the TOCs
- allows excluding certain headings or heading levels
- allows the numbering of headings in a `"1.2.3.4.5.6."` fashion
- supports in-place modification of the input file or writing the TOCs to a separate output file

To add the TOC, you need either of the following two HTML comments:

```markdown
<!-- <toc> -->
<!-- <toc title="Table of contents" -->
```

followed by the closing tag

```markdown
<!-- </toc> -->
```

The first version adds the next title from the command line to the TOC, while the second version instead uses the specified title.

Then, run `create_toc.sh` on your Markdown file, which will create the table of contents between these two HTML tags. You may either run

```bash
create_toc.sh --out-file=<out_file.md> -- <in_file.md>
```

to get the resultant Markdown file written to `<out_file.md>`, or you can run

```bash
create_toc.sh --in-place -- <in_file.md>
```

to write the TOC directly into the input file, modifying it in-place.

There are several command-line parameters available:

- `-a`, `--add-titles`: add a title to each TOC (default: `true`)
- `-e`, `--exclude-headings=HEADINGS`: comma-separated list of heading names to exclude (default: `""`)
- `-l`, `--exclude-levels=LEVELS`: comma-separated list of heading levels to exclude (default: `0`)
- `-i`, `--in-place`: act in-place, writing the TOC to the input file (default: `false`)
- `-n`, `--number-headings`: number the headings, in a `"1.2.3.4.5.6."` fashion (default: `true`)
- `-o`, `--out-file=FILE`: the output file to write the TOC to (default: `""`)
- `-t`, `--titles=TITLES`: the TOC titles to add to the TOCs (default: `"Table of contents"`)

### 3.2. Figure and table captions

Figures and tables provide information in a very condensed form. They may explain facts briefer than text, but are usually not self-explanatory. This is where figure and table captions can help, since they describe the intent in one or two short sentences, facilitating understanding of the figure's or table's contents. Thus, the Markdown Tools' [`create_captions.sh`](create_captions.sh) adds these captions to existing tables and the figures it includes.

Thereby, `create_captions.sh`

- includes figures according to their filepath
- adds captions to figures and tables
- numbers both caption types individually and sequentially (as `Fig. <number>: <caption>.` or `Tab. <number>: <caption>.`)

To add captions, you need either of the following HTML comments:

```markdown
<!-- <figure file="/path/to/file" caption="Figure caption"> -->
<!-- <table caption="Table caption"> -->
```

without a closing tag. Instead, the next empty line delimits the caption. The first version includes a file and adds the caption to it, the second version adds the caption to the already existing table. The caption must not end in a period, as the script adds one by itself, doubling the period, otherwise.

Then, run `create_captions.sh` on your Markdown file, which will create the captions. The inclusion is always in-place, so the command simply is:

```bash
create_captions.sh <in_file.md>
```

### 3.3. Include directives

When *e.g.* showing the output of a certain command to be documented, one needs to keep the command's functionality and its documentation in sync. Therefore, the Markdown Tools' [`include_file.sh`](include_file.sh) script includes other files, or the output of commands, in the Markdown file using an include directive.

To this end, `include_file.sh`

- includes a file's contents
- runs commands and captures their STDOUT and STDERR
- optionally surrounds the data with a fenced code block
- supports language specifications as identifier for the fenced code block for syntax highlighting by an appropriate Markdown renderer
- includes the command as first line *iff* the language specification is `console`, and precedes it by a `$` and space.

To include a file, you need either of the following HTML comments:

```markdown
<!-- <include file="/path/to/file"> -->
<!-- <include file="/path/to/file" lang="lang_spec"> -->
<!-- <include command="cmd"> -->
<!-- <include command="cmd" lang="lang_spec"> -->
```

followed by the closing tag

```markdown
<!-- </include> -->
```

The former two versions include a file, the latter two the command's output (STDOUT and STDERR). The second and fourth form put the output in a fenced code block and add a language identifier.

Then, run `include_file.sh` on your Markdown file, which will include the file or command output between these two HTML tags. The inclusion is always in-place, so the command simply is:

```bash
include_file.sh <in_file.md>
```

Imagine that you want to include a Bash script (here the "Hello, world!" script from [`example.sh`](example.sh)) as an example of how to run it. Then, you need to specifiy the two tags

```markdown
<!-- <include file="example.sh" lang="bash"> -->
<!-- </include> -->
```

on the desired position in your Markdown file, run `include_file.sh`, and between these tags, the script will be inserted (overwriting the previous contents, if already existing). This yields:

<!-- <include file="example.sh" lang="bash"> -->
```bash
#!/bin/bash

# Author: Simon Brandt
# E-Mail: simon.brandt@uni-greifswald.de
# Last Modification: 2025-05-28

printf "Hello, world!\n"
```
<!-- </include> -->

So, we have the file included, surrounded by a fenced code block and using Bash syntax highlighting.

Likewise, we could include the contents of a Markdown file (here [`example.md`](example.md)), but this time using a command ([`sed`](https://man7.org/linux/man-pages/man1/sed.1.html "man7.org &rightarrow; man pages &rightarrow; sed(1)")):

```markdown
<!-- <include command="sed 's/^#/###/' example.md"> -->
```

This includes `sed`'s output as normal Markdown, which is then interpreted by the renderer:

<!-- <include command="sed 's/^#/###/' example.md"> -->
### 3.4. Include directive example
 
 <!-- <include command="printf '%s\n' "This line has been included.""> -->
 This line has been included.
 <!-- </include> -->
<!-- </include> -->

In the raw view, you can see that the Markdown file contains another include directive (interpreted by running `include_file.sh` on `example.md`):

<!-- <include command="sed 's/^#/###/' example.md" lang="markdown"> -->
 ```markdown
 ### Include directive example
 
 <!-- <include command="printf '%s\n' "This line has been included.""> -->
 This line has been included.
 <!-- </include> -->
```
<!-- </include> -->

This shows that you don't need to (and must not) escape potential quotes in your command. Further, since the include directive in the file must not be interpreted upon parsing the README, it is indented by one space. However, as this is not visible in the rendered view, just in the raw file, you shouldn't need to care about it.

### 3.5. Sections

For larger software, the documentation may grow to a point where it becomes unhandy for the reader to have everything kept in the same file. While it may still be advantageous to write the documentation in one single file (like for ease of cross-referencing sections), the reader might better obtain the documentation in separate files. To this end, the Markdown Tools' [`split_sections.sh`](split_sections.sh) script supports section tags, with which you can group sections. Any text between an opening and closing section tag will be output into a distinct file (possibly inside a subdirectory).

Thereby, `split_sections.sh`

- splits a Markdown file by section into separate files
- updates any hyperlink in the split files to point to the novel file the referred section has moved to
- possibly removes and re-creates the input file's (sub-)directories and/or companion (accompanying) files, such that within subdirectories and the CWD, only current files are located (and no files from former runs, after which you re-named a section and thus file)
- possibly prepends a comment block, *e.g.*, for a license note, to each file, when the Markdown file starts with a comment block
- appends a link to the previous and/or next section to each file (using the first heading or filename as link text), creating a contiguous documentation

To split a file, you need the following two HTML comments:

```markdown
<!-- <section file="/path/to/file"> -->
<!-- </section> -->
```

Then, run `split_sections.sh` on your Markdown file, which will split the file into sections, delimited by these two HTML tags. Since no change to the input file happens, the command simply is either of the following:

```bash
split_sections.sh <in_file.md>
split_sections.sh --to-files -- <in_file.md>
split_sections.sh --to-headings -- <in_file.md>
split_sections.sh --to-files --to-headings -- <in_file.md>
```

The command-line parameters are as follows:

- `-f`, `--to-files`: use the filename as link text on section ends (default: `false`)
- `-h`, `--to-headings`: use the first heading as link text on section ends (default: `false`)
- `--rm-dirs`: remove all (sub-)directories from the CWD, for a clean start (default: `false`)
- `--rm-files`: remove all files in the CWD, except for `input_file`, for a clean start (default: `false`)

If both `--to-files` and `--to-headings` are omitted (`false`), only arrows will be drawn for the links.

> [!CAUTION]
> With `--rm-dirs` and `--rm-files`, you purge the files! In a Git repository, this may not be overly problematic, since files can be restored from the history, but to reduce the risk of inadvertently deleting files, both flags only have long option names that you need to type explicitly. Only use these options when you're 100&#8239;% sure that there are only files in the input file's directory which can be re-created from the `split_sections.sh` run, or should indeed be deleted. This may be true when having a `docs` directory with one source Markdown file, from which all other documentation files are generated. When running `split_sections.sh --rm-dirs --rm-files`, these files are either re-created or deleted as intended.

## 4. Pre-commit hook

When working with Git repositories, it may not be convenient to always have to re-run the Markdown Tools scripts by hand. Thus, using the provided sample [`pre-commit`](.hooks/pre-commit) file, you can run the scripts *via* a pre-commit hook anytime you create commits. Just copy or symlink `pre-commit` to `.git/hooks` in your Git repository, and before the actual commit happens, the Markdown Tools will run over any Markdown file (with `.md` filename extension, change as appropriate) in the current staging level.

After in-place modification, the Markdown files get staged, again, before committing them with the added or modified TOC, included file, or section splitting. This means that both your changes and the ones from the Markdown Tools will be included in the same commit.

Note that for simplicity, the sample hook also stages all other modifications within the Markdown file, so you can't change multiple locations prior committing them sequentially&mdash;they would be staged for commit all at once.
