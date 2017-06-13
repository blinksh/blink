#!/bin/sh
# Miscellaneous tests for "ln".

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
print_ver_ ln

t=tln-symlink
d=tln-subdir
ld=tln-symlink-to-subdir
f=tln-file

# Create a simple symlink with both source and destination files
# in current directory.
touch $f || framework_failure_
rm -f $t || framework_failure_
ln -s $f $t || fail=1
test -f $t || fail=1
rm $t $f

# Create a symlink with source file and explicit destination directory/file.
touch $f || framework_failure_
rm -rf $d || framework_failure_
mkdir $d || framework_failure_
ln -s ../$f $d/$t || fail=1
test -f $d/$t || fail=1
rm -rf $d $f

# Create a symlink with source file and destination directory.
touch $f || framework_failure_
rm -rf $d || framework_failure_
mkdir $d || framework_failure_
ln -s ../$f $d || fail=1
test -f $d/$f || fail=1
rm -rf $d $f

# See whether a trailing slash is followed too far.
touch $f || framework_failure_
rm -rf $d || framework_failure_
mkdir $d $d/$f || framework_failure_
returns_ 1 ln $f $d/ 2> /dev/null || fail=1
returns_ 1 ln -s $f $d/ 2> /dev/null || fail=1
rm -rf $d $f

# Make sure we get a failure with existing dest without -f option
touch $t || framework_failure_
# FIXME: don't ignore the error message but rather test
# it to make sure it's the right one.
returns_ 1 ln -s $t $t 2> /dev/null || fail=1
rm $t

# Make sure -sf fails when src and dest are the same
touch $t || framework_failure_
returns_ 1 ln -sf $t $t 2> /dev/null || fail=1
rm $t

# Create a symlink with source file and no explicit directory
rm -rf $d || framework_failure_
mkdir $d || framework_failure_
touch $d/$f || framework_failure_
ln -s $d/$f || fail=1
test -f $f || fail=1
rm -rf $d $f

# Create a symlink with source file and destination symlink-to-directory.
rm -rf $d $f $ld || framework_failure_
touch $f || framework_failure_
mkdir $d || framework_failure_
ln -s $d $ld
ln -s ../$f $ld || fail=1
test -f $d/$f || fail=1
rm -rf $d $f $ld

# Create a symlink with source file and destination symlink-to-directory.
# BUT use the new --no-dereference option.
rm -rf $d $f $ld || framework_failure_
touch $f || framework_failure_
mkdir $d || framework_failure_
ln -s $d $ld
af=$(pwd)/$f
ln --no-dereference -fs "$af" $ld || fail=1
test -f $ld || fail=1
rm -rf $d $f $ld

# Try to create a symlink with backup where the destination file exists
# and the backup file name is a hard link to the destination file.
touch a b || framework_failure_
ln b b~ || framework_failure_
ln -f --b=simple a b || fail=1

# ===================================================

# Make sure ln can make simple backups.
# This was fixed in 4.0.34.  Broken in 4.0r.
for cmd in ln cp mv ginstall; do
  rm -rf a x a.orig
  touch a x || framework_failure_
  $cmd --backup=simple --suffix=.orig x a || fail=1
  test -f a.orig || fail=1
done

# ===================================================
# With coreutils-5.2.1, this would mistakenly access argv[1][-1].
# I'm including it here, in case some day programs like valgrind detect that.
# Purify probably would have done so.
ln foo '' 2> /dev/null

# ===================================================

Exit $fail
