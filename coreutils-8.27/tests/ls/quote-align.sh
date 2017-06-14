#!/bin/sh
# test quote alignment combinations

# Copyright (C) 2016-2017 Free Software Foundation, Inc.

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

dirname='dir:name'
mkdir "$dirname" || framework_failure_
touch "$dirname/a b" "$dirname/c.foo" || framework_failure_

e=$(printf '\033')
color_code='0;31;42'
c_pre="$e[0m$e[${color_code}m"
c_post="$e[0m"

cat <<EOF >exp || framework_failure_
'$dirname':
'a b'  ${c_pre}c.foo${c_post}
'$dirname':
'a b'   ${c_pre}c.foo${c_post}
'$dirname':
'a b'
 ${c_pre}c.foo${c_post}
'$dirname':
'a b'
${c_pre}c.foo${c_post}
'$dirname':
'a b', ${c_pre}c.foo${c_post}
'$dirname':
'a b'   ${c_pre}c.foo${c_post}

EOF

for opt in '-w0 -x' '-x' '-og' '-1' '-m' '-C'; do
  env TERM=xterm LS_COLORS="*.foo=$color_code" TIME_STYLE=+T \
    ls $opt -R --quoting=shell-escape --color=always "$dirname" >> out || fail=1
done

# Append a newline, to accommodate less-capable versions of sed.
echo >> out || fail=1

# Strip possible varying portion of long format
sed -e 's/.*T //' -e '/^total/d' out > k && mv k out

compare exp out || fail=1

Exit $fail
