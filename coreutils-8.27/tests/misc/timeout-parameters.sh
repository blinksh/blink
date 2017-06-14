#!/bin/sh
# Validate timeout parameter combinations

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
print_ver_ timeout
getlimits_


# internal errors are 125, distinct from execution failure

# invalid timeout
returns_ 125 timeout invalid sleep 0 || fail=1

# invalid kill delay
returns_ 125 timeout --kill-after=invalid 1 sleep 0 || fail=1

# invalid timeout suffix
returns_ 125 timeout 42D sleep 0 || fail=1

# It was seen on 32 bit Linux/HPPA that a kernel time_t overflowed,
# thus causing the timer to fire immediately.
# So verify that doesn't happen before checking large timeouts
KERNEL_OVERFLOW_LIMIT=$(expr $TIME_T_MAX - $(date +%s) + 100) ||
  skip_ "failed to adjust TIME_T_MAX $TIME_T_MAX"
timeout $KERNEL_OVERFLOW_LIMIT sleep 0
if test $? != 124; then
  # timeout overflow
  timeout $UINT_OFLOW sleep 0 || fail=1

  # timeout overflow
  timeout ${TIME_T_OFLOW}d sleep 0 || fail=1

  # floating point notation
  timeout 2.34e+5d sleep 0 || fail=1

  # floating point overflow
  timeout $LDBL_MAX sleep 0 || fail=1
  returns_ 125 timeout -- -$LDBL_MAX sleep 0 || fail=1
fi

# floating point notation
timeout 10.34 sleep 0 || fail=1

# nanoseconds potentially supported
timeout 9.999999999 sleep 0 || fail=1

# invalid signal spec
returns_ 125 timeout --signal=invalid 1 sleep 0 || fail=1

# invalid command
returns_ 126 timeout 10 . || fail=1

# no such command
returns_ 127 timeout 10 no_such || fail=1

Exit $fail
