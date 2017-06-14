#!/bin/sh
# Test "nice".

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

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
print_ver_ nice

tests='
0 empty 10
1 -1 1
2 -12 12
3 -1:-2 2
4 -n:1 1
5 -n:1:-2 2
6 -n:1:-+12 12
7 -2:-n:1 1
8 -2:-n:12 12
9 -+1 1
10 -+12 12
11 -+1:-+12 12
12 -n:+1 1
13 --1:-2 2
14 --1:-2:-13 13
15 --1:-n:2 2
16 --1:-n:2:-3 3
17 --1:-n:2:-13 13
18 -n:-1:-12 12
19 --1:-12 12
NA LAST NA
'
set $tests

# Require that this test be run at 'nice' level 0.
niceness=$(nice)
if test "$niceness" = 0; then
    : ok
else
  skip_ "this test must be run at nice level 0"
fi

while :; do
  test_name=$1
  args=$2
  expected_result=$3
  test $args = empty && args=''
  test x$args = xLAST && break
  args=$(echo x$args|tr : ' '|sed 's/^x//')
  if test "$VERBOSE" = yes; then
    #echo "testing \$(nice $args nice\) = $expected_result ..."
    echo "test $test_name... " | tr -d '\n'
  fi
  test x$(nice $args nice 2> /dev/null) = x$expected_result \
    && ok=ok || ok=FAIL fail=1
  test "$VERBOSE" = yes && echo $ok
  shift; shift; shift
done

# Test negative niceness - command must be run whether or not change happens.
if test x$(nice -n -1 nice 2> /dev/null) = x0 ; then
  # unprivileged user - warn about failure to change
  nice -n -1 true 2> err || fail=1
  compare /dev/null err && fail=1
  mv err exp || framework_failure_
  nice --1 true 2> err || fail=1
  compare exp err || fail=1
  # Failure to write advisory message is fatal.  Buggy through coreutils 8.0.
  if test -w /dev/full && test -c /dev/full; then
    returns_ 125 nice -n -1 nice > out 2> /dev/full || fail=1
    compare /dev/null out || fail=1
  fi
else
  # superuser - change succeeds
  nice -n -1 nice 2> err || fail=1
  compare /dev/null err || fail=1
  test x$(nice -n -1 nice) = x-1 || fail=1
  test x$(nice --1 nice) = x-1 || fail=1
fi

Exit $fail
