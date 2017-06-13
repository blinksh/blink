#!/bin/sh
# Test for proper detection of EPIPE with ignored SIGPIPE

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

(trap '' PIPE && yes | :) 2>&1 | grep -qF 'Broken pipe' ||
    skip_ 'trapping SIGPIPE is not supported'

# upon EPIPE with signals ignored, 'seq' should exit with an error.
timeout 10 sh -c \
  'trap "" PIPE && { seq inf 2>err; echo $? >code; } | head -n1' >out

# Exit-code must be 1, indicating 'write error'
echo 1 > exp || framework_failure_
compare exp out || fail=1
compare exp code || fail=1

# The error message must begin with "standard output:"
# (but don't hard-code the strerror text)
grep '^seq: standard output: ' err \
  || { warn_ "seq emitted incorrect error on EPIPE"; \
       cat err;\
       fail=1; }

Exit $fail
