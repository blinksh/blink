#!/bin/sh
# ensure that 'cp -d' preserves hard-links between command line arguments
# ensure that --preserve=links works with -RH and -RL

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
print_ver_ cp

touch a || framework_failure_
ln a b || framework_failure_
mkdir c || framework_failure_
cp -d a b c || framework_failure_
test -f c/a || framework_failure_
test -f c/b || framework_failure_


a_inode=$(ls -i c/a|sed 's,c/.*,,')
b_inode=$(ls -i c/b|sed 's,c/.*,,')
test "$a_inode" = "$b_inode" || fail=1
# --------------------------------------

rm -rf a b c
touch a
ln -s a b
mkdir c
cp --preserve=links -R -H a b c || fail=1
a_inode=$(ls -i c/a|sed 's,c/.*,,')
b_inode=$(ls -i c/b|sed 's,c/.*,,')
test "$a_inode" = "$b_inode" || fail=1
# --------------------------------------

# Ensure that -L makes cp follow the b->a symlink
# and translates to hard-linked a and b in the destination dir.
rm -rf a b c d; mkdir d; (cd d; touch a; ln -s a b)
cp --preserve=links -R -L d c || fail=1
a_inode=$(ls -i c/a|sed 's,c/.*,,')
b_inode=$(ls -i c/b|sed 's,c/.*,,')
test "$a_inode" = "$b_inode" || fail=1
# --------------------------------------

# Same as above, but starting with a/b hard linked.
rm -rf a b c d; mkdir d; (cd d; touch a; ln a b)
cp --preserve=links -R -L d c || fail=1
a_inode=$(ls -i c/a|sed 's,c/.*,,')
b_inode=$(ls -i c/b|sed 's,c/.*,,')
test "$a_inode" = "$b_inode" || fail=1
# --------------------------------------

# Ensure that --no-preserve=links works.
rm -rf a b c d; mkdir d; (cd d; touch a; ln a b)
cp -dR --no-preserve=links d c || fail=1
a_inode=$(ls -i c/a|sed 's,c/.*,,')
b_inode=$(ls -i c/b|sed 's,c/.*,,')
test "$a_inode" = "$b_inode" && fail=1
# --------------------------------------

# Ensure that -d still preserves hard links.
rm -rf a b c d
touch a; ln a b
mkdir c
cp -d a b c || fail=1
a_inode=$(ls -i c/a|sed 's,c/.*,,')
b_inode=$(ls -i c/b|sed 's,c/.*,,')
test "$a_inode" = "$b_inode" || fail=1
# --------------------------------------

# Ensure that --no-preserve=mode works
rm -rf a b c d
touch a; chmod 731 a
umask 077
cp -a --no-preserve=mode a b || fail=1
mode=$(ls -l b|cut -b-10)
test "$mode" = "-rw-------" || fail=1
umask 022
# --------------------------------------

Exit $fail
