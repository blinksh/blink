#!/bin/sh
# Test for complete lines on output

# Copyright (C) 2015-2017 Free Software Foundation, Inc.

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
print_ver_ factor


odd() { LC_ALL=C sed '/[24680]$/d'; }
primes() { LC_ALL=C sed 's/.*: //; / /d'; }

# Before v8.24 the number reported here would vary
# Note -u not supplied to split, increased batching of quickly processed items.
# As processing cost increases it becomes advantageous to use -u to keep
# the factor processes supplied with data.
nprimes=$(seq 1e6 | odd | split -nr/4 --filter='factor' | primes | wc -l)

test "$nprimes" = '78498' || fail=1

Exit $fail
