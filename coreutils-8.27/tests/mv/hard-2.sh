#!/bin/sh
# Ensure that moving hard-linked arguments onto existing destinations works.
# Likewise when using cp --preserve=link.

# Copyright (C) 2003-2017 Free Software Foundation, Inc.

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
print_ver_ cp mv

skip_if_root_

mkdir dst || framework_failure_
(cd dst && touch a b c) || framework_failure_
touch a || framework_failure_
ln a b || framework_failure_
ln a c || framework_failure_


# ======================================
cp --preserve=link a b c dst || fail=1
# The source files must remain.
test -f a || fail=1
test -f b || fail=1
test -f c || fail=1
cd dst

# Three destination files must exist.
test -f a || fail=1
test -f b || fail=1
test -f c || fail=1

# The three i-node numbers must be the same.
ia=$(ls -i a|sed 's/ a//')
ib=$(ls -i b|sed 's/ b//')
ic=$(ls -i c|sed 's/ c//')
test $ia = $ib || fail=1
test $ia = $ic || fail=1

cd ..
rm -f dst/[abc]
(cd dst && touch a b c)

# ======================================
mv a b c dst || fail=1

# The source files must be gone.
test -f a && fail=1
test -f b && fail=1
test -f c && fail=1
cd dst

# Three destination files must exist.
test -f a || fail=1
test -f b || fail=1
test -f c || fail=1

# The three i-node numbers must be the same.
ia=$(ls -i a|sed 's/ a//')
ib=$(ls -i b|sed 's/ b//')
ic=$(ls -i c|sed 's/ c//')
test $ia = $ib || fail=1
test $ia = $ic || fail=1

Exit $fail
