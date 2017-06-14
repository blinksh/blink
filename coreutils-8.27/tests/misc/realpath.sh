#!/bin/sh
# Validate realpath operation

# Copyright (C) 2011-2017 Free Software Foundation, Inc.

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
print_ver_ realpath

stat_single=$(stat -c %d:%i /) || framework_failure_
stat_double=$(stat -c %d:%i //) || framework_failure_
double_slash=//
if test x"$stat_single" = x"$stat_double"; then
  double_slash=/
fi
nl='
'

test -d /dev || framework_failure_

# Setup dir, file, symlink structure

mkdir -p dir1/dir2 || framework_failure_
ln -s dir1/dir2 ldir2 || framework_failure_
touch dir1/f dir1/dir2/f || framework_failure_
ln -s / one || framework_failure_
ln -s // two || framework_failure_
ln -s /// three || framework_failure_

# Basic operation
realpath -Pqz . >/dev/null || fail=1
# Operand is required
returns_ 1 realpath >/dev/null || fail=1
returns_ 1 realpath --relative-base . --relative-to . || fail=1
returns_ 1 realpath --relative-base . || fail=1

# -e --relative-* require directories
returns_ 1 realpath -e --relative-to=dir1/f --relative-base=. . || fail=1
realpath -e --relative-to=dir1/  --relative-base=. . || fail=1

# Note NUL params are unconditionally rejected by canonicalize_filename_mode
returns_ 1 realpath -m '' || fail=1
returns_ 1 realpath --relative-base= --relative-to=. . || fail=1

# symlink resolution
this=$(realpath .)
test "$(realpath ldir2/..)" = "$this/dir1" || fail=1
test "$(realpath -L ldir2/..)" = "$this" || fail=1
test "$(realpath -s ldir2)" = "$this/ldir2" || fail=1

# relative string handling
test $(realpath -m --relative-to=prefix prefixed/1) = '../prefixed/1' || fail=1
test $(realpath -m --relative-to=prefixed prefix/1) = '../prefix/1' || fail=1
test $(realpath -m --relative-to=prefixed prefixed/1) = '1' || fail=1

# Ensure no redundant trailing '/' present, as was the case in v8.15
test $(realpath -sm --relative-to=/usr /) = '..' || fail=1
# Ensure no redundant leading '../' present, as was the case in v8.15
test $(realpath -sm --relative-to=/ /usr) = 'usr' || fail=1

# Ensure --relative-base works
out=$(realpath -sm --relative-base=/usr --relative-to=/usr /tmp /usr) || fail=1
test "$out" = "/tmp$nl." || fail=1
out=$(realpath -sm --relative-base=/ --relative-to=/ / /usr) || fail=1
test "$out" = ".${nl}usr" || fail=1
# --relative-to defaults to the value of --relative-base
out=$(realpath -sm --relative-base=/usr /tmp /usr) || fail=1
test "$out" = "/tmp$nl." || fail=1
out=$(realpath -sm --relative-base=/ / /usr) || fail=1
test "$out" = ".${nl}usr" || fail=1
# For now, --relative-base must be a prefix of --relative-to, or all output
# will be absolute (compare to MacOS 'relpath -d dir start end').
out=$(realpath -sm --relative-base=/usr/local --relative-to=/usr \
    /usr /usr/local) || fail=1
test "$out" = "/usr${nl}/usr/local" || fail=1

# Ensure // is handled correctly.
test "$(realpath / // ///)" = "/$nl$double_slash$nl/" || fail=1
test "$(realpath one two three)" = "/$nl$double_slash$nl/" || fail=1
out=$(realpath -sm --relative-to=/ / // /dev //dev) || fail=1
if test $double_slash = //; then
  test "$out" = ".$nl//${nl}dev$nl//dev" || fail=1
else
  test "$out" = ".$nl.${nl}dev${nl}dev" || fail=1
fi
out=$(realpath -sm --relative-to=// / // /dev //dev) || fail=1
if test $double_slash = //; then
  test "$out" = "/$nl.$nl/dev${nl}dev" || fail=1
else
  test "$out" = ".$nl.${nl}dev${nl}dev" || fail=1
fi
out=$(realpath --relative-base=/ --relative-to=// / //) || fail=1
if test $double_slash = //; then
  test "$out" = "/$nl//" || fail=1
else
  test "$out" = ".$nl." || fail=1
fi

Exit $fail
