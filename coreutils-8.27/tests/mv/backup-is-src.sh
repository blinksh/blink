#!/bin/sh
# Force mv to use the copying code.

# Copyright (C) 1998-2017 Free Software Foundation, Inc.

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
cleanup_() { rm -rf "$other_partition_tmpdir"; }
. "$abs_srcdir/tests/other-fs-tmpdir"

a="$other_partition_tmpdir/a"
a2="$other_partition_tmpdir/a~"

rm -f "$a" "$a2" || framework_failure_
echo a > "$a" || framework_failure_
echo a2 > "$a2" || framework_failure_

# This mv command should exit nonzero.
mv --b=simple "$a2" "$a" > out 2>&1 && fail=1

sed \
   -e "s,mv:,XXX:," \
   -e "s,$a,YYY," \
   -e "s,$a2,ZZZ," \
  out > out2

cat > exp <<\EOF
XXX: backing up 'YYY' would destroy source;  'ZZZ' not moved
EOF

compare exp out2 || fail=1

Exit $fail
