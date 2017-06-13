#!/bin/sh
# Test "stty" with rows and columns.

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

# Setting this envvar to a very small value used to cause e.g., 'stty size'
# to generate slightly different output on certain systems.
COLUMNS=80
export COLUMNS

# Make sure we get English-language behavior.
# See the report about a possibly-related Solaris problem by Alexandre Peshansky
# <http://lists.gnu.org/archive/html/bug-coreutils/2004-10/msg00035.html>.
# Currently stty isn't localized, but it might be in the future.
LC_ALL=C
export LC_ALL

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ stty

require_controlling_input_terminal_
require_trap_signame_

trap '' TTOU # Ignore SIGTTOU

# Versions of GNU stty from shellutils-1.9.2c and earlier failed
# tests #2 and #4 when run on SunOS 4.1.3.

tests='
1 rows_40_columns_80 40_80
2 rows_1_columns_1 1_1
3 rows_40_columns_80 40_80
4 rows_1 1_80
5 columns_1 1_1
6 rows_40 40_1
7 rows_1 1_1
8 columns_80 1_80
9 rows_30 30_80
10 rows_0x1E 30_80
11 rows_036 30_80
NA LAST NA
'
set $tests

saved_size=$(stty size) && test -n "$saved_size" \
  || skip_ "can't get window size"

# Linux virtual consoles issue an error if you
# try to increase their size.  So skip in that case.
if test "x$saved_size" != "x0 0"; then
  srow=$(echo $saved_size | cut -d ' ' -f1)
  scol=$(echo $saved_size | cut -d ' ' -f2)
  stty rows $(expr $srow + 1) cols $(expr $scol + 1) ||
    skip_ "can't increase window size"
fi

while :; do
  test_name=$1
  args=$2
  expected_result="$(echo $3|tr _ ' ')"
  test "$args" = empty && args=''
  test "x$args" = xLAST && break
  args=$(echo x$args|tr _ ' '|sed 's/^x//')
  if test "$VERBOSE" = yes; then
    # echo "testing \$(stty $args; stty size\) = $expected_result ..."
    echo "test $test_name... " | tr -d '\n'
  fi
  stty $args || exit 1
  test x"$(stty size 2> /dev/null)" = "x$expected_result" \
    && ok=ok || ok=FAIL fail=1
  test "$VERBOSE" = yes && echo $ok
  shift; shift; shift
done

set x $saved_size
stty rows $2 columns $3 || exit 1

Exit $fail
