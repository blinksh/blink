#!/bin/sh
# tests for printf %q

# Copyright (C) 2015-2017 Free Software Foundation, Inc.

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
print_ver_ printf

prog='env printf'

# Equivalent output to ls --quoting=shell-escape
$prog '%q\n' '' "'" a 'a b' '~a' 'a~' "$($prog %b 'a\r')" > out
cat <<\EOF > exp || framework_failure_
''
"'"
a
'a b'
'~a'
a~
'a'$'\r'
EOF
compare exp out || fail=1

unset LC_ALL
f=$LOCALE_FR_UTF8
: ${LOCALE_FR_UTF8=none}
if test "$LOCALE_FR_UTF8" != "none"; then
  (
   #printable multi-byte
   LC_ALL=$f $prog '%q\n' 'áḃç' > out
   #non-printable multi-byte
   LC_ALL=$f $prog '%q\n' "$($prog '\xc2\x81')" >> out
   #printable multi-byte in C locale
   LC_ALL=C $prog '%q\n' 'áḃç' >> out
  )
  cat <<\EOF > exp || framework_failure_
áḃç
''$'\302\201'
''$'\303\241\341\270\203\303\247'
EOF
  compare exp out || fail=1
fi

Exit $fail
