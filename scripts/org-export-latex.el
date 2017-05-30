(require 'cli (concat (file-name-directory load-file-name) "org-export-cli.el"))

;; (byte-compile-file (concat (file-name-directory load-file-name) "cli.el"))
(setq options-alist
      '(("--infile" "path to input .org file")
        ("--outfile" "path to output .pdf file (use base name of infile by default)"
         nil)
        ("--evaluate" "evaluate source code blocks by default" nil)
        ("--css" "path or URL of css" nil)
        ("--embed-css" "Include contents of css in a <style> block" nil)
        ("--bootstrap" "make Bootstrap-specific modifications to html output;
                        if selected, link to Bootstrap CDN by default" nil)
        ("--package-dir" "directory containing elpa packages" "~/.org-export")
        ("--verbose" "enable debugging message on error" nil)
        ))

(setq args (cli-parse-args options-alist "
Options --infile and --outfile are required. Note that code block
evaluation is disabled by default; use '--evaluate' to set a
default value of ':eval yes' for all code blocks. If you would
like to evaluate by default without requiring this option,
include '#+PROPERTY: header-args :eval yes' in the file
header. Individual blocks can be selectively evaluated using
':eval yes' in the block header.
"))
(defun getopt (name) (gethash name args))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Package
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(cli-package-setup (getopt "package-dir") '(ess org org-plus-contrib org-ref))
(require 'ox)
(require 'org-ref)
(require 'ox-extra)
(ox-extras-activate '(ignore-headlines))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Global configuration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(require 'ox)
(require 'ox-latex)

(setq debug-on-error (getopt "verbose"))

;; general configuration
(setq make-backup-files nil)

;; ess configuration
(setq ess-ask-for-ess-directory nil)
(setq ess-history-file nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Latex configuration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun endless/export-audio-link (path desc format)
  "Export org audio links to hmtl."
  (cl-case format
    (latex (format "(HOW DO I EXPORT AUDIO TO LATEX? \"%s\")" path))))

(org-add-link-type "audio" #'ignore #'endless/export-audio-link)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; org-mode and export configuration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; store the execution path for the current environment and provide it
;; to sh code blocks - otherwise, some system directories are
;; prepended in the code block's environment. Would be nice to figure
;; out where these are coming from. This solves the problem for shell
;; code blocks, but not for other languages (like python).
(defvar exec-path-str
  (mapconcat 'identity exec-path ":"))
(defvar sh-src-prologue
  (format "export PATH=\"%s\"" exec-path-str))

(add-hook 'org-mode-hook
          '(lambda ()
             ;; (font-lock-mode)
             ;; (setq org-src-fontify-natively t)
             ;; (setq htmlize-output-type 'inline-css)
             (setq org-confirm-babel-evaluate nil)
             (setq org-export-allow-BIND 1)
             ;; (setq org-export-preserve-breaks t)
             ;; (setq org-export-with-sub-superscripts nil)
             ;; (setq org-export-with-section-numbers nil)

             ;; (setq org-html-head-extra my-html-head-extra)
             (setq org-babel-sh-command "bash")
             (setq org-babel-default-header-args
                   (list `(:session . "none")
                         `(:eval . ,(if (getopt "evaluate") "yes" "no"))
                         `(:results . "output replace")
                         `(:exports . "both")
                         `(:cache . "no")
                         `(:noweb . "no")
                         `(:hlines . "no")
                         `(:tangle . "no")
                         `(:padnewline . "yes")
                         ))

             ;; explicitly set the PATH in sh code blocks; note that
             ;; `list`, the backtick, and the comma are required to
             ;; dereference sh-src-prologue as a variable; see
             ;; http://stackoverflow.com/questions/24188100
             (setq org-babel-default-header-args:sh
                   (list `(:prologue . ,sh-src-prologue)))


	     (org-babel-do-load-languages 'org-babel-load-languages
					  '((emacs-lisp . t)
					    (dot . t)
					    (ditaa . t)
					    (R . t)
					    (ruby . t)
					    (gnuplot . t)
					    (clojure . t)
					    (sh . t)
					    (ledger . t)
					    (org . t)
					    (latex . t)
					    (python . t)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; org-mode and export configuration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar infile (getopt "infile"))
(defvar outfile
  (file-truename
   (or (getopt "outfile") (replace-regexp-in-string "\.org$" ".pdf" infile))))

;; remember the current directory; find-file changes it

(defvar cwd default-directory)
;; copy the source file to a temporary file; note that using the
;; infile as the base name defines the working directory as the same
;; as the input file
(defvar infile-temp (replace-regexp-in-string "\.pdf$" ".org" outfile))
(copy-file infile infile-temp t)
(find-file infile-temp)
(org-mode)
(message (format "org-mode version %s" org-version))
(org-latex-export-to-pdf)

;; ;; clean up
;; (setq default-directory cwd)
;; (delete-file infile-temp)
