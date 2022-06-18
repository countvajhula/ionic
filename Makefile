# Adapted from: http://www.greghendershott.com/2017/04/racket-makefiles.html
SHELL=/bin/bash

PACKAGE-NAME=qi

DEPS-FLAGS=--check-pkg-deps --unused-pkg-deps

help:
	@echo "install - install package along with dependencies"
	@echo "remove - remove package"
	@echo "build - Compile libraries"
	@echo "build-docs - Build docs"
	@echo "build-all - Compile libraries, build docs, and check dependencies"
	@echo "clean - remove all build artifacts"
	@echo "check-deps - check dependencies"
	@echo "test - run tests"
	@echo "test-with-errortrace - run tests with error tracing"
	@echo "errortrace - alias for test-with-errortrace"
	@echo "test-<module> - Run tests for <module>"
	@echo "errortrace-<module> - Run tests for <module> with error tracing"
	@echo "Modules:"
	@echo "  flow"
	@echo "  on"
	@echo "  threading"
	@echo "  switch"
	@echo "  definitions"
	@echo "  macro"
	@echo "  util"
	@echo "  probe"
	@echo "    Note: As probe is not in qi-lib, it isn't part of"
	@echo "    the tests run in the 'test' target."
	@echo "cover - Run test coverage checker and view report"
	@echo "cover-coveralls - Run test coverage and upload to Coveralls"
	@echo "coverage-check - Run test coverage checker"
	@echo "coverage-report - View test coverage report"
	@echo "docs - view docs in a browser"
	@echo "profile - Run comprehensive performance benchmarks"
	@echo "profile-competitive - Run competitive benchmarks"
	@echo "profile-forms - Run benchmarks for individual Qi forms"
	@echo "profile-selected-forms - Run benchmarks for Qi forms by name (command only)"

# Primarily for use by CI.
# Installs dependencies as well as linking this as a package.
install:
	raco pkg install --deps search-auto --link $(PWD)/$(PACKAGE-NAME)-{lib,test,doc,probe} $(PWD)/$(PACKAGE-NAME)

remove:
	raco pkg remove $(PACKAGE-NAME)-{lib,test,doc,probe} $(PACKAGE-NAME)

# Primarily for day-to-day dev.
# Build libraries from source.
build:
	raco setup --no-docs --tidy --pkgs $(PACKAGE-NAME)-lib

# Primarily for day-to-day dev.
# Build docs (if any).
build-docs:
	raco setup --no-launcher --no-foreign-libs --no-info-domain --no-pkg-deps \
	--no-install --no-post-install --tidy --pkgs $(PACKAGE-NAME)-doc

# Primarily for day-to-day dev.
# Build libraries from source, build docs (if any), and check dependencies.
build-all:
	raco setup --tidy $(DEPS-FLAGS) --pkgs $(PACKAGE-NAME)-{lib,test,doc,probe} $(PACKAGE-NAME)

# Note: Each collection's info.rkt can say what to clean, for example
# (define clean '("compiled" "doc" "doc/<collect>")) to clean
# generated docs, too.
clean:
	raco setup --fast-clean --pkgs $(PACKAGE-NAME)-{lib,test,doc,probe}

# Primarily for use by CI, after make install -- since that already
# does the equivalent of make setup, this tries to do as little as
# possible except checking deps.
check-deps:
	raco setup --no-docs $(DEPS-FLAGS) $(PACKAGE-NAME)

# Suitable for both day-to-day dev and CI
test:
	raco test -exp $(PACKAGE-NAME)-{lib,test,doc,probe}

test-flow:
	racket $(PACKAGE-NAME)-test/tests/flow.rkt

test-on:
	racket $(PACKAGE-NAME)-test/tests/on.rkt

test-threading:
	racket $(PACKAGE-NAME)-test/tests/threading.rkt

test-switch:
	racket $(PACKAGE-NAME)-test/tests/switch.rkt

test-definitions:
	racket $(PACKAGE-NAME)-test/tests/definitions.rkt

test-macro:
	racket $(PACKAGE-NAME)-test/tests/macro.rkt

test-util:
	racket $(PACKAGE-NAME)-test/tests/util.rkt

test-probe:
	raco test -exp $(PACKAGE-NAME)-probe

test-with-errortrace:
	racket -l errortrace -l racket -e '(require (submod "qi-test/tests/qi.rkt" test))'

errortrace: test-with-errortrace

errortrace-flow:
	racket -l errortrace -l racket -e '(require (submod "qi-test/tests/flow.rkt" main))'

errortrace-on:
	racket -l errortrace -l racket -e '(require (submod "qi-test/tests/on.rkt" main))'

errortrace-threading:
	racket -l errortrace -l racket -e '(require (submod "qi-test/tests/threading.rkt" main))'

errortrace-switch:
	racket -l errortrace -l racket -e '(require (submod "qi-test/tests/switch.rkt" main))'

errortrace-definitions:
	racket -l errortrace -l racket -e '(require (submod "qi-test/tests/definitions.rkt" main))'

errortrace-macro:
	racket -l errortrace -l racket -e '(require (submod "qi-test/tests/macro.rkt" main))'

errortrace-util:
	racket -l errortrace -l racket -e '(require (submod "qi-test/tests/util.rkt" main))'

errortrace-probe:
	racket -l errortrace -l racket -e '(require (submod "qi-probe/tests/qi-probe.rkt" test))'

docs:
	raco docs $(PACKAGE-NAME)

coverage-check:
	raco cover -b -n dev -p $(PACKAGE-NAME)-{lib,test}

coverage-report:
	open coverage/index.html

cover: coverage-check coverage-report

cover-coveralls:
	raco cover -b -n dev -f coveralls -p $(PACKAGE-NAME)-{lib,test}

profile-forms:
	echo "Profiling forms..."
	racket profile/forms.rkt

profile-selected-forms:
	@echo "Use 'racket profile/forms.rkt' directly, with -f form-name for each form."

profile-competitive:
	echo "Running competitive benchmarks..."
	racket profile/competitive.rkt

profile: profile-competitive profile-forms

.PHONY:	help install remove build build-docs build-all clean check-deps test test-flow test-on test-threading test-switch test-definitions test-macro test-util test-probe test-with-errortrace errortrace errortrace-flow errortrace-on errortrace-threading errortrace-switch errortrace-definitions errortrace-macro errortrace-util errortrace-probe docs cover coverage-check coverage-report cover-coveralls profile-forms profile-selected-forms profile-competitive profile
