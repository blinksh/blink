#!/bin/sh
# Ensure that mv, cp -a and cp --preserve=xattr(all) options do work
# as expected on file systems without their support and do show correct
# diagnostics when required

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
print_ver_ cp mv

require_root_

cwd=$(pwd)
cleanup_() { cd /; umount "$cwd/noxattr"; umount "$cwd/xattr"; }

skip=0

# Mount an ext2 loopback file system at $WHERE with $OPTS
make_fs() {
  where="$1"
  opts="$2"

  fs="$where.bin"

  dd if=/dev/zero of="$fs" bs=8192 count=200 > /dev/null 2>&1 \
                                                 || skip=1
  mkdir "$where"                                 || skip=1
  mkfs -t ext2 -F "$fs" ||
    skip_ "failed to create ext2 file system"
  mount -oloop,$opts "$fs" "$where"              || skip=1
  echo test > "$where"/f                         || skip=1
  test -s "$where"/f                             || skip=1

  test $skip = 1 &&
    skip_ "insufficient mount/ext2 support"
}

make_fs noxattr nouser_xattr
make_fs xattr   user_xattr

# testing xattr name-value pair
xattr_name="user.foo"
xattr_value="bar"
xattr_pair="$xattr_name=\"$xattr_value\""

echo test > xattr/a || framework_failure_
getfattr -d xattr/a >out_a || skip_ "failed to get xattr of file"
grep -F "$xattr_pair" out_a >/dev/null && framework_failure_
setfattr -n "$xattr_name" -v "$xattr_value" xattr/a >out_a \
  || skip_ "failed to set xattr of file"
getfattr -d xattr/a >out_a || skip_ "failed to get xattr of file"
grep -F "$xattr_pair" out_a >/dev/null \
  || skip_ "failed to set xattr of file"


# This should pass without diagnostics
cp -a xattr/a noxattr/ 2>err || fail=1
test -s noxattr/a   || fail=1  # destination file must not be empty
compare /dev/null err || fail=1

rm -f err noxattr/a

# This should pass without diagnostics (new file)
cp --preserve=all xattr/a noxattr/ 2>err || fail=1
test -s noxattr/a   || fail=1  # destination file must not be empty
compare /dev/null err || fail=1

# This should pass without diagnostics (existing file)
cp --preserve=all xattr/a noxattr/ 2>err || fail=1
test -s noxattr/a   || fail=1  # destination file must not be empty
compare /dev/null err || fail=1

rm -f err noxattr/a

# This should fail with corresponding diagnostics
cp -a --preserve=xattr xattr/a noxattr/ 2>err && fail=1
if grep '^#define USE_XATTR 1' $CONFIG_HEADER > /dev/null; then
cat <<\EOF > exp
cp: setting attributes for 'noxattr/a': Operation not supported
EOF
else
cat <<\EOF > exp
cp: cannot preserve extended attributes, cp is built without xattr support
EOF
fi

compare exp err     || fail=1

rm -f err noxattr/a

# This should pass without diagnostics
mv xattr/a noxattr/ 2>err || fail=1
test -s noxattr/a         || fail=1  # destination file must not be empty
compare /dev/null err || fail=1

# This should pass and copy xattrs of the symlink
# since the xattrs used here are not in the 'user.' namespace.
# Up to and including coreutils-8.22 xattrs of symlinks
# were not copied across file systems.
ln -s 'foo' xattr/symlink || framework_failure_
# Note 'user.' namespace is only supported on regular files/dirs
# so use the 'trusted.' namespace here
txattr='trusted.overlay.whiteout'
if setfattr -hn "$txattr" -v y xattr/symlink; then
  # Note only root can read the 'trusted.' namespace
  if getfattr -h -m- -d xattr/symlink | grep -F "$txattr"; then
    mv xattr/symlink noxattr/ 2>err || fail=1
    if grep '^#define USE_XATTR 1' $CONFIG_HEADER > /dev/null; then
      getfattr -h -m- -d noxattr/symlink | grep -F "$txattr" || fail=1
    fi
    compare /dev/null err || fail=1
  else
    echo "failed to get '$txattr' xattr. skipping symlink check" >&2
  fi
else
  echo "failed to set '$txattr' xattr. skipping symlink check" >&2
fi

Exit $fail
