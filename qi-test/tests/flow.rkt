#lang racket/base

(provide tests)

(require qi
         rackunit
         rackunit/text-ui
         (only-in math sqr)
         (only-in adjutor values->list)
         racket/list
         racket/string
         racket/function
         "private/util.rkt")

;; used in the "language extension" tests for `qi:*`
(define-syntax-rule (qi:square flo)
  (☯ (feedback 2 flo)))

(define (get-f n)
  (λ (v)
    (+ v n)))

(define tests
  (test-suite
   "flow tests"

   (test-suite
    "core language"
    (test-suite
     "Edge/base cases"
     (check-equal? (values->list ((☯))) null "empty flow with no inputs")
     (check-equal? ((☯) 0) 0 "empty flow with one input")
     (check-equal? (values->list ((☯) 1 2)) (list 1 2) "empty flow with multiple inputs")
     (check-equal? ((☯ (const 3))) 3 "no arguments")
     (check-equal? ((flow add1) 2) 3 "simple function")
     (check-equal? ((flow (get-f 1)) 2) 3 "fully qualified function")
     (check-equal? ((flow _) 5) 5 "identity flow")
     (check-equal? ((flow (~> _ ▽)) 5 6) (list 5 6) "identity flow"))
    (test-suite
     "Literals"
     (check-equal? ((flow 0) 2) 0 "literal number")
     (check-equal? ((flow #\q) 5) #\q "literal character")
     (check-equal? ((flow "hi") 5) "hi" "literal string")
     (check-equal? ((flow #"hi") 5) #"hi" "literal byte string")
     (check-equal? ((flow #px"hi") 5) #px"hi" "literal regexp")
     (check-equal? ((flow #rx"hi") 5) #rx"hi" "literal regexp")
     (check-equal? ((flow 'hi) 5) 'hi "literal symbol")
     (check-equal? ((flow '(+ 1 2)) 5) '(+ 1 2) "literal quoted list")
     (check-equal? ((flow `(+ 1 ,(* 2 3))) 5) '(+ 1 6) "literal quasiquoted list")
     (check-equal? (syntax->datum ((flow #'(+ 1 2)) 5)) '(+ 1 2) "Literal syntax quoted list"))
    (test-suite
     "unary predicate"
     (check-false ((☯ negative?) 5))
     (check-true ((☯ positive?) 5)))
    (test-suite
     "binary predicate"
     (check-false ((☯ >) 5 6))
     (check-true ((☯ <) 5 6)))
    (test-suite
     "n-ary predicate"
     (check-false ((☯ >) 5 5 6 7))
     (check-false ((☯ <) 5 5 6 7))
     (check-true ((☯ <=) 5 5 6 7)))
    (test-suite
     "one-of?"
     (check-false ((☯ (one-of? "hi" "ola")) "hello"))
     (check-true ((☯ (one-of? "hi" "hello")) "hello")))
    (test-suite
     "predicate under a mapping"
     (check-true ((☯ (~> string->number (< 10))) "5"))
     (check-false ((☯ (~> string->number (> 10))) "5")))
    (test-suite
     "and (conjoin)"
     (check-true ((☯ (and positive? integer?)) 5))
     (check-false ((☯ (and positive? integer?)) 5.4))
     (check-true ((☯ (and (> 5) (< 10))) 6))
     (check-false ((☯ (and (> 5) (< 10))) 4))
     (check-false ((☯ (and (> 5) (< 10))) 14))
     (check-false ((☯ (and _ positive?)) #f) "_ in and"))
    (test-suite
     "or (disjoin)"
     (check-true ((☯ (or positive? odd?)) 6))
     (check-true ((☯ (or positive? odd?)) -5))
     (check-false ((☯ (or positive? odd?)) -6))
     (check-true ((☯ (or eq?
                         equal?
                         (~> (>< string->number) =)))
                  "5.0" "5"))
     (check-false ((☯ (or eq?
                          equal?
                          (~> (>< string->number) =)))
                   "5" "6"))
     (check-true ((☯ (or _ NOT)) #f) "_ in or"))
    (test-suite
     "not (predicate negation)"
     (check-true ((☯ (not positive?)) -5))
     (check-false ((☯ (not positive?)) 5))
     (check-true ((☯ (not _)) #f) "_ in not"))
    (test-suite
     "boolean combinators"
     (check-true ((☯ (and positive?
                          (not even?)))
                  5))
     (check-false ((☯ (and positive?
                           (not odd?)))
                   5))
     (check-true ((☯ (and positive?
                          (or integer?
                              odd?)))
                  5))
     (check-false ((☯ (and positive?
                           (or (> 6)
                               even?)))
                   5))
     (check-true ((☯ (and positive?
                          (or (eq? 3)
                              (eq? 5))))
                  5))
     (check-false ((☯ (and positive?
                           (or (eq? 3)
                               (eq? 6))))
                   5)))
    (test-suite
     "juxtaposed boolean combinators"
     (check-true ((☯ (and% positive?
                           (or (> 10)
                               odd?)))
                  20 5))
     (check-false ((☯ (and% positive?
                            (or (> 10)
                                even?)))
                   20 5)))
    (test-suite
     "juxtaposed conjoin"
     (check-true ((☯ (and% positive? string?))
                  5 "hi"))
     (check-false ((☯ (and% positive? string?))
                   5 5))
     (check-true ((☯ (and% positive? _))
                  5 "hi"))
     (check-true ((☯ (and% _ string?))
                  5 "hi")))
    (test-suite
     "juxtaposed disjoin"
     (check-true ((☯ (or% positive? string?))
                  5 "hi"))
     (check-true ((☯ (or% positive? string?))
                  -5 "hi"))
     (check-false ((☯ (or% positive? string?))
                   -5 5))
     (check-false ((☯ (or% positive? _))
                   -5 "hi"))
     (check-true ((☯ (or% positive? _))
                  5 "hi"))
     (check-true ((☯ (or% _ string?))
                  5 "hi"))
     (check-false ((☯ (or% _ string?))
                   5 5)))
    (test-suite
     "all"
     (check-true ((☯ (all positive?))
                  3 5))
     (check-false ((☯ (all positive?))
                   3 -5)))
    (test-suite
     "any"
     (check-true ((☯ (any positive?))
                  3 5))
     (check-true ((☯ (any positive?))
                  3 -5))
     (check-false ((☯ (any positive?))
                   -3 -5)))
    (test-suite
     "none"
     (check-true ((☯ (none positive?))
                  -3 -5))
     (check-false ((☯ (none positive?))
                   3 -5))
     (check-false ((☯ (none positive?))
                   3 5)))
    (test-suite
     "all?"
     (check-true ((☯ all?)) "design: should this produce no values instead?")
     (check-true ((☯ all?) 3))
     (check-false ((☯ all?) #f))
     (check-true ((☯ all?) 3 5 7))
     (check-false ((☯ all?) 3 #f 5)))
    (test-suite
     "any?"
     (check-false ((☯ any?)) "design: should this produce no values instead?")
     (check-true ((☯ any?) 3))
     (check-false ((☯ any?) #f))
     (check-true ((☯ any?) 3 5 7))
     (check-true ((☯ any?) 3 #f 5))
     (check-true ((☯ any?) #f #f 5))
     (check-false ((☯ any?) #f #f #f)))
    (test-suite
     "none?"
     (check-false ((☯ none?) 3))
     (check-true ((☯ none?) #f))
     (check-false ((☯ none?) 3 5 7))
     (check-false ((☯ none?) 3 #f 5))
     (check-false ((☯ none?) #f #f 5))
     (check-true ((☯ none?) #f #f #f)))
    (test-suite
     "collect"
     (check-equal? ((☯ (~> collect (string-join "")))
                    "a" "b" "c")
                   "abc")
     (check-equal? ((☯ (~> ▽ (string-join "")))
                    "a" "b" "c")
                   "abc")
     (check-equal? ((☯ (~> ▽ (string-join "")))
                    "a")
                   "a")
     (check-equal? ((☯ (~> ▽ (string-join ""))))
                   ""))
    (test-suite
     "sep"
     (check-equal? ((☯ (~> △ +))
                    null)
                   0)
     (check-equal? ((☯ (~> sep +))
                    null)
                   0)
     (check-equal? ((☯ △)
                    (list 1))
                   1)
     (check-equal? ((☯ (~> △ +))
                    (list 1 2 3 4))
                   10)
     (check-exn exn:fail:contract?
                (thunk ((☯ (~> △ +))
                        #(1 2 3 4))))
     (check-equal? ((☯ (~> (△ +) ▽)) (list 1 2 3) 10)
                   (list 11 12 13)
                   "separate into a flow with presupplied values")
     (check-equal? ((☯ (~> (△ (~> X string-append)) ▽)) (list "1" "2" "3") "10")
                   (list "101" "102" "103")
                   "separate into a non-primitive flow with presupplied values"))
    (test-suite
     "gen"
     (check-equal? ((☯ (gen 5)))
                   5)
     (check-equal? ((☯ (gen 5)) 3)
                   5)
     (check-equal? ((☯ (gen 5)) 3 7)
                   5)
     (check-equal? ((☯ (~> (>< (gen 5)) ▽)) 3 4)
                   (list 5 5))
     (check-equal? ((☯ (~> (gen 3 4 5) ▽)))
                   (list 3 4 5)))
    (test-suite
     "escape hatch"
     (check-equal? ((☯ (esc (first (list + *)))) 3 7)
                   10
                   "normal racket expressions"))
    (test-suite
     "elementary boolean gates"
     (test-suite
      "AND"
      (check-false ((☯ AND) #f))
      (check-true ((☯ AND) 3))
      (check-true ((☯ AND) 3 5 7))
      (check-false ((☯ AND) 3 #f 5))
      (check-false ((☯ AND) #f #f 5))
      (check-false ((☯ AND) #f #f #f)))
     (test-suite
      "OR"
      (check-false ((☯ OR) #f))
      (check-true ((☯ OR) 3))
      (check-true ((☯ OR) 3 5 7))
      (check-true ((☯ OR) 3 #f 5))
      (check-true ((☯ OR) #f #f 5))
      (check-false ((☯ OR) #f #f #f)))
     (test-suite
      "NOT"
      (check-false ((☯ NOT) 3))
      (check-true ((☯ NOT) #f)))
     (test-suite
      "NAND"
      (check-true ((☯ NAND) #f))
      (check-false ((☯ NAND) 3))
      (check-false ((☯ NAND) 3 5 7))
      (check-true ((☯ NAND) 3 #f 5))
      (check-true ((☯ NAND) #f #f 5))
      (check-true ((☯ NAND) #f #f #f)))
     (test-suite
      "NOR"
      (check-true ((☯ NOR) #f))
      (check-false ((☯ NOR) 3))
      (check-false ((☯ NOR) 3 5 7))
      (check-false ((☯ NOR) 3 #f 5))
      (check-false ((☯ NOR) #f #f 5))
      (check-true ((☯ NOR) #f #f #f)))
     (test-suite
      "XOR"
      (check-false ((☯ XOR) #f))
      (check-true ((☯ XOR) 3))
      (check-true ((☯ XOR) #f 3))
      (check-true ((☯ XOR) 3 #f))
      (check-false ((☯ XOR) 3 5))
      (check-false ((☯ XOR) #f #f))
      (check-false ((☯ XOR) #f #f #f))
      (check-true ((☯ XOR) #f #f 3))
      (check-true ((☯ XOR) #f 3 #f))
      (check-false ((☯ XOR) #f 3 5))
      (check-true ((☯ XOR) 3 #f #f))
      (check-false ((☯ XOR) 3 #f 5))
      (check-false ((☯ XOR) 3 5 #f))
      (check-true ((☯ XOR) 3 5 7)))
     (test-suite
      "XNOR"
      (check-true ((☯ XNOR) #f))
      (check-false ((☯ XNOR) 3))
      (check-false ((☯ XNOR) #f 3))
      (check-false ((☯ XNOR) 3 #f))
      (check-true ((☯ XNOR) 3 5))
      (check-true ((☯ XNOR) #f #f))
      (check-true ((☯ XNOR) #f #f #f))))
    (test-suite
     "interactions between components"
     (test-suite
      "prisms"
      (check-equal? ((☯ (~> △ ▽)) (list 1 2 3))
                    (list 1 2 3))
      (check-equal? ((☯ (~> ▽ △ string-append)) "a" "b" "c")
                    "abc"))))

   (test-suite
    "routing forms"
    (test-suite
     "~>"
     (check-equal? ((☯ (~> add1
                           (* 2)
                           number->string
                           (string-append "a" _ "b")))
                    5)
                   "a12b")
     (check-equal? ((☯ (~> (>< add1)
                           (>< number->string)
                           (string-append _ "a" _ "b")))
                    5 6)
                   "6a7b")
     (check-equal? ((☯ (~> (>< add1)
                           (>< (* 2))
                           ▽))
                    5 6)
                   (list 12 14))
     (check-equal? ((☯ (~> (>< (string-append "a" _ "b"))
                           string-append))
                    "p" "q")
                   "apbaqb")
     (check-equal? ((☯ (~> (string-append "a" "b")))
                    "p" "q")
                   "pqab"
                   "threading without template")
     (check-equal? ((☯ (~> (>< (string-append "a" "b"))
                           string-append))
                    "p" "q")
                   "pabqab"
                   "threading without template")
     (check-equal? ((☯ (thread add1
                               (* 2)
                               number->string
                               (string-append "a" _ "b")))
                    5)
                   "a12b"
                   "named threading form"))
    (test-suite
     "~>>"
     (check-equal? ((☯ (~>> add1
                            (* 2)
                            number->string
                            (string-append "a" _ "b")))
                    5)
                   "a12b")
     (check-equal? ((☯ (~>> (>< add1)
                            (>< number->string)
                            (string-append _ "a" _ "b")))
                    5 6)
                   "6a7b")
     (check-equal? ((☯ (~>> (>< add1)
                            (>< (* 2))
                            ▽))
                    5 6)
                   (list 12 14))
     (check-equal? ((☯ (~>> (>< (string-append "a" _ "b"))
                            string-append))
                    "p" "q")
                   "apbaqb")
     (check-equal? ((☯ (~>> (string-append "a" "b")))
                    "p" "q")
                   "abpq"
                   "right-threading without template")
     ;; TODO: propagate threading side to nested clauses
     ;; (check-equal? (on ("p" "q")
     ;;                   (~>> (>< (string-append "a" "b"))
     ;;                        string-append))
     ;;               "abpabq"
     ;;               "right-threading without template")
     (check-equal? ((☯ (thread-right add1
                                     (* 2)
                                     number->string
                                     (string-append "a" _ "b")))
                    5)
                   "a12b"
                   "named threading form"))
    (test-suite
     "crossover"
     (check-equal? ((☯ (~> X string-append))
                    "a" "b")
                   "ba")
     (check-equal? ((☯ (~> crossover string-append))
                    "a" "b")
                   "ba")
     (check-equal? ((☯ X) "a")
                   "a"))
    (test-suite
     "-<"
     (check-equal? ((☯ (~> (-< sqr add1) ▽))
                    5)
                   (list 25 6))
     (check-equal? ((☯ (~> (-< sum length) /))
                    (range 1 10))
                   5)
     (check-equal? ((☯ (~> (-< _ add1) ▽))
                    5)
                   (list 5 6)
                   "tee with don't-care")
     (check-equal? ((☯ (~> (-< + -) ▽))
                    5 7)
                   (list 12 -2)
                   "multi-valued tee")
     (check-equal? ((☯ (~> (-< ⏚) ▽))
                    5 7)
                   null
                   "tee with arity-nullifying clause")
     (check-equal? ((☯ (~> (-< + ⏚) ▽))
                    5 7)
                   (list 12)
                   "tee with arity-nullifying clause")
     (check-equal? ((☯ (~> (-< (-< _ _) _) ▽))
                    5)
                   (list 5 5 5)
                   "tee with arity-increasing clause")
     (check-equal? ((☯ (~> (tee sqr add1) ▽))
                    5)
                   (list 25 6)
                   "named tee junction form"))
    (test-suite
     "=="
     (check-equal? ((☯ (~> (== sqr add1) ▽))
                    5 7)
                   (list 25 8))
     (check-equal? ((☯ (~> (-< sum length)
                           (== add1 sub1)
                           ▽))
                    (range 1 10))
                   (list 46 8))
     (check-equal? ((☯ (~> (== _ add1) ▽))
                    5 7)
                   (list 5 8)
                   "relay with don't-care")
     (check-equal? ((☯ (~> (== _ _) ▽))
                    5 7)
                   (list 5 7)
                   "relay with don't-care")
     (check-equal? ((☯ (~> (== ⏚ add1) ▽))
                    5 7)
                   (list 8)
                   "relay with arity-nullifying clause")
     (check-equal? ((☯ (~> (== (-< _ _) add1) ▽))
                    5 7)
                   (list 5 5 8)
                   "relay with arity-increasing clause")
     (check-exn exn:fail?
                (thunk ((☯ (~> (== ⏚ add1) ▽))
                        5 7 8))
                "relay elements must be in one-to-one correspondence with input")
     (check-equal? ((☯ (~> (relay sqr add1) ▽))
                    5 7)
                   (list 25 8)
                   "named relay form"))
    (test-suite
     "==*"
     (check-equal? ((☯ (~> (==* add1 sub1 +) ▽))
                    1 1 1 1 1)
                   (list 2 0 3))
     (check-equal? ((☯ (~> (==* add1 sub1 +) ▽))
                    1 1)
                   (list 2 0 0))
     (check-equal? ((☯ (~> (relay* add1 sub1 +) ▽))
                    1 1 1 1 1)
                   (list 2 0 3)
                   "named relay* form"))
    (test-suite
     "ground"
     (check-equal? ((☯ (-< ⏚ add1))
                    5)
                   6)
     (check-equal? ((☯ (-< ground add1))
                    5)
                   6)))

   (test-suite
    "Exceptions"
    (check-equal? ((☯ (try (/ 3)
                        [exn? 'hi])) 9)
                  3)
    (check-equal? ((☯ (try (/ 0)
                        [exn? 'hi])) 9)
                  'hi)
    (check-equal? ((☯ (try (/ 0)
                        [exn:fail:contract:arity? 'arity]
                        [exn:fail:contract:divide-by-zero? 'divide-by-zero])) 9)
                  'divide-by-zero))

   (test-suite
    "partial application"
    (test-suite
     "implicitly curried forms"
     (test-suite
      "eq?"
      (check-false ((☯ (eq? 5)) 6))
      (check-true ((☯ (eq? 5)) 5)))
     (test-suite
      "equal?"
      (check-false ((☯ (equal? "hello")) "bye"))
      (check-true ((☯ (equal? "hello")) "hello")))
     (test-suite
      "<"
      (check-false ((☯ (< 5)) 5))
      (check-true ((☯ (< 10)) 5)))
     (test-suite
      "<="
      (check-false ((☯ (<= 1)) 5))
      (check-true ((☯ (<= 10)) 5))
      (check-true ((☯ (<= 5)) 5)))
     (test-suite
      ">"
      (check-false ((☯ (> 5)) 5))
      (check-true ((☯ (> 1)) 5)))
     (test-suite
      ">="
      (check-false ((☯ (>= 10)) 5))
      (check-true ((☯ (>= 1)) 5))
      (check-true ((☯ (>= 5)) 5)))
     (test-suite
      "="
      (check-true ((☯ (= 5)) 5))
      (check-false ((☯ (= 10)) 5)))
     (check-equal? ((☯ (string-append "b"))
                    "a")
                   "ab")
     (check-equal? ((☯ (string-append "c" "d"))
                    "a" "b")
                   "abcd")
     (check-equal? ((☯ (~>> (map add1)))
                    (list 1 2 3))
                   (list 2 3 4)
                   "curried map")
     (check-equal? ((☯ (~>> (filter odd?)))
                    (list 1 2 3))
                   (list 1 3)
                   "curried filter")
     (check-equal? ((☯ (~>> (foldl string-append "")))
                    (list "a" "b" "c"))
                   "cba"
                   "curried foldl")
     (check-exn exn:fail?
                (thunk ((☯ (+))
                        5 7 8))
                "function isn't curried when no arguments are provided"))
    (test-suite
     "blanket template"
     (check-equal? ((☯ (+ __))) 0)
     (check-equal? ((☯ (string-append __))
                    "a" "b")
                   "ab")
     (check-equal? ((☯ (string-append "a" __))
                    "b" "c")
                   "abc")
     (check-equal? ((☯ (string-append __ "c"))
                    "a" "b")
                   "abc"))
    (test-suite
     "template with single argument"
     (check-false ((☯ (apply > _))
                   (list 1 2 3)))
     (check-true ((☯ (apply > _))
                  (list 3 2 1)))
     (check-equal? ((☯ (map add1 _))
                    (list 1 2 3))
                   (list 2 3 4)
                   "map in predicate")
     (check-equal? ((☯ (filter odd? _))
                    (list 1 2 3))
                   (list 1 3)
                   "filter in predicate")
     (check-equal? ((☯ (foldl string-append "" _))
                    (list "a" "b" "c"))
                   "cba"
                   "foldl in predicate"))
    (test-suite
     "template with multiple arguments"
     (check-true ((☯ (< 1 _ 5 _ 10)) 3 7)
                 "template with multiple arguments")
     (check-false ((☯ (< 1 _ 5 _ 10)) 3 5)
                  "template with multiple arguments"))
    (test-suite
     "templating behavior is contained to intentional template syntax"
     (check-exn exn:fail:syntax?
                (thunk (parameterize ([current-namespace (make-base-empty-namespace)])
                         (namespace-require 'racket/base)
                         (namespace-require 'qi)
                         (eval '(☯ (feedback _ add1))
                               (current-namespace))))
                "invalid syntax accepted on the basis of an assumed fancy-app template")))

   (test-suite
    "conditionals"
    (test-suite
     "if"
     (check-equal? ((☯ (if sub1 add1))
                    negative?
                    5)
                   6
                   "control form of if, where the predicate is an input")
     (check-equal? ((☯ (if sub1 add1))
                    positive?
                    5)
                   4
                   "control form of if, where the predicate is an input")
     (check-equal? ((☯ (if + -))
                    <
                    5 6)
                   11
                   "control form of if, where the predicate is an input")
     (check-equal? ((☯ (if + -))
                    >
                    5 6)
                   -1
                   "control form of if, where the predicate is an input")
     (check-equal? ((☯ (if negative? sub1 add1))
                    5)
                   6)
     (check-equal? ((☯ (if negative? sub1 add1))
                    -5)
                   -6)
     (check-equal? ((☯ (if negative? sub1 _))
                    5)
                   5)
     (check-equal? ((☯ (if < + -))
                    5 6)
                   11)
     (check-equal? ((☯ (if < + -))
                    6 5)
                   1)
     (check-equal? ((☯ (if (< 10) _ (gen 0)))
                    5)
                   5)
     (check-equal? ((☯ (if (< 10) _ (gen 0)))
                    15)
                   0))
    (test-suite
     "when"
     (check-equal? ((☯ (when positive? add1))
                    5)
                   6)
     (check-equal? ((☯ (~> (when positive? add1) ▽))
                    -5)
                   null))
    (test-suite
     "unless"
     (check-equal? ((☯ (~> (unless positive? add1) ▽))
                    5)
                   null)
     (check-equal? ((☯ (unless positive? add1))
                    -5)
                   -4))
    (test-suite
     "switch"
     (check-equal? ((☯ (~> (switch) ▽)))
                   null)
     (check-equal? ((☯ (switch [negative? sub1]))
                    -5)
                   -6)
     (check-equal? ((☯ (~> (switch [negative? sub1]) ▽))
                    5)
                   (list 5)
                   "no matching condition means input passes through")
     (check-equal? ((☯ (switch [negative? sub1] [else add1]))
                    5)
                   6)
     (check-equal? ((☯ (switch [negative? sub1] [else add1]))
                    -5)
                   -6)
     (check-equal? ((☯ (switch [< +] [else -]))
                    5 6)
                   11)
     (check-equal? ((☯ (switch [< +] [else -]))
                    6 5)
                   1)
     (check-equal? ((☯ (switch [< +] [> -] [else _]))
                    5 6)
                   11)
     (check-equal? ((☯ (switch [< +] [> -] [else _]))
                    6 5)
                   1)
     (check-equal? ((☯ (switch [< +] [> -] [else 0]))
                    6 6)
                   0)
     (check-equal? ((☯ (switch [< +] [> -] [= 0]))
                    6 6)
                   0)
     (check-equal? ((☯ (~> (switch [< +] [> -]) ▽))
                    6 6)
                   (list 6 6)
                   "no matching clause means inputs pass through")
     (check-equal? ((☯ (switch [(< 10) _] [else (gen 0)]))
                    5)
                   5)
     (check-equal? ((☯ (switch [(< 10) _] [else (gen 0)]))
                    15)
                   0)
     (test-suite
      "divert"
      (check-equal? ((☯ (~> (switch (% _ _)) ▽)))
                    null)
      (check-equal? ((☯ (switch (% 1> _)
                          [positive? +]
                          [negative? 'hi]
                          [else 'bye])) 4 -1)
                    3)
      (check-equal? ((☯ (switch (divert 1> _)
                          [positive? +]
                          [negative? 'hi]
                          [else 'bye])) 4 -1)
                    3
                    "divert word form")
      (check-equal? ((☯ (switch (% 1> _)
                          [positive? +]
                          [negative? 'hi]
                          [else 'bye])) -2 -1)
                    'hi)
      (check-equal? ((☯ (switch (% 1> _)
                          [positive? +]
                          [negative? 'hi]
                          [else 'bye])) 0 -1)
                    'bye)
      (check-equal? ((☯ (switch (% 1> 2>)
                          [negative? (=> 'hi)]
                          [add1 (=> + sqr)]
                          [else 'bye])) 4 -3)
                    4)
      (check-equal? ((☯ (switch (% 1> 2>)
                          [add1 (=> + sqr)])) 4 -4)
                    1
                    "when both divert and => are present, divert operates only on the original inputs")
      (check-equal? ((☯ (switch (% 1> 2>)
                          [positive? _]
                          [negative? 'hi]
                          [else 'bye])) 4 -1)
                    -1
                    "diverting to consequent flows"))
     (test-suite
      "result of predicate expression"
      (check-equal? ((☯ (switch
                            [add1 (=> 1> add1)]
                          [else 'hi]))
                     6)
                    8)
      (check-equal? ((☯ (switch
                            [(member (list 1 5 4 2 6)) (=> 1>)]
                          [else 'hi]))
                     2)
                    (list 2 6))
      (check-equal? ((☯ (switch
                            [(member (list 1 5 4 2 6)) (=> 1> length)]
                          [else 'hi]))
                     2)
                    2)
      (check-equal? ((☯ (switch
                            [car (=> (== _ 5) apply)]
                          [else 'hi]))
                     (list add1 sub1))
                    6)
      (check-equal? ((☯ (switch
                            [+ (=> 1>)]
                          [else 'hi]))
                     2 3)
                    5)
      (check-equal? ((☯ (switch
                            [(~>> △ (sort < #:key identity)) (=> 1>)]
                          [else 'no]))
                     (list 2 1 3))
                    (list 1 2 3)
                    "apply in predicate with non-tail arguments")))
    (test-suite
     "sieve"
     (check-equal? ((☯ (~> (sieve positive? add1 (const -1)) ▽))
                    1 -2)
                   (list 2 -1))
     (check-equal? ((☯ (~> (sieve positive? + (+ 2)) ▽))
                    1 2 -3 4)
                   (list 7 -1))
     (check-equal? ((☯ (~> (sieve positive? + (const 0)) ▽))
                    1 2 3 4)
                   (list 10 0))
     (check-equal? ((☯ (~> (sieve negative? ⏚ ⏚) ▽))
                    1 3 5 7)
                   null
                   "sieve with arity-nullifying clause")
     (check-equal? ((☯ (~> (sieve negative? ⏚ +) ▽))
                    1 -3 5 -7)
                   (list 6)
                   "sieve with arity-nullifying clause")
     (check-equal? ((☯ (~> (sieve positive? (>< (-< _ _)) _) ▽))
                    1 -3 5)
                   (list 1 1 5 5 -3)
                   "sieve with arity-increasing clause")
     (check-equal? (~> (1 2 -3 4)
                       (-< (gen positive?) (gen +) (gen (☯ (+ 2))) _)
                       sieve
                       ▽)
                   (list 7 -1)
                   "pure control form of sieve"))
    (test-suite
      "partition"
      (check-equal? ((flow (~> (partition) collect)))
                    (list)
                    "base partition case")
      (check-equal? ((flow (partition [positive? +]))
                     -1 2 1 1 -2 2)
                    6
                    "partition composes ~> and pass")
      (check-equal? ((flow (~> (partition [positive? +]
                                          [zero? (-< count (gen "zero"))]
                                          [negative? *]) collect))
                     -1 0 2 1 1 -2 0 0 2)
                    (list 6 3 "zero" 2))
      (check-equal? ((flow (~> (partition [positive? +]
                                          [zero? (-< count (gen "zero"))]
                                          [negative? *]) collect))
                     -1 2 1 1 -2 2)
                    (list 6 0 "zero" 2)
                    "some partition bodies have no inputs")
      (check-equal? ((flow (~> (partition [(and positive? (> 1)) +]
                                          [_ list]) collect))
                     -1 2 1 1 -2 2)
                    (list 4 (list -1 1 1 -2))
                    "partition bodies can be flows"))
    (test-suite
     "gate"
     (check-equal? ((☯ (gate positive?))
                    5)
                   5)
     (check-equal? ((☯ (-< (gate negative?) (gen 0)))
                    5)
                   0)
     (check-equal? ((☯ (~> (gate <) ▽))
                    5 6)
                   (list 5 6))))

   (test-suite
    "high-level circuit elements"
    (test-suite
     "input aliases"
     (check-equal? ((☯ (~> 1>))
                    1 2 3 4 5 6 7 8 9)
                   1)
     (check-equal? ((☯ (~> 2>))
                    1 2 3 4 5 6 7 8 9)
                   2)
     (check-equal? ((☯ (~> 3>))
                    1 2 3 4 5 6 7 8 9)
                   3)
     (check-equal? ((☯ (~> 4>))
                    1 2 3 4 5 6 7 8 9)
                   4)
     (check-equal? ((☯ (~> 5>))
                    1 2 3 4 5 6 7 8 9)
                   5)
     (check-equal? ((☯ (~> 6>))
                    1 2 3 4 5 6 7 8 9)
                   6)
     (check-equal? ((☯ (~> 7>))
                    1 2 3 4 5 6 7 8 9)
                   7)
     (check-equal? ((☯ (~> 8>))
                    1 2 3 4 5 6 7 8 9)
                   8)
     (check-equal? ((☯ (~> 9>))
                    1 2 3 4 5 6 7 8 9)
                   9))
    (test-suite
     "fanout"
     (check-equal? (~> (5) (fanout 3) ▽)
                   (list 5 5 5))
     (check-equal? (~> (2 3) (fanout 3) ▽)
                   (list 2 3 2 3 2 3))
     (check-equal? (~> (3 "a") fanout string-append)
                   "aaa"
                   "control form of fanout")
     (check-equal? (~> (3 "a" "b") fanout string-append)
                   "ababab"
                   "control form of fanout")
     (check-equal? (~> (5) (fanout (add1 2)) ▽)
                   (list 5 5 5)
                   "arbitrary racket expressions and not just literals")
     (check-equal? (let ([n 3])
                     (~> (5) (fanout n) ▽))
                   (list 5 5 5)
                   "arbitrary racket expressions and not just literals")
     (check-equal? (~> (2 3) (fanout 0) ▽)
                   null
                   "N=0 produces no values.")
     (check-equal? (~> () (fanout 3) ▽)
                   null
                   "No inputs produces no outputs.")
     (check-exn exn:fail:contract?
                (thunk (~> (-1 3) fanout ▽))
                "Negative N signals an error."))
    (test-suite
     "inverter"
     (check-false ((☯ (~> inverter
                          AND))
                   5 6))
     (check-true ((☯ (~> inverter
                         OR))
                  #f #t)))
    (test-suite
     "feedback"
     (check-equal? ((☯ (feedback 2 sqr))
                    5)
                   625
                   "(feedback N flo)")
     (check-equal? (~> (3 5) (feedback add1))
                   8
                   "(feedback flo) consumes the first input as N")
     (check-equal? ((☯ (feedback 5 (then sqr) add1))
                    11)
                   256
                   "(feedback N (then then-flo) flo)")
     (check-equal? ((☯ (feedback 5 (then sqr)))
                    add1 5)
                   100
                   "(feedback N (then then-flo))")
     (check-equal? ((☯ (~> (feedback 3 (>< add1)) ▽))
                    2 3)
                   (list 5 6)
                   "feedback producing multiple output values")
     (check-equal? ((☯ (~> (feedback 3 (== add1 sub1)) ▽))
                    2 3)
                   (list 5 0)
                   "feedback producing multiple output values")
     (check-equal? ((☯ (feedback (while positive?)))
                    (☯ (- 15)) 20)
                   -10
                   "(feedback (while cond-flo))")
     (check-equal? ((☯ (feedback (while positive?) (- 15)))
                    20)
                   -10
                   "(feedback (while cond-flo))")
     (check-equal? ((☯ (feedback (while positive?) (then (~> (-< _ _) *))))
                    (☯ (- 15)) 20)
                   100
                   "(feedback (while cond-flo) (then then-flo))")
     (check-equal? ((☯ (feedback (while positive?) (then (~> (-< _ _) *)) (- 15)))
                    20)
                   100
                   "(feedback (while cond-flo) (then then-flo) flo)")
     (check-equal? ((☯ (~> (-< 3
                               (gen (☯ (- 1)))
                               _)
                           feedback))
                    5)
                   2
                   "pure control form of feedback"))
    (test-suite
     "group"
     (check-equal? ((☯ (~> (group 0 (const 5) +) ▽))
                    1 2)
                   (list 5 3))
     (check-equal? ((☯ (~> (group 1 add1 sub1) ▽))
                    1 2)
                   (list 2 1))
     (check-equal? ((☯ (~> (group 3 * add1) ▽))
                    1 2 3 4)
                   (list 6 5))
     (check-equal? ((☯ (~> (group 2
                                  (~> (>< add1) +)
                                  add1)
                           ▽))
                    4 5 6)
                   (list 11 7))
     (check-equal? ((☯ (~> (group 2 ⏚ ⏚)
                           ▽))
                    1 3 5 7 9)
                   null
                   "group with arity-nullifying clause")
     (check-equal? ((☯ (~> (group 2 (>< (-< _ _)) _)
                           ▽))
                    1 3 5 7 9)
                   (list 1 1 3 3 5 7 9)
                   "group with arity-increasing clause")
     (check-equal? ((☯ (~> (group 2 (>< sqr) _) ▽))
                    1 2 3)
                   (list 1 4 3)
                   "group with don't-care")
     (check-equal? ((☯ (~> (group (add1 1) _ ⏚)
                           ▽))
                    1 3 5 7 9)
                   (list 1 3)
                   "group with racket expression specifying the number")
     (check-equal? ((☯ (~> (-< (gen 2 + (☯ _))
                               _)
                           group
                           ▽))
                    1 3 5 7 9)
                   (list 4 5 7 9)
                   "pure control form of group")
     (check-exn exn:fail?
                (thunk ((☯ (~> (group 3 _ ⏚)
                               ▽))
                        1 3))
                "grouping more inputs than are available shows a helpful error"))
    (test-suite
     "select"
     (check-equal? ((☯ (~> (select) ▽))
                    1)
                   null)
     (check-equal? ((☯ (select 1))
                    1)
                   1)
     (check-equal? ((☯ (select 2))
                    1 2 3)
                   2)
     (check-equal? ((☯ (select 3))
                    1 2 3)
                   3)
     (check-equal? ((☯ (~> (select 1 3)
                           string-append))
                    "1" "2" "3")
                   "13")
     (check-equal? ((☯ (~> (select 3 1)
                           string-append))
                    "1" "2" "3")
                   "31")
     (check-exn exn:fail?
                (thunk ((☯ (select 3))
                        1 3))
                "selecting input with a higher index than available")
     (check-exn exn:fail?
                (thunk ((☯ (select 0))
                        1 3))
                "attempting to select index 0 (select is 1-indexed)"))
    (test-suite
     "block"
     (check-equal? ((☯ (~> (block) list))
                    1 2)
                   (list 1 2))
     (check-equal? ((☯ (~> (block 1) list))
                    1)
                   null)
     (check-equal? ((☯ (~> (block 2) list))
                    1 2 3)
                   (list 1 3))
     (check-equal? ((☯ (~> (block 3) list))
                    1 2 3)
                   (list 1 2))
     (check-equal? ((☯ (~> (block 1 3) list))
                    1 2 3)
                   (list 2))
     (check-equal? ((☯ (~> (block 3 1) list))
                    1 2 3)
                   (list 2))
     (check-exn exn:fail?
                (thunk ((☯ (block 3))
                        1 3))
                "blocking input with a higher index than available")
     (check-exn exn:fail?
                (thunk ((☯ (block 0))
                        1 3))
                "attempting to block index 0 (block is 1-indexed)"))
    (test-suite
     "bundle"
     (check-equal? ((☯ (~> (bundle () + sqr) ▽))
                    3)
                   (list 0 9))
     (check-equal? ((☯ (bundle (1) sqr _))
                    3)
                   9)
     (check-equal? ((☯ (bundle (2) _ ⏚))
                    1 2 3)
                   2)
     (check-equal? ((☯ (bundle (3) _ ⏚))
                    1 2 3)
                   3)
     (check-equal? ((☯ (~> (bundle (1 3) string-append ⏚)))
                    "1" "2" "3")
                   "13")
     (check-equal? ((☯ (~> (bundle (3 1) string-append _) string-append))
                    "1" "2" "3")
                   "312"))
    (test-suite
     "effect"
     (check-equal? ((☯ (ε sub1 add1))
                    5)
                   6)
     (check-equal? (let ([sv (void)])
                     ((☯ (ε (~> sub1 (esc (λ (x) (set! sv x))))))
                      5)
                     sv)
                   4
                   "pure side effect")
     (let ([a 10])
       (check-equal? ((☯ (ε (esc (λ (_)
                                   (set! a (add1 a))))
                            add1))
                      5)
                     6)
       (check-equal? a 11)))

    (test-suite
     "count"
     (check-equal? ((☯ count) 3 4 5) 3)
     (check-equal? ((☯ count) 5) 1)
     (check-equal? ((☯ count)) 0))

    (test-suite
     "live?"
     (check-true ((☯ live?) 3 4 5))
     (check-true ((☯ live?) 5))
     (check-false ((☯ live?)))
     (check-true (~> (1 2) live?))
     (check-false (~> (1 2) ⏚ live?)))

    (test-suite
     "rectify"
     (check-equal? (~> (3 4 5) (rectify 'boo) ▽) (list 3 4 5))
     (check-equal? (~> (5) (rectify 'boo)) 5)
     (check-equal? (~> () (rectify 'boo)) 'boo)
     (check-equal? (~> (1 2) (rectify #f) ▽) (list 1 2))
     (check-equal? (~> (1 2) ⏚ (rectify #f)) #f)))

   (test-suite
    "higher-order flows"
    (test-suite
     "><"
     (check-equal? ((☯ (~> >< ▽))
                    sqr 3 5)
                   (list 9 25))
     (check-equal? ((☯ (~> (>< sqr) ▽))
                    3 5)
                   (list 9 25))
     (check-equal? ((☯ (~> (>< _) ▽))
                    3 5)
                   (list 3 5)
                   "amp with don't-care")
     (check-equal? ((☯ (~> (>< ⏚) ▽))
                    5 7)
                   null
                   "amp with arity-nullifying clause")
     (check-equal? ((☯ (~> (>< (-< _ _)) ▽))
                    5)
                   (list 5 5)
                   "amp with arity-increasing clause")
     (check-equal? ((☯ (~> (amp sqr) ▽))
                    3 5)
                   (list 9 25)
                   "named amplification form"))
    (test-suite
     "pass"
     (check-equal? ((☯ (~> pass ▽))
                    positive? -3 5 2)
                   (list 5 2)
                   "pure control form of pass")
     (check-equal? ((☯ (~> (pass positive?) ▽))
                    -3 5 2)
                   (list 5 2))
     (check-equal? ((☯ (~> (pass positive?) ▽))
                    -5 -7)
                   null
                   "pass with arity-nullifying clause"))
    (test-suite
     "left fold >>"
     (check-equal? ((☯ (>> +)) 1 2 3 4)
                   10)
     (check-equal? ((☯ (>> + 1)) 1 2 3 4)
                   11)
     (check-equal? ((☯ (>> (~> + _) 1)) 1 2 3 4)
                   11)
     (check-equal? ((☯ (>> cons (gen null))) 1 2 3 4)
                   (list 4 3 2 1))
     (check-equal? ((☯ (>> (esc (flip cons)) (gen null))) 1 2 3 4)
                   '((((() . 1) . 2) . 3) . 4))
     (check-equal? ((☯ (~> (-< (gen cons) (gen (☯ (gen null))) (gen 1 2 3 4)) >>)))
                   (list 4 3 2 1))
     (check-equal? ((☯ (~> (>> (-< (block 1) (~> 1> (-< _ _))) "") string-append)) "a" "b")
                   "aabb"))
    (test-suite
     "right fold <<"
     (check-equal? ((☯ (<< +)) 1 2 3 4)
                   10)
     (check-equal? ((☯ (<< + 1)) 1 2 3 4)
                   11)
     (check-equal? ((☯ (<< (~> + _) 1)) 1 2 3 4)
                   11)
     (check-equal? ((☯ (<< cons (gen null))) 1 2 3 4)
                   (list 1 2 3 4))
     (check-equal? ((☯ (<< (esc (flip cons)) (gen null))) 1 2 3 4)
                   '((((() . 4) . 3) . 2) . 1))
     (check-equal? ((☯ (~> (-< (gen cons) (gen (☯ (gen null))) (gen 1 2 3 4)) <<)))
                   (list 1 2 3 4))
     (check-equal? ((☯ (~> (<< (-< (block 1) (~> 1> (-< _ _))) "") string-append)) "a" "b")
                   "bbaa"))
    (test-suite
     "loop"
     (check-equal? ((☯ (~> (loop (~> ▽ (not null?))
                                 sqr)
                           ▽)) 1 2 3)
                   (list 1 4 9))
     (check-equal? ((☯ (~> (loop (~> ▽ (not null?))
                                 sqr
                                 +
                                 0))) 1 2 3)
                   14)
     (check-equal? ((☯ (~> (loop sqr) ▽))
                    1 2 3)
                   (list 1 4 9))
     (check-equal? ((☯ (~> (loop (~> ▽ (not null?))
                                 sqr
                                 +))) 1 2 3)
                   14))
    (test-suite
     "loop2"
     (check-equal? ((☯ (~> (loop2 (~> 1> (not null?))
                                  sqr
                                  cons)))
                    (list 1 2 3) null)
                   (list 9 4 1))
     (check-equal? ((☯ (~> (loop2 (~> 1> (not null?))
                                  sqr
                                  +)))
                    (list 1 2 3)
                    0)
                   14))
    (test-suite
     "apply"
     (check-equal? ((☯ (~> (-< (gen +) 2 3)
                           apply)))
                   5)
     (check-equal? ((☯ (~> (-< (gen (☯ (~> sqr add1)))
                               3)
                           apply)))
                   10))
    (test-suite
     "clos"
     (check-equal? ((☯ (~> (== (clos *) _) map)) 5 (list 1 2 3))
                   '(5 10 15))
     (check-equal? ((☯ (~> (== (clos string-append) _) map)) "a" (list "b" "c" "d"))
                   '("ab" "ac" "ad"))
     (check-equal? ((☯ (~> (== (~>> (clos string-append)) _) map)) "a" (list "b" "c" "d"))
                   '("ba" "ca" "da")
                   "clos respects threading direction at the site of definition")
     (check-equal? ((☯ (~> (== (~> (-< (gen string-append)
                                       _)
                                   clos)
                               _)
                           map)) "a" (list "b" "c" "d"))
                   '("ab" "ac" "ad"))
     (check-equal? ((☯ (~> (== (~>> (-< (gen string-append)
                                        _)
                                    clos)
                               _)
                           map)) "a" (list "b" "c" "d"))
                   '("ba" "ca" "da")
                   "clos respects threading direction at the site of definition")
     (check-equal? ((☯ (~> (-< (~> second (clos *)) _) map)) (list 1 2 3))
                   '(2 4 6))))

   (test-suite
    "language extension"
    (test-suite
     "qi:"
     (check-equal? (~> (2 3) + (qi:square sqr))
                   625)))

   (test-suite
    "arity modulating forms"
    (check-true ((☯ (and% positive? even?))
                 5 6)
                "and% arity propagation")
    (check-true ((☯ (or% positive? even?))
                 5 6)
                "or% arity propagation")
    (check-equal? ((☯ (~> (>< add1)
                          +))
                   5 6)
                  13
                  ">< arity propagation")
    (check-equal? ((☯ (~> (== add1 add1)
                          +))
                   5 6)
                  13
                  "== arity propagation")
    (let ([add-two (procedure-reduce-arity + 2)])
      (check-equal? ((☯ (~> (group 2 add-two add1)
                            *))
                     5 6 7)
                    88
                    "group arity propagation")))

   (test-suite
    "runtime arity changes"
    (check-equal? ((☯ (~>> list (findf even?) (if number? _ (gen 0)) sqr))
                   1 3 5)
                  0
                  "runtime arity changes in threading form")
    (check-equal? ((☯ (~>> list (findf even?) (if number? _ (gen 0)) sqr))
                   1 4 5)
                  16
                  "runtime arity changes in threading form")
    (check-false ((☯ (~>> list (-< (findf positive? _) (gen 0)) (and% even? number?)))
                  -1 3 5)
                 "runtime arity changes in threading form")
    (check-true ((☯ (~>> list (-< (findf positive? _) (gen 0)) (or% even? number?)))
                 -1 3 5)
                "runtime arity changes in threading form")
    (check-equal? ((☯ (~>> list (findf even?) (>< add1)))
                   1 4 5)
                  5
                  "runtime arity changes in threading form")
    (check-equal? ((☯ (~>> list (findf even?) (== add1)))
                   1 4 5)
                  5
                  "runtime arity changes in threading form")
    (check-equal? ((☯ (~>> list (findf even?) number->string (string-append "a" __ "b")))
                   1 4 5)
                  "a4b"
                  "runtime arity changes in threading form")
    (check-equal? ((☯ (~> (pass positive?) +))
                   1 -3 5)
                  6
                  "runtime arity changes in threading form"))))

(module+ main
  (void (run-tests tests)))