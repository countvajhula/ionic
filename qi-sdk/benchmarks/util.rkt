#lang racket/base

(provide average
         measure
         check-value
         check-value-medium-large
         check-value-large
         check-value-very-large
         check-list
         check-large-list
         check-values
         check-list-values
         check-two-values
         run-benchmark
         run-summary-benchmark
         run-nonlocal-benchmark
         (for-space qi only-if)
         for/call
         write-csv
         format-output)

(require (only-in racket/list
                  range
                  second
                  make-list)
         (only-in racket/function
                  curryr)
         (only-in adjutor
                  values->list)
         csv-writing
         json
         racket/format
         syntax/parse/define
         (for-syntax racket/base
                     (only-in racket/string
                              string-trim))
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

;; This uses a vector of inputs so that indexing into it
;; is constant time and doesn't factor prominently in the
;; overall time taken.
(define (check-value fn how-many [inputs #(0 1 2 3 4 5 6 7 8 9)])
  ;; call a function with a single (numeric) argument
  (let ([i 0]
        [len (vector-length inputs)])
    (for ([j how-many])
      (set! i (remainder (add1 i) len))
      (fn (vector-ref inputs i)))))

(define check-value-medium-large (curryr check-value #(100 200 300)))

(define check-value-large (curryr check-value #(1000)))

(define check-value-very-large (curryr check-value #(100000)))

;; This uses the same list input each time. Not sure if that
;; may end up being cached at some level and thus obfuscate
;; the results? On the other hand,
;; the cost of constructing a varying list each time ends up
;; taking up a nontrivial fraction of the total time spent
(define (check-list fn how-many)
  ;; call a function with a single list argument
  (let ([vs (range 10)])
    (for ([i how-many])
      (fn vs))))

(define (check-large-list fn how-many)
  ;; call a function with a single list argument
  (let ([vs (range 1000)])
    (for ([i how-many])
      (fn vs))))

;; This uses the same input values each time. See the note
;; above for check-list in this connection.
(define (check-values fn how-many)
  ;; call a function with multiple values as independent arguments
  (let ([vs (range 10)])
    (for ([i how-many])
      (call-with-values (λ ()
                          (apply values vs))
                        fn))))

(define (check-list-values fn how-many)
  ;; call a function with multiple list values as independent arguments
  (let* ([vs (range 10)]
         [list-vs (make-list 10 vs)])
    (for ([i how-many])
      (call-with-values (λ ()
                          (apply values list-vs))
                        fn))))

(define (check-two-values fn how-many)
  ;; call a function with two values as arguments
  (let ([vs (list 5 7)])
    (for ([i (in-range how-many)])
      (call-with-values (λ ()
                          (apply values vs))
                        fn))))

;; Run a single benchmarking function a specified number of times
;; and report the time taken.
;; TODO: this is very similar to run-nonlocal-benchmark and these
;; should be unified.
(define-syntax-parse-rule (run-benchmark f-name runner n-times)
  #:with name (datum->syntax #'f-name
                ;; this is because of the name collision between
                ;; Racket functions and Qi forms, now that the latter
                ;; are provided as identifiers in the qi binding space.
                ;; Using a standard prefix (i.e. ~) in the naming and then
                ;; detecting that, trimming it, here, is pretty hacky.
                ;; One alternative could be to broaden the run-benchmark
                ;; macro to support a name argument, but that seems like
                ;; more work. It would be better to be able to introspect
                ;; these somehow.
                (string-trim (symbol->string
                              (syntax->datum #'f-name))
                             "~"))
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
(define (run-nonlocal-benchmark name runner f n-times)
  (displayln (~a name ":") (current-error-port))
  (let ([ms (measure runner f n-times)])
    (displayln (~a ms " ms") (current-error-port))
    (hash 'name name 'unit "ms" 'value ms)))

(define (write-csv data)
  (~> (data)
      △
      (>< (~> (-< (hash-ref 'name)
                  (hash-ref 'unit)
                  (hash-ref 'value))
              ▽))
      (-< '(name unit value)
          _)
      ▽
      display-table))

(define (format-output output fmt)
  ;; Note: this is a case where declaring "constraints" on the CLI args
  ;; would be useful, instead of using the ad hoc fallback `else` check here
  ;; https://github.com/countvajhula/cli/issues/6
  (cond
    [(equal? fmt "json") (write-json output)]
    [(equal? fmt "csv") (write-csv output)]
    [(equal? fmt "") (values)]
    [else (error (~a "Unrecognized format: " fmt "!"))]))
