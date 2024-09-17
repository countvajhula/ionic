#lang scribble/doc
@require[scribble/manual
         scribble-abbrevs/manual
         scribble/example
         racket/sandbox
         scribble/core
         scribble-math
         @for-label[qi
                    racket]]

@(use-mathjax)

@; based on scribble-abbrevs/latex
@(define (definition term . defn*)
  (make-paragraph plain
    (list
      (bold "Definition")
      (element #f (list " (" (deftech term) "). "))
      defn*)))

@(define (theorem . thm*)
  (make-paragraph plain
    (list
      (bold "Theorem")
      (element #f (list ". "))
      thm*)))

@title{Principles of Qi}

 After many patient hours meticulously crafting Qi flows, you may find that you seek a deeper understanding; insight into guiding principles and inner workings, so that you can hone your skills on firmer ground.

 Welcome. Your wanderings have brought you to the right place. In this chapter, we discuss various topics that will help you have a fuller understanding and a sound conceptual model of how Qi works. This kind of facility with the fundamentals will be useful as you employ Qi for more complex tasks, enabling you to engage in higher level reasoning about the task at hand rather than be mired in conceptual building blocks.

@table-of-contents[]

@section{What is a Flow?}

 A @deftech{flow} is either made up of flows, or is a native (e.g. Racket) @seclink["lambda" #:doc '(lib "scribblings/guide/guide.scrbl")]{function}. Flows may be composed using a number of combinators that could yield either linear or nonlinear composite flows.

 A flow in general accepts @code{m} @deftech{inputs} and yields @code{n} @deftech{outputs}, for arbitrary non-negative integers @code{m} and @code{n}. We say that such a flow is @code{m × n}. Inputs and outputs are ordinary @tech/reference{values}.

 The semantics of a flow is function invocation -- simply invoke a flow with inputs (i.e. ordinary arguments) to obtain the outputs.

 The Qi language allows you to describe and use flows in your code.

@section{Values and Flows}

@tech{Flows} accept inputs and produce outputs -- they are functions. The things that flow -- the inputs and outputs -- are @emph{values}. Yet, values do not actually "move" through a flow, since a flow does not mutate them. The flow simply produces new values that are related to the inputs by a computation.

 Every flow is made up of components that are themselves flows. Thus, each of these components is a relationship between an input set of values and an output set of values, so that at every level, flows produce sequences of sets of values beginning with the inputs and ending with the outputs, with each set related to the preceding one by a computation, and again, no real "motion" of values at all.

 So indeed, when we say that values "flow," there is nothing in fact that truly flows, and it is merely a convenient metaphor.

@section{Flows as Graphs}

 A flow could also be considered an @hyperlink["https://en.wikipedia.org/wiki/Directed_acyclic_graph"]{acyclic graph}, with its component flows as nodes, and a directed edge connecting two flows if an output of one is used as an input of the other. There may be many distinct @deftech{paths} that could be traced over this graph, and we may imagine values to flow along these paths at runtime (although of course, @seclink["Values_and_Flows"]{there is nothing that flows}). At each point in the flow (in this spatial sense), there are a certain number of values present, depending on the runtime inputs. We refer to this number as the @deftech{arity} or the @deftech{volume} of the flow at that point. Volume is a runtime concept since it depends on the actual inputs provided to the flow, although there may be cases where it could be determined at compile time.

@section{Values are Not Collections}

 The things that flow are @tech/reference{values}. Individual values may happen to be collections such as @tech/guide{lists}, but the values that are flowing are not, together, a collection of any kind.

 To understand this with an example: when we employ a tee junction in a @tech{flow}, colloquially, we might say that the junction "divides the flow into two," which might suggest that there are now two flows. But in fact, there is just one flow that divides @emph{values} down two separate flows which are part of its makeup. More precisely, @racket[-<] composes two flows to yield a single composite flow. Like any flow, this composite flow accepts values and produces values, not collections of values. There is no way to differentiate, at the output end, which values came from the first channel of the junction and which ones came from the second, since downstream flows have no idea about the structure of upstream flows and only see the values they receive.

 The way to group values, if we need grouping, is to collect them into a data structure (e.g. a list) using a collection prism, @racket[▽]. In the case of a tee junction, the way to differentiate between values coming from each channel of the junction is for the channels to individually @racket[collect] their values at the end. That way, the values that are the output of the composite flow are lists generated individually by the various channels of the flow.

@section[#:tag "Everything_is_a_Function"]{Counting Flows}

Everything in Qi is a @seclink["lambda" #:doc '(lib "scribblings/guide/guide.scrbl")]{function}. Programs are functions, they are made up of functions. Even @seclink["Literals"]{literals} are interpreted as functions generating them.

Consider this example:

@codeblock{
  (~> sqr (-< add1 5) *)
}

There are six @tech{flows} here, in all: the entire one, each component of the thread, and each component of the tee junction.

@section{Effect Locality}

Qi programs provide weaker guarantees on @seclink["Order_of_Effects"]{order of effects} than do otherwise equivalent Racket programs.

For instance, this Qi flow:

@codeblock{
  (~>> (filter my-odd?) (map my-sqr))
}

is roughly equivalent to this Racket expression:

@codeblock{
  (lambda (vs)
    (map my-sqr
         (filter my-odd? vs)))
}

But if @racket[my-odd?] and @racket[my-sqr] exhibit any side effects, such as printing their inputs to the screen, then the behavior of these two expressions is not quite the same. Racket guarantees that @emph{all} of the @racket[my-odd?] effects will occur before @emph{any} of the @racket[my-sqr] effects. Qi provides a more minimal (and ultimately very simple) guarantee that can be summarized as (1) effects are only defined in association with function invocations, and (2) they will occur at the same time as the function invocation with which they are associated. We call this property "effect locality."

To understand what this means, we will need to develop some concepts.

@subsection{Functional Effects}

First, regarding the definability of effects, as far as Qi is concerned, they are only well-defined in connection with some @tech{flow}, and are not independently conceivable.

@definition["Associated effect"]{If a flow @${f} either includes an effect @${e} in its primitive definition or has one declared using @racket[effect], then @${e} is said to be an effect "on" @${f}. We denote an arbitrary effect on @${f} by @${ε(f)}.}

In the case where we use the @racket[effect] form on its own as in @racket[(effect displayln)], the implicit associated function is the identity flow, @racket[_].

Note that @tech{effects} are a distinct concept from program @tech{inputs} and @tech{outputs}.

@subsection{Upstream and Downstream}

We already saw how a flow can be thought of as a @seclink["Flows_as_Graphs"]{directed graph}. This naturally suggests that some flows are upstream (or downstream) of others in terms of this directionality. Let's define this relation more precisely, as it will be useful to us.

@definition["Upstream and downstream"]{A flow invocation @${f} is @deftech{upstream} of another invocation @${g} if the output of @${f} is @emph{necessary} to determining the input of @${g}. Conversely, @${g} is @deftech{downstream} of @${f}. We will denote this relation @${f < g}.}

@; This relation, like the usual strict order relation on numbers, is
@; irreflexive (f isn't upstream of itself, not f < f),
@; asymmetric (f < g ⇒ not g < f)
@; and transitive (f < g and g < h ⇒ f < h)

Note that this definition relates flow @emph{invocations} rather than @tech{flows} themselves. For now, we need not worry about this distinction, but we will soon see why it matters.

In terms of the @tech{paths} that could be traced over a flow, the ordering implied by @racket[~>] naturally shows us many members of this relation: flows that come later in the sequence in a @racket[~>] form are downstream of those that come earlier, because the output of earlier flows is needed to determine the input to later flows.

In the above example, @racket[filter] and @racket[map] are obviously ordered by @racket[~>] in this way, so that @racket[(filter my-odd?)] is upstream of @racket[(map my-sqr)]. But it's not so obvious how @racket[my-odd?] and @racket[my-sqr] should be treated. These are employed "internally" by the higher-order flows @racket[filter] and @racket[map], and are not directly ordered by the @racket[~>] form. Should @racket[my-odd?] be considered to be upstream of @racket[my-sqr] here?

This is where the distinction between flows and flow invocations comes into play. In fact, not all invocations of @racket[my-odd?] are upstream of any particular invocation of @racket[my-sqr]. Rather, specific invocations of @racket[my-sqr] that use values computed by individual invocations of @racket[my-odd?] are downstream of those invocations, and notably, these invocations involve the individual elements of the input list rather than the entire list, so that the computational dependency expressed by this relation is as fine-grained as possible.

For instance, for an input list @racket[(list 1 2 3)], @racket[(my-odd? 1)] is @tech{upstream} of @racket[(my-sqr 1)], and likewise, @racket[(my-odd? 3)] is @tech{upstream} of @racket[(my-sqr 3)], but @racket[(my-odd? 3)] is not upstream of @racket[(my-sqr 1)], and @racket[(my-odd? 2)] isn't upstream of anything.

That brings us to the guarantee that Qi provides in this case (and in general).

@subsection{Qi's Guarantee on Effects}

@definition["Well-ordering"]{For @tech{flow} invocations @${f} and @${g} and corresponding effects @${ε(f)} and @${ε(g)},

@$${f \lt g \implies \epsilon(f) \lt \epsilon(g)}

where @${<} on the left denotes the relation of being upstream, and @${<} on the right denotes one effect happening before another. Such effects are said to be @emph{well-ordered}.
}

Well-ordering is defined in relation to a source program encoding the intended meaning of the flow, which serves as the point of reference for program translations. Qi guarantees that effects will remain well-ordered through any such translations of the source program that are undertaken during @seclink["It_s_Languages_All_the_Way_Down"]{optimization}. As we will soon see, this guarantee assumes, and prescribes, that effects employed in flows be @tech{local}.

@definition["Effect locality"]{@tech{Effects} in a flow F are said to be @deftech{local} if the @tech{output} of F is invariant under all @tech{well-orderings} of effects. Specifically, if a @techlink[#:key "well-ordering"]{well-ordered} program translation causes a program to produce different @tech{output}, then the program contains @deftech{nonlocal} effects.}

For example, effects that mutate shared state serving as the input to other flows are often nonlocal in this way. The section on @secref["Order_of_Effects"] elaborates on this example.

We will discuss the practicalities of these in more detail shortly, but first, it's worth noting that although well-ordered effects seem natural for flows, the property does not necessarily hold under arbitrary program translations without an explicit compiler guarantee (as Qi provides). We can see this in terms of the underlying pure flow that is free of effects.

@definition["Pure projection"]{The pure projection of a flow @${f} is @${f} with all effects removed. We'll denote this @${π(f)}. For flows @${f_{1}} and @${f_{2}}, @${π(f_{1})} is @emph{equivalent} to @${π(f_{2})} if they produce the same @tech{output} given the same @tech{input}.}

@theorem{For a @tech{flow} @${f}, not every flow @${f′} such that @${π(f′)} is equivalent to @${π(f)} preserves @tech{well-ordering} of effects in relation to @${f}.}

For instance, the compiler could accumulate all effects and execute them in an arbitrary order at the end of execution of the flow. For at least some subset of local effects (say, effects that simply print their inputs), the output remains the same even if the effects are not well-ordered.

Locality of effects does not imply well-ordering of effects under program translation, nor vice versa – these are independent.

In sum, @emph{Qi guarantees that the @tech{output} of execution of the compiled program is the same as that of the source program, assuming @tech{effects} are @tech{local}, and further, it guarantees that the effects will be @techlink[#:key "well-ordering"]{well-ordered} in relation to the source program.}

This has a few implications of note.

@subsubsection{The @racket[effect] Form}

First, for the @racket[effect] form, this implies that Qi considers an effectful flow @${f} performing an effect @${e} to be indistinguishable from a flow @racket[(effect e f′)], where @${f′} is @${f} without @${e} (and therefore pure), and effects declared in this way will never be separated from the associated flows. Thus, Qi @seclink["Separate_Effects_from_Other_Computations"]{encourages writing pure functions} while preserving the intuitive association of effects with functions.

@subsubsection{The @racket[esc] Form}

Qi will not optimize a flow that is wrapped with @racket[esc]. Thus, such flows will exhibit @seclink["Racket_vs_Qi"]{Racket's order of effects} (which, as we'll discuss below, also satisfies the requirements of locality).

For more on how @racket[esc] is handled, see @secref["Using_Racket_to_Define_Flows"].

@subsubsection{Truncating Effects}

Next, for a flow like this one:

@racketblock[
  (~>> (filter my-odd?) (map my-sqr) car)
]

… when it is invoked with a large input list, Qi in fact @seclink["Don_t_Stop_Me_Now"]{only processes the very first value} of the list, since it determines, at the end, that no further elements are needed in order to generate the final result. This means that all effects on would-be subsequent invocations of @racket[my-odd?] and @racket[my-sqr] would simply not be performed. Yet, @tech{well-ordering} is preserved here, since the @techlink[#:key "well-ordering"]{defining implication} holds for every flow invocation that actually happens. Well-ordering is about effects being guided by the @emph{necessity} of @techlink[#:key "associated effect"]{associated} computations to the final result.

@subsubsection{Independent Effects}

For a nonlinear flow like this one:

@racketblock[

(~>> (filter my-odd?)
     (-< (map my-sqr __)
         (map my-add1 __))
     (map my-*)
     (foldl + 0))
]

… as invocations of neither @racket[my-sqr] nor @racket[my-add1] are @tech{upstream} of the other, there is no guarantee on the mutual order of effects either. For instance, the effects @techlink[#:key "associated effect"]{on} @racket[my-sqr] may happen first, or those @techlink[#:key "associated effect"]{on} @racket[my-add1] may happen first, or they may be interleaved.

But both of these effects would occur before the one on the corresponding @racket[my-*] invocation, since this is @tech{downstream} of them both.

@subsubsection{Designing Effects}

The guarantee of @tech{well-ordering} of effects provided by the compiler represents a prescription for the design of @tech{effects} by users.

As @secref["Order_of_Effects"] elaborates on, it's possible that the @tech{output} of effectful flows will differ from that of seemingly equivalent Racket programs. In fact, it's precisely in the cases where the program contains @tech{nonlocal} effects that the output could differ.

From Qi's perspective, such effects are poorly defined as they are either too broadly scoped or likely have the scope of their operation diffused over multiple function invocations in a way that is not neatly captured by their composition.

In general, Qi encourages designing your programs so that effects are @tech{local}.

@subsubsection{A Natural Order of Effects}

By being as fine-grained as possible in expressing computational dependencies, and in tying the execution of effects to such computational dependencies, @tech{well-ordering} is in some sense the minimum well-formed guarantee on effects, and a natural one for functional languages to provide.

@subsection{Racket vs Qi}

In the earlier example, reproduced here for convenience:

@racketblock[
  (lambda (vs)
    (map my-sqr
         (filter my-odd? vs)))
]

@racketblock[
  (~>> (filter my-odd?) (map my-sqr))
]

… with an input list @racket[(list 1 2 3)], Racket's order of effects follows the invocation order:

@racketblock[
  (my-odd? 1) (my-odd? 2) (my-odd? 3) (my-sqr 1) (my-sqr 3)
]

Qi's order of effects is:

@racketblock[
  (my-odd? 1) (my-sqr 1) (my-odd? 2) (my-odd? 3) (my-sqr 3)
]

Either of these orders @emph{satisfies} @tech{well-ordering}, but as we saw earlier, Racket guarantees something more than this minimum, or, in mathematical terms, Racket's guarantees on effects are @emph{stronger} than Qi's.

In principle, this allows Qi to offer @seclink["Don_t_Stop_Me_Now"]{faster performance} in some cases.

@section{Flowy Logic}

Qi's design is inspired by buddhist śūnyatā logic. To understand it holistically would require a history lesson to put the sunyata development in context, and that would be quite a digression. But in essence, sunyata is about transcension of context or viewpoint. A viewpoint is identifiable with a logical span of possibilities (@emph{catuṣkoṭi}) in terms of which assertions may be made. Sunyata is the rejection of @emph{all} of the available logical possibilities, thus transcending the very framing of the problem (this is signified by the word @emph{mu} in Zen). This kind of transcension could suggest alternative points of view, but more precisely, does not indicate a point of view (which isn't the same as being ambivalent or even agnostic). This idea has implications not just for formal logical systems but also for everyday experience and profound metaphysical questions alike.

But for the purposes of Qi, what it means is that the existence of a value is a logical span within which it takes on specific forms. Sunyata is the difference between a value taking on a form indicating tangible output (e.g. @racket[5] or @racket["hello"]) or indicating absence (e.g. @racket[(void)] or @racket[""]) or failure (e.g. @racket[#f]), or provisionality (e.g. @racket['suspended]) or certainty (e.g. @racket[#t]) -- it's the difference between these, and @emph{not existing at all}.

The same considerations extend the other way as well, from nonexistence to existence to existence of more than one. As each value corresponds to an independent logical span of possibilities, sunyata in the context of Qi translates into the core paradigm being the existence/non-existence and consequently also the number of values at each point in the flow.

In practice, this means that Qi will often opt to either return or not return a value rather than return a value signifying absence or raise an error. This principle even suggests considerations for the design of ordinary functions and the evaluator itself, which from a Qi/sunyata perspective, could model absence and number in positions that typically expect values.

For example, the following would seem to be in accord with these principles:

@itemlist[
   @item{Variadic functions, on receiving no input, produce a nullary value (e.g. a monoid identity) if applicable, or no output otherwise, instead of raising an error. For instance, @racket[(max)] currently raises an error, and under this guideline would produce no output, instead.}
   @item{Upon receiving multiple values in positions where a single value is expected, the evaluator "forks" the continuation so that each possibility is independently (combinatorially) evaluated. The results from these parallel computations could be "flattened" as multiple output values, but it may be more correct to evaluate them instead as completely independent computations. These could be manipulated distinctly -- for instance, each forked continuation could be fulfilled by a distinct process, and the evaluator could provide a means to refer to the output of these processes from within the language or in a metalanguage, while keeping the processes themselves abstracted. @racket[(cons (values 1 2) (list 3))] independently produces @racket[(list 1 3)] and @racket[(list 2 3)].}
   @item{Upon receiving @emph{no} values in positions where a single value is expected, there are a few cases to consider. If no values were received in a position corresponding to the "object" of the function, in the grammatical sense, then the function produces no values. If no values were received in another position, then the function produces the input object(s) (again, objects in the grammatical sense) -- which would be consistent with the expected output type. If there is more than one object position, then the result of the function is empty if @emph{any} of the object positions is. If no values were received in a position serving another grammatical role (e.g. a modifier or adverb such as a function-valued argument), the function generally produces nothing. In none of these cases does the function raise an error. @racket[(cons (values) (list 1 2 3))] produces @racket[(list 1 2 3)], while @racket[(cons 1 (values))], @racket[(add-two-numbers (values) 5)], and @racket[(sort (values) (list 2 3 1))] (where the first argument position indicates a comparator function to be used in sorting) produce nothing.}
   @item{If the function receives valid inputs but is unable to produce a valid result (for instance, if the inputs fail some runtime requirement), it produces nothing.}
   @item{If an @emph{invalid} input (such as one of an unexpected type) is received, the function raises an error.}
  ]

See @secref["Write_Yourself_a_Maybe_Monad_for_Great_Good"] for an example that applies some of these ideas to implement the Maybe monad commonly used in many functional languages. Although, note that if the above design were adopted by the underlying language and interpreter, Maybe would be unnecessary in most cases.

@section{Phrases}

When reading languages like English, we understand what we read in terms of words and then phrases and the relationship of these phrases to one another as clauses of a sentence, and then the relationship of sentences to one another, and then paragraphs to one another. The resourceful speed readers among us even do this in the reverse order at first, discerning high level structure before parsing the low level component meanings. Just like human languages, Qi expressions exhibit phrase structure that we can leverage in similar ways. Here are some common phrases in the language to get you started thinking about the language in this way.

@;clarify arity of adaptation; and scribble mathify some of these things (and review/distinguish from code); and add diagrams - look at the prolog bookmark for the fold diagram
@itemlist[
   @item{@racket[(~> △ (>< f) ...)] -- "sep-amp". A standard mapping over values extracted from a list.}
   @item{@racket[(~> (-< _ f ...) ...)] -- "augment". The tee junction may augment the flow in any order -- the signature of this phrase is the presence of a @racket[_] in the tee junction.}
   @item{@racket[(~> (-< f ...) g)] -- "diamond composition". This is one way to adapt a flow @racket[f] of arity @${k} to a flow @racket[g] of arity @${m}, that is, by branching the @${k} inputs into @${m} copies of @racket[f] (assuming @racket[f] produces one output). It is the same as the "composition operator" used in defining @hyperlink["https://en.wikipedia.org/wiki/Primitive_recursive_function"]{primitive recursive functions}.}
   @item{@racket[(group 1 car-flo cdr-flo)] -- "pare". This is analogous to "car and cdr" style destructuring with lists, but for segregating values instead. Note that while it is analogous, this isn't "destructuring," since the values taken together @seclink["Values_are_Not_Collections"]{do not form a data structure}.}
  ]

Some of these phrases may someday make it into the language as forms themselves, and there may be higher-level phrases still, made up of such phrases.

@section{Identities}

Here are some useful identities for the core routing forms. They can be used to simplify your code or say things in different ways.

@$${(\sim> (\sim> f g) h) = (\sim> f (\sim> g h)) = (\sim> f g h)} [associative law]
@$${(\sim> f \_) = (\sim> \_ f) = (\sim> f) = f} [left and right identity]
@$${(== (\sim> f₁ g₁) (\sim> f₂ g₂)) = (\sim> (== f₁ f₂) (== g₁ g₂))}
@$${(\sim> (>< f) (>< g)) = (>< (\sim> f g))}
@$${(\sim> \_ \cdots) = \_}
@$${(== \_ \ldots) = \_}
@$${(>< \_) = \_}
@$${(-< f) = f}
@$${(-< (\text{gen} a) (\text{gen} b)) = (-< (\text{gen} a b))}
@$${(\sim> △ ▽) = \_ = (\sim> ▽ △) \text{(the former only holds when the input is a list)}}

@section{Flows and Arrows}

[@emph{The connection between flows and arrows was pointed out by Sergiu Ivanov (Scolobb on Discourse).}]

It turns out that the core routing forms of Qi fulfill the definition of @hyperlink["https://www.haskell.org/arrows/"]{arrows} in category theory and Haskell (in an unfortunate conflation of terminology, these "arrows" are an entirely different notion than morphisms, which are also sometimes referred to as arrows). The specific correspondence is as follows:

@itemlist[
 @item{Qi's "base case" of @seclink["What_is_a_Flow_"]{treating any function as a flow} corresponds to the @racket[arr] method of arrows.}
 @item{@racket[~>] is equivalent to the @racket[(>>>)] of arrows.}
 @item{The @racket[relay], and specifically, @racket[(== a _)], @racket[(== _ b)], and @racket[(== a b)], respectively correspond to @racket[first], @racket[second], and their composite @racket[(***)] in arrows.}
 @item{@racket[(-< f g)] corresponds to what is referred to as "fanout composition", @racket[(&&&)], in arrows.}
]

So evidently, flows are just @hyperlink["https://www.sciencedirect.com/science/article/pii/S1571066106001666/pdf"]{monoids in suitable subcategories of bifunctors} (what's the problem?), or, in another way of looking at it, @hyperlink["https://bentnib.org/arrows.pdf"]{enriched Freyd categories}.

Therefore, any theoretical results about arrows should generally apply to Qi as well (but not necessarily, since Qi is not @emph{just} arrows).

@section{It's Languages All the Way Down}

Qi is a language implemented on top of another language, Racket, by means of a @tech/reference{macro} called @racket[flow]. All of the other macros that serve as Qi's @seclink["Embedding_a_Hosted_Language"]{embedding} into Racket, such as (the Racket macros) @racket[~>] and @racket[switch], expand to a use of @racket[flow].

The @racket[flow] form accepts Qi syntax and (like any @tech/reference{macro}) produces Racket syntax. It does this in two stages:

@itemlist[#:style 'ordered
  @item{Expansion, where the Qi source expression is translated to a small core language (Core Qi).}
  @item{Compilation, where the Core Qi expression is optimized and then translated into Racket.}
]

All of this happens at @seclink["phases" #:doc '(lib "scribblings/guide/guide.scrbl")]{compile time}, and consequently, the generated Racket code is then itself @seclink["expansion" #:doc '(lib "scribblings/reference/reference.scrbl")]{expanded} to a @seclink["fully-expanded" #:doc '(lib "scribblings/reference/reference.scrbl")]{small core language} and then @tech/reference{compiled} to @seclink["JIT" #:doc '(lib "scribblings/guide/guide.scrbl")]{bytecode} for evaluation in the runtime environment, as usual.

Thus, Qi is a special kind of @seclink["Hosted_Languages"]{hosted language}, one that happens to have the same architecture as the host language, Racket, in terms of having distinct expansion and compilation steps. This gives it a lot of flexibility in its implementation, including allowing much of its surface syntax to be implemented as @seclink["Qi_Macros"]{Qi macros} (for instance, Qi's @racket[switch] expands to a use of Qi's @racket[if] just as Racket's @racket[cond] expands to a use of Racket's @racket[if]), allowing it to be naturally macro-extensible by users, and lending it the ability to @seclink["Don_t_Stop_Me_Now"]{perform optimizations on the core language} that allow idiomatic code to be performant.

This architecture is achieved through the use of @seclink["top" #:indirect? #t #:doc '(lib "syntax-spec-v2/scribblings/main.scrbl")]{Syntax Spec}, following the general approach described in @hyperlink["https://dl.acm.org/doi/abs/10.1145/3674627"]{Compiled, Extensible, Multi-language DSLs (Ballantyne et. al.)} and @hyperlink["https://dl.acm.org/doi/abs/10.1145/3428297"]{Macros for Domain-Specific Languages (Ballantyne et. al.)}.
