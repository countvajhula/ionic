#lang scribble/doc
@require[scribble/manual
         (for-label qi
                    racket/list
                    racket/base)]

@title{List Operations}

@defmodule[qi/list]

This module defines functional list operations analogous to those in
@racketmodname[racket/base] and @racketmodname[racket/list], except
that these forms support @tech{flows} in higher-order function
positions and leverage the @seclink["Don_t_Stop_Me_Now"]{stream fusion
/ deforestation} optimization to avoid constructing intermediate
representations along the way to computing the result.

The forms in this module extend the syntax of the
@seclink["The_Qi_Core_Language"]{core Qi language}. This extended
syntax is given below:

@racketgrammar*[
[floe (map floe)
      (filter floe)
      (filter-map floe)
      (foldl floe expr)
      (foldr floe expr)
      (range expr)
      (range expr expr)
      (range expr expr expr)
      (take expr)
      car
      cadr
      caddr
      cadddr
      (list-ref expr)
      length
      empty?
      null?]]

The operations are categorized based on their role in the deforested
pipeline.

@section{Producers}

@defform*[
  ((range end)
   (range start end)
   (range start end step))
  #:contracts
  ((start real?)
   (end real?)
   (step real?))]{

Deforestable version of @racket[range] from @racketmodname[racket/list].

By default @racket[start] is @racket[0] and @racket[step] is @racket[1].

}

@section{Transformers}

@defform[
  (filter pred)
  #:contracts
  ((pred (-> any/c any/c)))]{

Deforestable version of @racket[filter] from @racketmodname[racket/base].

}

@defform[
  (map proc)
  #:contracts
  ((proc (-> any/c any/c)))]{

Deforestable version of @racket[map] from @racketmodname[racket/base]. Note that, unlike the Racket version, this accepts only one argument. For the "zip"-like behavior with multiple list inputs, see @racket[△].

}

@defform[
  (filter-map proc)
  #:contracts
  ((proc (-> any/c any/c)))]{

Deforestable version of @racket[filter-map] from @racketmodname[racket/list].

}

@defform[
  (take pos)
  #:contracts
  ((pos exact-nonnegative-integer?))]{

Deforestable version of @racket[take] from @racketmodname[racket/list].

}

@section{Consumers}

@defform[
  (foldl proc init)
  #:contracts
  ((proc (-> any/c any/c any/c any/c))
   (init any/c))]{

Deforestable version of @racket[foldl] from @racketmodname[racket/base].

}

@defform[
  (foldr proc init)
  #:contracts
  ((proc (-> any/c any/c any/c any/c))
   (init any/c))]{

Deforestable version of @racket[foldr] from @racketmodname[racket/base].

}

@defidform[car]{

Deforestable version of @racket[car] from @racketmodname[racket/base].

}

@defidform[cadr]{

Deforestable version of @racket[cadr] from @racketmodname[racket/base].

}

@defidform[caddr]{

Deforestable version of @racket[caddr] from @racketmodname[racket/base].

}

@defidform[cadddr]{

Deforestable version of @racket[cadddr] from @racketmodname[racket/base].

}

@defform[
  (list-ref pos)
  #:contracts
  ((pos exact-nonnegative-integer?))]{

Deforestable version of @racket[list-ref] from @racketmodname[racket/base].

}

@defidform[length]{

Deforestable version of @racket[length] from @racketmodname[racket/base].

}

@defidform[empty?]{

Deforestable version of @racket[empty?] from @racketmodname[racket/list].

}

@defidform[null?]{

Deforestable version of @racket[null?] from @racketmodname[racket/base].

}
