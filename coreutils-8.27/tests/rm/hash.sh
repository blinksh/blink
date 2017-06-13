#!/bin/sh
# Exercise a bug that was fixed in 4.0s.
# Before then, rm would fail occasionally, sometimes via
# a failed assertion, others with a seg fault.

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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
print_ver_ rm
expensive_

# Create a hierarchy with 3*26 leaf directories, each at depth 153.
echo "$0: creating 78 trees, each of depth 153; this will take a while..." >&2
y=$(seq 1 150|tr -sc '\n' y|tr '\n' /)
for i in 1 2 3; do
  for j in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
    mkdir -p t/$i/$j/$y || framework_failure_
  done
done


rm -r t || fail=1

Exit $fail
