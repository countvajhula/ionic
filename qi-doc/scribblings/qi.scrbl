#lang scribble/manual
@require[scribble-abbrevs/manual
         racket/runtime-path
         @for-label[qi
                    racket]]

@title{Qi: An Embeddable Flow-Oriented Language}

@defmodule[qi]

An embeddable, general-purpose language to allow convenient framing of programming logic in terms of functional @tech{flows}. A flow is a function from inputs to outputs, and Qi provides compact notation for describing complex flows.

@; Modified from Maciej Barc's req package
@(define-runtime-path logo-path "assets/img/logo.svg")
@(if (file-exists? logo-path)
     (centered (image logo-path #:scale 0.7))
     (printf "[WARNING] No ~a file found!~%" logo-path))

Tired of writing long functional pipelines with nested syntax like this?
@racketblock[(map _f (filter _g (vector->list _my-awesome-data)))]
Then Qi is for you!
@racketblock[(~> (_my-awesome-data) vector->list (filter _g) (map _f))]
But wait, there's more: Qi isn't just a turbo-charged threading language. It
supports multiple values and a suite of other operators for describing
computations:
@racketblock[(define-flow average
               (~> (-< + count) /))]

Start by @seclink["Using_These_Docs"]{getting your bearings}. For an overview of the language, continue to @secref["Introduction_and_Usage"]. For a thorough orientation, @hyperlink["https://www.youtube.com/watch?v=XkIoGmWkEpM"]{watch the original video} from RacketCon 2021.

@table-of-contents[]

@section{Using These Docs}

@secref["Introduction_and_Usage"] provides a high-level overview and includes installation and setup instructions. Learn the language by going through the @secref["Tutorial"], and read @secref["When_Should_I_Use_Qi_"] for examples illustrating its use. The many ways in which Qi may be used from the host language (e.g. Racket), as well as the ways in which Qi may be used in tandem with other DSLs, are described in @secref["Language_Interface"]. The various built-in forms of the language are documented in @secref["Qi_Forms"], while @secref["Qi_Macros"] covers using macros to extend the language by adding new features or implementing new DSLs, and @secref["List_Operations"] describes forms for expressing optimized list-oriented operations. @secref["Principles_of_Qi"] provides a theoretical foundation to develop a sound intuition for Qi, and the @secref["Field_Guide"] contains practical advice. @secref["Flowing_with_the_Flow"] contains recommendations on editor configuration to help you to write Qi effectively.

This site hosts @emph{user} documentation. If you are interested in contributing to Qi development you may be interested in the @emph{developer} documentation at the @hyperlink["https://github.com/drym-org/qi/wiki"]{Qi Wiki}. The wiki is also your one-stop shop for keeping up with planned events in the Qi community.

@include-section["intro.scrbl"]
@include-section["tutorial.scrbl"]
@include-section["interface.scrbl"]
@include-section["forms.scrbl"]
@include-section["list-operations.scrbl"]
@include-section["macros.scrbl"]
@include-section["field-guide.scrbl"]
@include-section["principles.scrbl"]
@include-section["using-qi.scrbl"]
@include-section["input-methods.scrbl"]
