#!/bin/sh
# A cross-partition move of a file in a sticky tmpdir and owned by
# someone else would evoke an invalid diagnostic:
# mv: cannot remove 'x': Operation not permitted
# Affects coreutils-6.0-6.9.

# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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
require_root_

cleanup_() { rm -rf "$other_partition_tmpdir"; }
. "$abs_srcdir/tests/other-fs-tmpdir"

# Set up to run a test where non-root user tries to move a root-owned
# file from a sticky tmpdir to a directory owned by that user on
# a different partition.

mkdir t || framework_failure_
chmod a=rwx,o+t t || framework_failure_
echo > t/root-owned || framework_failure_
chmod a+r t/root-owned || framework_failure_
chown "$NON_ROOT_USERNAME" "$other_partition_tmpdir" || framework_failure_

# We have to allow $NON_ROOT_USERNAME access to ".".
chmod go+x . || framework_failure_


# Ensure that $NON_ROOT_USERNAME can access the required version of mv.
version=$(
  chroot --skip-chdir --user=$NON_ROOT_USERNAME / env PATH="$PATH" \
    mv --version |
  sed -n '1s/.* //p'
)
case $version in
  $PACKAGE_VERSION) ;;
  *) skip_ "cannot access just-built mv as user $NON_ROOT_USERNAME";;
esac

chroot --skip-chdir --user=$NON_ROOT_USERNAME / env PATH="$PATH" \
  mv t/root-owned "$other_partition_tmpdir" 2> out-t && fail=1

# On some systems, we get 'Not owner'.  Convert it.
# On other systems (HPUX), we get 'Permission denied'.  Convert it, too.
onp='Operation not permitted'
sed "s/Not owner/$onp/;s/Permission denied/$onp/" out-t > out

cat <<\EOF > exp
mv: cannot remove 't/root-owned': Operation not permitted
EOF

compare exp out || fail=1

Exit $fail
