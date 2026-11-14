;;;; llm-oracle.lisp: Qwen reads a passage and answers with a mood and loose tokens
;;;; The prompt carries no canvas state; the reply's words and numbers are
;;;; scanned into token bags and one mutation is assembled from them.

(in-package :squiggle/oracle)

(defparameter *prompt-template*
  "Read this passage:

---
~A
---

Respond in this format:
\"MOOD=N <words and numbers>\"

Where:
- N is 1-10. 1 = slow, heavy, blue. 10 = racing, manic, electric.
  Don't default to 5 — use the full range.
- Words come from: teal, coral, cream, ink, mustard, blob, squiggle, triangle, curve
- Numbers are integers 0-800

Example: \"MOOD=8 coral squiggle 340 teal blob 120 triangle 600 mustard\"

Don't explain. Just the score and the words.")

(defstruct parsed
  (mood    :none :read-only t)
  (colors  '()   :read-only t)
  (shapes  '()   :read-only t)
  (numbers '()   :read-only t))

(defun json-object (&rest plist)
  "Takes string keys."
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on plist by #'cddr do (setf (gethash k h) v))
    (jzon:stringify h)))

(defun call-ollama (llm-oracle prompt)
  (let ((response (dex:post (llm-oracle-url llm-oracle)
                            :headers '(("Content-Type" . "application/json"))
                            :content (json-object "model" (llm-oracle-model llm-oracle)
                                                  "prompt" prompt
                                                  "stream" nil))))
    (gethash "response" (jzon:parse response))))

(defun build-prompt (passage)
  (format nil *prompt-template* passage))

(defun scan-mood (text)
  "The MOOD=N score clamped to 1-10, or :none."
  (or (ppcre:register-groups-bind ((#'parse-integer mood))
          ("MOOD=(\\d+)" text)
        (max 1 (min 10 mood)))
      :none))

(defun scan-keywords (text valid)
  (loop for tok in (ppcre:split "\\s+" text)
        for kw = (find-symbol (string-upcase tok) :keyword)
        when (member kw valid) collect kw))

(defun scan-numbers (text)
  (loop for tok in (ppcre:split "\\s+" text)
        for n = (parse-integer tok :junk-allowed t)
        when n collect n))

(defun assemble-mutation (parsed canvas rng)
  "An :add if there is a shape and two numbers, else a :recolor if there is a
color, else a :nudge if there are two numbers, else :none."
  (let ((shape (first (parsed-shapes parsed)))
        (color (first (parsed-colors parsed)))
        (nums  (parsed-numbers parsed)))
    (cond
      ((and shape (>= (length nums) 2))
       (list :add shape (first nums) (second nums)
             (or color (random-elt +palette+ rng))))
      (color
       (list :recolor (random-id canvas rng) color))
      ((>= (length nums) 2)
       (list :nudge (random-id canvas rng) (first nums) (second nums)))
      (t :none))))

(defun parse-response (text)
  (make-parsed :mood    (scan-mood text)
               :colors  (scan-keywords text +palette+)
               :shapes  (scan-keywords text +entity-types+)
               :numbers (scan-numbers text)))

(defun proposal-from-reply (parsed canvas rng)
  "The reply's mutation and mood, or the fake oracle's when either is :none."
  (let ((mutation (assemble-mutation parsed canvas rng))
        (mood     (parsed-mood parsed)))
    (if (or (eq mutation :none) (eq mood :none))
        (propose (make-fake-oracle) canvas rng)
        (make-oracle-result :mutations (list mutation) :mood mood))))

(defmethod propose ((llm-oracle llm-oracle) canvas rng)
  "Falls back to the fake oracle when Ollama fails or the reply is unusable."
  (handler-case
      (proposal-from-reply
       (parse-response (call-ollama llm-oracle (build-prompt (next-passage!))))
       canvas rng)
    (error () (propose (make-fake-oracle) canvas rng))))
