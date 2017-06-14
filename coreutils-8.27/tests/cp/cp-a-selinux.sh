#!/bin/sh
# Ensure that cp -Z, -a and cp --preserve=context work properly.
# In particular, test on a writable NFS partition.
# Check also locally if --preserve=context, -a and --preserve=all
# does work

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
print_ver_ cp
require_root_
require_selinux_

cwd=$(pwd)
cleanup_() { cd /; umount "$cwd/mnt"; }

# This context is special: it works even when mcstransd isn't running.
ctx='root:object_r:tmp_t'
mls_enabled_ && ctx="$ctx:s0"

# Check basic functionality - before check on fixed context mount
touch c || framework_failure_
chcon $ctx c || framework_failure_
cp -a c d 2>err || framework_failure_
cp --preserve=context c e || framework_failure_
cp --preserve=all c f || framework_failure_
ls -Z d | grep $ctx || fail=1
# there must be no stderr output for -a
compare /dev/null err || fail=1
ls -Z e | grep $ctx || fail=1
ls -Z f | grep $ctx || fail=1
rm -f f

# Check handling of existing dirs which requires specific handling
# due to recursion, and was handled incorrectly in coreutils-8.22
# Note standard permissions are updated for existing directories
# in the destination, so SELinux contexts should be updated too.
mkdir -p backup/existing_dir/ || framework_failure_
ls -Zd backup/existing_dir > ed_ctx || fail=1
grep $ctx ed_ctx && framework_failure_
touch backup/existing_dir/file || framework_failure_
chcon $ctx backup/existing_dir/file || framework_failure_
# Set the dir context to ensure it is reset
mkdir -p --context="$ctx" restore/existing_dir || framework_failure_
# Copy and ensure existing directories updated
cp -a backup/. restore/ || fail=1
ls -Zd restore/existing_dir > ed_ctx || fail=1
grep $ctx ed_ctx &&
  { ls -lZd restore/existing_dir; fail=1; }

# Check context preserved with directories created with --parents,
# which was not handled before coreutils-8.27
mkdir -p parents/a/b || framework_failure_
ls -Zd parents/a/b > ed_ctx || fail=1
grep $ctx ed_ctx && framework_failure_
touch parents/a/b/file || framework_failure_
chcon $ctx parents/a/b || framework_failure_
# Set the dir context to ensure it is reset
mkdir -p --context="$ctx" parents_dest/parents/a || framework_failure_
# Copy and ensure existing directories updated
cp -r --parents --preserve=context parents/a/b/file parents_dest || fail=1
# Check new context
ls -Zd parents_dest/parents/a/b > ed_ctx || fail=1
grep $ctx ed_ctx ||
  { ls -lZd parents_dest/parents/a/b; fail=1; }
# Check updated context
ls -Zd parents_dest/parents/a > ed_ctx || fail=1
grep $ctx ed_ctx &&
  { ls -lZd parents_dest/parents/a; fail=1; }

# Check restorecon (-Z) functionality for file and directory
# Also make a dir with our known context
mkdir c_d || framework_failure_
chcon $ctx c_d || framework_failure_
# Get the type of this known context for file and dir for tracing
old_type_f=$(get_selinux_type c)
old_type_d=$(get_selinux_type c_d)
# Setup copies for manipulation with restorecon
# and get the adjusted type for comparison
cp -a c Z1 || fail=1
cp -a c_d Z1_d || fail=1
if restorecon Z1 Z1_d 2>restorecon.err \
   && compare /dev/null restorecon.err; then
  new_type_f=$(get_selinux_type Z1)
  new_type_d=$(get_selinux_type Z1_d)

  # Ensure -Z sets the type like restorecon does
  cp -Z c Z2 || fail=1
  cpZ_type_f=$(get_selinux_type Z2)
  test "$cpZ_type_f" = "$new_type_f" || fail=1

  # Ensure -Z overrides -a and that dirs are handled too
  cp -aZ c Z3 || fail=1
  cp -aZ c_d Z3_d || fail=1
  cpaZ_type_f=$(get_selinux_type Z3)
  cpaZ_type_d=$(get_selinux_type Z3_d)
  test "$cpaZ_type_f" = "$new_type_f" || fail=1
  test "$cpaZ_type_d" = "$new_type_d" || fail=1

  # Ensure -Z sets the type for existing files
  mkdir -p existing/c_d || framework_failure_
  touch existing/c || framework_failure_
  cp -aZ c c_d existing || fail=1
  cpaZ_type_f=$(get_selinux_type existing/c)
  cpaZ_type_d=$(get_selinux_type existing/c_d)
  test "$cpaZ_type_f" = "$new_type_f" || fail=1
  test "$cpaZ_type_d" = "$new_type_d" || fail=1
fi

skip=0
# Create a file system, then mount it with the context=... option.
dd if=/dev/zero of=blob bs=8192 count=200    || skip=1
mkdir mnt                                    || skip=1
mkfs -t ext2 -F blob ||
  skip_ "failed to create an ext2 file system"

mount -oloop,context=$ctx blob mnt           || skip=1
test $skip = 1 \
  && skip_ "insufficient mount/ext2 support"

cd mnt                                       || framework_failure_

# Create files with hopefully different contexts
echo > ../f                                  || framework_failure_
echo > g                                     || framework_failure_
test "$(stat -c%C ../f)" = "$(stat -c%C g)" &&
  skip_ "files on separate file systems have the same security context"

# /bin/cp from coreutils-6.7-3.fc7 would fail this test by letting cp
# succeed (giving no diagnostics), yet leaving the destination file empty.
cp -a ../f g 2>err || fail=1
test -s g       || fail=1     # The destination file must not be empty.
compare /dev/null err || fail=1

# =====================================================
# Here, we expect cp to succeed and not warn with "Operation not supported"
rm -f g
echo > g
cp --preserve=all ../f g 2>err || fail=1
test -s g || fail=1
grep "Operation not supported" err && fail=1

# =====================================================
# The same as above except destination does not exist
rm -f g
cp --preserve=all ../f g 2>err || fail=1
test -s g || fail=1
grep "Operation not supported" err && fail=1

# An alternative to the following approach would be to run in a confined
# domain (maybe creating/loading it) that lacks the required permissions
# to the file type.
# Note: this test could also be run by a regular (non-root) user in an
# NFS mounted directory.  When doing that, I get this diagnostic:
# cp: failed to set the security context of 'g' to 'system_u:object_r:nfs_t': \
#   Operation not supported
cat <<\EOF > exp || framework_failure_
cp: failed to set the security context of
EOF

rm -f g
echo > g
# =====================================================
# Here, we expect cp to fail, because it cannot set the SELinux
# security context through NFS or a mount with fixed context.
cp --preserve=context ../f g 2> out && fail=1
# Here, we *do* expect the destination to be empty.
compare /dev/null g || fail=1
sed "s/ .g'.*//" out > k
mv k out
compare exp out || fail=1

rm -f g
echo > g
# Check if -a option doesn't silence --preserve=context option diagnostics
cp -a --preserve=context ../f g 2> out2 && fail=1
# Here, we *do* expect the destination to be empty.
compare /dev/null g || fail=1
sed "s/ .g'.*//" out2 > k
mv k out2
compare exp out2 || fail=1

for no_g_cmd in '' 'rm -f g'; do
  # restorecon equivalent.  Note even though the context
  # returned from matchpathcon() will not match $ctx
  # the resulting ENOTSUP warning will be suppressed.

   # With absolute path
  $no_g_cmd
  cp -Z ../f $(realpath g) || fail=1
   # With relative path
  $no_g_cmd
  cp -Z ../f g || fail=1
   # -Z overrides -a
  $no_g_cmd
  cp -Z -a ../f g || fail=1
   # -Z doesn't take an arg
  $no_g_cmd
  returns_ 1 cp -Z "$ctx" ../f g || fail=1

  # Explicit context
  $no_g_cmd
   # Explicitly defaulting to the global $ctx should work
  cp --context="$ctx" ../f g || fail=1
   # --context overrides -a
  $no_g_cmd
  cp -a --context="$ctx" ../f g || fail=1
done

# Mutually exclusive options
returns_ 1 cp -Z --preserve=context ../f g || fail=1
returns_ 1 cp --preserve=context -Z ../f g || fail=1
returns_ 1 cp --preserve=context --context="$ctx" ../f g || fail=1

Exit $fail
