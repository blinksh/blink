#!/bin/sh
# Ensure "ls --color" doesn't output colors for TERM=dumb

# Copyright (C) 2014-2017 Free Software Foundation, Inc.

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

# Output time as something constant
export TIME_STYLE="+norm"

touch exe || framework_failure_
chmod u+x exe || framework_failure_

# output colors
LS_COLORS='' COLORTERM='nonempty' TERM='' ls --color=always exe >> out || fail=1
LS_COLORS='' COLORTERM='' TERM='xterm' ls --color=always exe >> out || fail=1

# Don't output colors
LS_COLORS='' COLORTERM='' TERM='dumb' ls --color=always exe >> out || fail=1
LS_COLORS='' COLORTERM='' TERM='' ls --color=always exe >> out || fail=1

cat -A out > out.display || framework_failure_
mv out.display out || framework_failure_

cat <<\EOF > exp || framework_failure_
^[[0m^[[01;32mexe^[[0m$
^[[0m^[[01;32mexe^[[0m$
exe$
exe$
EOF

compare exp out || fail=1

Exit $fail
