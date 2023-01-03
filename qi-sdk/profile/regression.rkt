#!/usr/bin/env racket
#lang cli

(require qi
         qi/probe)

(require relation
         json
         racket/format
         racket/port)

(define LOWER-THRESHOLD 0.75)
(define HIGHER-THRESHOLD 1.5)

(define (parse-json-file filename)
  (call-with-input-file filename
    (λ (port)
      (read-json port))))

(help
 (usage (~a "Reports relative performance of forms between two sets of results\n"
            "(e.g. run against two different commits).")))

(define (parse-benchmarks filename)
  (make-hash
   (map (☯ (~> (-< (~> (hash-ref 'name)
                       (switch
                         [(equal? "foldr") "<<"] ; these were renamed at some point
                         [(equal? "foldl") ">>"] ; so rename them back to match them
                         [else _]))
                   (hash-ref 'value))
               cons))
        (parse-json-file filename))))

(program (main [before-file "'before' file"]
               [after-file "'after' file"])
  ;; before and after are expected to be JSON-formatted, as
  ;; generated by report.rkt (e.g. via `make benchmarks-report`)
  (define before (parse-benchmarks before-file))
  (define after (parse-benchmarks after-file))

  (define-flow calculate-ratio
    (~> (-< (hash-ref after _)
            (hash-ref before _))
        /
        (if (< LOWER-THRESHOLD _ HIGHER-THRESHOLD)
            1
            (~r #:precision 2))))

  (define results
    (~>> (before)
         hash-keys
         △
         (><
          (~>
           (-< _
               calculate-ratio)
           ▽))
         ▽
         (sort > #:key (☯ (~> cadr ->inexact)))))
  ;; (write-json results)
  (println results))

(run main)