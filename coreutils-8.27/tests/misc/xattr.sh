#!/bin/sh
# Ensure that cp --preserve=xattr, cp --preserve=all and mv preserve extended
# attributes and install does not preserve extended attributes.
# cp -a should preserve xattr, error diagnostics should not be displayed

# Copyright (C) 2009-2017 Free Software Foundation, Inc.

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
print_ver_ cp mv ginstall

# Skip this test if cp was built without xattr support:
touch src dest || framework_failure_
cp --preserve=xattr -n src dest \
  || skip_ "coreutils built without xattr support"

# this code was taken from test mv/backup-is-src
cleanup_() { rm -rf "$other_partition_tmpdir"; }
. "$abs_srcdir/tests/other-fs-tmpdir"
b_other="$other_partition_tmpdir/b"
rm -f "$b_other" || framework_failure_

# testing xattr name-value pair
xattr_name="user.foo"
xattr_value="bar"
xattr_pair="$xattr_name=\"$xattr_value\""

# create new file and check its xattrs
touch a || framework_failure_
getfattr -d a >out_a || skip_ "failed to get xattr of file"
grep -F "$xattr_pair" out_a && framework_failure_

# try to set user xattr on file
setfattr -n "$xattr_name" -v "$xattr_value" a >out_a \
  || skip_ "failed to set xattr of file"
getfattr -d a >out_a || skip_ "failed to get xattr of file"
grep -F "$xattr_pair" out_a \
  || skip_ "failed to set xattr of file"


# cp should not preserve xattr by default
cp a b || fail=1
getfattr -d b >out_b || skip_ "failed to get xattr of file"
grep -F "$xattr_pair" out_b && fail=1

# test if --preserve=xattr option works
cp --preserve=xattr a b || fail=1
getfattr -d b >out_b || skip_ "failed to get xattr of file"
grep -F "$xattr_pair" out_b || fail=1

# test if --preserve=all option works
cp --preserve=all a c || fail=1
getfattr -d c >out_c || skip_ "failed to get xattr of file"
grep -F "$xattr_pair" out_c || fail=1

# cp's -a option must produce no diagnostics.
cp -a a d 2>err && { compare /dev/null err || fail=1; }
getfattr -d d >out_d || skip_ "failed to get xattr of file"
grep -F "$xattr_pair" out_d || fail=1

# test if --preserve=xattr works even for files without write access
chmod a-w a || framework_failure_
rm -f e
cp --preserve=xattr a e || fail=1
getfattr -d e >out_e || skip_ "failed to get xattr of file"
grep -F "$xattr_pair" out_e || fail=1

# Ensure that permission bits are preserved, too.
src_perm=$(stat --format=%a a)
dst_perm=$(stat --format=%a e)
test "$dst_perm" = "$src_perm" || fail=1

chmod u+w a || framework_failure_

rm b || framework_failure_

# install should never preserve xattr
ginstall a b || fail=1
getfattr -d b >out_b || skip_ "failed to get xattr of file"
grep -F "$xattr_pair" out_b && fail=1

# mv should preserve xattr when renaming within a file system.
# This is implicitly done by rename () and doesn't need explicit
# xattr support in mv.
mv a b || fail=1
getfattr -d b >out_b || skip_ "failed to get xattr of file"
grep -F "$xattr_pair" out_b || cat >&2 <<EOF
=================================================================
$0: WARNING!!!
rename () does not preserve extended attributes
=================================================================
EOF

# try to set user xattr on file on other partition
test_mv=1
touch "$b_other" || framework_failure_
setfattr -n "$xattr_name" -v "$xattr_value" "$b_other" >out_a \
  || test_mv=0
getfattr -d "$b_other" >out_b || test_mv=0
grep -F "$xattr_pair" out_b || test_mv=0
rm -f "$b_other" || framework_failure_

if test $test_mv -eq 1; then
  # mv should preserve xattr when copying content from one partition to another
  mv b "$b_other" || fail=1
  getfattr -d "$b_other" >out_b ||
    skip_ "failed to get xattr of file"
  grep -F "$xattr_pair" out_b || fail=1
else
  cat >&2 <<EOF
=================================================================
$0: WARNING!!!
failed to set xattr of file $b_other
=================================================================
EOF
fi

Exit $fail
