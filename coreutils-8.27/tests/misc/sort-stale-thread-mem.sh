#!/bin/sh
# Trigger a bug that would cause 'sort' to reference stale thread stack memory.

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

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

# written by Jim Meyering and Paul Eggert

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ sort

very_expensive_
require_valgrind_

grep '^#define HAVE_PTHREAD_T 1' "$CONFIG_HEADER" > /dev/null ||
  skip_ 'requires pthreads'

# gensort output seems to trigger the failure more often,
# so prefer gensort if it is available.
(gensort -a 10000 in) 2>/dev/null ||
  seq -f %-98f 10000 | shuf > in ||
  framework_failure_

# On Fedora-17-beta (valgrind-3.7.0-2.fc17.x86_64), this evokes two
# "Conditional jump or move depends on uninitialised value(s)" errors,
# each originating from _dl_start.
valgrind --quiet --error-exitcode=3 sort --version > /dev/null ||
  framework_failure_ 'valgrind fails for trivial sort invocation'

# With the bug, 'sort' would fail under valgrind about half the time,
# on some circa-2010 multicore Linux platforms.  Run the test 100 times
# so that the probability of missing the bug should be about 1 in
# 2**100 on these hosts.
for i in $(seq 100); do
  valgrind --quiet --error-exitcode=3 \
      sort -S 100K --parallel=2 in > /dev/null ||
    { fail=$?; echo iteration $i failed; Exit $fail; }
done

Exit $fail
