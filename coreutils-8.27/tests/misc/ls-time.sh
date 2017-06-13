#!/bin/sh
# Test some of ls's sorting options.

# Copyright (C) 1998-2017 Free Software Foundation, Inc.

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

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ ls

# Avoid any possible glitches due to daylight-saving changes near the
# timestamps used during the test.
TZ=UTC0
export TZ

t1='1998-01-15 21:00'
t2='1998-01-15 22:00'
t3='1998-01-15 23:00'

u1='1998-01-14 11:00'
u2='1998-01-14 12:00'
u3='1998-01-14 13:00'

touch -m -d "$t3" a || framework_failure_
touch -m -d "$t2" b || framework_failure_
touch -m -d "$t1" c || framework_failure_

touch -a -d "$u3" c || framework_failure_
touch -a -d "$u2" b || framework_failure_
# Make sure A has ctime at least 1 second more recent than C's.
sleep 2
touch -a -d "$u1" a || framework_failure_
# Updating the atime is usually enough to update the ctime, but on
# Solaris 10's tmpfs, ctime is not updated, so force an update here:
{ ln a a-ctime && rm a-ctime; } || framework_failure_


# A has ctime more recent than C.
set $(ls -c a c)
test "$*" = 'a c' || fail=1

# Sleep so long in an attempt to avoid spurious failures
# due to NFS caching and/or clock skew.
sleep 2

# Create a link, updating c's ctime.
ln c d || framework_failure_

# Before we go any further, verify that touch's -m option works.
set -- $(ls --full -l a)
case "$*" in
  *" $t3:00.000000000 +0000 a") ;;
  *)
  # This might be what's making HPUX 11 systems fail this test.
  cat >&2 << EOF
A basic test of touch -m has just failed, so the subsequent
tests in this file will not be run.

In the output below, the date of last modification for 'a' should
have been $t3.
EOF
  ls --full -l a
  skip_ "touch -m -d '$t3' didn't work"
  ;;
esac

# Ensure that touch's -a option works.
set -- $(ls --full -lu a)
case "$*" in
  *" $u1:00.000000000 +0000 a") ;;
  *)
  # This might be what's making HPUX 11 systems fail this test.
  cat >&2 << EOF
A fundamental touch -a test has just failed, so the subsequent
tests in this file will not be run.

In the output below, the date of last access for 'a' should
have been $u1.
EOF
  ls --full -lu a
  Exit 77
  ;;
esac

set $(ls -ut a b c)
test "$*" = 'c b a' && : || fail=1
test $fail = 1 && ls -l --full-time --time=access a b c

set $(ls -t a b c)
test "$*" = 'a b c' && : || fail=1
test $fail = 1 && ls -l --full-time a b c

# Now, C should have ctime more recent than A.
set $(ls -ct a c)
if test "$*" = 'c a'; then
  : ok
else
  # In spite of documentation, (e.g., stat(2)), neither link nor chmod
  # update a file's st_ctime on SunOS4.1.4.
  cat >&2 << \EOF
failed ls ctime test -- this failure is expected at least for SunOS4.1.4
and for tmpfs file systems on Solaris 5.5.1.
It is also expected to fail on a btrfs file system until
https://bugzilla.redhat.com/591068 is addressed.

In the output below, 'c' should have had a ctime more recent than
that of 'a', but does not.
EOF
  #'
  ls -ctl --full-time a c
  fail=1
fi

# This check is ineffective if:
#   en_US locale is not on the system.
#   The system en_US message catalog has a specific TIME_FMT translation,
#   which was inadvertently the case between coreutils 8.1 and 8.5 inclusive.

if gettext --version >/dev/null 2>&1; then

  default_tf1='%b %e  %Y'
  en_tf1=$(LC_ALL=en_US gettext coreutils "$default_tf1")

  if test "$default_tf1" = "$en_tf1"; then
    LC_ALL=en_US ls -l c >en_output
    ls -l --time-style=long-iso c >liso_output
    if compare en_output liso_output; then
      fail=1
      echo "Long ISO TIME_FMT being used for en_US locale." >&2
    fi
  fi
fi

Exit $fail
