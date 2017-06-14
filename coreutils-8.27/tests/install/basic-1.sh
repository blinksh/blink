#!/bin/sh
# Basic tests for "install".

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
print_ver_ ginstall
skip_if_root_

dir=dir
file=file

rm -rf $dir $file || framework_failure_
mkdir -p $dir || framework_failure_
echo foo > $file || framework_failure_

ginstall $file $dir || fail=1
# Make sure the source file still exists.
test -f $file || fail=1
# Make sure the dest file has been created.
test -f $dir/$file || fail=1

# Make sure strip works.
dd=dd$EXEEXT
dd2=dd2$EXEEXT

just_built_dd=$abs_top_builddir/src/$dd

test -r "$just_built_dd" \
  || warn_ "WARNING!!! Your just-built dd binary, $just_built_dd
is not readable, so skipping the remaining tests in this file."

cp "$just_built_dd" . || fail=1
cp $dd $dd2 || fail=1

strip=-s
if ! strip $dd2; then
  ! test -e $abs_top_builddir/src/coreutils \
    && warn_ "WARNING!!! Your strip command doesn't seem to work,
so skipping the test of install's --strip option."
  strip=
fi

# This test would fail with 3.16s when using versions of strip that
# don't work on read-only files (the one from binutils works fine).
ginstall $strip -c -m 555 $dd $dir || fail=1
# Make sure the source file is still around.
test -f $dd || fail=1

# Make sure that the destination file has the requested permissions.
mode=$(ls -l $dir/$dd|cut -b-10)
test "$mode" = -r-xr-xr-x || fail=1

# These failed in coreutils CVS from 2004-06-25 to 2004-08-11.
ginstall -d . || fail=1
ginstall -d newdir || fail=1
test -d newdir || fail=1
ginstall -d newdir1 newdir2 newdir3 || fail=1
test -d newdir1 || fail=1
test -d newdir2 || fail=1
test -d newdir3 || fail=1

# This fails because mkdir-p.c's make_dir_parents fails to return to its
# initial working directory ($iwd) after creating the first argument, and
# hence cannot do anything meaningful with the following relative-named dirs.
iwd=$(pwd)
mkdir sub || fail=1
(cd sub &&
 chmod 0 . &&
 returns_ 1 ginstall -d "$iwd/xx/yy" rel/sub1 rel/sub2 2> /dev/null
) || fail=1
chmod 755 sub

# Ensure that the first argument-dir has been created.
test -d xx/yy || fail=1

# Make sure that the 'rel' directory was not created...
test -d sub/rel && fail=1
# and make sure it was not created in the wrong place.
test -d xx/rel && fail=1

# Test that we can install from an unreadable directory with an
# inaccessible parent.  coreutils 5.97 fails this test.
# Perform this test only if "." is on a local file system.
# Otherwise, it would fail e.g., on an NFS-mounted file system.
if is_local_dir_ .; then
  mkdir -p sub1/d || fail=1
  (cd sub1/d && chmod a-r . && chmod a-rx .. &&
   ginstall -d "$iwd/xx/zz" rel/a rel/b) || fail=1
  chmod 755 sub1 sub1/d || fail=1
  test -d xx/zz || fail=1
  test -d sub1/d/rel/a || fail=1
  test -d sub1/d/rel/b || fail=1
fi

touch file || fail=1
ginstall -Dv file sub3/a/b/c/file >out 2>&1 || fail=1
compare - out <<\EOF || fail=1
ginstall: creating directory 'sub3'
ginstall: creating directory 'sub3/a'
ginstall: creating directory 'sub3/a/b'
ginstall: creating directory 'sub3/a/b/c'
'file' -> 'sub3/a/b/c/file'
EOF

# Test -D together with -t (available since coreutils >= 8.23).
# Let ginstall create a completely new destination hierarchy.
ginstall -t sub4/a/b/c -Dv file >out 2>&1 || fail=1
compare - out <<\EOF || fail=1
ginstall: creating directory 'sub4'
ginstall: creating directory 'sub4/a'
ginstall: creating directory 'sub4/a/b'
ginstall: creating directory 'sub4/a/b/c'
'file' -> 'sub4/a/b/c/file'
EOF

# Ensure that -D with an already existing file as -t's option argument fails.
touch sub4/file_exists || framework_failure_
ginstall -t sub4/file_exists -Dv file >out 2>&1 && fail=1
compare - out <<\EOF || fail=1
ginstall: target 'sub4/file_exists' is not a directory
EOF

# Ensure that -D with an already existing directory for -t's option argument
# succeeds.
mkdir sub4/dir_exists || framework_failure_
touch sub4/dir_exists || framework_failure_
ginstall -t sub4/dir_exists -Dv file >out 2>&1 || fail=1
compare - out <<\EOF || fail=1
'file' -> 'sub4/dir_exists/file'
EOF

# Ensure omitted directories are diagnosed
returns_ 1 ginstall . . 2>err || fail=1
printf '%s\n' "ginstall: omitting directory '.'" >exp || framework_failure_
compare exp err || fail=1

Exit $fail
