#! /bin/sh
# Test suite for exclude.
# Copyright (C) 2010-2017 Free Software Foundation, Inc.
# This file is part of the GNUlib Library.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

. "${srcdir=.}/init.sh"; path_prepend_ .
fail=0

# Test escaped metacharacters.

cat > in <<'EOT'
f\*e
b[a\*]r
EOT

cat > expected <<'EOT'
f*e: 1
file: 0
bar: 1
EOT

test-exclude -wildcards in -- 'f*e' 'file' 'bar' > out || exit $?

# Find out how to remove carriage returns from output. Solaris /usr/ucb/tr
# does not understand '\r'.
case $(echo r | tr -d '\r') in '') cr='\015';; *) cr='\r';; esac

# normalize output
LC_ALL=C tr -d "$cr" < out > k && mv k out

compare expected out || fail=1

Exit $fail
