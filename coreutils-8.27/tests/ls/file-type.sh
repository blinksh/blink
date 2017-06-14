#!/bin/sh
# contrast ls -F, ls -p, and ls --indicator-style=file-type

# Copyright (C) 2002-2017 Free Software Foundation, Inc.

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

mkdir sub
cd sub
mkdir dir
touch regular executable
chmod a+x executable
ln -s regular slink-reg
ln -s dir slink-dir
ln -s nowhere slink-dangle
mknod block b 20 20 2> /dev/null && block="block
"
mknod char c 10 10 2> /dev/null && char="char
"
mkfifo_or_skip_ fifo
cd ..



ls -F sub > out || fail=1
cat <<EOF > exp
$block${char}dir/
executable*
fifo|
regular
slink-dangle@
slink-dir@
slink-reg@
EOF

sed 's/\*//' exp > exp2
ls --indicator-style=file-type sub > out2 || fail=1

sed 's/[@|]$//' exp2 > exp3
ls -p sub > out3 || fail=1

compare exp out || fail=1

compare exp2 out2 || fail=1

compare exp3 out3 || fail=1

ls --color=auto -F sub > out || fail=1
compare exp out || fail=1

Exit $fail
