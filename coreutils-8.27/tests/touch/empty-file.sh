#!/bin/sh
# Make sure touch can set the mtime on an empty file.

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


# Volker Borchert reported that touch 3.16r (and presumably all before that)
# fails to work on SunOS 4.1.3 with 'most of the recommended patches' when
# the empty file is on an NFS-mounted 4.2 volume.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ touch

DEFAULT_SLEEP_SECONDS=2
SLEEP_SECONDS=${SLEEP_SECONDS=$DEFAULT_SLEEP_SECONDS}


# FIXME: find writable directories on other partitions
# and run the test in those directories, too.

: ${TOUCH_DIR_LIST=.}


for d in $TOUCH_DIR_LIST; do
  rm -rf $d/a $d/b $d/c
  > $d/a || framework_failure_
  test -f $d/a || framework_failure_
  > $d/b || framework_failure_
  test -f $d/b || framework_failure_
  > $d/c || framework_failure_
  test -f $d/c || framework_failure_
done

echo sleeping for $SLEEP_SECONDS seconds...
sleep $SLEEP_SECONDS
for d in $TOUCH_DIR_LIST; do
  touch $d/a || fail=1
  set x $(ls -t $d/a $d/b)
  test "$*" = "x $d/a $d/b" || fail=1
done

echo sleeping for $SLEEP_SECONDS seconds...
sleep $SLEEP_SECONDS
for d in $TOUCH_DIR_LIST; do
  touch $d/b
  set x $(ls -t $d/a $d/b)
  test "$*" = "x $d/b $d/a" || fail=1

  if touch - 1< $d/c 2> /dev/null; then
    set x $(ls -t $d/a $d/c)
    test "$*" = "x $d/c $d/a" || fail=1
  fi

  rm -rf $d/a $d/b $d/c
done

if test $fail != 0; then
  cat 1>&2 <<EOF
*** This test has just failed.  That can happen when the test is run in an
*** NFS-mounted directory on a system whose clock is not well synchronized
*** with that of the NFS server.  If you think that is the reason, set the
*** environment variable SLEEP_SECONDS to some number of seconds larger than
*** the default of $DEFAULT_SLEEP_SECONDS and rerun the test.
EOF
fi

Exit $fail
