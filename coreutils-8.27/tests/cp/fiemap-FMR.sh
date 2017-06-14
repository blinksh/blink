#!/bin/sh
# Trigger a free-memory read bug in cp from coreutils-[8.11..8.19]

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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
print_ver_ cp

require_valgrind_
require_perl_
: ${PERL=perl}

$PERL -e 'for (1..600) { sysseek (*STDOUT, 4096, 1)' \
  -e '&& syswrite (*STDOUT, "a" x 1024) or die "$!"}' > j || fail=1
valgrind --quiet --error-exitcode=3 cp j j2 || fail=1
cmp j j2 || fail=1

Exit $fail
