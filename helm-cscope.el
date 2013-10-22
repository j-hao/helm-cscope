;;; helm-cscope.el --- helm cscope

;; Copyright (C) 2013 Jun Hao <achilles.hao@gmail.com>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Code:

;;; Require
;;
;;
(require 'helm)
(require 'xcscope)

(defgroup helm-cscope nil
  "Cscope applications for helm."
  :group 'helm)

(defcustom helm-cscope-display
  #'(lambda (file function-name line-number line)
      (concat file ":" line-number ":" function-name ":" line))
  "display format for helm-cscope.
Expect a function takes arguments: file function-name line-number line"
  :group 'helm-cscope
  :type 'function)

;;; Set up source
;;
;;
(defvar helm-source-cscope
  '((name . "Cscope")
    (candidates . helm-cscope-get-candidates)
    (candidate-number-limit . 9999)
    (volatile)
    (no-delay-on-input)
    (type . line)
    (action  . (("Display source code" . helm-cscope-default-action)))))

;;; Set up internal variable
(defvar helm-cscope-call-parameter nil
  "Parameter pass into cscope-call")

(defvar helm-cscope-current-directory nil
  "Directory cscope used")

(defun helm-cscope-default-action (candidate)
  "Default action for jumping to a search result from helm."
  (let* ((file (if helm-cscope-current-directory
                   (concat helm-cscope-current-directory (car candidate))
                 (car candidate)))
         (line-number (cdr candidate))
         (window (cscope-show-entry-internal file line-number)))
    (if (windowp window)
        (select-window window))))

(defun helm-cscope-get-candidates ()
  (cscope-call nil (list helm-cscope-call-parameter cscope-symbol) nil nil nil)
  (helm-cscope-parse-result (get-buffer cscope-output-buffer-name)))

(defun helm-cscope-parse-result (buffer)
  "Accept cscope process output and reformat it for helm."
  (let ((result))
    (unwind-protect
        (progn
          (set-buffer buffer)
          (goto-char (point-min))
          (forward-line 1)
          (let ((line (thing-at-point 'line)))
            (if (string-match "^Database directory: \\(.*\\)$" line)
                (setq helm-cscope-current-directory
                      (file-name-as-directory
                       (substring line (match-beginning 1)
                                  (match-end 1))))))
          (forward-line 2)
          (let ((buffer-read-only nil))
            (delete-region (point-min) (point)))
          (setq cscope-process-output (buffer-string))
          (let ((start 0) whole-line file function-name line-number line)
            (while (string-match
                    "^\\([^ \t-]+\\)[ \t]+\\([^ \t]+\\)[ \t]+\\([0-9]+\\)[ \t]+\\(.*\\)\n"
                    cscope-process-output start)
              ;; Get a line
              (setq whole-line (substring cscope-process-output
                                          (match-beginning 0) (match-end 0)))
              (setq file (substring whole-line (- (match-beginning 1) start)
                                    (- (match-end 1) start))
                    function-name (substring whole-line (- (match-beginning 2) start)
                                             (- (match-end 2) start))
                    line-number (substring whole-line (- (match-beginning 3) start)
                                           (- (match-end 3) start))
                    line (substring whole-line (- (match-beginning 4) start)
                                    (- (match-end 4) start))
                    start (match-end 0))
              (setq result (cons (cons (funcall helm-cscope-display file function-name line-number line) (cons file (string-to-number line-number))) result))))))
    (nreverse result)))

(defun helm-cscope-find-1 (pattern)
  "Find pattern with `helm' completion.
Use it for non--interactive calls of `helm-cscope-find'."
  (when (get-buffer helm-action-buffer)
    (kill-buffer helm-action-buffer))
  (helm :sources 'helm-source-cscope
        ;; :input pattern
        ;; :prompt "Find: "
        :buffer "*Helm Cscope*"))

;;;###autoload
(defmacro helm-cscope-find (function-name doc prompt parameter-for-cscope)
  "Define all the autoload functions for helm-cscope"
  (let ((function-name-symbol (intern function-name))
        (function-name-no-prompt-symbol (intern (concat function-name "-no-prompt"))))
    `(progn
       ;;;###autoload
       (defun ,function-name-symbol (symbol)
         ,doc
         (interactive (list
                       (cscope-prompt-for-symbol ,prompt nil)))
         (let ((cscope-adjust t) ;; Use fuzzy matching.
               (cscope-display-cscope-buffer nil)
               (cscope-symbol symbol)
               (helm-cscope-call-parameter ,parameter-for-cscope))
           (helm-cscope-find-1 cscope-symbol)))
       ;;;###autoload
       (defun ,function-name-no-prompt-symbol ()
          ,(concat doc " Without prompting")
          (interactive)
          (let ((cscope-adjust t) ;; Use fuzzy matching.
                (cscope-display-cscope-buffer nil)
                (cscope-symbol (cscope-extract-symbol-at-cursor nil))
                (helm-cscope-call-parameter ,parameter-for-cscope))
            (helm-cscope-find-1 cscope-symbol))))))

(helm-cscope-find "helm-cscope-find-this-symbol"
                  "Locate a symbol in source code."
                  "Find this symbol: "
                  "-0")

(helm-cscope-find "helm-cscope-find-global-definition"
                  "Find a symbol's global definition."
                  "Find this global definition: "
                  "-1")

(helm-cscope-find "helm-cscope-find-called-functions"
                  "Display functions called by a function."
                  "Find functions called by this function: "
                  "-2")

(helm-cscope-find "helm-cscope-find-functions-calling-this-function"
                  "Display functions calling a function."
                  "Find functions calling this function: "
                  "-3")

(helm-cscope-find "helm-cscope-find-this-text-string"
                  "Locate where a text string occurs."
                  "Find this text string: "
                  "-4")

(helm-cscope-find "helm-cscope-find-egrep-pattern"
                  "Run egrep over the cscope database."
                  "Find this egrep pattern: "
                  "-6")

(helm-cscope-find "helm-cscope-find-this-file"
                  "Locate a file."
                  "Find this file: "
                  "-7")

(helm-cscope-find "helm-cscope-find-files-including-file"
                  "Locate all files #including a file."
                  "Find files #including this file: "
                  "-8")

(provide 'helm-cscope)
