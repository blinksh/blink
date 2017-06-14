#!/bin/sh
# test diagnostics are printed when seeking too far in seekable files.

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
print_ver_ dd
require_sparse_support_ # for 'truncate --size=$OFF_T_MAX'
eval $(getlimits) # for OFF_T limits


printf "1234" > file || framework_failure_

echo "\
dd: 'standard input': cannot skip to specified offset
0+0 records in
0+0 records out" > skip_err || framework_failure_

# skipping beyond number of blocks in file should issue a warning
dd bs=1 skip=5 count=0 status=noxfer < file 2> err || fail=1
compare skip_err err || fail=1

# skipping beyond number of bytes in file should issue a warning
dd bs=3 skip=2 count=0 status=noxfer < file 2> err || fail=1
compare skip_err err || fail=1

# skipping beyond number of blocks in pipe should issue a warning
cat file | dd bs=1 skip=5 count=0 status=noxfer 2> err || fail=1
compare skip_err err || fail=1

# skipping beyond number of bytes in pipe should issue a warning
cat file | dd bs=3 skip=2 count=0 status=noxfer 2> err || fail=1
compare skip_err err || fail=1

# Check seeking beyond file already offset into
# skipping beyond number of blocks in file should issue a warning
(dd bs=1 skip=1 count=0 2>/dev/null &&
 dd bs=1 skip=4 status=noxfer 2> err) < file || fail=1
compare skip_err err || fail=1

# Check seeking beyond file already offset into
# skipping beyond number of bytes in file should issue a warning
(dd bs=1 skip=1 count=0 2>/dev/null &&
 dd bs=2 skip=2 status=noxfer 2> err) < file || fail=1
compare skip_err err || fail=1

# seeking beyond end of file is OK
dd bs=1 seek=5 count=0 status=noxfer > file 2> err || fail=1
echo "0+0 records in
0+0 records out" > err_ok || framework_failure_
compare err_ok err || fail=1

# skipping > OFF_T_MAX should fail immediately
dd bs=1 skip=$OFF_T_OFLOW count=0 status=noxfer < file 2> err && fail=1
# error message should be "... cannot skip: strerror(EOVERFLOW)"
grep "cannot skip:" err >/dev/null || fail=1

# skipping > max file size should fail immediately
if ! truncate --size=$OFF_T_MAX in 2>/dev/null; then
  # truncate is to ensure file system doesn't actually support OFF_T_MAX files
  dd bs=1 skip=$OFF_T_MAX count=0 status=noxfer < file 2> err \
    && lseek_ok=yes \
    || lseek_ok=no

  if test $lseek_ok = yes; then
    # On Solaris 10 at least, lseek(>max file size) succeeds,
    # so just check for the skip warning.
    compare skip_err err || fail=1
  else
    # On Linux kernels at least, lseek(>max file size) fails.
    # error message should be "... cannot skip: strerror(EINVAL)"
    grep "cannot skip:" err >/dev/null || fail=1
  fi
fi

Exit $fail
