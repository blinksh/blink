# Most of this is probably too coreutils-centric to be useful to other packages.

bin=bin-$$$$

write_loser = printf '\#!%s\necho $$0: bad path 1>&2; exit 1\n' '$(SHELL)'

tmpdir = $(abs_top_builddir)/tests/torture

t=$(tmpdir)/$(PACKAGE)/test
pfx=$(t)/i

built_programs := $(sort $(patsubst src/%$(EXEEXT),%,$(bin_PROGRAMS)))

# More than once, tainted build and source directory names would
# have caused at least one "make check" test to apply "chmod 700"
# to all directories under $HOME.  Make sure it doesn't happen again.
tp = $(tmpdir)/taint
t_prefix = $(tp)/a
t_taint = '$(t_prefix) b'
fake_home = $(tp)/home

# When extracting from a distribution tarball, extract using the fastest
# method possible.  With dist-xz, that means using the *.xz file.
ifneq ('', $(filter *.xz, $(DIST_ARCHIVES)))
  tar_decompress_opt_ = J
  suffix_ = xz
else
  ifneq ('', $(filter *.gz, $(DIST_ARCHIVES)))
    tar_decompress_opt_ = z
    suffix_ = gz
  else
    tar_decompress_opt_ = j
    suffix_ = bz2
  endif
endif
amtar_extract_ = $(AMTAR) -$(tar_decompress_opt_)xf
preferred_tarball_ = $(distdir).tar.$(suffix_)

# Ensure that tests run from tainted build and src dir names work,
# and don't affect anything in $HOME.  Create witness files in $HOME,
# record their attributes, and build/test.  Then ensure that the
# witnesses were not affected.
# Skip this test when using libtool, since libtool-generated scripts
# cannot deal with a space-tainted srcdir.
ALL_RECURSIVE_TARGETS += taint-distcheck
taint-distcheck: $(DIST_ARCHIVES)
	grep '^[	 ]*LT_INIT' configure.ac >/dev/null && exit 0 || :
	test -d $(t_taint) && chmod -R 700 $(t_taint) || :
	-rm -rf $(t_taint) $(fake_home)
	mkdir -p $(t_prefix) $(t_taint) $(fake_home)
	$(amtar_extract_) $(preferred_tarball_) -C $(t_taint)
	mkfifo $(fake_home)/fifo
	touch $(fake_home)/f
	mkdir -p $(fake_home)/d/e
	ls -lR $(fake_home) $(t_prefix) > $(tp)/.ls-before
	HOME=$(fake_home); export HOME;			\
	cd $(t_taint)/$(distdir)			\
	  && ./configure				\
	  && $(MAKE)					\
	  && $(MAKE) check				\
	  && ls -lR $(fake_home) $(t_prefix) > $(tp)/.ls-after \
	  && diff $(tp)/.ls-before $(tp)/.ls-after	\
	  && test -d $(t_prefix)
	rm -rf $(tp)

# Verify that a twisted use of --program-transform-name=PROGRAM works.
define install-transform-check
  echo running install-transform-check			\
    && rm -rf $(pfx)					\
    && $(MAKE) program_transform_name='s/.*/zyx/'	\
      prefix=$(pfx) install				\
    && test "$$(echo $(pfx)/bin/*)" = "$(pfx)/bin/zyx"	\
    && test "$$(find $(pfx)/share/man -type f|sed 's,.*/,,;s,\..*,,')" = "zyx"
endef

# Install, then verify that all binaries and man pages are in place.
# Note that neither the binary, ginstall, nor the [.1 man page is installed.
define my-instcheck
  echo running my-instcheck;				\
  $(MAKE) prefix=$(pfx) install				\
    && test ! -f $(pfx)/bin/ginstall			\
    && { fail=0;					\
      for i in $(built_programs); do			\
        test "$$i" = ginstall && i=install;		\
        for j in "$(pfx)/bin/$$i"			\
                 "$(pfx)/share/man/man1/$$i.1"; do	\
          case $$j in *'[.1') continue;; esac;		\
          test -f "$$j" && :				\
            || { echo "$$j not installed"; fail=1; };	\
        done;						\
      done;						\
      test $$fail = 1 && exit 1 || :;			\
    }
endef

# Use this to make sure we don't run these programs when building
# from a virgin compressed tarball file, below.
null_AM_MAKEFLAGS ?= \
  ACLOCAL=false \
  AUTOCONF=false \
  AUTOMAKE=false \
  AUTOHEADER=false \
  GPERF=false \
  MAKEINFO=false

ALL_RECURSIVE_TARGETS += my-distcheck
my-distcheck: $(DIST_ARCHIVES) $(local-check)
	$(MAKE) syntax-check
	$(MAKE) check
	-rm -rf $(t)
	mkdir -p $(t)
	$(amtar_extract_) $(preferred_tarball_) -C $(t)
	(set -e; cd $(t)/$(distdir);			\
	  ./configure --quiet --enable-gcc-warnings --disable-nls; \
	  $(MAKE) AM_MAKEFLAGS='$(null_AM_MAKEFLAGS)';	\
	  $(MAKE) dvi;					\
	  $(install-transform-check);			\
	  $(my-instcheck);				\
	  $(MAKE) distclean				\
	)
	(cd $(t) && mv $(distdir) $(distdir).old	\
	  && $(amtar_extract_) - ) < $(preferred_tarball_)
# With post-v1.15 automake, "distclean" would fail to remove .deps
# directories, leading to a spurious failure of the following recursive diff.
# FIXME: remove this, once automake is fixed.
	find $(t)/$(distdir).old $(t)/$(distdir) -name .deps | xargs -r rmdir
	diff -ur $(t)/$(distdir).old $(t)/$(distdir)
	-rm -rf $(t)
	rmdir $(tmpdir)/$(PACKAGE) $(tmpdir)
	@echo "========================"; \
	echo "ready for distribution:"; \
	for i in $(DIST_ARCHIVES); do echo "  $$i"; done; \
	echo "========================"
