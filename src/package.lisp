;;;; package.lisp
;;;;
;;;; Package definitions for the squiggle system.

(defpackage :squiggle
  (:use :cl)
  (:export
   ;; state
   :*state*
   ;; lifecycle
   :boot! :reset! :make-canvas :make-seed-canvas
   ;; accessors
   :entities :find-entity
   ;; entity struct
   :make-entity :copy-entity
   :entity-id :entity-type :entity-pos :entity-scale :entity-color :entity-layer
   ;; canvas struct
   :canvas-entities :canvas-next-id
   ;; mutation verbs
   :apply-mutation :apply-mutations
   :apply-nudge :apply-recolor :apply-resize :apply-add :apply-remove
   ;; tick
   :stamp-layers :tick!
   ;; oracles
   :fake-oracle :llm-oracle
   ;; repl
   :demo))