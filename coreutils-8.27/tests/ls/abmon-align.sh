#!/bin/sh
# Ensure ls output is aligned when using abbreviated months from the locale

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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
print_ver_ ls

for mon in $(seq -w 12); do
    touch -d"+$mon month" $mon.ts || framework_failure_
done


# Note some of the following locales may be missing but if so
# we should fail back to the C locale which should be aligned

for format in "%b" "[%b" "%b]" "[%b]"; do
  for LOC in C gv_GB ga_IE fi_FI.utf8 zh_CN ar_SY $LOCALE_FR_UTF8; do
    # The sed usage here is slightly different from the original,
    # removing the \(.*\), to avoid triggering misbehavior in at least
    # GNU sed 4.2 (possibly miscompiled) on Mac OS X (Darwin 9.8.0).
    n_widths=$(
      LC_ALL=$LOC TIME_STYLE=+"$format" ls -lgG *.ts |
      LC_ALL=C sed 's/.\{15\}//;s/ ..\.ts$//;s/ /./g' |
      while read mon; do echo "$mon" | LC_ALL=$LOC wc -L; done |
      uniq | wc -l
    )
    test "$n_widths" = "1" || { fail=1; break 2; }
  done
done
if test "$fail" = "1"; then
   echo "misalignment detected in $LOC locale:"
   LC_ALL=$LOC TIME_STYLE=+%b ls -lgG *.ts
fi

Exit $fail
