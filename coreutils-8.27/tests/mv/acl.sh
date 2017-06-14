#!/bin/sh
# move files/directories across file system boundaries
# and make sure acls are preserved

# Copyright (C) 2005-2017 Free Software Foundation, Inc.

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

require_acl_

# Skip this test if cp was built without ACL support:
grep '^#define USE_ACL 1' $CONFIG_HEADER > /dev/null ||
  skip_ "insufficient ACL support"

cleanup_() { rm -rf "$other_partition_tmpdir"; }
. "$abs_srcdir/tests/other-fs-tmpdir"

touch file || framework_failure_
t1=$other_partition_tmpdir/t1
touch $t1 || framework_failure_

skip_partition=none
# Ensure that setfacl and getfacl work on this file system.
setfacl -m user:bin:rw- file 2> /dev/null || skip_partition=.
# And on the destination file system.
setfacl -m user:bin:rw- $t1 || skip_partition=$other_partition_tmpdir
acl1=$(getfacl file) || skip_partition=.

test $skip_partition != none &&
  skip_ "'$skip_partition' is not on a suitable file system for this test"

# move the access acl of a file
mv file "$other_partition_tmpdir" || fail=1
acl2=$(cd "$other_partition_tmpdir" && getfacl file) || framework_failure_
test "$acl1" = "$acl2" || fail=1

# move the access acl of a directory
mkdir dir || framework_failure_
setfacl -m user:bin:rw- dir || framework_failure_
acl1=$(getfacl dir) || framework_failure_
mv dir "$other_partition_tmpdir" || fail=1
acl2=$(cd "$other_partition_tmpdir" && getfacl dir) || framework_failure_
test "$acl1" = "$acl2" || fail=1

# move the default acl of a directory
mkdir dir2 || framework_failure_
setfacl -d -m user:bin:rw- dir2 || framework_failure_
acl1=$(getfacl dir2) || framework_failure_
mv dir2 "$other_partition_tmpdir" || fail=1
acl2=$(cd "$other_partition_tmpdir" && getfacl dir2) || framework_failure_
test "$acl1" = "$acl2" || fail=1

Exit $fail
