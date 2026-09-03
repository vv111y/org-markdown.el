;;; org-markdown-test.el --- Tests for org-markdown -*- lexical-binding: t; -*-

(require 'ert)
(require 'org)
(require 'org-markdown)

(ert-deftest org-markdown-min-heading-level-in-string-test ()
  (should (equal (org-markdown-min-heading-level-in-string "plain text") nil))
  (should (= (org-markdown-min-heading-level-in-string "** B\n*** C\n") 2))
  (should (= (org-markdown-min-heading-level-in-string "text\n* A\n*** C\n") 1)))

(ert-deftest org-markdown-shift-headings-in-string-test ()
  (should (equal (org-markdown-shift-headings-in-string "plain" 3) "plain"))
  (should (equal (org-markdown-shift-headings-in-string "* A\n** B\n" 3)
                 "*** A\n**** B\n"))
  (should (equal (org-markdown-shift-headings-in-string "*** A\n**** B\n" 1)
                 "* A\n** B\n")))

(ert-deftest org-markdown-current-child-heading-level-test ()
  (with-temp-buffer
    (org-mode)
    (should (= (org-markdown-current-child-heading-level) 1))
    (insert "* A\nBody\n** B\nMore\n")
    (goto-char (point-min))
    (should (= (org-markdown-current-child-heading-level) 2))
    (goto-char (point-max))
    (should (= (org-markdown-current-child-heading-level) 3))))

(ert-deftest org-markdown-markdown-input-format-test ()
  (let ((org-markdown-markdown-input-format "gfm"))
    (let ((org-markdown-generate-heading-identifiers nil))
      (should (equal (org-markdown--markdown-input-format)
                     "gfm-gfm_auto_identifiers")))
    (let ((org-markdown-generate-heading-identifiers t))
      (should (equal (org-markdown--markdown-input-format) "gfm")))))

(ert-deftest org-markdown-pandoc-generated-heading-identifiers-test ()
  (skip-unless (executable-find org-markdown-pandoc-executable))
  (let ((org-markdown-markdown-input-format "gfm")
        (org-markdown-generate-heading-identifiers nil))
    (should-not
     (string-match-p
      ":CUSTOM_ID:"
      (org-markdown--convert-markdown-to-org "# Generated heading\n")))))

(ert-deftest org-markdown-pandoc-convert-smoke-test ()
  (skip-unless (executable-find org-markdown-pandoc-executable))
  (should (string-match-p "^\\* Heading"
                          (org-markdown-convert-string "# Heading\n"
                                                       "gfm" "org"))))

(provide 'org-markdown-test)
;;; org-markdown-test.el ends here
