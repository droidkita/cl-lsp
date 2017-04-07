(defpackage :cl-lsp/formatting
  (:use :cl
        :cl-lsp/protocol
        :cl-lsp/protocol-util
        :cl-lsp/logger)
  (:import-from :lem-base)
  (:import-from :alexandria)
  (:export :on-type-formatting
           :range-formatting
           :buffer-formatting))
(in-package :cl-lsp/formatting)

(defun indent-line (p &optional editp)
  (unless (lem-base:blank-line-p p)
    (let ((line-number (1- (lem-base:line-number-at-point p)))
          (old-charpos (lem-base:point-charpos (lem-base:back-to-indentation p)))
          (new-column (lem-lisp-syntax.indent:calc-indent (lem-base:copy-point p :temporary))))
      (when new-column
        (when editp
          (lem-base:line-start p)
          (lem-base:delete-character p old-charpos)
          (lem-base:insert-character p #\space new-column))
        (convert-to-hash-table
         (make-instance '|TextEdit|
                        :|range| (make-instance
                                  '|Range|
                                  :|start| (make-instance '|Position|
                                                          :|line| line-number
                                                          :|character| 0)
                                  :|end| (make-instance '|Position|
                                                        :|line| line-number
                                                        :|character| old-charpos))
                        :|newText| (make-string new-column :initial-element #\space)))))))

(defun set-formatting-options (options)
  (setf (lem-base:tab-size) (slot-value options '|tabSize|)))

(defun on-type-formatting (point ch options)
  (declare (ignore ch))
  (set-formatting-options options)
  (let ((edit (indent-line point)))
    (if edit
        (list edit)
        (vector))))

(defun range-formatting (start end options)
  (set-formatting-options options)
  (let ((buffer (lem-base:point-buffer start))
        (edits '()))
    (lem-base:buffer-enable-undo buffer)
    (lem-base:apply-region-lines start end
                                 (lambda (point)
                                   (multiple-value-bind (edit)
                                       (indent-line point t)
                                     (when edit
                                       (push edit edits)))))
    (lem-base:buffer-undo start)
    (lem-base:buffer-disable-undo buffer)
    (list-to-object[] (nreverse edits))))

(defun buffer-formatting (buffer options)
  (lem-base:with-point ((start (lem-base:buffer-start-point buffer))
                        (end (lem-base:buffer-end-point buffer)))
    (range-formatting start end options)))
