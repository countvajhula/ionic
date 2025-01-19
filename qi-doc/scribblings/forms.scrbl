#lang scribble/doc
@require[scribble/manual
         scribble-abbrevs/manual
         scribble/example
         metapict ; technically only used dynamically, but adding here for info deps
         "eval.rkt"
         @for-label[(only-space-in qi qi)
                    racket]]

@(define eval-for-docs (make-eval-for-docs))
@(define diagram-eval (make-base-eval))
@(diagram-eval '(require metapict))
@;{For an explanation of the special handling of `__` in code blocks and in examples, see racket/scribble#369}
@(define my-__ @racketidfont{__})

@title[#:tag "Qi_Forms"]{The Qi Language}

The syntax and semantics of the Qi language. Qi @tech{flows} may be described using these forms and @seclink["Embedding_a_Hosted_Language"]{embedded} into Racket using the @seclink["Language_Interface"]{language interface}.

@table-of-contents[]

@section{Syntax}

The syntax of a language is most economically and clearly expressed using a grammar, in the form of "nonterminal" symbols along with production rules expressing the syntax that is entailed in positions marked by those symbols. We may thus take the single starting symbol in such a grammar to formally designate the entire syntax of the language.

The symbol @racket[expr] is typically used in this sense to indicate a Racket nonterminal position in the syntax, i.e., a position that expects a Racket expression. Analogously, we use the identifier @deftech{@racket[floe]} (pronounced "flow-e," for "flow expression") to refer to the Qi nonterminal, i.e., a position expecting Qi syntax.

@tech{floe} is not to be confused with @tech{flow}. The relationship between the two is one of syntax and semantics, that is, the meaning of a @tech{floe} is a @tech{flow}.

The full surface syntax of Qi is given below. Note that this expands to a @seclink["The_Qi_Core_Language"]{smaller core language} before being @seclink["It_s_Languages_All_the_Way_Down"]{compiled to Racket}. It does not include the @seclink["List_Operations"]{list-oriented forms}, which may be added via @racket[(require qi/list)].

@racketgrammar*[
[floe @#,seclink["The_Qi_Core_Language"]{core-form}
      macro-form]
[macro-form △
            ▽
            (one-of? expr ...)
            (and% floe ...)
            (or% floe ...)
            AND
            &
            OR
            ∥
            !
            NOR
            NAND
            XNOR
            any?
            all?
            none?
            inverter
            ⏚
            (~> floe ...)
            (~>> floe ...)
            (thread-right floe ...)
            X
            crossover
            ==
            (== floe ...)
            (==* floe ...)
            (relay* floe ...)
            -<
            (-< floe ...)
            count
            1>
            2>
            3>
            4>
            5>
            6>
            7>
            8>
            9>
            (bundle (index ...) floe floe)
            (when floe floe)
            (unless floe floe)
            switch
            (switch switch-expr ...)
            (switch (% floe) switch-expr ...)
            (switch (divert floe) switch-expr ...)
            (gate floe)
            ><
            (>< floe)
            (ε floe floe)
            (effect floe floe)
            apply
            (expr expr ... __ expr ...)
            (expr expr ... _ expr ...)
            (expr expr ...)
            literal
            identifier]
[literal boolean
         char
         string
         bytes
         number
         regexp
         byte-regexp
         vector-literal
         box-literal
         prefab-literal
         (@#,racket[quote] value)
         (@#,racket[quasiquote] value)
         (@#,racket[quote-syntax] value)
         (@#,racket[syntax] value)]
[expr a-racket-expression]
[index exact-positive-integer?]
[nat exact-nonnegative-integer?]
[switch-expr [floe floe]
             [floe (=> floe)]
             [else floe]]
[identifier a-racket-identifier]
[value a-racket-value]]

@section{Basic}

@defidform[_]{
  The symbol @racket[_] means different things depending on the context, but when used on its own, it is the identity flow or trivial transformation, where the outputs are the same as the inputs. It is equivalent to Racket's @racket[values].

@examples[
    #:eval eval-for-docs
    ((☯ _) 3)
    ((☯ _) 1 2)
    ((☯ (-< _ _)) 3)
  ]
}

@defform[(gen expr ...)]{
  A @tech{flow} that generates the @emph{values} of the provided Racket expressions @racket[expr], ignoring any input values provided to it at runtime. This is the most common way to translate an ordinary value into a flow.

  Note that @seclink["Literals"]{literals} are transparently wrapped with @racket[gen] during @tech/reference{expansion} and don't need to be explicitly wrapped.

  @racket[gen] generalizes @racket[const] in the same way that @racket[values] generalizes @racket[identity].

  Also see @secref["Using_Racket_Values_in_Qi_Flows"].

@examples[
    #:eval eval-for-docs
    ((☯ (gen 1)) 3)
    ((☯ (gen (string-append "hello" " " "there")))
     3 4 5)
    ((☯ (gen 1 2)) 3)
  ]
}

@deftogether[(
  @defidform[△]
  @defidform[sep]
  @defform[#:link-target? #f
           (△ flo)]
  @defform[#:link-target? #f
           (sep flo)]
)]{
  Separate the input list into its component values. This is the inverse of @racket[▽].

  When used in parametrized form with a presupplied @racket[flo], this @tech{flow} accepts any number of inputs, where the first is expected to be the list to be unraveled. In this form, the flow separates the list into its component values and passes each through @racket[flo] along with the remaining input values.

  @racket[△] and @racket[▽] often allow you to use functions directly where you might otherwise need to use an indirection like @racket[apply] or @racket[list].

@examples[
    #:eval eval-for-docs
    ((☯ (~> △ +)) (list 1 2 3 4))
    ((☯ (~> △ (>< sqr) ▽)) (list 1 2 3 4))
    ((☯ (~> (△ +) ▽)) (list 1 2 3) 10)
    (struct kitten (name age) #:transparent)
    ((☯ (~> (△ kitten) ▽))
     (list "Ferdinand" "Imp" "Zacky") 0)
  ]
}

@deftogether[(
  @defidform[▽]
  @defidform[collect]
)]{
  Collect the input values into a list. This is the inverse of @racket[△].

  @racket[△] and @racket[▽] often allow you to use functions directly where you might otherwise need to use an indirection like @racket[apply] or @racket[list].

@examples[
    #:eval eval-for-docs
    ((☯ (~> ▽ (string-join ""))) "a" "b" "c")
    ((☯ (~> △ (>< sqr) ▽)) (list 1 2 3 4))
  ]
}

@defform[(esc expr)]{
  Escape to the host language to evaluate @racket[expr] which is expected to yield a @tech{flow}. @racket[(☯ (esc (☯ expr)))] is equivalent to @racket[(☯ expr)].

  Also see @secref["Using_Racket_to_Define_Flows"].

@examples[
    #:eval eval-for-docs
    ((☯ (esc (λ (x) (+ 2 x)))) 3)
  ]
}

@deftogether[(
  @defform[(lambda expr ...)]
  @defform[(λ expr ...)]
)]{
  Shorthand for @racket[(esc (lambda ...))].

That is, this lambda is a @emph{Qi} form that expands to a use of @emph{Racket}'s lambda form, providing a shorthand for a common way to describe a flow using Racket.

@examples[
    #:eval eval-for-docs
    ((☯ (λ (x) (+ 2 x))) 3)
  ]
}

@defform[(clos flo)]{
  A @tech{flow} that generates a flow as a value. Any inputs to the @racket[clos] flow are available to @racket[flo] when it is applied to inputs, i.e. it is analogous to a @hyperlink["https://www.gnu.org/software/guile/manual/html_node/Closure.html"]{closure} in Racket.

  We typically describe flows using Qi, while @racket[esc] allows us to describe a flow using the host language. In either case, the flow simply @emph{operates} on runtime inputs. In some cases, though, we need to generate a flow as a @emph{value} to be used later, for instance, when the flow is parametrized by inputs not available until runtime. @racket[clos] allows us to define and produce such a flow using Qi.

  Without @racket[clos], we could still accomplish this by using @racket[esc] and producing a function value (i.e. a @racket[lambda]) as the result of the function we define -- but this would mean that we must employ the host language to describe the flow rather than Qi.

  When used within a threading form (i.e. @racket[~>] or @racket[~>>]), @racket[clos] incorporates the pre-supplied input in accordance with the threading direction at the site of its definition.

  See @secref["Converting_a_Function_to_a_Closure"] in the field guide for more tips on using closures.

@examples[
    #:eval eval-for-docs
    ((☯ (~> (-< (~> first (clos *)) rest) map)) (list 5 4 3 2 1))
    (~> ("a" (list "b" "c" "d")) (== (clos string-append) _) map)
    (~> ("a" (list "b" "c" "d")) (== (~>> (clos string-append)) _) map)
  ]
}

@section{Predicates}

@defform[(one-of? expr ...)]{
  Is the input one of the indicated values?

@examples[
    #:eval eval-for-docs
    ((☯ (one-of? 'a 'b 'c)) 'b)
  ]
}

@defform[(all flo)]{
  Do @emph{all} of the inputs satisfy the predicate @racket[flo]?

@examples[
    #:eval eval-for-docs
    ((☯ (all positive?)) 1 2 3)
    ((☯ (all positive?)) 1 -2 3)
  ]
}

@defform[(any flo)]{
  Do @emph{any} of the inputs satisfy the predicate @racket[flo]?

@examples[
    #:eval eval-for-docs
    ((☯ (any positive?)) -1 2 -3)
    ((☯ (any positive?)) -1 -2 -3)
  ]
}

@defform[(none flo)]{
  Output true if @emph{none} of the inputs satisfy the predicate @racket[flo].

@examples[
    #:eval eval-for-docs
    ((☯ (none positive?)) -1 2 -3)
    ((☯ (none positive?)) -1 -2 -3)
  ]
}

@defform[(and flo ...)]{
  Output true if the inputs, when considered together, satisfy each of the @racket[flo] predicates.

@examples[
    #:eval eval-for-docs
    ((☯ (and positive? odd?)) 9)
    ((☯ (and (all odd?) <)) 3 7 11)
  ]
}

@defform[(or flo ...)]{
  Output true if the inputs, when considered together, satisfy any of the @racket[flo] predicates.

@examples[
    #:eval eval-for-docs
    ((☯ (or positive? odd?)) 8)
    ((☯ (or (all odd?) <)) 3 8 12)
  ]
}

@defform[(not flo)]{
  Output true if the inputs, when considered together, do @emph{not} satisfy the predicate @racket[flo].

@examples[
    #:eval eval-for-docs
    ((☯ (not positive?)) -9)
    ((☯ (not <)) 8 3 12)
  ]
}

@defform[(and% flo ...)]{
  Output true if the inputs, when considered independently or "in parallel," satisfy each of the respective @racket[flo] predicates. Equivalent to @racket[(~> (== flo ...) AND)], except that the identifier @racket[_] when used in the present form indicates that you "don't care" about the corresponding input in determining the result (whereas it ordinarily indicates the identity transformation).

@examples[
    #:eval eval-for-docs
    ((☯ (and% positive? negative?)) 3 -9)
    ((☯ (and% positive? negative?)) -3 -9)
  ]
}

@defform[(or% flo ...)]{
  Output true if @emph{any} of the inputs, when considered independently or "in parallel," satisfies its corresponding @racket[flo] predicate. Equivalent to @racket[(~> (== flo ...) OR)], except that the identifier @racket[_] when used in the present form indicates that you "don't care" about the corresponding input in determining the result (whereas it ordinarily indicates the identity transformation).

@examples[
    #:eval eval-for-docs
    ((☯ (or% positive? negative?)) -3 -9)
    ((☯ (or% positive? negative?)) -3 9)
  ]
}

@section{Boolean Algebra}

@deftogether[(
  @defidform[NOT]
  @defidform[!]
)]{
  A Boolean NOT gate, this negates the input. This is equivalent to Racket's @racket[not].

@examples[
    #:eval eval-for-docs
    ((☯ NOT) #t)
    ((☯ NOT) #f)
  ]
}

@deftogether[(
  @defidform[AND]
  @defidform[&]
)]{
  A Boolean AND gate, this outputs the conjunction of the inputs.

@examples[
    #:eval eval-for-docs
    ((☯ AND) #t #t #t)
    ((☯ AND) #t #f #t)
  ]
}

@deftogether[(
  @defidform[OR]
  @defidform[∥]
)]{
  A Boolean OR gate, this outputs the disjunction of the inputs.

Note that the symbol form uses Unicode @code{0x2225} corresponding to LaTeX's @code{\parallel}. We do not use the easier-to-type @racket[||] symbol (that was formerly used here in older versions of Qi) as that is treated as the @seclink["default-readtable-dispatch" #:doc '(lib "scribblings/reference/reference.scrbl")]{empty symbol} by Racket's reader, which could cause problems in some cases.

@examples[
    #:eval eval-for-docs
    ((☯ OR) #t #f #t)
    ((☯ OR) #f #f #f)
  ]
}

@deftogether[(
  @defidform[NOR]
  @defidform[NAND]
  @defidform[XOR]
  @defidform[XNOR]
)]{
  @tech{Flows} corresponding to the identically-named Boolean gates.
}

@deftogether[(
  @defidform[any?]
  @defidform[all?]
  @defidform[none?]
)]{
  Output true if any, all, or none (respectively) of the inputs are truthy.

@examples[
    #:eval eval-for-docs
    ((☯ any?) #t #f #t)
    ((☯ any?) #f #f #f)
    ((☯ all?) #t #t #t)
    ((☯ all?) #t #f #t)
    ((☯ none?) #f #t #f)
    ((☯ none?) #f #f #f)
  ]
}

@defidform[inverter]{
  Negate each input in parallel. Equivalent to @racket[(>< NOT)].

@examples[
    #:eval eval-for-docs
    ((☯ inverter) #f #t #f)
  ]
}

@section{Routing}

@deftogether[(
  @defidform[⏚]
  @defidform[ground]
)]{
  Extinguish the input values, yielding no output at all.

@examples[
    #:eval eval-for-docs
    ((☯ ⏚) 1 2 3)
  ]
}

@deftogether[(
@defform[#:link-target? #f
         (~> flo ...)]
@defform[#:link-target? #f
         (~>> flo ...)]
)]{
  Compose @tech{flows} in sequence, from left to right. In the metaphor of an analog electrical circuit, you could think of this as a wire.

  @racket[~>] "threads" the arguments in the leading position, while @racket[~>>] threads them in the trailing position. Argument positions may also be explicitly indicated via a @seclink["Templates_and_Partial_Application"]{template}, either individually or en masse.

@examples[
    #:eval eval-for-docs
    ((☯ (~> + sqr)) 1 2 3)
    ((☯ (~>> (string-append "a" "b"))) "c" "d")
  ]
}

@deftogether[(
@defidform[X]
@defidform[crossover]
)]{
  Invert the order of the inputs, so that the last output is the first input, the second-to-last output is the second input, and so on.

@examples[
    #:eval eval-for-docs
    ((☯ X) 1 2 3)
    ((☯ (~> X string-append)) "a" "b" "c")
  ]
}

@deftogether[(
@defform[(== flo ...)]
@defform[(relay flo ...)]
@defidform[#:link-target? #f ==]
@defidform[#:link-target? #f relay]
)]{
  Compose @tech{flows} in parallel, so that inputs are passed through the corresponding @racket[flo]'s individually. The number of @racket[flo]s must be the same as the number of runtime inputs.

  In the common case of @code{1 × 1} @racket[flo]s (i.e. where the flows each accept one input and produce one output), the number of outputs will be the same as the number of inputs, but as @seclink["What_is_a_Flow_"]{flows can be nonlinear}, this is not necessarily the case in general.

  When used in identifier form simply as @racket[==], it behaves identically to @racket[><].

  See also the field guide entry on the @seclink["Bindings_are_an_Alternative_to_Nonlinearity"]{relationship between bindings and nonlinearity}.

@examples[
    #:eval eval-for-docs
    ((☯ (== add1 sub1)) 1 2)
  ]
}

@deftogether[(
@defform[(==* flo ...)]
@defform[(relay* flo ...)]
)]{
  Similar to @racket[==] and analogous to @racket[list*], this passes each input through the corresponding @racket[flo] individually, until it encounters the last @racket[flo]. This last one receives all of the remaining inputs.

@examples[
    #:eval eval-for-docs
    ((☯ (==* add1 sub1 +)) 1 1 1 1 1)
  ]
}

@deftogether[(
@defform[(-< flo ...)]
@defform[(tee flo ...)]
)]{
  A "tee" junction, this forks the input values into multiple copies, each set of which is passed through a @racket[flo] "in parallel." Equivalent to @racket[(☯ (~> (fanout N) (== flo ...)))], where @racket[N] is the number of @racket[flo]'s.

@examples[
    #:eval eval-for-docs
    ((☯ (-< add1 sub1)) 3)
    ((☯ (-< + *)) 3 5)
  ]
}

@deftogether[(
@defidform[fanout]
@defform[#:link-target? #f
         (fanout N)]
)]{
  Split the inputs into @racket[N] copies of themselves.

  When used in identifier form simply as @racket[fanout], it treats the first input as @racket[N], and the remaining inputs as the values to be fanned out.

@examples[
    #:eval eval-for-docs
    ((☯ (fanout 3)) 5)
    ((☯ (fanout 2)) 3 7)
    (~> (3 "hello?") fanout)
  ]
}

@deftogether[(
  @defidform[1>]
  @defidform[2>]
  @defidform[3>]
  @defidform[4>]
  @defidform[5>]
  @defidform[6>]
  @defidform[7>]
  @defidform[8>]
  @defidform[9>]
)]{
  Aliases for inputs, by index. Equivalent to @racket[(select N)], for index @racket[N]. If you need to select more than one input, use @racket[select] directly.

@examples[
    #:eval eval-for-docs
    ((☯ 4>) 'a 'b 'c 'd 'e 'f)
  ]
}

@deftogether[(
@defform[(select index ...)]
@defform[(block index ...)]
)]{
  Select or block inputs by index, outputting the selection or remainder, respectively. @racket[index] is @emph{1-indexed}, that is, for instance, in order to select the first and the third input, we would use @racket[(select 1 3)].

@examples[
    #:eval eval-for-docs
    ((☯ (select 1 4)) 'a 'b 'c 'd 'e 'f)
    ((☯ (block 1 2 4 6)) 'a 'b 'c 'd 'e 'f)
  ]
}

@defform[(bundle (index ...) selection-flo remainder-flo)]{
  Divide the set of inputs into two groups or "bundles" based on provided @emph{indexes}, passing the selection to @racket[selection-flo] and the remainder to @racket[remainder-flo].

@examples[
    #:eval eval-for-docs
    ((☯ (bundle (1 3) + *)) 1 2 3 4 5)
  ]
}

@deftogether[(
@defidform[group]
@defform[#:link-target? #f
         (group number selection-flo remainder-flo)]
)]{
  Divide the set of inputs into two groups @emph{by number}, passing the first @racket[number] inputs to @racket[selection-flo] and the remainder to @racket[remainder-flo].

  In the context of a @racket[loop], this is a typical way to do "structural recursion" on flows (see @seclink["Phrases"]{"pare"}), and in this respect it is the values analogue to @racket[car] and @racket[cdr] for lists.

  When used in identifier form simply as @racket[group], it treats the first three inputs as @racket[number], @racket[selection-flo] and @racket[remainder-flo], respectively, and the remaining as the data inputs to be acted upon.

@examples[
    #:eval eval-for-docs
    ((☯ (group 2 + *)) 1 2 3 4 5)
  ]
}

@deftogether[(
@defidform[sieve]
@defform[#:link-target? #f
         (sieve condition-flo selection-flo remainder-flo)]
)]{
  Divide the set of inputs into two groups @emph{by condition}, passing the inputs that satisfy @racket[condition-flo] (individually) to @racket[selection-flo] and the remainder to @racket[remainder-flo].

 When used in identifier form simply as @racket[sieve], it treats the first three inputs as @racket[condition-flo], @racket[selection-flo] and @racket[remainder-flo], respectively, and the remaining as the data inputs to be acted upon.

@examples[
    #:eval eval-for-docs
    ((☯ (sieve positive? max min)) 1 -2 3 -4 5)
  ]
}

@defform[(partition [condition-flo body-flo] ...)]{
A form of generalized @racket[sieve], passing all the inputs that satisfy each
@racket[condition-flo] to the corresponding @racket[body-flo].

@examples[
          #:eval eval-for-docs
          ((☯ (partition)))
          ((☯ (partition [positive? max])) 1 -2 3 -4 5)
          ((☯ (partition [positive? max]
                         [negative? min]))
              1 -2 3 -4 5)
          ((☯ (partition [positive? max]
                         [negative? min]))
              1 -2 3 -4 5)
          ((☯ (partition [positive? max]
                         [zero? (-< count (gen "zero"))]
                         [negative? min]))
              1 -2 3 -4 5)
          ((☯ (partition [(and positive? (> 1)) max]))
              1 -2 3 -4 5)
          ]
}

@section{Conditionals}

@deftogether[(
  @defform[(if condition-flo consequent-flo alternative-flo)]
  @defform[(when condition-flo consequent-flo)]
  @defform[(unless condition-flo alternative-flo)]
)]{
  The @tech{flow} analogue of @racket[if], this is the basic conditional, passing the inputs through either @racket[consequent-flo] or @racket[alternative-flo], depending on whether they satisfy @racket[condition-flo].

  @racket[when] is shorthand for @racket[(if condition-flo consequent-flo ⏚)] and @racket[unless] is shorthand for @racket[(if condition-flo ⏚ alternative-flo)].

@examples[
    #:eval eval-for-docs
    ((☯ (if positive? add1 sub1)) 3)
    ((☯ (when positive? add1)) 3)
    ((☯ (unless positive? add1)) 3)
  ]
}

@defform*/subs[#:link-target? #f
               [(switch maybe-divert-expr switch-expr ...)]
                ([maybe-divert-expr (divert condition-gate-flow consequent-gate-flow)
                                    (% condition-gate-flow consequent-gate-flow)]
                 [switch-expr [floe floe]
                              [floe (=> floe)]
                              [else floe]])]{
  The @tech{flow} analogue of @racket[cond], this is a dispatcher where the condition and consequent expressions are all flows which operate on the switch inputs.

  Typically, each of the component flows -- conditions and consequents both -- receives all of the original inputs to the @racket[switch]. This can be changed by using a @racket[divert] clause, which takes two flow arguments, the first of whose outputs go to all of the condition flows, and the second of whose outputs go to all of the consequent flows. This can be useful in cases where multiple values flow, but only some of them are predicated upon, and others (or all of them) inform the actions to be taken. Using @racket[(divert _ _)] is equivalent to not using it. @racket[%] is a symbolic alias for @racket[divert] -- parse it visually not as the percentage sign, but as a convenient way to depict a "floodgate" diverting values down different channels.

  When the @racket[=>] form is used in a consequent flow, the consequent receives @emph{N + 1} inputs, where the first input is the result of the predicate flow, and the remaining @racket[N] inputs are the a priori inputs to the consequent flow (which are typically the original inputs to the switch, unless modulated with a @racket[divert] clause). This form is analogous to the @racket[=>] symbol when used in a @racket[cond]. Note that while switch can direct any number of values, we can unambiguously channel the result of the predicate to the first input of the consequent here because it is guaranteed to be a single value (otherwise it wouldn't be a predicate).

  If none of the conditions are met, this flow produces @emph{the input values}, unchanged, except if a @racket[divert] clause is specified, in which case it produces the input values transformed under @racket[consequent-gate-flow]. If you need a specific value such as @racket[(void)] or would prefer to output no values, indicate this explicitly via e.g. @racket[[else void]] or @racket[[else ⏚]].

@examples[
    #:eval eval-for-docs
    ((☯ (switch [positive? add1]
                [else sub1]))
     3)
    ((☯ (switch [(member (list 1 2 3)) (=> 1> (map - _))]
                [else 'not-found]))
     2)
    ((☯ (switch (% 1> _)
          [number? cons]
          [list? append]
          [else 2>]))
     (list 3)
     (list 1 2))
  ]
}

@defform[(gate condition-flo)]{
  Allow the inputs through unchanged if they satisfy @racket[condition-flo], otherwise, @racket[ground] them so that there is no output.

@examples[
    #:eval eval-for-docs
    ((☯ (gate <)) 3 5)
    ((☯ (gate <)) 5 1)
  ]
}

@section{Loops}

@deftogether[(
  @defform[(loop condition-flo map-flo combine-flo return-flo)]
  @defform[#:link-target? #f
           (loop condition-flo map-flo combine-flo)]
  @defform[#:link-target? #f
           (loop condition-flo map-flo)]
  @defform[#:link-target? #f
           (loop map-flo)]
  @defidform[#:link-target? #f loop]
)]{
  A simple loop for structural recursion on the input values, this applies @racket[map-flo] to the first input on each successive iteration and recurses on the remaining inputs, combining these using @racket[combine-flo] to yield the result as long as the inputs satisfy @racket[condition-flo]. When the inputs do not satisfy @racket[condition-flo], @racket[return-flo] is applied to the inputs to yield the result at that terminating step. If the condition is satisfied and there are no further values, the loop terminates naturally.

  If unspecified, @racket[condition-flo] defaults to @racket[#t], @racket[combine-flo] defaults to @racket[_], and @racket[return-flo] defaults to @racket[⏚].

  When used in identifier form simply as @racket[loop], this behaves the same as the fully qualified version, except that the flows parametrizing the loop are expected as the initial four inputs (in the same order), and the data inputs being acted upon are expected to follow.

@examples[
    #:eval eval-for-docs
    ((☯ (loop (* 2))) 1 2 3)
    ((☯ (loop #t _ +)) 1 2 3 4)
  ]
}

@defform[(loop2 condition-flo map-flo combine-flo)]{
  A "tail-recursive" looping form, this passes the result at each step as a flow input to the next, alongside the inputs to the subsequent step, simply evaluating to the result flow on the last step.

@examples[
    #:eval eval-for-docs
    ((☯ (loop2 (~> 1> (not null?))
               sqr
               cons))
     (list 1 2 3) null)
  ]
}

@deftogether[(
@defidform[feedback]
@defform[#:link-target? #f
         (feedback flo)]
@defform[#:link-target? #f
         (feedback N flo)]
@defform[#:link-target? #f
         (feedback N (then then-flo))]
@defform[#:link-target? #f
         (feedback N (then then-flo) flo)]
@defform[#:link-target? #f
         (feedback (while cond-flo))]
@defform[#:link-target? #f
         (feedback (while cond-flo) flo)]
@defform[#:link-target? #f
         (feedback (while cond-flo) (then then-flo))]
@defform[#:link-target? #f
         (feedback (while cond-flo) (then then-flo) flo)]
)]{
  Pass the inputs @racket[N] times through @racket[flo] by "feeding back" the outputs each time. If a @racket[while] clause is specified in place of a value, then the outputs are fed back as long as @racket[cond-flo] is true. If the optional @racket[then] form is specified, @racket[then-flo] will be invoked on the outputs at the end after the loop has completed.

  If used as @racket[(feedback flo)], the first input to the @racket[feedback] block will be expected to be @racket[N] and will not be "fed back" with the rest of the inputs. If @racket[flo] is not specified, then it will be expected as the first input, with the remaining inputs being treated as the inputs being acted upon. If used in identifier form simply as @racket[feedback], it treats the first two inputs as @racket[N] and @racket[flo], respectively, and both are expected. The remaining inputs are treated as the data inputs being acted upon.

  For practical advice on using @racket[feedback], see @secref["Effectively_Using_Feedback_Loops"] in the field guide.

@examples[
    #:eval eval-for-docs
    ((☯ (feedback 3 add1)) 5)
    ((☯ (feedback (while (< 50)) sqr)) 2)
  ]
}

@section{Exceptions}

@defform[(try flo [error-predicate-flo error-handler-flo] ...)]{
  A dispatcher for handling exceptions that works similarly to @racket[switch], this attempts @racket[flo] and simply produces its results if successful. Otherwise, if an exception is raised, the exception is provided to each of the @racket[error-predicate-flo]'s in turn, and for the first predicate that returns true, the corresponding @racket[error-handler-flo] is invoked with the input arguments.

@examples[
    #:eval eval-for-docs
    (~> (9) (try (/ 3) [exn:fail? 0]) add1)
    (~> (9)
        (try (/ 0)
          [exn:fail:contract:arity? 0]
          [exn:fail:contract:divide-by-zero? _])
        add1)
  ]
}

@section{Higher-order Flows}

@deftogether[(
@defidform[><]
@defform[#:link-target? #f
         (>< flo)]
@defidform[amp]
@defform[#:link-target? #f
         (amp flo)]
)]{
  The @tech{flow} analogue to @racket[map], this maps each input individually under @racket[flo]. As flows may generate any number of output values, unlike @racket[map], the number of outputs need not equal the number of inputs here.

  If used in identifier form simply as @racket[><], it treats the first input as @racket[flo].

@examples[
    #:eval eval-for-docs
    ((☯ (>< sqr)) 1 2 3)
    ((☯ ><) sqr 1 2 3)
    ((☯ (>< (-< _ _))) 1 2 3)
  ]
}

@deftogether[(
@defidform[pass]
@defform[#:link-target? #f
         (pass condition-flo)]
)]{
  The @tech{flow} analogue to @racket[filter], this filters the input values individually under @racket[condition-flo], yielding only those values that satisfy it.

  If used in identifier form simply as @racket[pass], it treats the first input as @racket[condition-flo] and the remaining inputs as the values to be filtered.

@examples[
    #:eval eval-for-docs
    ((☯ (pass positive?)) 1 -2 3)
    ((☯ pass) positive? 1 -2 3)
  ]
}

@deftogether[(
@defform[(<< flo init-flo)]
@defform[#:link-target? #f
         (<< flo)]
@defform[(>> flo init-flo)]
@defform[#:link-target? #f
         (>> flo)]
)]{
  The @tech{flow} analogues to @racket[foldr] and @racket[foldl] (respectively -- the side on which the symbols "fold" corresponds to the type of fold), these fold over input @emph{values} rather than an input list.

  @racket[flo] processes one input value at a time. It receives the current input value in the first position, followed by the accumulated values, and may generate any number of output values. These output values are fed back as accumulated values for the next iteration if input values remain to be processed; otherwise, they are produced as the output of the flow.

@examples[
    #:eval diagram-eval
    #:result-only
    (set-curve-pict-size 200 200)
    (current-label-gap (px 8))

    (define dim 100)

    (define-values (w h)
      (values dim dim))

    (define-values (box-w box-h)
      (values (/ w 3) (/ h 3)))

    (define box-width (* 1/3 dim))
    (define box-height (* 1/3 dim))

    (with-window (window (- (* 1/2 w))
                         (* 1/2 w)
                         (- (* 1/2 h))
                         (* 1/2 h))
      (draw (rectangle (pt (- (* 1/2 box-width)) (- (* 1/2 box-height)))
                       (pt (* 1/2 box-width) (* 1/2 box-height)))
            (label-cnt "flo" origo)
            ;; current value
            (curve (pt (- (* 2 1/2 box-width)) (* 1/5 1/2 box-height))
                   --
                   (pt (- (* 1/2 box-width)) (* 1/5 1/2 box-height)))
            (label-urt "v" (pt (- (* 2 1/2 box-width)) (* 1/5 1/2 box-height)))
            ;; accumulated values
            (curve (pt (- (* 2 1/2 box-width)) 0)
                   --
                   (pt (- (* 1/2 box-width)) 0))
            (label-bot "acc" (pt (- (* 2 1/2 box-width)) 0))
            ;; accumulated ...
            (curve (pt (- (* 1.3 1/2 box-width)) (* -1 1/10 1/2 box-height))
                   --
                   (pt (- (* 1/2 box-width)) (* -1 1/10 1/2 box-height)))
            (curve (pt (- (* 1.3 1/2 box-width)) (* -1 2/10 1/2 box-height))
                   --
                   (pt (- (* 1/2 box-width)) (* -1 2/10 1/2 box-height)))
            (curve (pt (- (* 1.3 1/2 box-width)) (* -1 3/10 1/2 box-height))
                   --
                   (pt (- (* 1/2 box-width)) (* -1 3/10 1/2 box-height)))
            ;; outputs
            (curve (pt (* 1/2 box-width) 0)
                   --
                   (pt (* 1.5 1/2 box-width) 0))
            (curve (pt (* 1/2 box-width) (* -1 1/10 1/2 box-height))
                   --
                   (pt (* 1.3 1/2 box-width) (* -1 1/10 1/2 box-height)))
            (curve (pt (* 1/2 box-width) (* -1 2/10 1/2 box-height))
                   --
                   (pt (* 1.3 1/2 box-width) (* -1 2/10 1/2 box-height)))
            (curve (pt (* 1/2 box-width) (* -1 3/10 1/2 box-height))
                   --
                   (pt (* 1.3 1/2 box-width) (* -1 3/10 1/2 box-height)))
            ;; feedback
            (curve (pt (* 1.5 1/2 box-width) 0)
                   --
                   (pt (* 1.5 1/2 box-width) (- (* 1.5 1/2 box-height)))
                   --
                   (pt (- (* 1.5 1/2 box-width)) (- (* 1.5 1/2 box-height)))
                   --
                   (pt (- (* 1.5 1/2 box-width)) 0))
            ;; final output
            (curve (pt (* 1.5 1/2 box-width) 0)
                   --
                   (pt (* 2 1/2 box-width) 0))
            (label-rt "out" (pt (* 2 1/2 box-width) 0))))
]

  @racket[init-flo] is expected to be a @emph{@tech{flow}} that will generate the initial values for the fold, and will be invoked with no inputs for this purpose at runtime. It is done this way to support having multiple initial values or no initial values, rather than specifically one. Specifying @racket[init-flo] is optional; if it isn't provided, @racket[flo] itself is invoked with no arguments to obtain the init value, to borrow a convention from the Clojure language.

@examples[
    #:eval eval-for-docs
    ((☯ (<< +)) 1 2 3 4)
    ((☯ (<< string-append)) "a" "b" "c" "d")
    ((☯ (>> string-append)) "a" "b" "c" "d")
    ((☯ (<< string-append "☯")) "a" "b" "c" "d")
    ((☯ (<< cons '())) 1 2 3 4)
    ((☯ (<< + (gen 2 3))) 1 2 3 4)
    ((☯ (>> (-< (block 1)
                (~> 1> (fanout 2)))
            ⏚)) 1 2 3)
  ]
}

@deftogether[(
  @defform[(ε side-effect-flo flo)]
  @defform[#:link-target? #f (ε side-effect-flo)]
  @defform[(effect side-effect-flo flo)]
  @defform[#:link-target? #f (effect side-effect-flo)]
)]{
  Pass the inputs through @racket[flo] but also independently to @racket[side-effect-flo]. The results of the latter, if any, are grounded, so they would have no effect on downstream flows, which would only receive the results of @racket[flo]. Equivalent to @racket[(-< (~> side-effect-flo ⏚) flo)].

  Use @racket[(ε side-effect-flo)] to just perform a side effect without modifying the input, equivalent to @racket[(-< (~> side-effect-flo ⏚) _)].

  Remember that, as the side-effect @tech{flow} is based on a tee junction, it must handle as many inputs as the main flow. For instance, if you were to use @racket[displayln] as the side-effect, it wouldn't work if more than one value were flowing, and you'd get an inscrutable error resembling:

@codeblock{
; displayln: contract violation
;   expected: output-port?
;   given: 1
;   argument position: 2nd
;   other arguments...:
;    1
}

  As @racket[displayln] expects a single input, you'd need to use @racket[(>< displayln)] for this side-effect in general.

  If you are interested in using @racket[effect] to debug a flow, see the section on @secref["Debugging" #:doc '(lib "qi/scribblings/qi.scrbl")] in the field guide for more strategies.

@examples[
    #:eval eval-for-docs
    ((☯ (~> (ε displayln sqr) add1)) 3)
    ((☯ (~> (ε (>< displayln) *) add1)) 3 5)
  ]
}

@defidform[apply]{
  Analogous to @racket[apply], this treats the first input as a @tech{flow} and passes the remaining inputs through it, producing the output that the input flow would produce if the argument flows were passed through it directly.

@examples[
    #:eval eval-for-docs
    ((☯ apply) + 1 2 3)
  ]
}

@section{Binding}

@defform[(as v ...)]{
  A @tech{flow} that binds an identifier @racket[v] to the input value. If there are many input values, than there should be as many identifiers as there are inputs. Aside from introducing bindings, this flow produces no output.

@examples[
    #:eval eval-for-docs
    ((☯ (~> (-< (~> list (as vs))
                +)
            (~a "The sum of " vs " is " _)))
     1 2)
    ((☯ (~> (-< + count)
            (as total number)
            (/ total number)))
     1 2 3 4 5)
 ]
}

@subsection{Variable Scope}

We will use @racket[(gen v)] as an example of a flow referencing a binding, to illustrate variable scope.

In general, bindings are scoped to the @emph{outermost} threading form, and may be referenced downstream.

@examples[
    #:eval eval-for-docs
    #:label #f
    (~> (5) (as v) (gen v))
    (~> (5) (-< (~> sqr (as v))
                _) (gen v))
]

A @racket[tee] junction binds downstream flows in a containing threading form, with later tines shadowing earlier tines.

@examples[
    #:eval eval-for-docs
    #:label #f
    (~> () (-< (~> 5 (as v))
               (~> 6 (as v))) (gen v))
]

A @racket[relay] binds downstream flows in a containing threading form, with later tines shadowing earlier tines.

@examples[
    #:eval eval-for-docs
    #:label #f
    (~> (5 6)
        (== (as v)
            (as v))
        (gen v))
]

In an @racket[if] conditional form, variables bound in the condition bind the consequent and alternative flows, and do not bind downstream flows.

@examples[
    #:eval eval-for-docs
    #:label #f
    (on ("Ferdinand")
      (if (-< (~> string-titlecase (as name))
              (string-suffix? "cat"))
          (gen name)
          (gen (~a name " the Cat"))))
]

Analogously, in a @racket[switch], variables bound in each condition bind the corresponding consequent flow.

@examples[
    #:eval eval-for-docs
    #:label #f
    (switch ("Ferdinand the cat")
      [(-< (~> string-titlecase (as name))
           (string-suffix? "cat")) (gen name)]
      [else "dog"])
]

As @racket[switch] compiles to @racket[if], technically, earlier conditions bind all later switch clauses (and are shadowed by them), but this is considered an incidental implementation detail. Like @racket[if], @racket[switch] bindings are unavailable downstream.

@section{Identifiers}

Identifiers in a flow context are interpreted as @tech/reference{variables} whose @tech/reference{values} are expected to be @seclink["lambda" #:doc '(lib "scribblings/guide/guide.scrbl")]{functions}. In other words, any named function may be used directly as a @tech{flow}.

More precisely, for instance, @racket[add1] in a flow context is equivalent to @racket[(esc add1)].

@examples[
    #:eval eval-for-docs
    ((☯ +) 1 2 3)
    ((☯ add1) 3)
  ]

@section{Literals}

Literals and quoted values (including syntax-quoted values) in a flow context are interpreted as @tech{flows} generating them. That is, for instance, @racket[5] in a flow context is equivalent to @racket[(gen 5)].

@examples[
    #:eval eval-for-docs
    ((☯ "hello") 1 2 3)
  ]

@section{Templates and Partial Application}

A parenthesized expression that isn't one of the Qi forms is treated as @emph{partial function application}, where the syntactically-indicated arguments are pre-supplied to yield a partially applied function that is applied to the input values at runtime.

Usually, the @racket[_] symbol indicates the trivial or identity flow, simply passing the inputs through unchanged. Within a partial application, however, the underscore indicates argument positions. If the expression includes a double underscore, @racket[___], then it is treated as a blanket template such that the runtime arguments (however many there may be) are passed starting at the position indicated by the placeholder. Another type of template is indicated by using one or more single underscores. In this case, a specific number of runtime arguments are expected (corresponding to the number of blanks indicated by underscores). Note that this could even include the function to be applied, if that position is templatized. This more fine-grained template is powered under the hood by @seclink["top" #:indirect? #t #:doc '(lib "fancy-app/main.scrbl")]{Fancy App: Scala-Style Magic Lambdas}.

@examples[
    #:eval eval-for-docs
    ((☯ (* 3)) 7)
    ((☯ (string-append "c")) "a" "b")
    ((☯ (string-append "a" _ "c")) "b")
    ((☯ (< 5 _ 10)) 7)
    ((☯ (< 5 _ 7 _ 10)) 6 9)
    ((☯ (< 5 _ 7 _ 10)) 6 11)
    ((☯ (~> (clos *) (_ 3))) 10)
    (eval:alts #, @racket[((☯ (< 5 #,my-__ 10)) 6 7 8)]  ((☯ (< 5 __ 10)) 6 7 8))
    (eval:alts #, @racket[((☯ (< 5 #,my-__ 10)) 6 7 11)]  ((☯ (< 5 __ 10)) 6 7 11))
  ]

@section{Utilities}

@defidform[count]{
  Analogous to @racket[length] for lists, but for values, this counts the values in the flow.

@examples[
    #:eval eval-for-docs
    ((☯ count) 5)
    ((☯ (~> (-< _ _ _) count)) 5)
  ]
}

@defidform[live?]{
  Check if there are any values flowing -- evaluates to @racket[true] if there are, and @racket[false] otherwise.

@examples[
    #:eval eval-for-docs
    ((☯ live?) 5)
    (~> (5) (-< _ _ _) live?)
    (~> (5) (-< _ _ _) ⏚ live?)
    (~> (8 "hello" 3 'boo 4) (pass number?) (if live? min #f))
    (~> ("hello" 'boo) (pass number?) (if live? min #f))
  ]
}

@defform[(rectify v ...)]{
  Check if the flow is @racket[live?], and if it isn't, then ensure that the values @racket[v ...] are produced. Equivalent to @racket[(if live? _ (gen v ...))].

  A @tech{flow} may sometimes produce @emph{no values}. In such cases, depending on how the output of the flow is used, it may be desirable to ensure that it returns some default value or values instead. @racket[rectify] produces the original output of the flow unchanged if there is any output, and otherwise outputs @racket[v ...].

@examples[
    #:eval eval-for-docs
    (~> (5) (rectify #f))
    (~> (5) ⏚ (rectify #f))
    (~> (8 "hello" 3 'boo 4) (pass number?) (rectify 0) min)
    (~> ("hello" 'boo) (pass number?) (rectify 0) min)
  ]
}

@section{Language Extension}

This way to extend the language is intended for use in @bold{legacy versions of Racket only}, that is, versions 8.2 or earlier. Qi now (as of Racket 8.3) offers "first class" macro extensibility where there is no need for the special prefix, "qi:". See @secref["Qi_Macros"] for more. Prefix-based macros (i.e. the kind discussed in the present section) should be considered @bold{deprecated} on versions 8.3 or later.

@defform[(qi:* expr ...)]{
  A form with a name starting with "qi:" is treated in a special way -- it is simply left alone during the macro expansion phase as far as Qi is concerned, as it is expected to be a macro written by a third party that will expand into a @emph{Racket} expression that is usable as a @tech{flow} (i.e. similar to the @racket[esc] form). That is, such a form must expand either to a flow specified using Qi and wrapped with @racket[☯], or to a @seclink["lambda" #:doc '(lib "scribblings/guide/guide.scrbl")]{lambda} containing arbitrary Racket code.

 This allows you to extend the Qi language locally without requiring changes to be made in the library itself.

@examples[
    #:eval eval-for-docs
    (define-syntax-rule (qi:square flo)
      (☯ (feedback 2 flo)))
    (~> (2 3) + (qi:square sqr))
  ]
}

@close-eval[eval-for-docs]
@(set! eval-for-docs #f)
@close-eval[diagram-eval]
@(set! diagram-eval #f)
