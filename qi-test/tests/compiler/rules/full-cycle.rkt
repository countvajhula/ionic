#lang racket/base

(provide tests)

(require (for-syntax racket/base)
         ;; necessary to recognize and expand core forms correctly
         qi/flow/extended/expander
         ;; necessary to correctly expand the right-threading form
         qi/flow/extended/forms
         rackunit
         rackunit/text-ui
         syntax/macro-testing
         (submod qi/flow/extended/expander invoke))

(begin-for-syntax
  (require racket/base
           syntax/parse/define
           racket/string
           (for-template qi/flow/core/compiler)
           (for-syntax racket/base))

  (define (deforested? exp)
    (string-contains? (format "~a" exp) "cstream"))

  ;; A macro that accepts surface syntax, expands it, and then applies the
  ;; indicated optimization passes.
  (define-syntax-parser test-compile~>
    [(_ stx)
     #'(expand-flow stx)]
    [(_ stx pass ... passN)
     #'(passN
        (test-compile~> stx pass ...))]))


(define tests

  (test-suite
   "full cycle tests"

   (test-suite
    "multiple passes"
    (test-true "normalize → deforest"
               (phase1-eval
                (deforested?
                  (test-compile~> #'(~>> (filter odd?) values (map sqr))
                                  normalize-pass
                                  deforest-pass)))))))

(module+ main
  (void
   (run-tests tests)))
