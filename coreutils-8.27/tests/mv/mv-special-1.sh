#!/bin/sh
# Test "mv" with special files.

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

null=mv-null
dir=mv-dir

rm -f $null || framework_failure_
mknod $null p || framework_failure_
test -p $null || framework_failure_
mkdir -p $dir/a/b/c $dir/d/e/f || framework_failure_
touch $dir/a/b/c/file1 $dir/d/e/f/file2 || framework_failure_

# We used to...
# exit 77 here to indicate that we couldn't run the test.
# At least running on SunOS 4.1.4, using a directory NFS mounted
# from an OpenBSD system, the above mknod fails.
# It's not worth making an exception any more.

mv --verbose $null $dir "$other_partition_tmpdir" > out || fail=1
# Make sure the files are gone.
test -p $null && fail=1
test -d $dir && fail=1
# Make sure they were moved.
test -p "$other_partition_tmpdir/$null" || fail=1
test -d "$other_partition_tmpdir/$dir/a/b/c" || fail=1

# POSIX says rename (A, B) can succeed if A and B are on different file systems,
# so ignore chatter about when files are removed and copied rather than renamed.
sed "
  /^removed /d
  s,$other_partition_tmpdir,XXX,
" out | sort > out2

cat <<EOF | sort > exp
'$null' -> 'XXX/$null'
'$dir' -> 'XXX/$dir'
'$dir/a' -> 'XXX/$dir/a'
'$dir/a/b' -> 'XXX/$dir/a/b'
'$dir/a/b/c' -> 'XXX/$dir/a/b/c'
'$dir/a/b/c/file1' -> 'XXX/$dir/a/b/c/file1'
'$dir/d' -> 'XXX/$dir/d'
'$dir/d/e' -> 'XXX/$dir/d/e'
'$dir/d/e/f' -> 'XXX/$dir/d/e/f'
'$dir/d/e/f/file2' -> 'XXX/$dir/d/e/f/file2'
EOF

compare exp out2 || fail=1

# cd "$other_partition_tmpdir"
# ls -l -A -R "$other_partition_tmpdir"

Exit $fail
