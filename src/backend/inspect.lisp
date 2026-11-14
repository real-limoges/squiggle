;;;; inspect.lisp: REPL printers

(in-package :squiggle/backend)

(defun print-entity (entity)
  (format t "  id=~D ~A pos=~A scale=~,2F color=~A~%"
          (entity-id entity) (entity-type entity) (entity-pos entity)
          (entity-scale entity) (entity-color entity)))

(defun print-state (&optional (canvas *state*))
  (format t "~&--- ~D entities ---~%" (length (entities canvas)))
  (mapc #'print-entity (entities canvas))
  (values))

(defun print-tick (n mutations)
  (format t "~&~%=== tick ~D ===~%mutations: ~S~%" n mutations)
  (print-state))

(defun demo (&optional (steps 20))
  (setf *state* (make-seed-canvas))
  (dotimes (i steps)
    (print-tick (1+ i) (tick! squiggle/oracle:*oracle*)))
  (values))
