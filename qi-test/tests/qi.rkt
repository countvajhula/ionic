#lang racket/base

(require rackunit
         rackunit/text-ui
         (prefix-in flow: "flow.rkt")
         (prefix-in on: "on.rkt")
         (prefix-in switch: "switch.rkt")
         (prefix-in threading: "threading.rkt")
         (prefix-in definitions: "definitions.rkt")
         (prefix-in macro: "macro.rkt")
         (prefix-in util: "util.rkt")
         (prefix-in compiler: "compiler.rkt"))

(define tests
  (test-suite
   "qi tests"

   flow:tests
   on:tests
   switch:tests
   threading:tests
   definitions:tests
   macro:tests
   util:tests
   compiler:tests))

(module+ main
  (void
   (run-tests tests)))
