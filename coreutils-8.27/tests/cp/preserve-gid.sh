#!/bin/sh
# Verify that cp -p preserves GID when it is possible.

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

# Some of the tests expect a umask that grants group and/or world read access.
working_umask_or_skip_

# Record primary group number, usually 0.
# This is the group ID used when cp (without -p) creates a new file.
primary_group_num=$(id -g)

create() {
  echo "$1" > "$1" || exit 1
  chown "+$2:+$3" "$1" || exit 1
}

t0() {
  f=$1; shift
  u=$1; shift
  g=$1; shift
  rm -f b || exit 1
  "$@" "$f" b || exit 1
  s=$(stat -c '%u %g' b)
  if test "x$s" != "x$u $g"; then
    # Allow the actual group to match that of the parent directory
    # (it was set to 0 above).
    if test "x$s" = "x$u $primary_group_num"; then
      :
    else
      echo "$0: $* $f b: $u $g != $s" 1>&2
      Exit 1
    fi
  fi
}

nameless_uid=$($PERL -le '
  foreach my $i (1000..16*1024-1)
    {
      getpwuid $i or (print $i), exit
    }
')
nameless_gid1=$($PERL -le '
  foreach my $i (1000..16*1024)
    {
      getgrgid $i or (print $i), exit
    }
')
nameless_gid2=$($PERL -le '
  foreach my $i ('"$nameless_gid1"'+1..16*1024)
    {
      getgrgid $i or (print $i), exit
    }
')

if test -z "$nameless_uid" \
    || test -z "$nameless_gid1" \
    || test -z "$nameless_gid2"; then
  skip_ "couldn't find a nameless UID or GID"
fi

chown "+$nameless_uid:+0" .

create a0 0 0
create b0 "$nameless_uid" "$nameless_gid1"
create b1 "$nameless_uid" "$nameless_gid2"
create c0 0 "$nameless_gid1"
create c1 0 "$nameless_gid2"

t0 a0 0 0 cp
t0 b0 0 0 cp
t0 b1 0 0 cp
t0 c0 0 0 cp
t0 c1 0 0 cp

t0 a0 0 0 cp -p
t0 b0 "$nameless_uid" "$nameless_gid1" cp -p
t0 b1 "$nameless_uid" "$nameless_gid2" cp -p
t0 c0 0 "$nameless_gid1" cp -p
t0 c1 0 "$nameless_gid2" cp -p

# For the remaining tests, we need a cp binary that is accessible to a user
# with UID of $nameless_uid.  The build directory may not be accessible,
# so create a temporary directory and copy cp into it, ensure that
# $nameless_uid can access it and then make that directory the search path.
tmp_path=
cleanup_() { rm -rf "$tmp_path"; }

# Cause mktemp to create a directory directly under /tmp.
# Setting TMPDIR explicitly is required here, in case $TMPDIR
# is not readable by our nameless IDs.
test -d /tmp && TMPDIR=/tmp
tmp_path=$(mktemp -d) || fail_ "failed to create temporary directory"
cp "$abs_path_dir_/cp" "$tmp_path"
chmod -R a+rx "$tmp_path"

t1() {
  f=$1; shift
  u=$1; shift
  g=$1; shift
  t0 "$f" "$u" "$g" \
      chroot --skip-chdir \
             --user=+$nameless_uid:+$nameless_gid1 \
             --groups="+$nameless_gid1,+$nameless_gid2" \
        / env PATH="$tmp_path" "$@"
}

t1 a0 "$nameless_uid" "$nameless_gid1" cp
t1 b0 "$nameless_uid" "$nameless_gid1" cp
t1 b1 "$nameless_uid" "$nameless_gid1" cp
t1 c0 "$nameless_uid" "$nameless_gid1" cp
t1 c1 "$nameless_uid" "$nameless_gid1" cp

t1 a0 "$nameless_uid" "$nameless_gid1" cp -p
t1 b0 "$nameless_uid" "$nameless_gid1" cp -p
t1 b1 "$nameless_uid" "$nameless_gid2" cp -p
t1 c0 "$nameless_uid" "$nameless_gid1" cp -p
t1 c1 "$nameless_uid" "$nameless_gid2" cp -p

Exit $fail
