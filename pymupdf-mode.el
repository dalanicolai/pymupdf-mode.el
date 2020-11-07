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

(defun pymupdf-show-buffer-modified-message ()
  (message "This buffer has been modified.
Please use `M-x pymupdf-restart' to save buffer and continue editing using pymupdf."))

(defun pymupdf-draw-arrow (event)
  (interactive "e")
  (if (buffer-modified-p)
      (pymupdf-show-buffer-modified-message)
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
         (format "doc.save('%s', incremental=True, encryption=fitz.PDF_ENCRYPT_KEEP)" file-path))))))

(defun pymupdf-draw-free-text (event)
  (interactive "e")
  (if (buffer-modified-p)
      (pymupdf-show-buffer-modified-message)
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
         (format "doc.save('%s', incremental=True, encryption=fitz.PDF_ENCRYPT_KEEP)" file-path))))))

(defun pymupdf-draw-caret (event)
  (interactive "e")
  (if (buffer-modified-p)
      (pymupdf-show-buffer-modified-message)
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
         (format "doc.save('%s', incremental=True, encryption=fitz.PDF_ENCRYPT_KEEP)" file-path))))))

(defun pymupdf-kill-comint-buffer ()
  (let ((comint-buffer (python-shell-get-buffer)))
    (when comint-buffer
      (with-current-buffer comint-buffer
        (set-process-query-on-exit-flag (get-buffer-process (current-buffer)) nil)
        (kill-current-buffer)
        (message "pymupdf comint process has been killed")))))

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
    (set-buffer buffer)
    (get-buffer-process buffer)))

(defun pymupdf-restart ()
  (interactive)
  (pymupdf-mode 0)
  (pymupdf-mode 1))

;;;###autoload
(define-minor-mode pymupdf-mode
  "PDF annotation extension using pymupdf."
  nil
  "pymupdf"
  '(([C-S-drag-mouse-1] . pymupdf-draw-arrow)
    ([C-S-drag-mouse-3] . pymupdf-draw-free-text)
    ([C-S-mouse-1] . pymupdf-draw-caret))
  (if (pdf-tools-pdf-buffer-p)
    (if pymupdf-mode
        (let ((file-path buffer-file-name))
        (when (buffer-modified-p)
          (save-buffer)
          (pdf-view-revert-buffer nil t))
        (run-python (python-shell-calculate-command) t nil)
        (set-buffer (get-file-buffer file-path))
        (with-current-buffer (python-shell-get-buffer)
          (comint-simple-send (current-buffer)
                              (concat "import fitz\n\
doc=fitz.open('" file-path "')")))
        (add-hook 'kill-buffer-hook 'pymupdf-kill-comint-buffer nil t))
      (remove-hook 'kill-buffer-hook 'pymupdf-kill-comint-buffer t)
      (pymupdf-kill-comint-buffer))
    (message "buffer not associated with a PDF file")))

(provide 'pymupdf-mode)

;;; pymupdf-mode.el ends here
