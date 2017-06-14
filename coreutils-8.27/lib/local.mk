include lib/gnulib.mk

# Allow "make distdir" to succeed before "make all" has run.
dist-hook: $(noinst_LIBRARIES)
.PHONY: dist-hook
