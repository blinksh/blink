#!/bin/sh
# Validate sleep parameters

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
print_ver_ sleep
getlimits_

# invalid timeouts
returns_ 1 timeout 10 sleep invalid || fail=1
returns_ 1 timeout 10 sleep -- -1 || fail=1
returns_ 1 timeout 10 sleep 42D || fail=1
returns_ 1 timeout 10 sleep 42d 42day || fail=1
returns_ 1 timeout 10 sleep nan || fail=1
returns_ 1 timeout 10 sleep '' || fail=1
returns_ 1 timeout 10 sleep || fail=1

# subsecond actual sleep
timeout 10 sleep 0.001 || fail=1
timeout 10 sleep 0x.002p1 || fail=1

# Using small timeouts for larger sleeps is racy,
# but false positives should be avoided on most systems
returns_ 124 timeout 0.1 sleep 1d 2h 3m 4s || fail=1
returns_ 124 timeout 0.1 sleep inf || fail=1
returns_ 124 timeout 0.1 sleep $LDBL_MAX || fail=1

Exit $fail
