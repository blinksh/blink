#!/bin/sh
# 'md5sum' tests for generation and checking of
# BSD traditional and alternate formats (md5 [-r])

# Copyright (C) 2011-2017 Free Software Foundation, Inc.

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
print_ver_ md5sum

## BSD alternate format tests ##

# Ensure we can --check BSD alternate format.
# Note we start this list with a name
# that's unambiguous in BSD format.
# I.e., one not starting with ' ' or '*'
for i in 'a' ' b' '*c' 'dd' ' '; do
  echo "$i" > "$i"
  md5sum "$i" >> check.md5sum || fail=1
done
sed 's/  / /' check.md5sum > check.md5

# Note only a single format is supported per run
md5sum --strict -c check.md5sum || fail=1
md5sum --strict -c check.md5 || fail=1

# If we skip the first entry in the BSD format checksums
# then it'll be detected as standard format and error.
# This unlikely caveat was thought better than mandating
# an option to avoid the ambiguity.
tail -n+2 check.md5 | returns_ 1 md5sum --strict -c || fail=1


## BSD traditional format tests (--tag option) ##

# Ensure --tag and --check are mutually exclusive
returns_ 1 md5sum --tag --check /dev/null || fail=1

# Ensure --tag and --text are mutually exclusive
# We don't support --text with BSD tradition format,
# as that would complicate the output format,
# while providing little benefit over --text processing
# available with the default md5sum output format.
returns_ 1 md5sum --tag --text /dev/null || fail=1

# Ensure we can --check BSD traditional format we produce
rm check.md5
for i in 'a' ' b' '*c' 'dd' ' '; do
  echo "$i" > "$i"
  md5sum --tag "$i" >> check.md5 || fail=1
done
md5sum --strict -c check.md5 || fail=1

# Ensure we can --check BSD traditional format we produce
# with the GNU extension of escaped newlines
nl='
'
tab='	'
rm check.md5
for i in 'a\b' 'a\' "a${nl}b" "a${tab}b"; do
  : > "$i"
  md5sum --tag "$i" >> check.md5 || fail=1
done
md5sum --strict -c check.md5 || fail=1

# Ensure BSD traditional format with GNU extension escapes
# is in the expected format
ex_file='test
\\file'
ex_output='\MD5 (test\n\\\\file) = d41d8cd98f00b204e9800998ecf8427e'
touch "$ex_file"
printf "%s\n" "$ex_output" > exp
md5sum --tag "$ex_file" > out || fail=1
compare exp out || fail=1

Exit $fail
