#!/bin/sh
# Ensure that hard-linked files are counted (and listed) only once.
# Likewise for excluded directories.
# Ensure that hard links _are_ listed twice when using --count-links.

# Copyright (C) 2003-2017 Free Software Foundation, Inc.

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
print_ver_ du

mkdir -p dir/sub
( cd dir &&
  { echo non-empty > f1
    ln f1 f2
    ln -s f1 f3
    echo non-empty > sub/F; } )

du -a -L --exclude=sub --count-links dir \
  | sed 's/^[0-9][0-9]*	//' | sort -r > out || fail=1

# For these tests, transform f1 or f2 or f3 (whichever name is find
# first) to f_.  That is necessary because, depending on the type of
# file system, du could encounter any of those linked files first,
# thus listing that one and not the others.
for args in '-L' 'dir' '-L dir'
do
  echo === >> out
  du -a --exclude=sub $args dir \
    | sed 's/^[0-9][0-9]*	//' | sed 's/f[123]/f_/' >> out || fail=1
done

cat <<\EOF > exp
dir/f3
dir/f2
dir/f1
dir
===
dir/f_
dir
===
dir/f_
dir/f_
dir
===
dir/f_
dir
EOF

compare exp out || fail=1

Exit $fail
