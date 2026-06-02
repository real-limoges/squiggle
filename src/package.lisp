;;;; package.lisp
;;;;
;;;; Package definitions for the squiggle system.

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

;;; :squiggle/backend — engine: state, mutations, dispatch, lifecycle, tick.
(defpackage :squiggle/backend
  (:use :cl :squiggle)
  (:export
   :*oracle-rng* :*jitter-rng* :seed-rngs!
   :*state*
   :boot! :reset! :make-seed-canvas
   :stamp-layers :apply-mutation :apply-mutations
   :with-entities :update-entity
   :apply-nudge :apply-recolor :apply-resize :apply-add :apply-remove
   :tick!
   :demo))

;;; :squiggle/oracle — oracle implementations and shared random-draw substrate.
(defpackage :squiggle/oracle
  (:use :cl :squiggle)
  (:local-nicknames (:jzon :com.inuoe.jzon)
                    (:ppcre :cl-ppcre))
  (:export
   :random-elt :random-id :random-delta
   :load-passages! :next-passage!
   :fake-oracle :llm-oracle
   :use-fake-oracle! :use-llm-oracle!
   :*generators* :*oracle*))