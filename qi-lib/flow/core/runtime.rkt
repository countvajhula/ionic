#lang racket/base

(provide give
         map-values
         filter-values
         partition-values
         relay
         loom-compose
         parity-xor
         arg
         except-args
         call
         repeat-values
         foldl-values
         foldr-values
         values->list
         feedback-times
         feedback-while
         kw-helper
         singleton?
         zip-with)

(require racket/match
         (only-in racket/function
                  negate
                  thunk)
         racket/bool
         racket/list
         racket/format
         syntax/parse/define
         (for-syntax racket/base))

(define-syntax-parse-rule (values->list body:expr ...+)
  (call-with-values (λ () body ...) list))

(define (kw-helper f args)
  (make-keyword-procedure
   (λ (kws kws-vs . pos)
     (keyword-apply f kws kws-vs (append args pos)))))

;; we use a lambda to capture the arguments at runtime
;; since they aren't available at compile time
(define (loom-compose f g n)
  (λ args
    (let ([num-args (length args)])
      (if (< num-args n)
          (if (= 0 num-args)
              (values)
              (error 'group (~a "Can't select "
                                n
                                " arguments from "
                                args)))
          (let ([sargs (take args n)]
                [rargs (drop args n)])
            (apply values
                   (append (values->list (apply f sargs))
                           (values->list (apply g rargs)))))))))

(define (parity-xor . args) (and (foldl xor #f args) #t))

(define (counting-string n)
  (let ([d (remainder n 10)]
        [ns (number->string n)])
    (cond [(= d 1) (string-append ns "st")]
          [(= d 2) (string-append ns "nd")]
          [(= d 3) (string-append ns "rd")]
          [else (string-append ns "th")])))

(define (arg n)
  (λ args
    (cond [(> n (length args))
           (error 'select (~a "Can't select "
                              (counting-string n)
                              " value in "
                              args))]
          [(= 0 n)
           (error 'select (~a "Can't select "
                              (counting-string n)
                              " value in "
                              args
                              " -- select is 1-indexed"))]
          [else (list-ref args (sub1 n))])))

(define (except-args . indices)
  (λ args
    (let ([indices (sort indices <)])
      (if (and (not (empty? indices))
               (<= (first indices) 0))
          (error 'block (~a "Can't block "
                            (counting-string (first indices))
                            " value in "
                            args
                            " -- block is 1-indexed"))
          (let loop ([indices indices]
                     [rem-args args]
                     [cur-idx 1])
            (if (empty? indices)
                rem-args
                (match rem-args
                  ['() (error 'block (~a "Can't block "
                                         (counting-string (first indices))
                                         " value in "
                                         args))]
                  [(cons v vs)
                   (if (= cur-idx (first indices))
                       (loop (rest indices) vs (add1 cur-idx))
                       (cons v (loop indices vs (add1 cur-idx))))])))))))

;; give a (list-)lifted function available arguments
;; directly instead of wrapping them with a list
;; related to `unpack`
(define (give f)
  (λ args
    (f args)))

(define (~map f vs)
  (match vs
    ['() null]
    [(cons v vs) (append (values->list (f v))
                         (~map f vs))]))

;; Note: can probably get rid of implicit packing to args, and the
;; final apply values
(define (map-values f . args)
  (apply values (~map f args)))

(define (filter-values f . args)
  (apply values (filter f args)))

;; partition arguments by the first matching condition, then feed the
;; accumulated subsequences into associated bodies.
;; - c+bs is a list of pair?
;; - each car is a condition-flow (c) and each cdr a body-flow (b)
(define (partition-values c+bs . args)
  ;; The accumulator type is {condition-flow → [args]}. The first
  ;; accumulator, acc₀, maps conditions to empty args.
  (define acc0
    (for/hasheq ([c+b (in-list c+bs)])
      (values (car c+b) empty)))
  ;; Partition the arguments by first matching condition.
  (define by-cs
    ;; Accumulates result lists in reverse…
    (for/fold ([acc acc0]
               ;; …then reverses them.
               #:result (for/hash ([(c args) (in-hash acc)])
                          (values c (reverse args))))
      ([arg (in-list args)])
      (define matching-c
        ;; first condition…
        (for*/first ([c+b (in-list c+bs)]
                     [c (in-value (car c+b))]
                     ;; …that holds
                     #:when (c arg))
          c))
      (if matching-c
        (hash-update acc matching-c (λ (acc-at-c) (cons arg acc-at-c)))
        acc)))
  ;; Apply bodies to partitioned arguments. Each body's return values are
  ;; collected in a list, and all return-lists are collected in order of
  ;; appearance. The resulting list is flattened twice, once by apply and once
  ;; by append, to remove the lists introduced by this function. The resulting
  ;; list is the sequence of return values.
  (define results
    (for*/list ([c+b (in-list c+bs)]
                [c (in-value (car c+b))]
                [b (in-value (cdr c+b))]
                [args (in-value (hash-ref by-cs c))])
      (call-with-values (λ () (apply b args)) list)))
  (apply values (apply append results)))

(define exists ormap)

(define for-all andmap)

(define (singleton? seq)
  ;; cheap check to see if a list is of length 1,
  ;; instead of traversing to compute the length
  (and (not (empty? seq))
       (empty? (rest seq))))

(define (~zip-with op seqs truncate)
  (if (exists empty? seqs)
      (if (for-all empty? seqs)
          null
          (if truncate
              null
              (apply raise-arity-error
                     'zip-with
                     0
                     (first (filter (negate empty?) seqs)))))
      (let ([vs (map first seqs)])
        (append (values->list (apply op vs))
                (~zip-with op (map rest seqs) truncate)))))

(define (zip-with op)
  (λ seqs
    (if (empty? seqs)
        (values)
        (let ([v (first seqs)])
          (if (list? v)
              (apply values (apply ~zip-with (list op seqs #true)))
              (raise-argument-error 'zip-with
                                    "list?"
                                    v))))))

;; from mischief/function - requiring it runs aground
;; of some "name is protected" error while building docs, not sure why;
;; so including the implementation directly here for now
(define call
  (make-keyword-procedure
   (lambda (ks vs f . xs)
     (keyword-apply f ks vs xs))))

(define (relay . fs)
  (λ args
    (apply values (~zip-with call (list fs args) #false))))

(define (repeat-values n . vs)
  (apply values (apply append (make-list n vs))))

(define (fold-values f init vs)
  (let loop ([vs vs]
             [accs (values->list (init))])
    (match vs
      ['() (apply values accs)]
      [(cons v rem-vs) (loop rem-vs (values->list (apply f v accs)))])))

(define (foldl-values f init . vs)
  (fold-values f init vs))

(define (foldr-values f init . vs)
  (fold-values f init (reverse vs)))

(define (feedback-times f n then-f)
  (λ args
    (if (= n 0)
        (apply then-f args)
        (call-with-values (thunk (apply f args))
                          (feedback-times f (sub1 n) then-f)))))

(define (feedback-while f condition then-f)
  (λ args
    (let loop ([args args])
      (if (apply condition args)
          (loop (values->list
                 (apply f args)))
          (apply then-f args)))))
