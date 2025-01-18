#lang scribble/doc
@require[scribble/manual
         scribble-abbrevs/manual
         scribble/example
         racket/sandbox
         @for-label[qi
                    racket]]

@title{When Should I Use Qi?}

Okay, so you've read @secref{Using_Qi} and understand at a high level that there are interface macros providing a bridge between Racket and Qi, which allow you to use Qi anywhere in your code, and you have some idea of how to write @tech{flows} (maybe you've gone through the @secref["Tutorial"]). Let's now look at a collection of examples that may help shed light on when you should use Qi vs Racket or another language.

@table-of-contents[]

@section{Hadouken!}

When you're interested in transforming values, Qi is often the right language to use.

@subsection{Super Smush Numbers}

Let's say we'd like to define a function that adds together all of the input numbers, except that instead of using usual addition, we want to just adjoin them ("smush them") together to create a bigger number as the result.

In Qi, we could express it this way:

@codeblock{
  (define-flow smush
    (~> (>< ->string)
        string-append
        ->number))
}

The equivalent in Racket would be:

@codeblock{
  (define (smush . vs)
    (->number
     (apply string-append
            (map ->string vs))))
}

The Qi version uses @racket[><] to "map" all input values under the @hyperlink["https://docs.racket-lang.org/relation/Types.html#%28def._%28%28lib._relation%2Ftype..rkt%29._-~3estring%29%29"]{@racket[->string]} @tech{flow} to convert them to strings. Then it appends these values together as strings, finally converting the result back to a number to produce the result.

The Racket version needs to be parsed in detail in order to be understood, while the Qi version reads sequentially in the natural order of the transformations, and makes plain what these transformations are. Qi is the natural choice here.

The documentation for the @seclink["top" #:indirect? #t #:doc '(lib "scribblings/threading.scrbl")]{threading macro} contains additional examples of such transformations which to a first approximation apply to Qi as well (see @secref["Relationship_to_the_Threading_Macro"]).

@subsection{Root-Mean-Square}

While you can always use Qi to express computations as @tech{flows}, it isn't always a better way of thinking about them -- just a @emph{different} way, more appropriate in some cases and less in others. Let's look at an example that illustrates this subjectivity.

The "root mean square" is a measure often used in statistics to estimate the magnitude of some quantity for which there are many independent measurements. For instance, given a set of values representing the "deviation" of the result from the predictions of a model, we can use the square root of the mean of the squares of these values as an estimate of "error" in the model, i.e. inversely, an estimate of the accuracy of the model. The RMS also comes up in other branches of engineering and mathematics. What if we encountered such a case and wanted to implement this function? In Racket, we might implement it as:

@codeblock{
    (define (rms vs)
      (sqrt (/ (apply + (map sqr vs))
               (length vs))))
}

In Qi, it would be something like:

@codeblock{
    (define-flow rms
      (~> △ (-< (~> (>< sqr) +)
                count) / sqrt))
}

This first uses the "prism" @racket[△] to separate the input list into its component values. Then it uses a tee junction, @racket[-<], to fork these values down two @tech{flows}, one to compute the sum of squares and the other to count how many values there are. In computing the sum of squares, @racket[><] "maps" the input values under the @racket[sqr] flow to yield the squares of the input values which are then summed. This is then divided by the count to yield the mean of the squares, whose square root is then produced as the result.

Here, there are reasons to favor either representation. The Racket version doesn't have too much redundancy so it is a fine way to express the computation. The Qi version eliminates the redundant references to the input (as it usually does), but aside from that it is primarily distinguished as being a way to express the computation as a series of transformations evaluated sequentially, while the Racket version expresses it as a compound expression to be evaluated hierarchically. They're just @emph{different} and neither is necessarily better.

@section{The Science of Deduction}

When you seek to analyze some values and make inferences or assertions about them, or take certain actions based on observed properties of values, or, more generally, when you want to express anything exhibiting @emph{subject-predicate structure}, Qi is often the right language to use.

@subsection{Compound Predicates}

In Racket, if we seek to make a compound assertion about some value, we might do something like this:

@codeblock{
  (λ (num)
    (and (positive? num)
         (integer? num)
         (= 0 (remainder num 3))))
}

This recognizes positive integers divisible by three. Using the utilities in @secref["Additional_Higher-Order_Functions"
         #:doc '(lib "scribblings/reference/reference.scrbl")], we might write it as:

@codeblock{
  (conjoin positive?
           integer?
           (compose (curry = 0) (curryr remainder 3)))
}

... which avoids the wrapping lambda, doesn't mention the argument redundantly, and transparently encodes the fact that the function is a compound predicate. On the other hand, it is arguably less easy on the eyes. For starters, it uses the word "conjoin" to avoid colliding with "and," to refer to a similar idea. It also uses the words "curry" and "curryr" to partially apply functions, which are somewhat gratuitous as ways of saying "equal to zero" and "remainder by three."

In Qi, this would be written as:

@codeblock{
  (and positive?
       integer?
       (~> (remainder 3) (= 0)))
}

They say that perfection is achieved not when there is nothing left to add, but when there is nothing left to take away. Well then.

@subsection{abs}

Let's say we want to implement @racket[abs]. This is a function that returns the absolute value of the input argument, i.e. the value unchanged if it is positive, and negated otherwise -- a conditional transformation. With Racket, we might implement it like this:

@codeblock{
    (define (abs v)
      (if (negative? v)
          (- v)
          v))
}

For this very simple function, the input argument is mentioned @emph{four} times! An equivalent Qi definition is:

@codeblock{
    (define-switch abs
      [negative? -]
      [else _])
}

This uses the definition form of @racket[switch], which is a flow-oriented conditional analogous to @racket[cond]. The @racket[_] symbol here indicates that the input is to be passed through unchanged, i.e. it is the trivial or identity @tech{flow}. The input argument is not mentioned; rather, the definition expresses @racket[abs] as a conditioned transformation of the input, that is, the essence of what this function is.

Technically, as the @racket[switch] form transforms the input based on conditions, if none of the conditions match, no transformation is applied, and the inputs are produced, unchanged. So @racket[abs] could also be implemented simply as:

@codeblock{
  (define-switch abs [negative? -])
}

@subsection{Range}

[@emph{This example was suggested by user Rubix on the Racket Discord}]

We'd like to find the greatest difference in a set of values, which in statistical applications is called the @hyperlink["https://en.wikipedia.org/wiki/Range_(statistics)"]{range}. This is how we'd do it in Qi:

@codeblock{
    (define-flow range
      (~> △ (-< max min) -))
}

This separates the input list into its component values and passes those values independently through the functions @racket[max] and @racket[min] before taking the difference between them.

The code in Racket would be:

@codeblock{
    (define (range xs)
      (- (apply max xs)
         (apply min xs)))
}

The Racket version mentions the input three times and needs to "lift" the @racket[max] and @racket[min] functions so that they are applicable to lists rather than values. The Qi version is about as economical an implementation as you will find, expressing the essential idea and nothing more.

@subsection{Length}

Calculating the length of a list is a straightforward computation. Here are a few different ways to do it in Racket:

@codeblock{
(define (length lst)
  (if (empty? lst)
      0
      (add1 (length (rest lst)))))

(define (length lst)
  (apply + (map (const 1) lst)))

(define length
  (compose (curry apply +) (curry map (const 1))))

(define (length vs)
  (foldl (λ (v acc) (add1 acc)) 0 vs))

(define (length vs)
  (for/sum ([_ vs]) 1))
}

And here it is in Qi:

@codeblock{
(define-flow length
  (~> △ (>< 1) +))
}

This separates the input list into its component values, produces a @racket[1] corresponding to each value, and then adds these ones together to get the length. It is the same idea encoded (and indeed, hidden) in some of the Racket implementations.

This succinctness is possible because Qi reaps the twin benefits of (1) working directly with values (and not just collections of values), and (2) Racket's support for variadic functions that accept any number of inputs (in this case, @racket[+]).

@section{Don't Stop Me Now}

When you're interested in functionally transforming lists using operations like @racket[map], @racket[filter], @racket[foldl] and @racket[foldr], Qi is a good choice because its @seclink["It_s_Languages_All_the_Way_Down"]{optimizing compiler} eliminates intermediate representations that would ordinarily be constructed in computing the result of such a sequence, resulting in significant performance gains in some cases.

For example, consider the Racket function:

@codeblock{
  (define (filter-map vs)
    (map sqr (filter odd? vs)))
}

In evaluating this sequence, the input list is traversed to produce the result of @racket[filter], which is a list that is traversed one more time to produce another list that is the result of @racket[map].

The equivalent Qi flow is:

@codeblock{
  (define-flow filter-map
    (~> (filter odd?) (map sqr)))
}

Here, under the hood, each element of the input list is processed one at a time, with both of these functions being invoked on it in sequence, and then the output list is constructed by accumulating these individual results. This ensures that no intermediate lists are constructed along the way and that the input list is traversed just once -- a standard optimization technique called "stream fusion" or "deforestation." The Qi version produces the same result as the Racket code above, but it can be both faster as well as more memory-efficient, especially on large input lists. Note however that if the functions used in @racket[filter] and @racket[map] are not @emph{pure}, that is, if they perform side effects like printing to the screen or writing to a file, then the Qi flow would exhibit a different @seclink["Order_of_Effects"]{order of effects} than the Racket version.

@section{Curbing Curries and Losing Lambdas}

Since flows are just functions, you can use them anywhere that you would normally use a function. In particular, they are often a clearer alternative to using @hyperlink["https://en.wikipedia.org/wiki/Currying"]{currying} or @seclink["lambda"  #:doc '(lib "scribblings/guide/guide.scrbl")]{lambdas}. For instance, to double every number in a list, we could do:

@codeblock{
    (map (☯ (* 2)) (range 10))
}

... rather than use currying:

@codeblock{
    (map (curry * 2) (range 10))
}

... or a lambda:

@codeblock{
    (map (λ (v) (* v 2)) (range 10))
}

The Qi version expresses the essential idea without introducing arcane concepts (such as currying).

@section{The Value in Values}

Racket exhibits a @seclink["values-model" #:doc '(lib "scribblings/reference/reference.scrbl")]{satisfying symmetry} between input arguments and return values, allowing functions to return multiple values just as they accept multiple arguments. But syntactically, working with multiple values in Racket can be cumbersome, as we see in this example where we simply collect the return values of the built-in @racket[time-apply] utility into a list:

@codeblock{
(call-with-values (λ _ (time-apply + (list 1 2 3)))
                  list)
}

The symmetry between arguments and return values is even more apparent and natural in Qi, where functions are seen as @tech[#:doc '(lib "qi/scribblings/qi.scrbl")]{flows}, and arguments and return values as inputs and outputs, respectively. Thus, a function returning multiple values is just another flow and doesn't require special handling, making Qi a good choice in such cases:

@codeblock{
(~> () (time-apply + (list 1 2 3)) list)
}

@section{Making the Switch}

Scheme code in the wild is littered with @racket[cond] expressions resembling these:

@codeblock{
    (cond [(positive? v) (add1 v)]
          [(negative? v) (sub1 v)]
          [else v])
}

@codeblock{
    (cond [(>= a b) (- a b)]
          [(< a b) (- b a)])
}

... or even @racket[if] expressions like these:

@codeblock{
    (if (>= a b)
        (- a b)
        (- b a))
}

Such expressions are conditional transformations of the inputs, but this idea is nowhere encoded in the expressions themselves, leading to repetition, duplication, recapitulation, and even redundancy. In such cases, switch to @racket[switch]:

@codeblock{
    (switch (v)
      [positive? add1]
      [negative? sub1])
}

@codeblock{
    (switch (a b)
      [>= -]
      [< (~> X -)])
}

@racket[switch] is a versatile conditional form that can also express more complex @tech{flows}, as we will see in the next example.

@section{The Structure and Interpretation of Flows}

Sometimes, it is natural to express the entire computation as a @tech{flow}, while at other times it may be better to express just a part of it as a flow. In either case, the most natural representation may not be apparent at the outset, by virtue of the fact that we don't always understand the computation at the outset. In such cases, it may make sense to take an incremental approach.

The classic Computer Science textbook, "The Structure and Interpretation of Computer Programs," contains the famous "metacircular evaluator" -- a Scheme interpreter written in Scheme. The code given for the @racket[eval] function is:

@codeblock{
    (define (eval exp env)
      (cond [(self-evaluating? exp) exp]
            [(variable? exp) (lookup-variable-value exp env)]
            [(quoted? exp) (text-of-quotation exp)]
            [(assignment? exp) (eval-assignment exp env)]
            [(definition? exp) (eval-definition exp env)]
            [(if? exp) (eval-if exp env)]
            [(lambda? exp) (make-procedure (lambda-parameters exp)
                                           (lambda-body exp)
                                           env)]
            [(begin? exp) (eval-sequence (begin-actions exp) env)]
            [(cond? exp) (eval (cond->if exp) env)]
            [(application? exp) (apply (eval (operator exp) env)
                                       (list-of-values (operands exp) env))]
            [else (error "Unknown expression type -- EVAL" exp)]))
}

This implementation in Racket mentions the expression to be evaluated, @racket[exp], @emph{twenty-five} times. This kind of redundancy is often a sign that the computation can be profitably thought of as a @tech{flow}. In the present case, we notice that every condition in the @racket[cond] expression is a predicate applied to @racket[exp]. It would seem that it is the expression @racket[exp] that flows, here, through a series of checks and transformations in the context of some environment @racket[env]. By modeling the computation this way, we derive the following implementation:

@codeblock{
    (define (eval exp env)
      (switch (exp)
        [self-evaluating? _]
        [variable? (lookup-variable-value env)]
        [quoted? text-of-quotation]
        [assignment? (eval-assignment env)]
        [definition? (eval-definition env)]
        [if? (eval-if env)]
        [lambda? (~> (-< lambda-parameters
                         lambda-body) (make-procedure env))]
        [begin? (~> begin-actions (eval-sequence env))]
        [cond? (~> cond->if (eval env))]
        [application? (~> (-< (~> operator (eval env))
                              (~> operands △ (>< (eval env)))) apply)]
        [else (error "Unknown expression type -- EVAL" _)]))
}

This version eliminates two dozen redundant references to the input expression that were present in the original Racket implementation, and reads naturally. As it uses partial application @seclink["Templates_and_Partial_Application"]{templates} in the consequent flows, this version could be considered a hybrid implementation in Qi and Racket.

Yet, an astute observer may point out that although this eliminates almost all mention of @racket[exp], that it still contains @emph{ten} references to the environment, @racket[env]. In our first attempt at a flow-oriented implementation, we chose to see the @racket[eval] function as a @tech{flow} of the input @emph{expression} through various checks and transformations. We were led to this choice by the observation that all of the conditions in the original Racket implementation were predicated exclusively on @racket[exp]. But now we see that almost all of the consequent expressions use the @emph{environment}, in addition. That is, it would appear that the environment @racket[env] @emph{flows} through the consequent expressions.

For such cases, by means of a @racket[divert] (or its alias, @racket[%]) clause "at the floodgates," the @racket[switch] form allows us to control which values flow to the predicates and which ones flow to the consequents. In the present case, we'd like the predicates to only receive the input @emph{expression}, and the consequents to receive both the expression as well as the environment. By modeling the @tech{flow} this way, we arrive at the following pure-Qi implementation.

@codeblock{
    (define-switch eval
      (% 1> _)
      [self-evaluating? 1>]
      [variable? lookup-variable-value]
      [quoted? (~> 1> text-of-quotation)]
      [assignment? eval-assignment]
      [definition? eval-definition]
      [if? eval-if]
      [lambda? (~> (== (-< lambda-parameters
                           lambda-body) _) make-procedure)]
      [begin? (~> (== begin-actions _) eval-sequence)]
      [cond? (~> (== cond->if _) eval)]
      [application? (~> (-< (~> (== operator _) eval)
                            (~> (== operands (as env)) (>< (eval env)))) apply)]
      [else (error "Unknown expression type -- EVAL" 1>)])
}

This version eliminates the more than @emph{thirty} mentions of the inputs to the function that were present in the Racket version, while introducing four flow references (i.e. @racket[1>]). Some of the clauses are unsettlingly elementary, reading like pseudocode rather than a real implementation, while other clauses become complex flows reflecting the path the inputs take through the expression. This version is stripped down to the essence of what the @racket[eval] function @emph{does}, encoding a lot of our understanding syntactically that otherwise is gleaned only by manual perusal -- for instance, the fact that @emph{all} of the predicates are only concerned with the input expression is apparent on the very first line of the switch body. The complexity in this implementation reflects the complexity of the computation being modeled, nothing more.

While the purist may favor this last implementation, it is perhaps a matter of some subjectivity. We were led to Qi in this instance by the evidence of redundancy in the implementation, which we took to be a clue that this could be modeled as a @tech{flow}. It wasn't obvious at the outset that this was the case. Some may see this as evidence that a flow isn't the "natural" way to think about this computation. Others may disagree with this position, citing that it's difficult for the intuition to always penetrate the fog of complexity, and employing evidence to reinforce our intuitions is precisely how we can see farther, and that, as the evidence in this case suggested it was a flow, that it is, in fact, best thought of as a flow. Wherever you may find your sympathies to lie on this spectrum, objectively, we find that the pure-Qi solution is the most economical both conceptually as well as lexically (i.e. the shortest in terms of number of characters), while the hybrid solution is just a little more verbose. The original Racket implementation is in third place on both counts.

@section{Using the Right Tool for the Job}

We've seen a number of examples covering transformations, predicates, and conditionals, both simple and complex, where using Qi to describe the computation was often a natural and elegant choice, though not always an obvious one.

The examples hopefully illustrate an age-old doctrine -- use the right tool for the job. A language is the best tool of all, so use the right language to express the task at hand. Sometimes, that language is Qi and sometimes it's Racket and sometimes it's a combination of the two, or something else. Don't try too hard to coerce the computation into one way of looking at things. It's less important to be consistent and more important to be fluent and clear. And by the same token, it's less important for you to fit your brain to the language and more important for the language to be apt to describe the computation, and consequently for it to encourage a way of thinking about the problem that fits your brain.

Employing a potpourri of general purpose and specialized languages, perhaps, is the best way to flow!
