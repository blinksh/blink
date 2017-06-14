#!/bin/sh
# Make sure chmod gives the right diagnostic for a readable,
# but inaccessible directory.

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
print_ver_ chmod
skip_if_root_

mkdir -p d/no-x/y a/b || framework_failure_
chmod u=rw d/no-x || framework_failure_


# This must exit nonzero.
chmod -R o=r d >/dev/null 2>out && fail=1

prog=chmod
# NOTE: this code is the same for all tests/*/no-x tests.
# Depending on whether fts is using native fdopendir, we see one
# of the following diagnostics (note also the /y suffix in one case):
#   prog: 'd/no-x': Permission denied
#   prog: cannot access 'd/no-x/y': Permission denied
#   prog: cannot read directory 'd/no-x': Permission denied
# Convert either of the latter two to the first one.
sed "s/^$prog: cannot access /$prog: /" out > t && mv t out
sed "s/^$prog: cannot read directory /$prog: /" out > t && mv t out
sed 's,d/no-x/y,d/no-x,' out > t && mv t out

cat <<EOF > exp
$prog: 'd/no-x': Permission denied
EOF

compare exp out || fail=1

cd a
# This will fail with ''chmod: fts_read failed: Permission denied''
# chmod must exit with status 1.
# Due to a bug in coreutils-5.93's fts.c, chmod would provoke
# an abort (exit with status 134) on recent glibc-based systems.
returns_ 1 chmod a-x . b 2> /dev/null || fail=1

Exit $fail
