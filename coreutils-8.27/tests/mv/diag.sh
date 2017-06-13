#!/bin/sh
# make sure we get proper diagnostics: e.g., with --target-dir=d but no args

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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

touch f1 || framework_failure_
touch f2 || framework_failure_
touch d || framework_failure_

# These mv commands should all exit nonzero.

# Too few args.  This first one did fail, but with an incorrect diagnostic
# until fileutils-4.0u.
mv --target=. >> out 2>&1 && fail=1
mv no-file >> out 2>&1 && fail=1

# Target is not a directory.
mv f1 f2 f1 >> out 2>&1 && fail=1
mv --target=f2 f1 >> out 2>&1 && fail=1

cat > exp <<\EOF
mv: missing file operand
Try 'mv --help' for more information.
mv: missing destination file operand after 'no-file'
Try 'mv --help' for more information.
mv: target 'f1' is not a directory
mv: target 'f2' is not a directory
EOF

compare exp out || fail=1

Exit $fail
