# Make coreutils documentation.				-*-Makefile-*-
# This is included by the top-level Makefile.am.

# Copyright (C) 1995-2017 Free Software Foundation, Inc.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

info_TEXINFOS = doc/coreutils.texi

doc_coreutils_TEXINFOS = \
  doc/perm.texi \
  doc/parse-datetime.texi \
  doc/constants.texi \
  doc/fdl.texi

# The following is necessary if the package name is 8 characters or longer.
# If the info documentation would be split into 10 or more separate files,
# then this is necessary even if the package name is 7 characters long.
#
# Tell makeinfo to put everything in a single info file: <package>.info.
# Otherwise, it would also generate files with names like <package>.info-[123],
# and those names all map to one 14-byte name (<package>.info-) on some crufty
# old systems.
AM_MAKEINFOFLAGS = --no-split

doc/constants.texi: $(top_srcdir)/src/tail.c $(top_srcdir)/src/shred.c
	$(AM_V_GEN)LC_ALL=C; export LC_ALL; \
	$(MKDIR_P) doc && \
	{ sed -n -e 's/^#define \(DEFAULT_MAX[_A-Z]*\) \(.*\)/@set \1 \2/p' \
	    $(top_srcdir)/src/tail.c && \
	  sed -n -e \
	      's/.*\(DEFAULT_PASSES\)[ =]* \([0-9]*\).*/@set SHRED_\1 \2/p'\
	    $(top_srcdir)/src/shred.c; } > $@-t \
	  && { cmp $@-t $@ >/dev/null 2>&1 || mv $@-t $@; rm -f $@-t; }

MAINTAINERCLEANFILES += doc/constants.texi

# Extended regular expressions to match word starts and ends.
_W = (^|[^A-Za-z0-9_])
W_ = ([^A-Za-z0-9_]|$$)

syntax_checks =		\
  sc-avoid-builtin	\
  sc-avoid-io		\
  sc-avoid-non-zero	\
  sc-avoid-path		\
  sc-avoid-timezone	\
  sc-avoid-zeroes	\
  sc-exponent-grouping	\
  sc-lower-case-var

texi_files = $(srcdir)/doc/*.texi

.PHONY: $(syntax_checks) check-texinfo

# List words/regexps here that should not appear in the texinfo documentation.
check-texinfo: $(syntax_checks)
	$(AM_V_GEN)fail=0;						\
	grep '@url{' $(texi_files) && fail=1;				\
	grep '\$$@"' $(texi_files) && fail=1;				\
	grep -n '[^[:punct:]]@footnote' $(texi_files) && fail=1;	\
	grep -n filename $(texi_files)					\
	    | $(EGREP) -v 'setfilename|[{]filename[}]'			\
	  && fail=1;							\
	exit $$fail

sc-avoid-builtin:
	$(AM_V_GEN)$(EGREP) -i '$(_W)builtins?$(W_)' $(texi_files)	\
	  && exit 1 || :

sc-avoid-path:
	$(AM_V_GEN)fail=0;						\
	$(EGREP) -i '$(_W)path(name)?s?$(W_)' $(texi_files)		\
	  | $(EGREP) -v							\
	  'PATH=|path search|search path|@vindex PATH$$|@env[{]PATH[}]'	\
	  && fail=1;							\
	exit $$fail

# Use "time zone", not "timezone".
sc-avoid-timezone:
	$(AM_V_GEN)$(EGREP) timezone $(texi_files) && exit 1 || :

# Check for insufficient exponent grouping, e.g.,
# @math{2^64} should be @math{2^{64}}.
sc-exponent-grouping:
	$(AM_V_GEN)$(EGREP) '\{.*\^[0-9][0-9]' $(texi_files) && exit 1 || :

# Say I/O, not IO.
sc-avoid-io:
	$(AM_V_GEN)$(EGREP) '$(_W)IO$(W_)' $(texi_files) && exit 1 || :

# I prefer nonzero over non-zero.
sc-avoid-non-zero:
	$(AM_V_GEN)$(EGREP) non-zero $(texi_files) && exit 1 || :

# Use "zeros", not "zeroes" (nothing wrong with "zeroes"; just be consistent).
sc-avoid-zeroes:
	$(AM_V_GEN)$(EGREP) -i '$(_W)zeroes$(W_)' $(texi_files)	\
	  && exit 1 || :

# The quantity inside @var{...} should not contain upper case letters.
# The leading backslash exemption is to permit in-macro uses like
# @var{\varName\} where the upper case letter is part of a parameter name.
find_upper_case_var =		\
  '/\@var\{/ or next;		\
   while (/\@var\{(.+?)}/g)	\
     {				\
       $$v = $$1;		\
       $$v =~ /[A-Z]/ && $$v !~ /^\\/ and (print "$$ARGV:$$.:$$_"), $$m = 1 \
     }				\
   END {$$m and (warn "$@: do not use upper case in \@var{...}\n"), exit 1}'
sc-lower-case-var:
	$(AM_V_GEN)$(PERL) -e 1 || { echo $@: skipping test; exit 0; }; \
	  $(PERL) -lne $(find_upper_case_var) $(texi_files)

check-local: check-texinfo
