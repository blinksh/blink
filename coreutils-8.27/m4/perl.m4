# serial 9

dnl From Jim Meyering.
dnl Find a new-enough version of Perl.

# Copyright (C) 1998-2001, 2003-2004, 2007, 2009-2017 Free Software Foundation,
# Inc.
#
# This file is free software; the Free Software Foundation
# gives unlimited permission to copy and/or distribute it,
# with or without modifications, as long as this notice is preserved.

AC_DEFUN([gl_PERL],
[
  dnl FIXME: don't hard-code 5.005
  AC_MSG_CHECKING([for perl5.005 or newer])
  if test "${PERL+set}" = set; then
    # 'PERL' is set in the user's environment.
    candidate_perl_names="$PERL"
    perl_specified=yes
  else
    candidate_perl_names='perl perl5'
    perl_specified=no
  fi

  found=no
  AC_SUBST([PERL])
  PERL="$am_missing_run perl"
  for perl in $candidate_perl_names; do
    # Run test in a subshell; some versions of sh will print an error if
    # an executable is not found, even if stderr is redirected.
    if ( $perl -e 'require 5.005; use File::Compare' ) > /dev/null 2>&1; then
      PERL=$perl
      found=yes
      break
    fi
  done

  AC_MSG_RESULT([$found])
  test $found = no && AC_MSG_WARN([
WARNING: You don't seem to have perl5.005 or newer installed, or you lack
         a usable version of the Perl File::Compare module.  As a result,
         you may be unable to run a few tests or to regenerate certain
         files if you modify the sources from which they are derived.
] )
])
