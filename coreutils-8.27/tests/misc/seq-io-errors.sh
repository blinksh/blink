#!/bin/sh
# Test for proper detection of I/O errors in seq

# Copyright (C) 2016-2017 Free Software Foundation, Inc.

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
print_ver_ seq

if ! test -w /dev/full || ! test -c /dev/full; then
  skip_ '/dev/full is required'
fi

# Run 'seq' with a timeout, preventing infinite-loop run.
# expected returned codes:
#  1     - seq detected an I/O error and exited with an error.
#  124   - timed-out (seq likely infloop)
#  other - unexpected error
timed_seq_fail() { timeout 10 seq "$@" >/dev/full 2>/dev/null; }


# Test infinite sequence, using fast-path method (seq_fast).
returns_ 1 timed_seq_fail 1 inf || fail=1

# Test infinite sequence, using slow-path method (print_numbers).
returns_ 1 timed_seq_fail 1.1 .1 inf || fail=1

# Test non-infinite sequence, using slow-path method (print_numbers).
# (despite being non-infinite, the entire sequence should take long time to
#  print. Thus, either an I/O error is detected immediately, or seq will
#  timeout).
returns_ 1 timed_seq_fail 1 0.0001 99999999 || fail=1

Exit $fail
