#!/bin/sh

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
print_ver_ dd

# count_bytes
echo 0123456789abcdefghijklm > in || framework_failure_
dd count=14 conv=swab iflag=count_bytes < in > out 2> /dev/null || fail=1
case $(cat out) in
 1032547698badc) ;;
 *) fail=1 ;;
esac

# skip_bytes
echo 0123456789abcdefghijklm > in || framework_failure_
dd skip=10 iflag=skip_bytes < in > out 2> /dev/null || fail=1
case $(cat out) in
 abcdefghijklm) ;;
 *) fail=1 ;;
esac

# skip records and bytes from pipe
echo 0123456789abcdefghijklm |
 dd skip=10 bs=2 iflag=skip_bytes > out 2> /dev/null || fail=1
case $(cat out) in
 abcdefghijklm) ;;
 *) fail=1 ;;
esac

# seek bytes
echo abcdefghijklm |
 dd bs=5 seek=8 oflag=seek_bytes > out 2> /dev/null || fail=1
printf '\0\0\0\0\0\0\0\0abcdefghijklm\n' > expected
compare expected out || fail=1

# Just truncation, no I/O
dd bs=5 seek=8 oflag=seek_bytes of=out2 count=0 2> /dev/null || fail=1
truncate -s8 expected2
compare expected2 out2 || fail=1

Exit $fail
