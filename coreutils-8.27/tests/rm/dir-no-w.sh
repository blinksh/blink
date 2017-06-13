#!/bin/sh
# rm (without -r) must give a diagnostic for any directory.
# It must not prompt, even if that directory is unwritable.

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
print_ver_ rm

mkdir --mode=0500 unwritable-dir || framework_failure_


# For rm from coreutils-5.0.1, this would prompt.
rm ---presume-input-tty unwritable-dir < /dev/null > out-t 2>&1 && fail=1
cat <<\EOF > exp || fail=1
rm: cannot remove 'unwritable-dir': Is a directory
EOF

# When run by a non-privileged user we get this:
# rm: cannot remove directory 'unwritable-dir': Is a directory
# When run by root we get this:
# rm: cannot remove 'unwritable-dir': Is a directory
# Normalize the message.
sed 's/remove directory/remove/' out-t > out
rm -f out-t

compare exp out || fail=1

Exit $fail
