#!/bin/sh
# Test the suffix auto width functionality

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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


# ensure auto widening is off when start number specified
truncate -s12 file.in || framework_failure_
returns_ 1 split file.in -b1 --numeric=89 || fail=1
test "$(ls -1 x* | wc -l)" = 11 || fail=1
rm -f x*

# ensure auto widening works when no start num specified
truncate -s91 file.in || framework_failure_
for prefix in 'x' 'xx' ''; do
    for add_suffix in '.txt' ''; do
      split file.in "$prefix" -b1 --numeric --additional-suffix="$add_suffix" \
        || fail=1
      test "$(ls -1 $prefix*[0-9]*$add_suffix | wc -l)" = 91 || fail=1
      test -e "${prefix}89$add_suffix" || fail=1
      test -e "${prefix}9000$add_suffix" || fail=1
      rm -f $prefix*[0-9]*$add_suffix
    done
done

# ensure auto width with --number and start num < number of files
# That's the single run use case which is valid to adjust suffix len
truncate -s100 file.in || framework_failure_
split --numeric-suffixes=1 --number=r/100 file.in || fail=1
rm -f x*

# ensure no auto width with --number and start num >= number of files
# That's the multi run use case which is invalid to adjust suffix len
# as that would result in an incorrect order for the total output file set
returns_ 1 split --numeric-suffixes=100 --number=r/100 file.in || fail=1

Exit $fail
