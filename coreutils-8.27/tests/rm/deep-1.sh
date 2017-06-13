#!/bin/sh
# Test "rm" with a deep hierarchy.

# Copyright (C) 1997-2017 Free Software Foundation, Inc.

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

# This is a bit of a torture test for mkdir -p, too.
# GNU rm performs *much* better on systems that have a d_type member
# in the directory structure because then it does only one stat per
# command line argument.

# If this test takes too long on your system, blame the OS.

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ rm

umask 022


k20=/k/k/k/k/k/k/k/k/k/k/k/k/k/k/k/k/k/k/k/k
k200=$k20$k20$k20$k20$k20$k20$k20$k20$k20$k20

# Be careful not to exceed max file name length (usu 512?).
# Doing so wouldn't affect GNU mkdir or GNU rm, but any tool that
# operates on the full pathname (like 'test') would choke.
k_deep=$k200$k200

t=t
# Create a directory in $t with lots of 'k' components.
deep=$t$k_deep
mkdir -p $deep || fail=1

# Make sure the deep dir was created.
test -d $deep || fail=1

rm -r $t || fail=1

# Make sure all of $t was deleted.
test -d $t && fail=1

Exit $fail
