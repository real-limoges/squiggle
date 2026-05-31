(ql:quickload :str)

(defun count-sentences (paragraph)
  (count-if (lambda (c) (member c '(#\. #\! #\?))) paragraph))

(defun split-on-blank-lines (text)
  (let ((paragraphs nil)
        (current nil))
    (dolist (line (str:lines text))
      (cond ((str:blank? line)
             (when current
                (push (str:join " " (nreverse current)) paragraphs)
                (setf current nil)))
              (t (push line current))))
          (when current
            (push (str:join " " (nreverse current)) paragraphs))
          (nreverse paragraphs)))

; (defun preprocess-corpus (&key (in "corpus/book.txt") (out "corpus/passages.txt"))
;   (let* ((text (uiop:read-file-string in))
;   )))

; (preprocess-corpus)