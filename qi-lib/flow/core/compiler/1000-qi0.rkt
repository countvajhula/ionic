#lang racket/base

(require "../passes.rkt"
         (prefix-in fancy: fancy-app)
         "../runtime.rkt"
         racket/function
         racket/list
         (for-syntax racket/base
                     racket/match
                     syntax/parse
                     "../syntax.rkt"
                     "../../aux-syntax.rkt"
                     (only-in racket/list make-list)
                     ))

(begin-for-syntax
  (define-and-register-pass 1000 (qi0-wrapper stx)
    (syntax-parse stx
      (ex #'(qi0->racket ex)))))

(define-syntax (qi0->racket stx)
  ;; this is a macro so it receives the entire expression
  ;; (qi0->racket ...). We use cadr here to parse the
  ;; contained expression.
  (syntax-parse (cadr (syntax->list stx))

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;; Core language forms ;;;;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;; A note regarding symbolic aliases like ~>, ⏚ and △:
    ;;
    ;; These aren't technically part of the core language
    ;; as they aren't directly part of the syntax
    ;; spec in the expander (which includes only, e.g.,
    ;; thread and tee and so on). Instead, they are simply
    ;; aliased at the module level there when provided.
    ;; Yet, during code generation in the present module,
    ;; it's more convenient to express expansions
    ;; using these symbolic aliases, and that's the
    ;; reason we retain these in the patterns below. As
    ;; these patterns are matched as _datum literals_,
    ;; it doesn't matter that they aren't actually the
    ;; literal core forms declared in the expander.

    [((~datum gen) ex:expr ...)
     #'(λ _ (values ex ...))]
    ;; pass-through (identity flow)
    [(~datum _) #'values]
    ;; routing
    [(~or* (~datum ⏚) (~datum ground)) ; NOTE: technically not core
     #'(qi0->racket (select))]
    [((~or* (~datum ~>) (~datum thread)) onex:clause ...)
     #`(compose . #,(reverse
                     (syntax->list
                      #'((qi0->racket onex) ...))))]
    [e:relay-form (relay-parser #'e)]
    [e:tee-form (tee-parser #'e)]
    ;; map and filter
    [e:amp-form (amp-parser #'e)] ; NOTE: technically not core
    [e:pass-form (pass-parser #'e)] ; NOTE: technically not core
    ;; prisms
    [e:sep-form (sep-parser #'e)]
    [(~or* (~datum ▽) (~datum collect))
     #'list]
    ;; predicates
    [(~or* (~datum NOT) (~datum !))
     #'not]
    [(~datum XOR)
     #'parity-xor]
    [((~datum and) onex:clause ...)
     #'(conjoin (qi0->racket onex) ...)]
    [((~datum or) onex:clause ...)
     #'(disjoin (qi0->racket onex) ...)]
    [((~datum not) onex:clause) ; NOTE: technically not core
     #'(negate (qi0->racket onex))]
    [((~datum all) onex:clause)
     #`(give (curry andmap (qi0->racket onex)))]
    [((~datum any) onex:clause)
     #'(give (curry ormap (qi0->racket onex)))]

    ;; selection
    [e:select-form (select-parser #'e)]
    [e:block-form (block-parser #'e)]
    [e:group-form (group-parser #'e)]
    ;; conditionals
    [e:if-form (if-parser #'e)]
    [e:sieve-form (sieve-parser #'e)]
    [e:partition-form (partition-parser #'e)]
    ;; exceptions
    [e:try-form (try-parser #'e)]
    ;; folds
    [e:fold-left-form (fold-left-parser #'e)]
    [e:fold-right-form (fold-right-parser #'e)]
    ;; high-level routing
    [e:fanout-form (fanout-parser #'e)]
    ;; looping
    [e:feedback-form (feedback-parser #'e)]
    [e:loop-form (loop-parser #'e)]
    [((~datum loop2) pred:clause mapex:clause combex:clause)
     #'(letrec ([loop2 (qi0->racket (if pred
                                        (~> (== (-< (esc cdr)
                                                    (~> (esc car) mapex)) _)
                                            (group 1 _ combex)
                                            (esc loop2))
                                        (select 2)))])
         loop2)]
    ;; towards universality
    [(~datum appleye)
     #'call]
    [e:clos-form (clos-parser #'e)]
    [e:deforestable-form (deforestable-parser #'e)]
    ;; escape hatch for racket expressions or anything
    ;; to be "passed through"
    [((~datum esc) ex:expr)
     #'ex]

    ;;; Miscellaneous

    ;; Partial application with syntactically pre-supplied arguments
    ;; in a blanket template
    [((~datum #%blanket-template) e)
     (blanket-template-form-parser this-syntax)]

    ;; Fine-grained template-based application
    ;; This handles templates that indicate a specific number of template
    ;; variables (i.e. expected arguments). The semantics of template-based
    ;; application here is fulfilled by the fancy-app module. In order to use
    ;; it, we simply use the #%app macro provided by fancy-app instead of the
    ;; implicit one used for function application in racket/base.
    ;; "prarg" = "pre-supplied argument"
    [((~datum #%fine-template) (prarg-pre ... (~datum _) prarg-post ...))
     #'(fancy:#%app prarg-pre ... _ prarg-post ...)]

    ;; If in the course of optimization we ever end up with a fully
    ;; simplified host expression, the compiler would a priori reject it as
    ;; not being a core Qi expression. So we add this extra rule here
    ;; to simply pass this expression through.
    ;; TODO: should `#%host-expression` be formally declared as being part
    ;; of the core language by including it in the syntax-spec grammar
    ;; in extended/expander.rkt?
    [((~datum #%host-expression) hex)
     this-syntax]))

#|

The form-specific parsers, which are delegated to from the qi0->racket
macro, are below.

Keep in mind that as we are at the code generation stage here -- which
is post-expansion and post-optimization -- for any synthesized syntax
at this stage, any floe positions there must be expressed purely in
the core language and should be recursively codegen'd by calling
`qi0->racket` on them. In particular, any Racket functions used must
be explicitly `esc`aped, as plain function identifiers are not part of
the core language though they are part of the surface language.

A note on error handling:

There should be no syntax errors reported at this stage, as that is
already handled during expansion by Syntax Spec.

|#

(begin-for-syntax

  (define (sep-parser stx)
    (syntax-parse stx
      [(_ op:clause)
       #'(zip-with (qi0->racket op))]
      [_:id #'(λ args
                (if (singleton? args)
                    (let ([v (first args)])
                      (if (list? v)
                          (apply values v)  ; fast path to the basic △ behavior
                          (raise-argument-error '△
                                                "list?"
                                                v)))
                    (apply (qi0->racket (△ _)) args)))]))

  (define (select-parser stx)
    (syntax-parse stx
      [(_ n:number ...) #'(qi0->racket (-< (esc (arg n)) ...))]))

  (define (block-parser stx)
    (syntax-parse stx
      [(_ n:number ...)
       #'(qi0->racket (~> (esc (except-args n ...))
                          △))]))

  (define (group-parser stx)
    (syntax-parse stx
      [(_ n:expr
          selection-onex:clause
          remainder-onex:clause)
       #'(loom-compose (qi0->racket selection-onex)
                       (qi0->racket remainder-onex)
                       n)]
      [_:id
       #'(λ (n selection-flo remainder-flo . vs)
           (apply (qi0->racket (group n
                                      (esc selection-flo)
                                      (esc remainder-flo))) vs))]))

  (define (sieve-parser stx)
    (syntax-parse stx
      [(_ condition:clause
          sonex:clause
          ronex:clause)
       #'(qi0->racket (-< (~> (pass condition) sonex)
                          (~> (pass (not condition)) ronex)))]
      [_:id
       ;; sieve can be a core form once bindings
       ;; are introduced into the language
       #'(λ (condition sonex ronex . args)
           (apply (qi0->racket (-< (~> (pass (esc condition)) (esc sonex))
                                   (~> (pass (not (esc condition))) (esc ronex))))
                  args))]))

  (define (partition-parser stx)
    (syntax-parse stx
      [(_:id)
       #'(qi0->racket ground)]
      [(_ [cond:clause body:clause])
       #'(qi0->racket (~> (pass cond) body))]
      [(_ [cond:clause body:clause]  ...+)
       #:with c+bs #'(list (cons (qi0->racket cond) (qi0->racket body)) ...)
       #'(qi0->racket (#%blanket-template (partition-values c+bs __)))]))

  (define (try-parser stx)
    (syntax-parse stx
      [(_ flo
          [error-condition-flo error-handler-flo]
          ...+)
       #'(λ args
           (with-handlers ([(qi0->racket error-condition-flo)
                            (λ (e)
                              ;; TODO: may be good to support reference to the
                              ;; error via a binding / syntax parameter
                              (apply (qi0->racket error-handler-flo) args))]
                           ...)
             (apply (qi0->racket flo) args)))]))

  (define (if-parser stx)
    (syntax-parse stx
      [(_ consequent:clause
          alternative:clause)
       #'(λ (f . args)
           (if (apply f args)
               (apply (qi0->racket consequent) args)
               (apply (qi0->racket alternative) args)))]
      [(_ condition:clause
          consequent:clause
          alternative:clause)
       #'(λ args
           (if (apply (qi0->racket condition) args)
               (apply (qi0->racket consequent) args)
               (apply (qi0->racket alternative) args)))]))

  (define (fanout-parser stx)
    (syntax-parse stx
      [_:id #'repeat-values]
      [(_ n:number)
       ;; a slightly more efficient compile-time implementation
       ;; for literally indicated N
       ;; TODO: implement this as an optimization instead
       #`(λ args
           (apply values
                  (append #,@(make-list (syntax->datum #'n) #'args))) )]
      [(_ n:expr)
       #'(lambda args
           (apply values
                  (apply append
                         (make-list n args))))]))

  (define (feedback-parser stx)
    (syntax-parse stx
      [(_ ((~datum while) tilex:clause)
          ((~datum then) thenex:clause)
          onex:clause)
       #'(feedback-while (qi0->racket onex)
                         (qi0->racket tilex)
                         (qi0->racket thenex))]
      [(_ ((~datum while) tilex:clause)
          ((~datum then) thenex:clause))
       #'(λ (f . args)
           (apply (qi0->racket (feedback (while tilex) (then thenex) (esc f)))
                  args))]
      [(_ ((~datum while) tilex:clause) onex:clause)
       #'(qi0->racket (feedback (while tilex) (then _) onex))]
      [(_ ((~datum while) tilex:clause))
       #'(qi0->racket (feedback (while tilex) (then _)))]
      [(_ n:expr
          ((~datum then) thenex:clause)
          onex:clause)
       #'(lambda args
           (apply (feedback-times (qi0->racket onex) n (qi0->racket thenex))
                  args))]
      [(_ n:expr
          ((~datum then) thenex:clause))
       #'(λ (f . args)
           (apply (qi0->racket (feedback n (then thenex) (esc f))) args))]
      [(_ n:expr onex:clause)
       #'(qi0->racket (feedback n (then _) onex))]
      [(_ onex:clause)
       #'(λ (n . args)
           (apply (qi0->racket (feedback n onex)) args))]
      [_:id
       #'(λ (n flo . args)
           (apply (qi0->racket (feedback n (esc flo)))
                  args))]))

  (define (tee-parser stx)
    (syntax-parse stx
      [((~or* (~datum -<) (~datum tee)) onex:clause ...)
       #'(λ args
           (apply values
                  (append (values->list
                           (apply (qi0->racket onex) args))
                          ...)))]
      [(~or* (~datum -<) (~datum tee))
       #'repeat-values]))

  (define (relay-parser stx)
    (syntax-parse stx
      [((~or* (~datum ==) (~datum relay)) onex:clause ...)
       #'(relay (qi0->racket onex) ...)]
      [(~or* (~datum ==) (~datum relay))
       ;; review this – this "map" behavior may not be natural
       ;; for relay. And map-values should probably end up being
       ;; used in a compiler optimization
       #'map-values]))

  (define (amp-parser stx)
    (syntax-parse stx
      [_:id
       #'(qi0->racket ==)]
      [(_ onex:clause)
       #'(curry map-values (qi0->racket onex))]))

  (define (pass-parser stx)
    (syntax-parse stx
      [_:id
       #'filter-values]
      [(_ onex:clause)
       #'(λ args
           (apply filter-values
                  (qi0->racket onex)
                  args))]))

  (define (fold-left-parser stx)
    (syntax-parse stx
      [_:id
       #'foldl-values]
      [(_ fn init)
       #'(qi0->racket (~> (-< (gen (qi0->racket fn)
                                   (qi0->racket init))
                              _)
                          >>))]
      [(_ fn)
       #'(qi0->racket (>> fn (gen ((qi0->racket fn)))))]))

  (define (fold-right-parser stx)
    (syntax-parse stx
      [_:id
       #'foldr-values]
      [(_ fn init)
       #'(qi0->racket (~> (-< (gen (qi0->racket fn)
                                   (qi0->racket init))
                              _)
                          <<))]
      [(_ fn)
       #'(qi0->racket (<< fn (gen ((qi0->racket fn)))))]))

  (define (loop-parser stx)
    (syntax-parse stx
      [(_ pred:clause mapex:clause combex:clause retex:clause)
       #'(letrec ([loop (qi0->racket (if pred
                                         (~> (group 1 mapex (esc loop))
                                             combex)
                                         retex))])
           loop)]
      [(_ pred:clause mapex:clause combex:clause)
       #'(qi0->racket (loop pred mapex combex ⏚))]
      [(_ pred:clause mapex:clause)
       #'(qi0->racket (loop pred mapex _ ⏚))]
      [(_ mapex:clause)
       #'(qi0->racket (loop (gen #t) mapex _ ⏚))]
      [_:id #'(λ (predf mapf combf retf . args)
                (apply (qi0->racket (loop (esc predf)
                                          (esc mapf)
                                          (esc combf)
                                          (esc retf)))
                       args))]))

  (define (clos-parser stx)
    (syntax-parse stx
      [_:id
       #:do [(define chirality (syntax-property stx 'chirality))]
       (if (and chirality (eq? chirality 'right))
           #'(λ (f . args) (apply curryr f args))
           #'(λ (f . args) (apply curry f args)))]
      [(_ onex:clause)
       #:do [(define chirality (syntax-property stx 'chirality))]
       (if (and chirality (eq? chirality 'right))
           #'(λ args
               (qi0->racket (~> (-< _ (~> (gen args) △))
                                onex)))
           #'(λ args
               (qi0->racket (~> (-< (~> (gen args) △) _)
                                onex))))]))

  (define (deforestable-clause-parser c)
    (syntax-parse c
      [((~datum floe) e) #'(qi0->racket e)]
      [((~datum expr) e) #'e]))

  (define (deforestable-parser e)
    (syntax-parse e
      #:datum-literals (#%deforestable)
      [(#%deforestable _name info c ...)
       (let ([es^ (map deforestable-clause-parser (attribute c))])
         (match-let ([(deforestable-info codegen) (syntax-local-value #'info)])
           (apply codegen es^)))]))

  (define (blanket-template-form-parser stx)
    (syntax-parse stx
      ;; "prarg" = "pre-supplied argument"
      ;; Note: use of currying here doesn't play well with bindings
      ;; because curry / curryr immediately evaluate their arguments
      ;; and resolve any references to bindings at compile time.
      ;; That's why we use a lambda which delays evaluation until runtime
      ;; when the reference is actually resolvable. See "anaphoric references"
      ;; in the compiler meeting notes,
      ;; "The Artist Formerly Known as Bindingspec"
      [((~datum #%blanket-template)
        (natex prarg-pre ...+ (~datum __) prarg-post ...+))
       ;; "(curry (curryr ...) ...)"
       #'(lambda largs
           (apply
            (lambda rargs
              ((kw-helper natex rargs) prarg-post ...))
            prarg-pre ...
            largs))]
      [((~datum #%blanket-template) (natex prarg-pre ...+ (~datum __)))
       ;; "curry"
       #'(lambda args
           (apply natex prarg-pre ... args))]
      [((~datum #%blanket-template)
        (natex (~datum __) prarg-post ...+))
       ;; "curryr"
       #'(lambda args
           ((kw-helper natex args) prarg-post ...))])))
