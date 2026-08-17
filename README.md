# org-markdown.el

`org-markdown.el` is a small Pandoc-backed bridge for using Org mode comfortably in a Markdown-dominant agentic workflow.

The intended model:

- agents, GitHub, READMEs, specs, and project templates speak Markdown;
- personal thinking, capture, review, agenda, and knowledge work remain in Org;
- Pandoc translates at the boundary;
- Emacs provides workflow-specific commands instead of manual conversion.

## Features

- Convert Markdown clipboard text to Org and paste at point.
- Shift pasted Org headings relative to the current Org parent heading.
- Optionally preserve the original Markdown before the converted Org.
- Replace a Markdown region or buffer with Org.
- Convert Org regions or subtrees back to Markdown.
- Export the current Org subtree to a Markdown file.

## Requirements

- Emacs 27.1 or newer
- Org mode
- [Pandoc](https://pandoc.org/)

On macOS with Homebrew:

```sh
brew install pandoc
```

On Debian/Ubuntu:

```sh
sudo apt-get install pandoc
```

## Installation

With straight.el:

```elisp
(straight-use-package
 '(org-markdown :type git
                :host github
                :repo "vv111y/org-markdown.el"))
```

With use-package and straight.el:

```elisp
(use-package org-markdown
  :straight (:type git :host github :repo "vv111y/org-markdown.el")
  :commands (org-markdown-paste-clipboard-as-org
             org-markdown-replace-region-or-buffer-with-org
             org-markdown-copy-region-as-markdown
             org-markdown-copy-subtree-as-markdown
             org-markdown-export-subtree-to-markdown-file))
```

Manual installation:

```elisp
(add-to-list 'load-path "/path/to/org-markdown.el")
(require 'org-markdown)
```

## Commands

| Command | Purpose |
| --- | --- |
| `org-markdown-paste-clipboard-as-org` | Convert Markdown clipboard text to Org and insert it under the current parent heading. |
| `org-markdown-replace-region-or-buffer-with-org` | Convert the active Markdown region, or whole buffer if no region, to Org. |
| `org-markdown-copy-region-as-markdown` | Convert an Org region to Markdown and copy it to the kill ring. |
| `org-markdown-copy-subtree-as-markdown` | Convert the current Org subtree to Markdown and copy it to the kill ring. |
| `org-markdown-export-subtree-to-markdown-file` | Convert the current Org subtree to Markdown and write it to a file. |

## Heading-relative paste

When pasting Markdown into an Org subtree, `org-markdown-paste-clipboard-as-org` treats the shallowest heading in the converted Org as the pasted root and shifts it one level below the current Org heading.

Given point here:

```org
* Project
** Parent
   <point>
```

And Markdown on the clipboard:

```markdown
# A
## B
### C
```

The command inserts:

```org
*** A
**** B
***** C
```

If point is before the first Org heading, converted headings remain top-level.

## Preserving raw Markdown

Call `org-markdown-paste-clipboard-as-org` with a prefix argument to insert the original Markdown in an Org source block before the converted Org.

In vanilla Emacs:

```text
C-u M-x org-markdown-paste-clipboard-as-org
```

This is useful for agent output because Markdown to Org conversion is good but not perfectly lossless, especially for unusual tables, HTML fragments, admonitions, task-list dialects, or Mermaid blocks.

## Suggested bindings

Vanilla Emacs:

```elisp
(global-set-key (kbd "C-c m p") #'org-markdown-paste-clipboard-as-org)
(global-set-key (kbd "C-c m o") #'org-markdown-replace-region-or-buffer-with-org)
(global-set-key (kbd "C-c m k") #'org-markdown-copy-subtree-as-markdown)
```

Spacemacs:

```elisp
(spacemacs/set-leader-keys
  "xmp" #'org-markdown-paste-clipboard-as-org
  "xmo" #'org-markdown-replace-region-or-buffer-with-org
  "xmk" #'org-markdown-copy-subtree-as-markdown)
```

## Configuration

```elisp
(setq org-markdown-pandoc-executable "pandoc")
(setq org-markdown-markdown-input-format "gfm")
(setq org-markdown-markdown-output-format "gfm")
(setq org-markdown-pandoc-extra-arguments '("--wrap=none"))
```

## Development

Run tests:

```sh
make test
```

Byte-compile:

```sh
make compile
```

Clean generated files:

```sh
make clean
```

## License

MIT
