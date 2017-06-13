#!/bin/sh
# basic tests for printf

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

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

prog='env printf'

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ printf

getlimits_


# Verify the 3 methods of specifying "Escape":
printf '%s\n' . . . | tr . '\033' > exp
$prog '\x1b\n\33\n\e\n' > out || fail=1
compare exp out || fail=1

# This would fail (by printing the '--') for printf in sh-utils
# and in coreutils 4.5.1.
$prog -- 'foo\n' > out || fail=1
cat <<\EOF > exp
foo
EOF

compare exp out || fail=1

rm -f out exp
# Until coreutils-4.5.10, this would elicit a segfault.
$prog '1 %*sy\n' -3 x >  out || fail=1

# Until coreutils 5.2.2, this would succeed.
if POSIXLY_CORRECT=1 $prog '2 \x' >/dev/null 2>&1; then
  fail=1
else
  echo '2 failed, as expected' >> out
fi

# Until coreutils-4.5.12, these would fail.
$prog '3 \x40\n'      >> out || fail=1
POSIXLY_CORRECT=1 \
$prog '4 \x40\n'      >> out || fail=1
$prog '5 % +d\n' 234  >> out || fail=1

# This should print "6 !\n", but don't rely on '!' being the
# one-byte representation of octal 041.  With printf prior to
# coreutils-5.0.1, it would print six bytes: "6 \41\n".
$prog '6 \41\n' | tr '\41' '!' >> out

# Note that as of coreutils-5.0.1, printf with a format of '\0002x'
# prints a NUL byte followed by the digit '2' and an 'x'.
# By contrast bash's printf outputs the same thing as $(printf '\2x') does.
$prog '7 \2y \02y \002y \0002y\n' |tr '\0\2' '*=' >> out

$prog '8 %b %b %b %b\n' '\1y' '\01y' '\001y' '\0001y'|tr '\1' = >> out

$prog '9 %*dx\n' -2 0 >>out || fail=1

$prog '10 %.*dx\n' $INT_UFLOW 0 >>out || fail=1
returns_ 1 $prog '%.*dx\n' $INT_OFLOW 0 >>out 2> /dev/null || fail=1

$prog '11 %*c\n' 2 x >>out || fail=1

returns_ 1 $prog '%#d\n' 0 >>out 2> /dev/null || fail=1

returns_ 1 $prog '%0s\n' 0 >>out 2> /dev/null || fail=1

returns_ 1 $prog '%.9c\n' 0 >>out 2> /dev/null || fail=1

returns_ 1 $prog '%'\''s\n' 0 >>out 2> /dev/null || fail=1

cat <<\EOF > exp
1 x  y
2 failed, as expected
3 @
4 @
5 +234
6 !
7 =y =y =y *2y
8 =y =y =y =y
9 0 x
10 0x
11  x
EOF

compare exp out || fail=1

# Verify handling of single quote chars (\' or \")

$prog '%d\n' '"a'  >out 2>err   # valid
$prog '%d\n' '"a"' >>out 2>>err # invalid
$prog '%d\n' '"'   >>out 2>>err # invalid
$prog '%d\n' 'a'   >>out 2>>err # invalid

cat <<EOF > exp
97
97
0
0
EOF

# POSIX says strtoimax *may* set errno to EINVAL in the latter
# two cases.  So far, that happens at least on MacOS X 10.5.
# Map that output to the more common expected output.
sed 's/: Invalid.*/: expected a numeric value/' err > k && mv k err

cat <<EOF > exp_err
printf: warning: ": character(s) following character constant have been ignored
printf: '"': expected a numeric value
printf: 'a': expected a numeric value
EOF

compare exp out || fail=1
compare exp_err err || fail=1

Exit $fail
