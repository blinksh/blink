#!/bin/sh
# Make sure we give a sensible diagnostic when a cross-device 'mv'
# fails, e.g., because the destination cannot be unlinked.
# This is a bit fragile since it relies on the string used
# for EPERM: 'permission denied'.

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
print_ver_ mv
skip_if_root_
cleanup_() { t=$other_partition_tmpdir; chmod -R 700 "$t"; rm -rf "$t"; }
. "$abs_srcdir/tests/other-fs-tmpdir"

touch k "$other_partition_tmpdir/k" || framework_failure_
chmod u-w "$other_partition_tmpdir" || framework_failure_


mv -f k "$other_partition_tmpdir" 2> out && fail=1
printf \
"mv: inter-device move failed: '%s' to '%s';"\
' unable to remove target: Permission denied\n' \
  k "$other_partition_tmpdir/k" >exp

# On some (less-compliant) systems, we get EPERM in this case.
# Accept either diagnostic.
cat <<EOF > exp2
mv: cannot move 'k' to '$other_partition_tmpdir/k': Permission denied
EOF

if cmp out exp >/dev/null 2>&1; then
  :
else
  if cmp out exp2; then
    :
  else
    fail=1
  fi
fi
test $fail = 1 && compare exp out

Exit $fail
