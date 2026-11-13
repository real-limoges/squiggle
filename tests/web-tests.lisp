;;;; web-tests.lisp

(in-package :squiggle/tests)

;;; --- Fixtures ---
(defun canvas-of (&rest entities)
  (make-canvas :entities entities :next-id (1+ (length entities))))

(defun fill-position (svg hex)
  (search (format nil "fill='~A'" hex) svg))

(defun count-matches (needle haystack)
  (loop with start = 0
        for hit = (search needle haystack :start2 start)
        while hit
        count t
        do (setf start (1+ hit))))

;;; --- Tests ---

(deftest-engine svg-paints-seed-canvas-back-to-front
    (let ((svg (render-svg *state*)))
      (is (= 3 (count-matches "<rect" svg)))
      (is (< (fill-position svg "#ff6f5e")
             (fill-position svg "#1fa7a0")
             (fill-position svg "#e3b23c")))))

(deftest-engine svg-orders-by-layer-not-id
    (let ((svg (render-svg
                (canvas-of
                 (make-entity :id 1 :type :blob :pos '(0 0) :scale 1 :color :ink :layer 9000)
                 (make-entity :id 2 :type :blob :pos '(0 0) :scale 1 :color :teal :layer 10)))))
      (is (< (fill-position svg "#1fa7a0") (fill-position svg "#1d1d2b")))))

(deftest-engine svg-breaks-layer-ties-by-id
    (let ((svg (render-svg
                (canvas-of
                 (make-entity :id 2 :type :blob :pos '(0 0) :scale 1 :color :ink :layer 5)
                 (make-entity :id 1 :type :blob :pos '(0 0) :scale 1 :color :teal :layer 5)))))
      (is (< (fill-position svg "#1fa7a0") (fill-position svg "#1d1d2b")))))

(deftest-engine svg-is-one-line
    (is (null (find #\Newline (render-svg *state*)))))

(deftest-engine svg-spells-viewbox-in-camel-case
    (let ((svg (render-svg *state*)))
      (is (search "viewBox='0 0 800 500'" svg))
      (is (null (search "viewbox" svg)))))

(deftest-engine svg-leaves-state-alone
    (let ((before (mapcar #'entity-id (entities *state*))))
      (is (string= (render-svg *state*) (render-svg *state*)))
      (is (equal before (mapcar #'entity-id (entities *state*))))))

(deftest-engine canvas-page-embeds-the-frame
    (let ((svg (render-svg *state*)))
      (is (search svg (canvas-page svg)))))
