;;;; frozen.lisp: structs whose slots never change, defined with their copier
;;;; One slot list writes both the defstruct and the copier, so a slot can't be
;;;; left out of the copier and silently reset to its default in every copy.

(in-package :squiggle)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun refuse-frozen-struct (name format-control &rest arguments)
    (error "define-frozen-struct ~S: ~?" name format-control arguments))

  (defun check-slot-spec (name slot-spec)
    (unless (typep slot-spec '(cons symbol (cons t null)))
      (refuse-frozen-struct name "slot ~S is not (slot-name default)" slot-spec)))

  (defun check-fixed (name slots fixed)
    (dolist (slot fixed)
      (unless (member slot slots)
        (refuse-frozen-struct name "fixed slot ~S is not one of ~S" slot slots)))
    (when (subsetp slots fixed)
      (refuse-frozen-struct name "every slot is fixed, so the copier could change nothing")))

  (defun check-frozen-struct (name copier slot-specs fixed)
    (unless (and copier (symbolp copier))
      (refuse-frozen-struct name "needs a :copier name"))
    (dolist (slot-spec slot-specs)
      (check-slot-spec name slot-spec))
    (check-fixed name (mapcar #'first slot-specs) fixed))

  (defun struct-symbol (format-control &rest arguments)
    "The symbol defstruct interns for an accessor or constructor"
    (intern (apply #'format nil format-control arguments) *package*))

  (defun accessor-form (name slot)
    (list (struct-symbol "~A-~A" name slot) name))

  (defun frozen-slot (slot-spec)
    (list (first slot-spec) (second slot-spec) :read-only t))

  (defun copier-parameter (name slot)
    (list slot (accessor-form name slot)))

  (defun constructor-argument (name fixed slot)
    (list (intern (symbol-name slot) :keyword)
          (if (member slot fixed) (accessor-form name slot) slot)))

  (defun copier-docstring (name changeable fixed)
    (format nil "A copy of ~A with whichever of ~{~A~^, ~} you pass swapped in~@[; ~{~A~^, ~} never change~]"
            name changeable fixed))

  (defun changeable-slots (slots fixed)
    "SLOTS not in FIXED, in definition order"
    (remove-if (lambda (slot) (member slot fixed)) slots))

  (defun copier-lambda-list (name changeable)
    (list* name '&key (mapcar (lambda (slot) (copier-parameter name slot)) changeable)))

  (defun constructor-call (name slots fixed)
    (cons (struct-symbol "MAKE-~A" name)
          (mapcan (lambda (slot) (constructor-argument name fixed slot)) slots))))

(defmacro define-frozen-struct (name (&key copier fixed) &body slot-specs)
  "Define struct NAME with every slot read-only, and COPIER, which copies one with
whichever slots you pass as keywords swapped in. Slots in FIXED keep their value in
every copy. Each slot spec is (slot-name default)"
  (check-frozen-struct name copier slot-specs fixed)
  (let* ((slots (mapcar #'first slot-specs))
         (changeable (changeable-slots slots fixed)))
    `(progn
       (defstruct ,name ,@(mapcar #'frozen-slot slot-specs))
       (defun ,copier ,(copier-lambda-list name changeable)
         ,(copier-docstring name changeable fixed)
         ,(constructor-call name slots fixed)))))
