#!/bin/sh
# Like fail-eperm, but the failure must be for a file encountered
# while trying to remove the containing directory with the sticky bit set.

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
print_ver_ rm
require_root_

# The containing directory must be owned by the user who eventually runs rm.
chown $NON_ROOT_USERNAME .

mkdir a || framework_failure_
chmod 1777 a || framework_failure_
touch a/b || framework_failure_


# Try to ensure that $NON_ROOT_USERNAME can access
# the required version of rm.
rm_version=$(
  chroot --skip-chdir --user=$NON_ROOT_USERNAME / env PATH="$PATH" \
    rm --version |
  sed -n '1s/.* //p'
)
case $rm_version in
  $PACKAGE_VERSION) ;;
  *) skip_ "cannot access just-built rm as user $NON_ROOT_USERNAME";;
esac
chroot --skip-chdir --user=$NON_ROOT_USERNAME / \
  env PATH="$PATH" rm -rf a 2> out-t && fail=1

# On some systems, we get 'Not owner'.  Convert it.
# On other systems (HPUX), we get 'Permission denied'.  Convert it, too.
onp='Operation not permitted'
sed "s/Not owner/$onp/;s/Permission denied/$onp/" out-t > out

cat <<\EOF > exp
rm: cannot remove 'a/b': Operation not permitted
EOF

compare exp out || fail=1

Exit $fail
