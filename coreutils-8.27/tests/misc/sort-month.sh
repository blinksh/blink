#!/bin/sh
# Test sorting of abbreviated months from the locale

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
print_ver_ sort

locale --version >/dev/null 2>&1 ||
  skip_ 'The locale utility is not present'

# C will be used if the locale is not present
for LOC in "$LOCALE_FR" "$LOCALE_FR_UTF8" "ja_JP.utf8"; do
  mon="$(LC_ALL=$LOC locale abmon 2>/dev/null);"
  smon=$(LC_ALL=$LOC locale abmon 2>/dev/null |
          tr ';' '\n' | shuf | nl | LC_ALL=$LOC sort -k2,2M |
          cut -f2 | tr '\n' ';')
  test "$mon" = "$smon" || { fail=1; break; }
done

Exit $fail
