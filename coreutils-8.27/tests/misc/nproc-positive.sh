#!/bin/sh
# Ensure that nproc prints a number > 0

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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
print_ver_ nproc

for mode in --all ''; do
    procs=$(nproc $mode)
    test "$procs" -gt 0 || fail=1
done

for i in -1000 0 1 1000; do
    procs=$(OMP_NUM_THREADS=$i nproc)
    test "$procs" -gt 0 || fail=1
done

for i in 0 ' 1' 1000; do
    procs=$(nproc --ignore="$i")
    test "$procs" -gt 0 || fail=1
done

for i in -1 N; do
    returns_ 1 nproc --ignore=$i || fail=1
done

procs=$(OMP_NUM_THREADS=42 nproc --ignore=40)
test "$procs" -eq 2 || fail=1

Exit $fail
