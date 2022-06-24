#lang racket/base

(provide average
         measure
         check-value
         check-list
         check-values
         check-two-values
         run-benchmark
         run-summary-benchmark
         run-competitive-benchmark
         (for-space qi only-if)
         for/call)

(require (only-in racket/list
                  range
                  second)
         (only-in adjutor
                  values->list)
         (only-in data/collection
                  cycle
                  take
                  in)
         racket/function
         racket/format
         syntax/parse/define
         (for-syntax racket/base)
         qi)

(define-flow average
  (~> (-< + count) / round))

(define-qi-syntax-rule (only-if pred consequent)
  (if pred consequent _))

;; just like for/list, but instead of collecting results
;; into a list, it invokes each result
(define-syntax-parse-rule (for/call (binding ...) body)
  (for (binding ...)
    (body)))

(define (measure fn . args)
  (second (values->list (time-apply fn args))))

(define (check-value fn how-many [inputs (range 10)])
  ;; call a function with a single (numeric) argument
  (for ([i (take how-many (cycle inputs))])
    (fn i)))

(define (check-list fn how-many)
  ;; call a function with a single list argument
  (for ([i (in-range how-many)])
    (let ([vs (range i (+ i 10))])
      (fn vs))))

(define (check-values fn how-many)
  ;; call a function with multiple values as independent arguments
  (for ([i (in-range how-many)])
    (let ([vs (range i (+ i 10))])
      (call-with-values (λ ()
                          (apply values vs))
                        fn))))

(define (check-two-values fn how-many)
  ;; call a function with two values as arguments
  (for ([i (in-range how-many)])
    (let ([vs (range i (+ i 2))])
      (call-with-values (λ ()
                          (apply values vs))
                        fn))))

;; Run a single benchmarking function a specified number of times
;; and report the time taken.
(define-syntax-parse-rule (run-benchmark f-name runner n-times)
  #:with name (datum->syntax #'f-name
                (symbol->string
                 (syntax->datum #'f-name)))
  (let ([ms (measure runner f-name n-times)])
    (list name ms)))

;; Run many benchmarking functions (typically exercising a single form)
;; a specified number of times and report the time taken using the
;; provided summary function, e.g. sum or average
(define-syntax-parse-rule (run-summary-benchmark name f-summary (f-name runner n-times) ...)
  (let ([results null])
    (for ([f (list f-name ...)]
          [r (list runner ...)]
          [n (list n-times ...)])
      (let ([ms (measure r f n)])
        (set! results (cons ms results))))
    (let ([summarized-result (apply f-summary results)])
      (list name summarized-result))))

;; Run different implementations of the same benchmark (e.g. a Racket vs a Qi
;; implementation) a specified number of times, and report the time taken
;; by each implementation.
(define-syntax-parse-rule (run-competitive-benchmark name runner f-name n-times)
  #:with f-builtin (datum->syntax #'name
                     (string->symbol
                      (string-append "b:"
                                     (symbol->string
                                      (syntax->datum #'f-name)))))
  #:with f-qi (datum->syntax #'name
                (string->symbol
                 (string-append "q:"
                                (symbol->string
                                 (syntax->datum #'f-name)))))
  (begin
    (displayln (~a name ":"))
    (for ([f (list f-builtin f-qi)]
          [label (list "λ" "☯")])
      (let ([ms (measure runner f n-times)])
        (displayln (~a label ": " ms " ms"))))))
