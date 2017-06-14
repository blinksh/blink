#!/bin/sh
# show how to skip an amount that is smaller than the nominal block size.
# There's a more realistic example in the documentation.

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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
print_ver_ dd


echo LA:3456789abcdef > in || fail=1
(dd bs=1 skip=3 count=0 && dd bs=5) < in > out 2> /dev/null || fail=1
case $(cat out) in
  3456789abcdef) ;;
  *) fail=1 ;;
esac

echo LA:3456789abcdef > in || fail=1
(dd bs=1 skip=3 count=0 && dd bs=5 count=2) < in > out 2> /dev/null || fail=1
case $(cat out) in
  3456789abc) ;;
  *) fail=1 ;;
esac

Exit $fail
