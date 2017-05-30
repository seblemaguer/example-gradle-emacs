(require 'cli (concat (file-name-directory load-file-name) "org-export-cli.el"))

;; (byte-compile-file (concat (file-name-directory load-file-name) "cli.el"))
(setq options-alist
      '(("--infile" "path to input .org file")
        ("--outfile" "path to output .html file (use base name of infile by default)"
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
(cli-package-setup (getopt "package-dir") '(ess htmlize org org-plus-contrib ox-reveal org-ref))
(require 'ox)
(require 'ox-reveal)
(require 'org-ref)
(require 'ox-extra)
(ox-extras-activate '(ignore-headlines))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Global configuration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(setq debug-on-error (getopt "verbose"))

;; general configuration
(setq make-backup-files nil)

;; ess configuration
(setq ess-ask-for-ess-directory nil)
(setq ess-history-file nil)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; HTML configuration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; css configuration
(defvar bootstrap-url
  "http://netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css")

(defvar css-url (getopt "css"))
(if (getopt "bootstrap")
    (setq css-url (or css-url bootstrap-url)))

(defvar my-html-head "")
(if css-url
    (if (getopt "embed-css")
        ;; embed css contents in a <style> block
        (progn
          (setq my-html-head
                (format "<style type=\"text/css\">\n%s\n</style>\n"
                        (if (string-match "^http" css-url)
                            ;; use the contents of file at path
                            (with-current-buffer
                                (url-retrieve-synchronously css-url)
                              (message (format "Inserting contents of %s" css-url))
                              (buffer-string))
                          ;; use the contents of the file at css-url
                          (with-temp-buffer
                            (insert-file-contents css-url)
                            (buffer-string)))
                        )))
      ;; ...or add a link to the css file
      (setq my-html-head
            (format
             "<link rel=\"stylesheet\" type=\"text/css\" href=\"%s\" />" css-url))))


;; Redefined to avoid problem with sizing
(defun org-html--svg-image (source attributes info)
  "Return \"object\" embedding svg file SOURCE with given ATTRIBUTES.
INFO is a plist used as a communication channel.

The special attribute \"fallback\" can be used to specify a
fallback image file to use if the object embedding is not
supported.  CSS class \"org-svg\" is assigned as the class of the
object unless a different class is specified with an attribute."
  (org-html-close-tag
     "img"
     (org-html--make-attribute-string
      (org-combine-plists
       (list :src source
	     :alt (if (string-match-p "^ltxpng/" source)
		      (org-html-encode-plain-text
		       (org-find-text-property-in-string 'org-latex-src source))
		    (file-name-nondirectory source)))
       attributes))
     info))


(defun endless/export-audio-link (path desc format)
  "Export org audio links to hmtl."
  (cl-case format
    (html (format "<audio src=\"%s\" controls>%s</audio>" path (or desc "")))))
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
             (setq org-confirm-babel-evaluate nil)
             (setq org-export-allow-BIND 1)
             (setq org-html-doctype "html5")
             (setq org-html-head my-html-head)
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
;;;; Reveal export redefined
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun org-reveal-export-as-html
  (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer to an HTML buffer.

If narrowing is active in the current buffer, only export its
narrowed part.

If a region is active, export that region.

A non-nil optional argument ASYNC means the process should happen
asynchronously.  The resulting buffer should be accessible
through the `org-export-stack' interface.

When optional argument SUBTREEP is non-nil, export the sub-tree
at point, extracting information from the headline properties
first.

When optional argument VISIBLE-ONLY is non-nil, don't export
contents of hidden elements.

When optional argument BODY-ONLY is non-nil, only write code
between \"<body>\" and \"</body>\" tags.

EXT-PLIST, when provided, is a property list with external
parameters overriding Org default settings, but still inferior to
file-local settings.

Export is done in a buffer named \"*Org REVEAL Export*\", which
will be displayed when `org-export-show-temporary-export-buffer'
is non-nil."
  (interactive)
  (org-export-to-buffer 'reveal "*Org REVEAL Export*"
    async subtreep visible-only body-only ext-plist
    (lambda () (set-auto-mode t))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; compile and export ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar infile (getopt "infile"))
(defvar outfile
  (file-truename
   (or (getopt "outfile")
       (replace-regexp-in-string "\.org$" ".html" infile))))

;; remember the current directory; find-file changes it
(defvar cwd default-directory)

;; copy the source file to a temporary file; note that using the
;; infile as the base name defines the working directory as the same
;; as the input file
(defvar infile-temp (make-temp-name (format "%s.temp." infile)))
(copy-file infile infile-temp t)
(find-file infile-temp)

(org-mode)
(org-reveal-export-as-html)

(write-file outfile)

;; clean up
(setq default-directory cwd)
(delete-file infile-temp)
