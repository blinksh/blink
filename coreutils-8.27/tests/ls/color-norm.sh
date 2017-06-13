#!/bin/sh
# Ensure "ls --color" properly colors "normal" text and files.
# I.e., that it uses NORMAL to style non file name output and
# file names with no associated color (unless FILE is also set).

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
print_ver_ ls

# Don't let a different umask perturb the results.
umask 22

# Output time as something constant
export TIME_STYLE="+norm"

# helper to strip ls columns up to "norm" time
qls() { sed 's/-r.*norm/norm/'; }

touch exe || framework_failure_
chmod u+x exe || framework_failure_
touch nocolor || framework_failure_

TCOLORS="no=7:ex=01;32"

# Non coloured files inherit NORMAL attributes
LS_COLORS=$TCOLORS      ls -gGU --color exe nocolor | qls >> out || fail=1
LS_COLORS=$TCOLORS      ls -xU  --color exe nocolor       >> out || fail=1
LS_COLORS=$TCOLORS      ls -gGU --color nocolor exe | qls >> out || fail=1
LS_COLORS=$TCOLORS      ls -xU  --color nocolor exe       >> out || fail=1

# NORMAL does not override FILE though
LS_COLORS=$TCOLORS:fi=1 ls -gGU --color nocolor exe | qls >> out || fail=1

# Support uncolored ordinary files that do _not_ inherit from NORMAL.
# Note there is a redundant RESET output before a non colored
# file in this case which may be removed in future.
LS_COLORS=$TCOLORS:fi=  ls -gGU --color nocolor exe | qls >> out || fail=1
LS_COLORS=$TCOLORS:fi=0 ls -gGU --color nocolor exe | qls >> out || fail=1

# A caveat worth noting is that commas (-m), indicator chars (-F)
# and the "total" line, do not currently use NORMAL attributes
LS_COLORS=$TCOLORS      ls -mFU --color nocolor exe       >> out || fail=1

# Ensure no coloring is done unless enabled
LS_COLORS=$TCOLORS      ls -gGU         nocolor exe | qls >> out || fail=1

cat -A out > out.display || framework_failure_
mv out.display out || framework_failure_

cat <<\EOF > exp || framework_failure_
^[[0m^[[7mnorm ^[[m^[[01;32mexe^[[0m$
^[[7mnorm nocolor^[[0m$
^[[0m^[[7m^[[m^[[01;32mexe^[[0m  ^[[7mnocolor^[[0m$
^[[0m^[[7mnorm nocolor^[[0m$
^[[7mnorm ^[[m^[[01;32mexe^[[0m$
^[[0m^[[7mnocolor^[[0m  ^[[7m^[[m^[[01;32mexe^[[0m$
^[[0m^[[7mnorm ^[[m^[[1mnocolor^[[0m$
^[[7mnorm ^[[m^[[01;32mexe^[[0m$
^[[0m^[[7mnorm ^[[m^[[mnocolor^[[0m$
^[[7mnorm ^[[m^[[01;32mexe^[[0m$
^[[0m^[[7mnorm ^[[m^[[0mnocolor^[[0m$
^[[7mnorm ^[[m^[[01;32mexe^[[0m$
^[[0m^[[7mnocolor^[[0m, ^[[7m^[[m^[[01;32mexe^[[0m*$
norm nocolor$
norm exe$
EOF

compare exp out || fail=1

Exit $fail
