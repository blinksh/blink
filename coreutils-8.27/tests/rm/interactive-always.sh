#!/bin/sh
# Test the --interactive[=WHEN] changes added to coreutils 6.0

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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
print_ver_ rm

touch file1-1 file1-2 file2-1 file2-2 file3-1 file3-2 file4-1 file4-2 \
  || framework_failure_
# If asked, answer no to first question, then yes to second.
echo 'n
y' > in || framework_failure_
rm -f out err || framework_failure_


# The prompt has a trailing space, and no newline, so an extra
# 'echo .' is inserted after each rm to make it obvious what was asked.

echo 'no WHEN' > err || fail=1
rm -R --interactive file1-* < in >> out 2>> err || fail=1
echo . >> err || fail=1
test -f file1-1 || fail=1
test -f file1-2 && fail=1

echo 'WHEN=never' >> err || fail=1
rm -R --interactive=never file2-* < in >> out 2>> err || fail=1
echo . >> err || fail=1
test -f file2-1 && fail=1
test -f file2-2 && fail=1

echo 'WHEN=once' >> err || fail=1
rm -R --interactive=once file3-* < in >> out 2>> err || fail=1
echo . >> err || fail=1
test -f file3-1 || fail=1
test -f file3-2 || fail=1

echo 'WHEN=always' >> err || fail=1
rm -R --interactive=always file4-* < in >> out 2>> err || fail=1
echo . >> err || fail=1
test -f file4-1 || fail=1
test -f file4-2 && fail=1

echo '-f overrides --interactive' >> err || fail=1
rm -R --interactive=once -f file1-* < in >> out 2>> err || fail=1
echo . >> err || fail=1
test -f file1-1 && fail=1

echo '--interactive overrides -f' >> err || fail=1
rm -R -f --interactive=once file4-* < in >> out 2>> err || fail=1
echo . >> err || fail=1
test -f file4-1 || fail=1

cat <<\EOF > expout || fail=1
EOF
sed 's/@remove_empty/rm: remove regular empty file/g' <<\EOF > experr || fail=1
no WHEN
@remove_empty 'file1-1'? @remove_empty 'file1-2'? .
WHEN=never
.
WHEN=once
rm: remove 2 arguments recursively? .
WHEN=always
@remove_empty 'file4-1'? @remove_empty 'file4-2'? .
-f overrides --interactive
.
--interactive overrides -f
rm: remove 1 argument recursively? .
EOF

compare expout out || fail=1
compare experr err || fail=1

Exit $fail
