#!/bin/sh
# Test the various OpenMP override options

# Copyright (C) 2017 Free Software Foundation, Inc.

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

unset OMP_NUM_THREADS
unset OMP_THREADS_LIMIT

avail=$(nproc) || fail=1
test $(($avail > 0)) || fail=1

#OMP_THREAD_LIMIT       OMP_NUM_THREADS     NPROC
echo "\
 -                      -                   $avail
 1                      -                   1
 1                      0                   1
 -                      0                   $avail
 -                      2,2,1               2
 -                      2,ignored           2
 -                      2bad                $avail
 -                      -2                  $avail
 1                      2,2,1               1
 0                      2,2,1               2
 1bad                   2,2,1               2
 1bad                   $(($avail+1)),2,1   $(($avail+1))
 1                      $(($avail+1))       1
 $(($avail+2))          $(($avail+1))       $(($avail+1))
 $(($avail+1))          $(($avail+2))       $(($avail+1))
 -                      $(($avail+1))       $(($avail+1))" |

while read OMP_THREAD_LIMIT OMP_NUM_THREADS NPROC; do
  test $OMP_THREAD_LIMIT = '-' && unset OMP_THREAD_LIMIT
  test $OMP_NUM_THREADS = '-' && unset OMP_NUM_THREADS
  export OMP_THREAD_LIMIT
  export OMP_NUM_THREADS
  test $(nproc) = $NPROC ||
    echo "[$OMP_THREAD_LIMIT] [$OMP_NUM_THREADS]" >> failed
done

test -e failed && fail=1

Exit $fail
