#!/bin/sh

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
print_ver_ ptx

# Trigger a heap-clobbering bug in ptx from coreutils-6.10 and earlier.
# Using a long file name makes an abort more likely.
# Even with no file name, valgrind detects the buffer overrun.
f=01234567890123456789012345678901234567890123456789
touch $f empty || framework_failure_

# Specifying a regular expression ending in a lone backslash
# would cause ptx to write beyond the end of a malloc'd buffer.
ptx -F '\'      $f < /dev/null  > out || fail=1
ptx -S 'foo\'   $f < /dev/null >> out || fail=1
ptx -W 'bar\\\' $f < /dev/null >> out || fail=1
compare out empty || fail=1


# Trigger an invalid heap reference noticed by gcc -fsanitize=address
# from coreutils-8.22 and earlier.  As well as an invalid memory reference,
# the issue can be seen in the output, with non deterministice whitespace
# trimming when multiple files are specified.
printf '%s\n' 'This is a ptx whitespace Trimming test' > ws.in
ptx ws.in ws.in | sort | uniq -u > out
compare /dev/null out || fail=1


# Trigger an invalid heap reference noticed by gcc -fsanitize=address
# from coreutils-8.25 and earlier.
echo a > a
ptx -w1 -A "$PWD/a" >/dev/null || fail=1

Exit $fail
