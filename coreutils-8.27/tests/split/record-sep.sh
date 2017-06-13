#!/bin/sh
# test split with custom record separators

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
print_ver_ split

NL='
'

for sep in "$NL" '\0' ':'; do

  test "$sep" = "$NL" && tr='\n' || tr="$sep"

  for mode in '--lines=2' '--line-bytes=4' '--number=l/3' '--number=r/3'; do

    # Generate in default mode for comparison
    printf '1\n2\n3\n4\n5\n' > in || framework_failure_
    split $mode in || fail=1
    tr '\n' "$tr" < xaa > exp1
    tr '\n' "$tr" < xab > exp2
    tr '\n' "$tr" < xac > exp3

    rm -f x??

    # Generate output with specified --separator
    printf '1\n2\n3\n4\n5\n' | tr '\n' "$tr" > in || framework_failure_
    split $mode -t "$sep" in || fail=1

    compare exp1 xaa || fail=1
    compare exp2 xab || fail=1
    compare exp3 xac || fail=1
    test -f xad && fail=1
  done

done


#
# Test usage edge cases
#

# Should fail: '-t' requires an argument
returns_ 1 split -t </dev/null ||
  { warn_ "-t without argument did not trigger an error" ; fail=1 ; }

# should fail: multi-character separator
returns_ 1 split -txx </dev/null ||
  { warn_ "-txx did not trigger an error" ; fail=1 ; }

# should fail: different separators used
returns_ 1 split -ta -tb </dev/null ||
  { warn_ "-ta -tb did not trigger an error" ; fail=1 ; }

# should fail: different separators used, including default
returns_ 1 split -t"$NL" -tb </dev/null ||
  { warn_ "-t\$NL -tb did not trigger an error" ; fail=1 ; }

# should not fail: same separator used multiple times
split -t: -t: </dev/null ||
  { warn_ "-t: -t: triggered an error" ; fail=1 ; }


Exit $fail
