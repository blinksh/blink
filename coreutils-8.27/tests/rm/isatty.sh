#!/bin/sh
# Make sure 'chown 0 f; rm f' prompts before removing f.

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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
skip_if_root_


# Skip this test if there is no /dev/stdin file.
ls /dev/stdin >/dev/null 2>&1 \
  || skip_ 'there is no /dev/stdin file'

# Terminate any background processes
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

touch f
chmod 0 f
rm ---presume-input-tty f > out 2>&1 & pid=$!

# Wait a second, to give a buggy rm (as in fileutils-4.0.40)
# enough time to remove the file.
sleep 1

# The file must still exist.
test -f f || fail=1

cleanup_

# Note the trailing 'x' -- so I don't have to have a trailing
# blank in this file :-)
cat > exp <<\EOF
rm: remove write-protected regular empty file 'f'? x
EOF

# Append an 'x' and a newline.
echo x >> out

compare exp out || fail=1

Exit $fail
