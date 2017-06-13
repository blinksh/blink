#!/bin/sh
# Ensure that using 'cp --preserve=link' to copy hard-linked arguments
# onto existing destinations works, even when one of the link operations fails.

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


# This bug was fixed in coreutils-4.5.9.
# To exercise this bug is non-trivial:
# Set-up requires at least three hard-linked files.  In copying them,
# while preserving links, the initial copy must succeed, the attempt
# to create the second file via 'link' must fail, and the final 'link'
# (to create the third) must succeed.  Before the corresponding fix,
# the first and third destination files would not be linked.
#
# Note that this is nominally a test of 'cp', yet it is in the tests/mv
# directory, because it requires use of the --preserve=link option that
# mv enables by default.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ cp
skip_if_root_

mkdir -p x dst/x || framework_failure_
touch dst/x/b || framework_failure_
chmod a-w dst/x
touch a || framework_failure_
ln a x/b || framework_failure_
ln a c || framework_failure_


# ======================================
# This must fail -- because x/b cannot be unlinked.
cp --preserve=link --parents a x/b c dst 2> /dev/null && fail=1

# Source files must remain.
test -f a || fail=1
test -f x/b || fail=1
test -f c || fail=1
cd dst

# Three destination files must exist.
test -f a || fail=1
test -f x/b || fail=1
test -f c || fail=1

# The i-node numbers of a and c must be the same.
ia=$(ls -i a) || fail=1; set x $ia; ia=$2
ic=$(ls -i c) || fail=1; set x $ic; ic=$2
test "$ia" = "$ic" || fail=1

# The i-node number of x/b must be different.
ib=$(ls -i x/b) || fail=1; set x $ib; ib=$2
test "$ia" = "$ib" && fail=1

Exit $fail
