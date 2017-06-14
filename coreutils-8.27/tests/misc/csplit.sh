#!/bin/sh
# various csplit tests

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

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ csplit


# csplit could get a failed assertion to 2.0.17
(echo a; echo; echo) > in
csplit in '/^$/' 2 > out || fail=1
cat <<EOF > exp
2
0
2
EOF
compare exp out || fail=1
rm -f in out exp

# Ensure that xx02 contains just two newlines.
# This would fail due to reading from freed buffer with coreutils-5.0.91.
printf '\n\n' > exp
cp xx02 out || fail=1
compare exp out || fail=1
rm -f in out exp

# csplit would infloop
(echo; echo a) > in
csplit in '/a/-1' '{*}' > out || fail=1
cat <<EOF > exp
0
3
EOF
compare exp out || fail=1
rm -f in out exp

# 'echo |csplit - 1 1' used to abort.
echo > in
csplit in 1 1 > out 2> err || fail=1
cat <<EOF > exp
0
0
1
EOF
compare exp out || fail=1
cat <<\EOF > experr
csplit: warning: line number '1' is the same as preceding line number
EOF
compare experr err || fail=1
rm -f in out exp err experr

# 'echo | csplit -b '%0#6.3x' - 1' incorrectly warned about the format
# up through coreutils 8.6.
echo > in
csplit -b '%0#6.3x' in 1 > out 2> err || fail=1
cat <<EOF > exp
0
1
EOF
compare exp out || fail=1
touch experr
compare experr err || fail=1
compare 'xx   000' experr || fail=1
compare 'xx 0x001' in || fail=1
rm -f in out exp err experr xx*

# make sure 'csplit FILE 0' fails.
echo > in
csplit in 0 > out 2> err && fail=1
csplit in 2 1 > out 2>> err && fail=1
csplit in 3 3 > out 2>> err && fail=1
cat <<\EOF > experr
csplit: 0: line number must be greater than zero
csplit: line number '1' is smaller than preceding line number, 2
csplit: warning: line number '3' is the same as preceding line number
csplit: '3': line number out of range
EOF
compare experr err || fail=1

# Ensure that lines longer than the initial buffer length don't cause
# trouble (e.g. reading from freed memory, resulting in corrupt output).
# This test failed at least in coreutils-5.2.1 and 5.3.0, and was fixed
# in 5.3.1.
rm -f in out exp err experr xx??
printf 'x%8199s\nx\n%8199s\nx\n' x x > in
csplit in '/x\{1\}/' '{*}' > /dev/null || fail=1
cat xx?? | compare - in || fail=1

Exit $fail
