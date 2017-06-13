#!/bin/sh
# Make sure dd does the right thing when the input file descriptor
# is not rewound.

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


echo abcde > in
(dd skip=1 count=1 bs=1; dd skip=1 bs=1) < in > out 2> /dev/null || fail=1
case $(cat out) in
  bde) ;;
  *) fail=1 ;;
esac

Exit $fail
