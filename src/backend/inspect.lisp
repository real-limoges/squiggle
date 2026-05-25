;;;; inspect.lisp
;;;;
;;;; Debugging tools for backend

(in-package :squiggle/backend)

(defun print-entity (e)
  (format t "  id=~D ~A pos=~A scale=~,2F color=~A~%"
          (entity-id e) (entity-type e) (entity-pos e)
          (entity-scale e) (entity-color e)))

(defun print-state (&optional (state *state*))
  (format t "~&--- ~D entities ---~%" (length (entities state)))
  (mapc #'print-entity (entities state))
  (values))

(defun print-tick (n mutations)
  (format t "~&~%=== tick ~D ===~%mutations: ~S~%" n mutations)
  (print-state))

(defun demo (&optional (steps 20))
  "Load the seed canvas and run STEPS ticks, printing mutations and state each time."
  (setf *state* (make-seed-canvas))
  (dotimes (i steps)
    (print-tick (1+ i) (tick!)))
  (values))