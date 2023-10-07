#lang racket/base

(provide tests)

(require (for-template qi/flow/core/compiler)
         (only-in qi/flow/extended/syntax
                  make-right-chiral)
         rackunit
         rackunit/text-ui
         (only-in math sqr))

(define tests
  (test-suite
   "compiler tests"

   (test-suite
    "deforestation"
    ;; (~>> values (filter odd?) (map sqr) values)
    (let ([stx (make-right-chiral
                #'(#%partial-application
                   ((#%host-expression filter)
                    (#%host-expression odd?))))])
      (check-equal? (syntax->datum
                     (deforest-rewrite
                       #`(thread #,stx)))
                    '(thread
                      (esc
                       (λ (lst)
                         ((cstream->list (inline-compose1 (filter-cstream-next odd?) list->cstream-next)) lst))))
                    "deforestation of map -- note this tests the rule in isolation; with normalization this would never be necessary"))
    (let ([stx (make-right-chiral
                #'(#%partial-application
                   ((#%host-expression map)
                    (#%host-expression sqr))))])
      (check-equal? (syntax->datum
                     (deforest-rewrite
                       #`(thread #,stx)))
                    '(thread
                      (esc
                       (λ (lst)
                         ((cstream->list (inline-compose1 (map-cstream-next sqr) list->cstream-next)) lst))))
                    "deforestation of filter -- note this tests the rule in isolation; with normalization this would never be necessary"))
    (let ([stx (map make-right-chiral
                    (syntax->list
                     #'(values
                        (#%partial-application
                         ((#%host-expression filter)
                          (#%host-expression odd?)))
                        (#%partial-application
                         ((#%host-expression map)
                          (#%host-expression sqr)))
                        values)))])
      (check-equal? (syntax->datum
                     (deforest-rewrite
                       #`(thread #,@stx)))
                    '(thread
                      values
                      (esc
                       (λ (lst)
                         ((cstream->list
                           (inline-compose1
                            (map-cstream-next
                             sqr)
                            (filter-cstream-next
                             odd?)
                            list->cstream-next))
                          lst)))
                      values)
                    "deforestation in arbitrary positions"))
    (let ([stx (map make-right-chiral
                    (syntax->list
                     #'((#%partial-application
                         ((#%host-expression map)
                          (#%host-expression string-upcase)))
                        (#%partial-application
                         ((#%host-expression foldl)
                          (#%host-expression string-append)
                          (#%host-expression "I"))))))])
      (check-equal? (syntax->datum
                     (deforest-rewrite
                       #`(thread #,@stx)))
                    '(thread
                      (esc
                       (λ (lst)
                         ((foldl-cstream
                           string-append
                           "I"
                           (inline-compose1
                            (map-cstream-next
                             string-upcase)
                            list->cstream-next))
                          lst))))
                    "deforestation in arbitrary positions")))
   (test-suite
    "fixed point"
    null)))

(module+ main
  (void (run-tests tests)))