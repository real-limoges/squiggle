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
   :entities :find-entity ))

;;; :squiggle/backend — engine: state, mutations, dispatch, lifecycle, tick.
(defpackage :squiggle/backend
  (:use :cl :squiggle)
  (:export
   ;; rng
   :*oracle-rng* :*jitter-rng* :seed-rngs!
   ;; state
   :*state*
   ;; lifecycle
   :boot! :reset! :make-seed-canvas
   ;; dispatch
   :stamp-layers :apply-mutation :apply-mutations
   ;; updating helpers
   :with-entities :update-entity
   ;; mutation verbs
   :apply-nudge :apply-recolor :apply-resize :apply-add :apply-remove
   ;; tick
   :tick!
   ;; repl
   :demo))

;;; :squiggle/oracle — oracle implementations and shared random-draw substrate.
(defpackage :squiggle/oracle
  (:use :cl :squiggle)
  (:export
   :random-elt :random-id :random-delta
   :fake-oracle :llm-oracle
   :*generators* :*oracle*))