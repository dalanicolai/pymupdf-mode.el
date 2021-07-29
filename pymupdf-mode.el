;;; pymupdf-mode.el --- Extend pdf-tools annotation capabilities via pymupdf  -*- lexical-binding: t; -*-
;; Copyright (C) 2020  Daniel Laurens Nicolai

;; Author: Daniel Laurens Nicolai <dalanicolai@gmail.com>
;; Version: 0
;; Keywords: pdf-tools,
;; Package-Requires: ((emacs "27.1"))
;; URL: https://github.com/dalanicolai/pymupdf-mode.el


;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Usage:

;;; Code:

(require 'python)
(eval-when-compile
  (require 'pdf-view))

(defcustom pymupdf-meta-shell-interpreter python-shell-interpreter
  "Python interpreter used for running meta2csv and csv2meta scripts."
  :type 'string)

(defcustom pymupdf-utilities-examples/directory "~/git/PyMuPDF-Utilities/examples"
  "PyMuPDF-utilities examples directory.
See URL `https://github.com/dalanicolai/PyMuPDF-Utilities'."
  :type 'directory)

(defun pymupdf-draw-arrow (event)
  (interactive "e")
  (let ((file-path buffer-file-name)
        (page (- (pdf-view-current-page) 1))
        (start (posn-object-x-y (event-start  event)))
        (end (posn-object-x-y (event-end  event)))
        (object-size (posn-object-width-height (event-end  event))))
    (with-current-buffer (python-shell-get-buffer)
      (comint-simple-send (current-buffer) (format "page = doc[%s]" page))
      (comint-simple-send (current-buffer)
                          (format "mag = %s/page.MediaBoxSize[0]" (car object-size)))
      (comint-simple-send (current-buffer)
                          (format "start = fitz.Point(%s, %s)/mag"
                                  (car start)
                                  (cdr start)))
      (comint-simple-send (current-buffer)
                          (format "end = fitz.Point(%s, %s)/mag"
                                  (car end)
                                  (cdr end)))
      (comint-simple-send (current-buffer) "annot = page.addLineAnnot(start, end)")
      (comint-simple-send (current-buffer) "blue = (0, 0, 1)\ngreen = (0, 1, 0)\nannot.setColors(stroke=blue, fill=green)")
      (comint-simple-send (current-buffer) "annot.setLineEnds(0,5)")
      (comint-simple-send (current-buffer) "annot.update()")
      (comint-simple-send
       (current-buffer)
       (format "doc.save('%s', incremental=True, encryption=fitz.PDF_ENCRYPT_KEEP)" file-path)))))

(defun pymupdf-draw-free-text (event)
  (interactive "e")
  (let ((text (read-string "Type annotation text: "))
        (file-path buffer-file-name)
        (page (- (pdf-view-current-page) 1))
        (start (posn-object-x-y (event-start  event)))
        (end (posn-object-x-y (event-end  event)))
        (object-size (posn-object-width-height (event-end  event))))
    (with-current-buffer (python-shell-get-buffer)
      (comint-simple-send (current-buffer) (format "page = doc[%s]" page))
      (comint-simple-send (current-buffer)
                          (format "mag = %s/page.MediaBoxSize[0]" (car object-size)))
      (comint-simple-send (current-buffer) "blue = (0, 0, 1)\ngold = (1, 1, 0)")
      (comint-simple-send (current-buffer)
                          (format "rect = fitz.Rect(%s, %s, %s, %s)/mag"
                                  (car start)
                                  (cdr start)
                                  (car end)
                                  (cdr end)))
      (comint-simple-send (current-buffer) (format
                                            "annot = page.addFreetextAnnot(\
    rect,\
    '%s',\
    fontsize=12,\
    rotate=0,\
    text_color=blue,\
    fill_color=gold,\
    align=fitz.TEXT_ALIGN_CENTER,)"
                                            text))
      (comint-simple-send (current-buffer) "annot.update()")
      (comint-simple-send
       (current-buffer)
       (format "doc.save('%s', incremental=True, encryption=fitz.PDF_ENCRYPT_KEEP)" file-path)))))

(defun pymupdf-draw-caret (event)
  (interactive "e")
  (let ((file-path buffer-file-name)
        (page (- (pdf-view-current-page) 1))
        (start (posn-object-x-y (event-start  event)))
        (object-size (posn-object-width-height (event-end  event))))
    (with-current-buffer (python-shell-get-buffer)
      (comint-simple-send (current-buffer) (format "page = doc[%s]" page))
      (comint-simple-send (current-buffer)
                          (format "mag = %s/page.MediaBoxSize[0]" (car object-size)))
      (comint-simple-send (current-buffer)
                          (format "point = fitz.Point(%s, %s)/mag"
                                  (car start)
                                  (cdr start)))
      (comint-simple-send (current-buffer) "annot = page.addCaretAnnot(point)")
      (comint-simple-send (current-buffer) "annot.update()")
      (comint-simple-send
       (current-buffer)
       (format "doc.save('%s', incremental=True, encryption=fitz.PDF_ENCRYPT_KEEP)" file-path)))))

;;;###autoload
(defun pymupdf-edit-metadata ()
  (interactive)
  (let ((file-path (buffer-file-name)))
    (print (shell-command-to-string (format "%s %s/meta2csv.py '%s'"
                                      python-shell-interpreter
                                      (expand-file-name pymupdf-utilities-examples/directory)
                                      file-path)))
    (find-file (concat
                (file-name-sans-extension (file-name-nondirectory file-path))
                "-meta.csv"))
    (when (fboundp 'csv-mode)
        (csv-mode))
    (setq-local assoc-file file-path)
    (pymupdf-meta-mode)))

(defun pymupdf-write-metadata ()
  (interactive)
  (save-buffer)
  (shell-command (format "%s %s/csv2meta.py -csv '%s' -pdf '%s'"
                         pymupdf-meta-shell-interpreter
                         (expand-file-name pymupdf-utilities-examples/directory)
                         (buffer-file-name)
                         assoc-file))
  (kill-buffer))

(defun pymupdf-kill-comint-buffer ()
  (let (comint-buffer (python-shell-get-buffer))
    (when comint-buffer
      (with-current-buffer comint-buffer
        (comint-simple-send (current-buffer) "exit")
        (sit-for 0.1)
        (kill-current-buffer)))))

(defun run-python (&optional cmd dedicated show)
  "Run an inferior Python process.

Argument CMD defaults to `python-shell-calculate-command' return
value.  When called interactively with `prefix-arg', it allows
the user to edit such value and choose whether the interpreter
should be DEDICATED for the current buffer.  When numeric prefix
arg is other than 0 or 4 do not SHOW.

For a given buffer and same values of DEDICATED, if a process is
already running for it, it will do nothing.  This means that if
the current buffer is using a global process, the user is still
able to switch it to use a dedicated one.

Runs the hook `inferior-python-mode-hook' after
`comint-mode-hook' is run.  (Type \\[describe-mode] in the
process buffer for a list of commands.)"
  (interactive
   (if current-prefix-arg
       (list
        (read-shell-command "Run Python: " (python-shell-calculate-command))
        (y-or-n-p "Make dedicated process? ")
        (= (prefix-numeric-value current-prefix-arg) 4))
     (list (python-shell-calculate-command) nil t)))
  (let ((buffer
         (python-shell-make-comint
          (or cmd (python-shell-calculate-command))
          (python-shell-get-process-name dedicated) show)))
    (get-buffer-process buffer)))

(define-minor-mode pymupdf-meta-mode nil nil "PyMuPDF-meta"
  `((,(kbd "C-c C-c") . pymupdf-write-metadata)))

;;;###autoload
(define-minor-mode pymupdf-mode
  "PDF annotation extension using pymupdf."
  nil
  "pymupdf"
  '(([C-S-drag-mouse-1] . pymupdf-draw-arrow)
    ([C-S-drag-mouse-3] . pymupdf-draw-free-text)
    ([C-S-mouse-1] . pymupdf-draw-caret))
  (if pymupdf-mode
      (let ((file-path buffer-file-name))
        (run-python (python-shell-calculate-command) t t)
        (with-current-buffer (python-shell-get-buffer)
          (comint-simple-send (current-buffer)
                              (concat "import fitz\n\
doc=fitz.open('" file-path "')")))
        (add-hook 'kill-buffer-hook 'pymupdf-kill-comint-buffer nil t))
    (remove-hook 'kill-buffer-hook 'pymupdf-kill-comint-buffer t)
    (pymupdf-kill-comint-buffer)))

(provide 'pymupdf-mode)

;;; pymupdf-mode.el ends here
