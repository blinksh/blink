#!/bin/sh
# Test annotation of sort keys

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
print_ver_ sort printf

number() { cat -n | sed 's/^ *//'; }

cat <<\EOF > exp
1
 ^ no match for key

^ no match for key
44
  ^ no match for key
33
  ^ no match for key
2
 ^ no match for key
1
 ^ no match for key

^ no match for key
44
  ^ no match for key
33
  ^ no match for key
2
 ^ no match for key

^ no match for key
1
_
2
_
33
__
44
__
2>
  ^ no match for key
3>1
  _
1>2
  _
1
 ^ no match for key

^ no match for key
44
  ^ no match for key
33
  ^ no match for key
2
 ^ no match for key
1
 ^ no match for key

^ no match for key
44
  ^ no match for key
33
  ^ no match for key
2
 ^ no match for key

^ no match for key
1
_
2
_
33
__
44
__
2>
  ^ no match for key
3>1
  _
1>2
  _
1
 ^ no match for key

^ no match for key
44
  ^ no match for key
33
  ^ no match for key
2
 ^ no match for key
1
 ^ no match for key

^ no match for key
44
  ^ no match for key
33
  ^ no match for key
2
 ^ no match for key

^ no match for key
1
_
2
_
33
__
44
__
2>
  ^ no match for key
3>1
  _
1>2
  _

^ no match for key
JAN
___
FEB
___
FEB
   ^ no match for key

^ no match for key
JAN
   ^ no match for key
JAZZ
^ no match for key

^ no match for key
JAN
___
FEB
___
2>JAZZ
  ^ no match for key
3>
  ^ no match for key
4>JAN
  ___
1>FEB
  ___

^ no match for key
JANZ
___
JAN
___
FEB
___
3>
  ^ no match for key
2>JANZ
  ___
4>JAN
  ___
1>FEB
  ___
 1.2ignore
 ___
 1.1e4ignore
 _____
>>a
___
>b
__
a
 ^ no match for key

^ no match for key
a
_
b
_
-3
__
-2
__
-0
__
--Mi-1
^ no match for key
-0
__
1
_
 1
 _
__
1
_
_
 1
 _
1
_
 1
__
1
_
2,5
_
2.4
___
2.,,3
__
2.4
___
2,,3
_
2.4
___
1a
_
2b
_
>a
 _
A>chr10
     ^ no match for key
B>chr1
     ^ no match for key
1 2
 __
1 3
 __
EOF

(
for type in n h g; do
  printf '1\n\n44\n33\n2\n' | sort -s -k2$type --debug
  printf '1\n\n44\n33\n2\n' | sort -s -k1.3$type --debug
  printf '1\n\n44\n33\n2\n' | sort -s -k1$type --debug
  printf '2\n\n1\n' | number | sort -s -k2g --debug
done

printf 'FEB\n\nJAN\n' | sort -s -k1M --debug
printf 'FEB\n\nJAN\n' | sort -s -k2,2M --debug
printf 'FEB\nJAZZ\n\nJAN\n' | sort -s -k1M --debug
printf 'FEB\nJAZZ\n\nJAN\n' | number | sort -s -k2,2M --debug
printf 'FEB\nJANZ\n\nJAN\n' | sort -s -k1M --debug
printf 'FEB\nJANZ\n\nJAN\n' | number | sort -s -k2,2M --debug

printf ' 1.2ignore\n 1.1e4ignore\n' | sort -s -g --debug

printf '\tb\n\t\ta\n' | sort -s -d --debug # ignore = 1

printf 'a\n\n' | sort -s -k2,2 --debug #lena = 0

printf 'b\na\n' | sort -s -k1 --debug #otherwise key compare

printf -- '-0\n1\n-2\n--Mi-1\n-3\n-0\n' | sort -s --debug -k1,1h

printf ' 1\n1\n' | sort -b --debug
printf ' 1\n1\n' | sort -sb --debug
printf ' 1\n1\n' | sort --debug

# strnumcmp is a bit weird, so we don't match exactly
printf '2,5\n2.4\n' | sort -s -k1n --debug
printf '2.,,3\n2.4\n' | sort -s -k1n --debug
printf '2,,3\n2.4\n' | sort -s -k1n --debug

# -z means we convert \0 to \n
env printf '1a\x002b\x00' | sort -s -n -z --debug

# Check that \0 and \t intermix.
printf '\0\ta\n' | sort -s -k2b,2 --debug | tr -d '\0'

# Check that key end before key start is not underlined
printf 'A\tchr10\nB\tchr1\n' | sort -s -k2.4b,2.3n --debug

# Ensure that -b applied before -k offsets
printf '1 2\n1 3\n' | sort -s -k1.2b --debug
) > out

compare exp out || fail=1

cat <<\EOF > exp
   1²---++3   1,234  Mi
               _
   _________
________________________
   1²---++3   1,234  Mi
              _____
   ________
_______________________
+1234 1234Gi 1,234M
^ no match for key
_____
^ no match for key
      ____
      ____
      _____
             _____
             _____
             ______
___________________
EOF

unset LC_ALL
f=$LOCALE_FR_UTF8

: ${LOCALE_FR_UTF8=none}
if test "$LOCALE_FR_UTF8" != "none"; then
  (
  echo '   1²---++3   1,234  Mi' |
    LC_ALL=C sort --debug -k2g -k1b,1
  echo '   1²---++3   1,234  Mi' |
    LC_COLLATE=$f LC_CTYPE=$f LC_NUMERIC=$f LC_MESSAGES=C \
        sort --debug -k2g -k1b,1
  echo '+1234 1234Gi 1,234M' |
    LC_COLLATE=$f LC_CTYPE=$f LC_NUMERIC=$f LC_MESSAGES=C \
      sort --debug -k1,1n -k1,1g \
        -k1,1h -k2,2n -k2,2g -k2,2h -k3,3n -k3,3g -k3,3h
  ) > out
  compare exp out || fail=1
fi

Exit $fail
