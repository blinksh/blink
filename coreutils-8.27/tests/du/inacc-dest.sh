#!/bin/sh
# Prior to coreutils-6.5, an inaccessible destination dir (chmod a-x)
# would cause du to exit prematurely on systems with native openat support.

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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
skip_if_root_

mkdir f && cd f && mkdir a b c d e && touch c/j && chmod a-x c \
    || framework_failure_

du > ../t 2>&1 && fail=1

# Accept either of the following outputs.
# You get the first from a system with openat _emulation_ (via /proc),
# the second from a system with native openat support.
# FIXME: there may well be a third output, for systems with neither
# /proc support, nor native openat support.

sed 's/^[0-9][0-9]*	//' ../t | sort -u > out
cat <<\EOF > exp || fail=1
.
./a
./b
./c
./d
./e
du: cannot read directory './c': Permission denied
EOF

# Map a diagnostic like this
#   du: cannot access './c/j': Permission denied
# to this:
#   du: cannot access './c': Permission denied
# And accept "cannot read directory" in place of "cannot access"
sed "s,/c/j': ,/c': ," out > t && mv t out
sed 's,cannot access,cannot read directory,' out > t && mv t out

compare exp out || fail=1

Exit $fail
