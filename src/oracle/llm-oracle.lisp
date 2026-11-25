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
- Numbers are percentages 0-100, in pairs: across, then down

Example: \"MOOD=8 coral squiggle 42 61 teal blob 15 88 triangle mustard\"

Don't explain. Just the score and the words.")

(defparameter +token-punctuation+ ".,;:!?()[]{}\"'"
  "Trimmed from both ends of each reply token, so coral, still reads as coral")

(defparameter +reply-max-tokens+ 64
  "Cap on a reply's length. A normal reply is about 20 tokens; without a cap
Qwen sometimes runs on for thousands and the call times out")

(defparameter +reply-timeout-seconds+ 10
  "How long call-llama-server waits for a reply before signaling")

(defstruct parsed
  (mood    :none :read-only t)
  (colors  '()   :read-only t)
  (shapes  '()   :read-only t)
  (numbers '()   :read-only t))

(defun json-object (&rest plist)
  "A hash table for jzon to encode. Takes string keys."
  (let ((h (make-hash-table :test 'equal)))
    (loop for (k v) on plist by #'cddr do (setf (gethash k h) v))
    h))

(defun chat-request (prompt)
  "PROMPT as one user message; llama-server wraps it in the model's chat template."
  (jzon:stringify
   (json-object "messages" (vector (json-object "role" "user" "content" prompt))
                "max_tokens" +reply-max-tokens+
                "stream" nil)))

(defun reply-content (response)
  "The text of the first choice in a chat completion RESPONSE."
  (let ((choice (aref (gethash "choices" (jzon:parse response)) 0)))
    (gethash "content" (gethash "message" choice))))

(defun call-llama-server (llm-oracle prompt)
  (reply-content (dex:post (llm-oracle-url llm-oracle)
                           :headers '(("Content-Type" . "application/json"))
                           :content (chat-request prompt)
                           :read-timeout +reply-timeout-seconds+)))

(defun build-prompt (passage)
  (format nil *prompt-template* passage))

(defun scan-mood (text)
  "The MOOD=N score clamped to 1-10, or :none."
  (or (ppcre:register-groups-bind ((#'parse-integer mood))
          ("MOOD=(\\d+)" text)
        (max 1 (min 10 mood)))
      :none))

(defun reply-tokens (text)
  "TEXT split on whitespace, each token trimmed of surrounding punctuation."
  (loop for tok in (ppcre:split "\\s+" text)
        collect (string-trim +token-punctuation+ tok)))

(defun scan-keywords (text valid)
  (loop for tok in (reply-tokens text)
        for kw = (find-symbol (string-upcase tok) :keyword)
        when (member kw valid) collect kw))

(defun scan-numbers (text)
  (loop for tok in (reply-tokens text)
        for n = (parse-integer tok :junk-allowed t)
        when n collect n))

(defun percent-of (percent extent)
  "PERCENT of EXTENT, rounded down. The prompt asks for positions as percentages."
  (floor (* percent extent) 100))

(defun assemble-mutation (parsed canvas rng)
  "An :add if there is a shape and two numbers, else a :recolor if there is a
color, else a :nudge if there are two numbers, else :none. The :recolor and
:nudge need an entity to target, so an empty CANVAS gives :none for them.
An :add's numbers are percentages across and down the canvas; a :nudge's are
pixel offsets as given."
  (let ((shape    (first (parsed-shapes parsed)))
        (color    (first (parsed-colors parsed)))
        (nums     (parsed-numbers parsed))
        (targets? (entities canvas)))
    (cond
      ((and shape (>= (length nums) 2))
       (list :add shape
             (percent-of (first nums) +canvas-w+)
             (percent-of (second nums) +canvas-h+)
             (or color (random-elt +palette+ rng))))
      ((and color targets?)
       (list :recolor (random-id canvas rng) color))
      ((and (>= (length nums) 2) targets?)
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
  "Falls back to the fake oracle when llama-server fails or the reply is unusable."
  (handler-case
      (proposal-from-reply
       (parse-response (call-llama-server llm-oracle (build-prompt (next-passage!))))
       canvas rng)
    (error () (propose (make-fake-oracle) canvas rng))))
