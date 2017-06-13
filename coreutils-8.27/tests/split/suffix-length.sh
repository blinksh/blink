#!/bin/sh
# Show that split -a works.

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

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ split

a_z='a b c d e f g h i j k l m n o p q r s t u v w x y z'

# Generate a 27-byte file
printf %s $a_z 0 |tr -d ' ' > in || framework_failure_

files=
for i in $a_z; do
  files="${files}xa$i "
done
files="${files}xba"

for f in $files; do
  printf "creating file '%s'"'\n' $f
done > exp || framework_failure_

echo split: output file suffixes exhausted \
  > exp-too-short || framework_failure_


# This should fail.
split -b 1 -a 1 in 2> err && fail=1
test -f xa || fail=1
test -f xz || fail=1
test -f xaa && fail=1
test -f xaz && fail=1
rm -f x*
compare exp-too-short err || fail=1

# With a longer suffix, it must succeed.
split --verbose -b 1 -a 2 in > err || fail=1
compare exp err || fail=1

# Ensure that xbb is *not* created.
test -f xbb && fail=1

# Ensure that the 27 others files *were* created, and with expected contents.
n=1
for f in $files; do
  expected_byte=$(cut -b $n in)
  b=$(cat $f) || fail=1
  test "$b" = "$expected_byte" || fail=1
  n=$(expr $n + 1)
done

# Ensure that -a is independent of -[bCl]
split -a2 -b1000 < /dev/null || fail=1
split -a2 -l1000 < /dev/null || fail=1
split -a2 -C1000 < /dev/null || fail=1

# Ensure that -a fails early with a -n that is too large
rm -f x*
returns_ 1 split -a2 -n1000 < /dev/null || fail=1
test -f xaa && fail=1

Exit $fail
