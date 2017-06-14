#!/bin/sh
# Ensure that sort --sort-random doesn't sort.

# Copyright (C) 2005-2017 Free Software Foundation, Inc.

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
print_ver_ sort

seq 100 > in || framework_failure_


sort --random-sort in > out || fail=1

# Fail if the input is the same as the output.
# This is a probabilistic test :-)
# However, the odds of failure are very low: 1 in 100! (~ 1 in 10^158)
compare in out > /dev/null && { fail=1; echo "not random?" 1>&2; }

# Fail if the sorted output is not the same as the input.
sort -n out > out1
compare in out1 || { fail=1; echo "not a permutation" 1>&2; }

# If locale is available then use it to find a random non-C locale.
if (locale --version) > /dev/null 2>&1; then
  locale=$(locale -a | sort --random-sort | $AWK '/^.._/{print;exit}')
  LC_ALL=$locale sort --random-sort in > out1 || fail=1
  LC_ALL=$locale sort --random-sort in > out2 || fail=1

  # Fail if the output "randomly" is the same twice in a row.
  compare out1 out2 > /dev/null &&
    { fail=1; echo "not random with LC_ALL=$locale" 1>&2; }

  # Fail if the sorted output is not the same as the input.
  sort -n out > out1
  compare in out1 ||
    { fail=1; echo "not a permutation with LC_ALL=$locale" 1>&2; }
fi

Exit $fail
