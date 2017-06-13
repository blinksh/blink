#!/bin/sh
# make sure 'sum -s' works for input whose sum of bytes is larger than 2^32

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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

# Avoid a problem when run in a UTF-8 locale.
# Otherwise, Perl would try to (and fail to) interpret
# each string below as a sequence of multi-byte characters.
LC_ALL=C
export LC_ALL

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ sum

require_perl_

# FYI, 16843009 is floor (2^32 / 255).

# aka: perl -e 'print chr(255) x 16843009'
$PERL -e '$s = chr(255) x 65537; foreach (1..257) {print $s}' \
  | sum -s > out || fail=1
cat > exp <<\EOF
65535 32897
EOF
compare exp out || fail=1

rm -f out exp

# aka: perl -e 'print chr(255) x 16843010'
$PERL -e '$s = chr(255) x 65537; foreach (1..257) {print $s}; print chr(255)' \
  | sum -s > out || fail=1
cat > exp <<\EOF
254 32897
EOF
compare exp out || fail=1

Exit $fail
