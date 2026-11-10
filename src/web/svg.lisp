;;;; svg.lisp
;;;;
;;;; Pure canvas -> SVG string emitter

(in-package :squiggle/web)

(defparameter +palette-hex+
  '(:teal "#1fa7a0" :coral "#ff6f5e" :cream "#f6ecd2"
    :ink "#1d1d2b" :mustard "#e3b23c")
  "Placeholder fill for each palette keyword")

(defparameter +base-size+ 40
  "Side of a placeholder square at scale 1.0 in canvas units")

(defun paint-order-p (a b)
  "True when A paints before (underneath) B. By layer, then by id"
  (or (< (entity-layer a) (entity-layer b))
      (and (= (entity-layer a) (entity-layer b))
           (< (entity-id a) (entity-id b)))))

(defun paint-order (state)
  "STATE's entities back to front. A fresh list and STATE is untouched"
  (sort (copy-list (entities state)) #'paint-order-p))

(defun fill-hex (color)
  (getf +palette-hex+ color))

(defun render-svg (state)
  "Return STATE as a line of SVG markup, entities painted back to front"
  (with-html-output-to-string (s)
    (:svg :xmlns "http://www.w3.org/2000/svg"
          :viewbox (format nil "0 0 ~D ~D" +canvas-w+ +canvas-h+)
          (dolist (e (paint-order state))
            (let ((side (round (* +base-size+ (entity-scale e)))))
              (htm (:rect :x (round (first (entity-pos e)))
                          :y (round (second (entity-pos e)))
                          :width side
                          :height side
                          :fill (fill-hex (entity-color e)))))))))
