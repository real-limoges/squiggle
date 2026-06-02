;;;; package.lisp
;;;;
;;;; :squiggle/backend — engine: state, mutations, dispatch, lifecycle, tick.

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
