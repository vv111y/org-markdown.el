;;; org-markdown.el --- Markdown/Org clipboard and subtree bridge -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Willy Rempel

;; Author: Willy Rempel <vv111y@users.noreply.github.com>
;; Maintainer: Willy Rempel <vv111y@users.noreply.github.com>
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: outlines, markdown, convenience, wp
;; URL: https://github.com/vv111y/org-markdown.el
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; org-markdown is a small Pandoc-backed bridge for users who think and
;; plan in Org mode but exchange text with agents, repositories, and GitHub in
;; Markdown.  It provides commands for converting Markdown clipboard or region
;; contents to Org, pasting converted Org relative to the current heading level,
;; and exporting Org regions or subtrees back to Markdown.

;;; Code:

(require 'org)
(require 'subr-x)

(defgroup org-markdown nil
  "Pandoc-backed Markdown/Org conversion helpers."
  :group 'org
  :prefix "org-markdown-")

(defcustom org-markdown-pandoc-executable "pandoc"
  "Pandoc executable used by `org-markdown-convert-string'."
  :type 'string
  :group 'org-markdown)

(defcustom org-markdown-markdown-input-format "gfm"
  "Pandoc input format used for Markdown imports.

The default is GitHub Flavored Markdown because agent output and repository
files commonly use fenced code blocks, task lists, and tables."
  :type 'string
  :group 'org-markdown)

(defcustom org-markdown-markdown-output-format "gfm"
  "Pandoc output format used for Markdown exports."
  :type 'string
  :group 'org-markdown)

(defcustom org-markdown-org-format "org"
  "Pandoc format name used for Org conversion."
  :type 'string
  :group 'org-markdown)

(defcustom org-markdown-pandoc-extra-arguments '("--wrap=none")
  "Additional arguments passed to Pandoc for all conversions."
  :type '(repeat string)
  :group 'org-markdown)

(defcustom org-markdown-preserve-raw-on-prefix t
  "Whether prefix paste should preserve the original Markdown in an Org block."
  :type 'boolean
  :group 'org-markdown)

(defun org-markdown--pandoc-error-text (file)
  "Return trimmed Pandoc stderr from FILE."
  (if (and file (file-exists-p file))
      (string-trim
       (with-temp-buffer
         (insert-file-contents file)
         (buffer-string)))
    "unknown error"))

;;;###autoload
(defun org-markdown-convert-string (string from to)
  "Convert STRING from Pandoc format FROM to Pandoc format TO.

This function shells out to `org-markdown-pandoc-executable'.  FROM and TO are
Pandoc format strings such as `gfm' and `org'."
  (unless (executable-find org-markdown-pandoc-executable)
    (user-error "Pandoc not found; customize `org-markdown-pandoc-executable' or install pandoc"))
  (let ((out (generate-new-buffer " *org-markdown pandoc out*"))
        (errfile (make-temp-file "org-markdown-pandoc-stderr-")))
    (unwind-protect
        (with-temp-buffer
          (insert string)
          (let ((status
                 (apply #'call-process-region
                        (point-min) (point-max)
                        org-markdown-pandoc-executable nil
                        (list out errfile) nil
                        (append (list "-f" from "-t" to)
                                org-markdown-pandoc-extra-arguments))))
            (unless (zerop status)
              (user-error "Pandoc failed: %s"
                          (org-markdown--pandoc-error-text errfile)))
            (with-current-buffer out
              (buffer-string))))
      (when (buffer-live-p out)
        (kill-buffer out))
      (when (file-exists-p errfile)
        (delete-file errfile)))))

(defun org-markdown--clipboard-string ()
  "Return clipboard text, falling back to the kill ring."
  (let ((selection (when (fboundp 'gui-get-selection)
                     (gui-get-selection 'CLIPBOARD 'UTF8_STRING))))
    (cond
     ((stringp selection) selection)
     ((and kill-ring (stringp (current-kill 0 t))) (current-kill 0 t))
     (t nil))))

(defun org-markdown-current-child-heading-level ()
  "Return the Org heading level that should be used for a pasted child.

Inside an Org subtree, the returned level is one deeper than the current
heading.  Outside Org mode, or before the first heading, return 1."
  (if (derived-mode-p 'org-mode)
      (save-excursion
        (condition-case nil
            (progn
              (org-back-to-heading t)
              (1+ (org-outline-level)))
          (error 1)))
    1))

(defun org-markdown-min-heading-level-in-string (string)
  "Return the smallest Org heading level in STRING, or nil if none exists."
  (let (min-level)
    (with-temp-buffer
      (insert string)
      (goto-char (point-min))
      (while (re-search-forward "^\\(\\*+\\)[ \\t]" nil t)
        (let ((level (length (match-string 1))))
          (setq min-level (if min-level (min min-level level) level)))))
    min-level))

(defun org-markdown-shift-headings-in-string (string target-root-level)
  "Shift Org headings in STRING so its shallowest heading becomes TARGET-ROOT-LEVEL.

Relative heading depth is preserved.  If STRING contains no Org headings, return
it unchanged."
  (let ((min-level (org-markdown-min-heading-level-in-string string)))
    (if (not min-level)
        string
      (let ((delta (- target-root-level min-level)))
        (with-temp-buffer
          (insert string)
          (goto-char (point-min))
          (while (re-search-forward "^\\(\\*+\\)[ \\t]" nil t)
            (let* ((old-level (length (match-string 1)))
                   (new-level (max 1 (+ old-level delta))))
              (replace-match (make-string new-level ?*) t t nil 1)))
          (buffer-string))))))

(defun org-markdown--raw-markdown-block (markdown)
  "Return MARKDOWN wrapped in an Org source block."
  (concat "#+begin_src markdown\n" markdown "\n#+end_src\n\n"))

(defun org-markdown--convert-markdown-to-org (markdown &optional relative)
  "Convert MARKDOWN to Org.

When RELATIVE is non-nil, shift converted headings so the converted root heading
is a child of the current Org heading."
  (let ((org (org-markdown-convert-string
              markdown
              org-markdown-markdown-input-format
              org-markdown-org-format)))
    (if relative
        (org-markdown-shift-headings-in-string
         org (org-markdown-current-child-heading-level))
      org)))

;;;###autoload
(defun org-markdown-paste-clipboard-as-org (&optional preserve-raw)
  "Convert Markdown clipboard text to Org and insert it at point.

Converted headings are shifted so the shallowest pasted heading becomes a child
of the current Org heading.  With prefix argument PRESERVE-RAW, also insert the
original Markdown in a source block before the converted Org content."
  (interactive "P")
  (let* ((markdown (org-markdown--clipboard-string))
         (org (and markdown (org-markdown--convert-markdown-to-org markdown t))))
    (unless markdown
      (user-error "No clipboard or kill-ring text found"))
    (insert (if (and preserve-raw org-markdown-preserve-raw-on-prefix)
                (concat (org-markdown--raw-markdown-block markdown) org)
              org))))

;;;###autoload
(defun org-markdown-replace-region-or-buffer-with-org (beg end &optional relative)
  "Replace Markdown region or buffer between BEG and END with Org.

When called interactively with an active region, convert that region.  Otherwise
convert the whole buffer.  With prefix argument RELATIVE, shift converted headings
relative to the current Org parent."
  (interactive
   (append
    (if (use-region-p)
        (list (region-beginning) (region-end))
      (list (point-min) (point-max)))
    (list current-prefix-arg)))
  (let ((org (org-markdown--convert-markdown-to-org
              (buffer-substring-no-properties beg end)
              relative)))
    (delete-region beg end)
    (insert org)))

;;;###autoload
(defun org-markdown-copy-region-as-markdown (beg end)
  "Convert Org region between BEG and END to Markdown and copy it to kill ring."
  (interactive "r")
  (kill-new
   (org-markdown-convert-string
    (buffer-substring-no-properties beg end)
    org-markdown-org-format
    org-markdown-markdown-output-format))
  (message "Copied Markdown to kill ring"))

;;;###autoload
(defun org-markdown-copy-subtree-as-markdown ()
  "Convert the current Org subtree to Markdown and copy it to kill ring."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "This command requires Org mode"))
  (save-restriction
    (org-narrow-to-subtree)
    (org-markdown-copy-region-as-markdown (point-min) (point-max))))

;;;###autoload
(defun org-markdown-export-subtree-to-markdown-file (file)
  "Convert the current Org subtree to Markdown and write it to FILE."
  (interactive "FExport subtree to Markdown file: ")
  (unless (derived-mode-p 'org-mode)
    (user-error "This command requires Org mode"))
  (save-restriction
    (org-narrow-to-subtree)
    (let ((markdown
           (org-markdown-convert-string
            (buffer-substring-no-properties (point-min) (point-max))
            org-markdown-org-format
            org-markdown-markdown-output-format)))
      (with-temp-file file
        (insert markdown))))
  (message "Wrote %s" file))

(provide 'org-markdown)
;;; org-markdown.el ends here
