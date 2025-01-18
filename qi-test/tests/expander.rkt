#lang racket/base

(provide tests)

(require (for-syntax racket/base
                     qi/flow/extended/syntax)
         (submod qi/flow/extended/expander invoke)
         syntax/macro-testing
         racket/base
         ;; necessary to recognize and expand core forms correctly
         qi/flow/extended/expander
         ;; necessary to correctly expand the right-threading form
         qi/flow/extended/forms
         syntax/parse/define
         qi/flow/extended/util
         rackunit
         rackunit/text-ui)

(define-syntax-parse-rule (test-expand name source target)
  (test-true name
             (phase1-eval
              (equal? (syntax->datum
                       (expand-flow source))
                      (syntax->datum target)))))

;; TODO: these tests compare syntax as datums, but that's not sufficient
;; since the identifiers used may be bound differently which would affect
;; e.g. literal pattern matching.
;; To do it correctly, we need an alpha-equivalence predicate for Core Qi
;; that possibly delegates to a similar predicate for any Racket
;; subexpressions. This could be a predicate that syntax-spec could
;; infer, but it's unclear at this time.
(define tests
  (test-suite
   "expander tests"

   (test-suite
    "rules"
    (test-expand "basic expansion"
                 #'(~> sqr add1)
                 #'(thread (esc (#%host-expression sqr))
                           (esc (#%host-expression add1))))

    (test-expand "if"
                 #'(if p c a)
                 #'(if (esc (#%host-expression p))
                       (esc (#%host-expression c))
                       (esc (#%host-expression a))))

    (test-expand "amp"
                 #'(>< f)
                 #'(amp (esc (#%host-expression f))))

    (test-expand "tee"
                 #'(-< f g)
                 #'(tee (esc (#%host-expression f))
                        (esc (#%host-expression g))))

    (test-expand "mix of core forms"
                 #'(thread (amp a)
                           (relay b c)
                           (tee d e))
                 #'(thread
                    (amp (esc (#%host-expression a)))
                    (relay (esc (#%host-expression b)) (esc (#%host-expression c)))
                    (tee (esc (#%host-expression d)) (esc (#%host-expression e)))))

    (test-expand "undecorated identifiers are escaped"
                 #'f
                 #'(esc (#%host-expression f)))

    (test-expand "literal is expanded to an explicit use of the gen core form"
                 #'5
                 #'(gen (#%host-expression 5)))

    (test-expand "fine template syntax expands to an explicit use of the #%fine-template core form"
                 #'(f _ a _ b)
                 #'(#%fine-template
                    ((#%host-expression f)
                     _
                     (#%host-expression a)
                     _
                     (#%host-expression b))))

    (test-expand "blanket template syntax expands to an explicit use of the #%blanket-template core form"
                 #'(f a __ b)
                 #'(#%blanket-template
                    ((#%host-expression f)
                     (#%host-expression a)
                     __
                     (#%host-expression b))))

    (test-expand "partial application expands to a blanket template"
                 #'(f a b)
                 #'(#%blanket-template
                    ((#%host-expression f)
                     __
                     (#%host-expression a)
                     (#%host-expression b))))

    (test-expand "expand chiral forms to a use of a blanket template"
                 #'(~>> (f 1))
                 #'(thread (#%blanket-template
                            ((#%host-expression f)
                             (#%host-expression 1)
                             __))))
    (test-expand "sep"
                 #'(sep (>< f))
                 #'(sep (amp (esc (#%host-expression f)))))
    (test-expand "#%deforestable"
                 #'(#%deforestable name info (floe 0) (expr 0))
                 #'(#%deforestable name
                                   info
                                   (floe (gen (#%host-expression 0)))
                                   (expr (#%host-expression 0)))))
   (test-suite
    "utils"
    ;; this is just temporary until we properly track source expressions through
    ;; expansion, so it doesn't match all the nuances of the core language grammar
    (test-equal? "de-expansion"
                 (syntax->datum
                  (datum->syntax #f
                    (map prettify-flow-syntax
                         '(flow  (gen (#%host-expression f))
                                 ground
                                 (select 1 2)
                                 (amp (esc (#%host-expression f)))
                                 (relay (esc (#%host-expression f)) (esc (#%host-expression g)))
                                 (tee (esc (#%host-expression f)) (esc (#%host-expression g)))
                                 (thread (esc (#%host-expression f)) (esc (#%host-expression g)))
                                 (gen (#%host-expression 2) (#%host-expression 3))
                                 (pass (esc (#%host-expression f)))
                                 (sep (esc (#%host-expression g)))
                                 (and (esc (#%host-expression f)) (or (esc (#%host-expression g)) (not (esc (#%host-expression h)))))
                                 (all (esc (#%host-expression f)))
                                 (any (esc (#%host-expression f)))
                                 (fanout (#%host-expression 2))
                                 (group (#%host-expression a) (esc (#%host-expression b)) (esc (#%host-expression c)))
                                 (if (esc (#%host-expression a)) (esc (#%host-expression f)))
                                 (sieve (esc (#%host-expression a)) (esc (#%host-expression b)) (esc (#%host-expression c)))
                                 (partition ((esc (#%host-expression a)) (esc (#%host-expression b)))
                                            ((esc (#%host-expression c)) (esc (#%host-expression d))))
                                 (try (esc (#%host-expression q))
                                   ((esc (#%host-expression a)) (esc (#%host-expression b)))
                                   ((esc (#%host-expression c)) (esc (#%host-expression d))))
                                 (>> (esc (#%host-expression f)))
                                 (<< (esc (#%host-expression f)))
                                 (feedback (while (esc (#%host-expression f))))
                                 (loop (esc (#%host-expression f)))
                                 (loop2 (esc (#%host-expression f)) (esc (#%host-expression a)) (esc (#%host-expression f)))
                                 (clos (esc (#%host-expression f)))
                                 (esc (#%host-expression f))
                                 (#%blanket-template ((#%host-expression 1) __ (#%host-expression 4)))
                                 (#%blanket-template ((#%host-expression 4) __))
                                 (#%fine-template ((#%host-expression 4) _))
                                 (#%deforestable map info (floe (amp (esc (#%host-expression f)))) (expr 3))))))
                 '(flow  (gen f)
                         ground
                         (select 1 2)
                         (>< f)
                         (== f g)
                         (-< f g)
                         (~> f g)
                         (gen 2 3)
                         (pass f)
                         (sep g)
                         (and f (or g (not h)))
                         (all f)
                         (any f)
                         (fanout 2)
                         (group a b c)
                         (if a f)
                         (sieve a b c)
                         ;; partition and try are actually jumbled
                         (partition (a b) (c d))
                         (try q (a b) (c d))
                         (>> f)
                         (<< f)
                         ;; feedback grammar not handled - it's just a hack anyway
                         (feedback (while (esc (#%host-expression f))))
                         (loop f)
                         (loop2 f a f)
                         (clos f)
                         f
                         (1 __ 4)
                         (4 __)
                         (4 _)
                         (map (>< f) 3))))))

(module+ main
  (void
   (run-tests tests)))
