#!/bin/sh
# ensure that ls --color works well when a colored name is wrapped

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

long_name=zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz.foo
touch $long_name || framework_failure_

e='\33'
color_code='0;31;42'
c_pre="$e[0m$e[${color_code}m"
c_post="$e[0m$e[K\n"
printf "$c_pre$long_name$c_post\n" > exp || framework_failure_

env TERM=xterm COLUMNS=80 LS_COLORS="*.foo=$color_code" TIME_STYLE=+T \
  ls -og --color=always $long_name > out || fail=1

# Append a newline, to accommodate less-capable versions of sed.
echo >> out || fail=1

sed 's/.*T //' out > k && mv k out

compare exp out || fail=1

Exit $fail
