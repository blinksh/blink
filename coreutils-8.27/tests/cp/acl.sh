#!/bin/sh
# copy files/directories across file system boundaries
# and make sure acls are preserved appropriately

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
print_ver_ cp

require_acl_

# Skip this test if cp was built without ACL support:
grep '^#define USE_ACL 1' $CONFIG_HEADER > /dev/null ||
  skip_ "insufficient ACL support"

mkdir -p a b || framework_failure_
touch a/file || framework_failure_

# Ensure that setfacl and getfacl work on this file system.
skip=no
acl1=$(cd a && getfacl file) || skip=yes
setfacl -m user:bin:rw- a/file 2> /dev/null || skip=yes
test $skip = yes &&
  skip_ "'.' is not on a suitable file system for this test"

# copy a file without preserving permissions
cp a/file b/ || fail=1
acl2=$(cd b && getfacl file) || framework_failure_
test "$acl1" = "$acl2" || fail=1

# Update with acl set above
acl1=$(cd a && getfacl file) || framework_failure_

# copy a file, preserving permissions
cp -p a/file b/ || fail=1
acl2=$(cd b && getfacl file) || framework_failure_
test "$acl1" = "$acl2" || fail=1

# copy a file, preserving permissions, with --attributes-only
echo > a/file || framework_failure_ # add some data
test -s a/file || framework_failure_
cp -p --attributes-only a/file b/ || fail=1
compare /dev/null b/file || fail=1
acl2=$(cd b && getfacl file) || framework_failure_
test "$acl1" = "$acl2" || fail=1

Exit $fail
