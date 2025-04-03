# MarkdownTOC

`create_markdown_toc.sh` is a Bash script designed to generate a table of contents (TOC) for Markdown files. It extracts headings from the input Markdown file and converts them into a structured table of contents with valid hyperlinks, to be used in *e.g.* README files.

<!-- <toc> -->
## Table of contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
<!-- </toc> -->

## Features

The core script, `create_markdown_toc.sh`,

- supports **Markdown headings** in **ATX style** (one to six hashmarks, `#`) or **setext style** (underlined with `=` or `-`)
- skips "headings" inside **fenced** or **indented code blocks**
- generates **valid (and unique) hyperlinks** for each heading for a **clickable TOC**
- supports **in-place modification** of the input file or writing the TOC to a **separate output file**

## Installation

> [!WARNING]
> `create_markdown_toc.sh` requires Bash 4.0 or higher (try `bash --version`). It is tested with Bash 5.2, precisely, with `GNU bash, Version 5.2.21(1)-release (x86_64-pc-linux-gnu)`. If you encounter errors for versions earlier than 5.2, please file an issue, such that the minimum requirement can be adjusted.

No actual installation is necessary, as `create_markdown_toc.sh` is just a Bash script that can be located in an arbitrary directory of your choice, like `/usr/local/bin`. Thus, the "installation" is as simple as cloning the repository in this very directory:

```bash
# Switch to the installation directory of your choice, e.g., /usr/local/bin.
cd /path/to/directory

# Clone the repository.
git clone https://github.com/Simon-Brandt/MarkdownTOC.git
```

To be able to refer to `create_markdown_toc.sh` directly by its name, without providing the entire path, you may want to add

```bash
PATH="/path/to/MarkdownTOC:${PATH}"
```

(replace the `/path/to` with your actual path) to either of the following files (see `info bash` or `man bash`):

- `~/.profile` (local addition, for login shells)
- `~/.bashrc` (local addition, for non-login shells)
- `/etc/profile` (global addition, for login shells)
- `/etc/bash.bashrc` (global addition, for non-login shells)

> [!CAUTION]
> Be wary not to forget the final `${PATH}` component in the above command, or else you will override the [`PATH`](https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Variables.html#index-PATH "gnu.org &rightarrow; Bourne Shell Variables &rightarrow; PATH")) for all future shell sessions, meaning no other (non-builtin) command will be resolvable, anymore.

## Usage

Inside your Markdown file, all you need are two HTML comments reading

```html
<!-- <toc> -->
<!-- </toc> -->
```

*i.e.*, a virtual `<toc>` tag, along its closing tag, on separate lines, which contain no additional characters. Both tags must be commented out using HTML syntax (the only comment Markdown supports), such that they won't be shown in the rendered view.

Then, run `create_markdown_toc.sh` on your Markdown file, which will create the table of contents between these two HTML tags. Since they are kept, you can simply re-run the script to update the TOC, whenever you changed the file. Note that anything between these tags is *discarded*, since the script assumes that only the TOC may be given, there.

You may either run

```bash
create_markdown_toc.sh --out-file=<out_file.md> <in_file.md>
```

to get the resultant Markdown file written to `<out_file.md>`, or you can run

```bash
create_markdown_toc.sh --in-place <in_file.md>
```

to write the TOC directly into the input file, modifying it in-place.

When working with Git repositories, it may not be convenient to always have to re-run `create_markdown_toc.sh` by hand. Thus, using the provided sample [`pre-commit`](pre-commit) file, you can run the script *via* pre-commit hook anytime you create commits. Just copy `pre-commit` to `.git/hooks` in your Git repository, and before the actual commit happens, `create_markdown_toc.sh` will run over any Markdown file (with `.md` filename extension, change as appropriate) in the current staging level. After in-place modification, the Markdown files get staged, again, before committing them with the added or modified TOC. This means that both your changes and the TOC will be included in the same commit.
