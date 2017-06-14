#!/bin/sh
# Test case conversion classes

# Copyright (C) 2010-2017 Free Software Foundation, Inc.

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
print_ver_ tr

# Ensure we support translation of case classes with extension
echo '01234567899999999999999999' > exp
echo 'abcdefghijklmnopqrstuvwxyz' |
tr '[:lower:]' '0-9' > out || fail=1
compare exp out || fail=1
echo 'abcdefghijklmnopqrstuvwxyz' |
tr '[:lower:][:lower:]' '[:upper:]0-9' > out || fail=1
compare exp out || fail=1

# Validate the alignment of case classes
returns_ 1 tr 'A-Z[:lower:]' 'a-y[:upper:]' </dev/null || fail=1
returns_ 1 tr '[:upper:][:lower:]' 'a-y[:upper:]' </dev/null || fail=1
returns_ 1 tr 'A-Y[:lower:]' 'a-z[:upper:]' </dev/null || fail=1
returns_ 1 tr 'A-Z[:lower:]' '[:lower:][:upper:]' </dev/null || fail=1
returns_ 1 tr 'A-Z[:lower:]' '[:lower:]A-Z' </dev/null || fail=1
tr '[:upper:][:lower:]' 'a-z[:upper:]' < /dev/null || fail=1
tr '[:upper:][:lower:]' '[:upper:]a-z' < /dev/null || fail=1

# Before coreutils 8.6 the trailing space in string1
# caused the case class in string2 to be extended.
# However that was not portable, dependent on locale
# and in contravention of POSIX.
tr '[:upper:] ' '[:lower:]' < /dev/null 2>out && fail=1
echo 'tr: when translating with string1 longer than string2,
the latter string must not end with a character class' > exp
compare exp out || fail=1

# Up to coreutils-6.9, tr rejected an unmatched [:lower:] or [:upper:] in SET1.
echo '#$%123abcABC' | tr '[:lower:]' '[.*]' > out || fail=1
echo '#$%123...ABC' > exp
compare exp out || fail=1
echo '#$%123abcABC' | tr '[:upper:]' '[.*]' > out || fail=1
echo '#$%123abc...' > exp
compare exp out || fail=1

# When doing a case-converting translation with something after the
# [:upper:] and [:lower:] elements, ensure that tr honors the following byte.
echo 'abc.' | tr '[:lower:].' '[:upper:]x' > out || fail=1
echo 'ABCx' > exp
compare exp out || fail=1

# Before coreutils 8.6 the disparate number of upper and lower
# characters in some locales, triggered abort()s and invalid behavior
export LC_ALL=en_US.ISO-8859-1

if test "$(locale charmap 2>/dev/null)" = ISO-8859-1; then
  # Up to coreutils-6.9.91, this would fail with the diagnostic:
  # tr: misaligned [:upper:] and/or [:lower:] construct
  # with LC_CTYPE=en_US.ISO-8859-1.
  tr '[:upper:]' '[:lower:]' < /dev/null || fail=1

  tr '[:upper:] ' '[:lower:]' < /dev/null 2>out && fail=1
  echo 'tr: when translating with string1 longer than string2,
the latter string must not end with a character class' > exp
  compare exp out || fail=1

  # Ensure when there are a different number of elements
  # in each string, we validate the case mapping correctly
  echo 'abc.xyz' |
  tr 'ab[:lower:]' '0-1[:upper:]' > out || fail=1
  echo 'ABC.XYZ' > exp
  compare exp out || fail=1

  # Ensure we extend string2 appropriately
  echo 'ABC- XYZ' |
  tr '[:upper:]- ' '[:lower:]_' > out || fail=1
  echo 'abc__xyz' > exp
  compare exp out || fail=1

  # Ensure the size of the case classes are accounted
  # for as a unit.
  echo 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' |
  tr '[:upper:]A-B' '[:lower:]0' >out || fail=1
  echo '00cdefghijklmnopqrstuvwxyz' > exp
  compare exp out || fail=1

  # Ensure the size of the case classes are accounted
  # for as a unit.
  echo 'a' |
  tr -t '[:lower:]a' '[:upper:]0' >out || fail=1
  echo '0' > exp
  compare exp out || fail=1

  # Ensure the size of the case classes are accounted
  # for as a unit.
  echo 'a' |
  tr -t '[:lower:][:lower:]a' '[:lower:][:upper:]0' >out || fail=1
  echo '0' > exp
  compare exp out || fail=1
fi

Exit $fail
