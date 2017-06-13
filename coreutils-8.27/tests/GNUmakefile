# Provide a compatibility layer so that the commands used before the
# conversion of tests/ to non-recursive make still work.  To do that, we
# must rerun the "make check" from the parent, and with tests/ prefixed
# onto any TESTS values.  The SUBDIRS=. is to prevent the top-level check
# rules from descending into e.g., gnulib-test/.

.PHONY: all
all:
	@echo 'tests/GNUmakefile: did you mean to make "check"?' 1>&2
	@exit 1

ifeq ($(TESTS),)
tests =
else
tests = TESTS=$(addprefix tests/,$(TESTS))
endif

.PHONY: check
check:
	cd .. && $(MAKE) $@ $(tests) SUBDIRS=.
