#!/bin/sh
# Ensure that cp/mv/ln don't clobber a just-copied/moved/linked file.
# With fileutils-4.1 and earlier, this test would fail for cp and mv.
# With coreutils-6.9 and earlier, this test would fail for ln.

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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
print_ver_ cp mv ln

skip_if_root_

mkdir a b c || framework_failure_
echo a > a/f || framework_failure_
echo b > b/f || framework_failure_


returns_ 1 cp a/f b/f c 2> /dev/null || fail=1
test -f a/f || fail=1
test -f b/f || fail=1
test -f c/f || fail=1
test "$(cat c/f)" = a || fail=1
rm -f c/f

# With --backup=numbered, it should succeed
cp --backup=numbered a/f b/f c || fail=1
test -f a/f || fail=1
test -f b/f || fail=1
test -f c/f || fail=1
test -f c/f.~1~ || fail=1
rm -f c/f*

returns_ 1 mv a/f b/f c 2> /dev/null || fail=1
test -f a/f && fail=1
test -f b/f || fail=1
test -f c/f || fail=1
test "$(cat c/f)" = a || fail=1

# Make sure mv still works when moving hard links.
# This is where the same_file test is necessary, and why
# we save file names in addition to dev/ino.
rm -f c/f* b/f
touch a/f
ln a/f b/g
mv a/f b/g c || fail=1
test -f a/f && fail=1
test -f b/g && fail=1
test -f c/f || fail=1
test -f c/g || fail=1

touch a/f b/f b/g
returns_ 1 mv a/f b/f b/g c 2> /dev/null || fail=1
test -f a/f && fail=1  # a/f should have been moved
test -f b/f || fail=1  # b/f should remain
test -f b/g && fail=1  # b/g should have been moved
test -f c/f || fail=1
test -f c/g || fail=1

# Test ln -f.

rm -f a/f b/f c/f
echo a > a/f || fail=1
echo b > b/f || fail=1
returns_ 1 ln -f a/f b/f c 2> /dev/null || fail=1
# a/f and c/f must be linked
test $(stat --format %i a/f) = $(stat --format %i c/f) || fail=1
# b/f and c/f must not be linked
test $(stat --format %i b/f) = $(stat --format %i c/f) && fail=1

Exit $fail
