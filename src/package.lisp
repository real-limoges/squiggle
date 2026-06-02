;;;; package.lisp
;;;;
;;;; Base package for the squiggle system. Subsystems define their own packages
;;;; alongside their code (src/oracle/package.lisp, src/backend/package.lisp) so
;;;; each system's external dependencies stay with that system.

;;; :squiggle — shared vocabulary: constants, structs, canvas helpers.
;;; All subsystems (:squiggle/backend, :squiggle/oracle, etc.) use this package.
(defpackage :squiggle
  (:use :cl)
  (:export
   ;; constants
   :+palette+ :+canvas-w+ :+canvas-h+ :+min-scale+ :+max-scale+ :+entity-types+
   ;; entity struct
   :make-entity :copy-entity
   :entity-id :entity-type :entity-pos :entity-scale :entity-color :entity-layer
   ;; canvas struct
   :make-canvas :copy-canvas :canvas-entities :canvas-next-id
   ;; canvas helpers
   :entities :find-entity
   ;; oracle-result struct (shared oracle→engine contract)
   :make-oracle-result :copy-oracle-result :oracle-result-p
   :oracle-result-mutations :oracle-result-mood ))
