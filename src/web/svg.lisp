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

(defun paint-order (canvas)
  "CANVAS's entities back to front. A fresh list and CANVAS is untouched"
  (sort (copy-list (entities canvas)) #'paint-order-p))

(defun fill-hex (color)
  "Signals on a color outside the palette"
  (or (getf +palette-hex+ color)
      (error "No hex for color ~S" color)))

(defun entity-rect (entity s)
  "Write ENTITY's placeholder square to the cl-who stream S"
  (let ((side (round (* +base-size+ (entity-scale entity))))
        (pos  (entity-pos entity)))
    (with-html-output (s)
      (:rect :x (round (first pos))
             :y (round (second pos))
             :width side
             :height side
             :fill (fill-hex (entity-color entity))))))

(defun render-svg (canvas)
  "Return CANVAS as a line of SVG markup, entities painted back to front"
  (with-html-output-to-string (s)
    (:svg :xmlns "http://www.w3.org/2000/svg"
          :|viewBox| (format nil "0 0 ~D ~D" +canvas-w+ +canvas-h+)
          (dolist (entity (paint-order canvas))
            (entity-rect entity s)))))
