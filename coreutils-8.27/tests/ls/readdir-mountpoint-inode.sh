#!/bin/sh
# ensure that ls -i works also for mount points

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
print_ver_ ls

# We use --local here so as to not activate
# potentially very many remote mounts.
df --local --out=target | sed -n '/^\/./p' > mount_points
test -s mount_points ||
  skip_ "this test requires a non-root mount point"

# Given e.g., /dev/shm, produce the list of GNU ls options that
# let us list just that entry using readdir data from its parent:
# ls -i -I '[^s]*' -I 's[^h]*' -I 'sh[^m]*' -I 'shm?*' -I '.?*' \
# -I '?' -I '??' /dev

ls_ignore_options()
{
  name=$1
  opts="-I '.?*' -I '$name?*'"
  while :; do
    glob=$(echo "$name"|sed 's/\(.*\)\(.\)$/\1[^\2]*/')
    opts="$opts -I '$glob'"
    name=$(echo "$name"|sed 's/.$//')
    test -z "$name" && break
    glob=$(echo "$name"|sed 's/./?/g')
    opts="$opts -I '$glob'"
  done
  echo "$opts"
}

inode_via_readdir()
{
  mount_point=$1
  base=$(basename "$mount_point")
  case "$base" in
    .*) skip_ 'mount point component starts with "."' ;;
    *[*?]*) skip_ 'mount point component contains "?" or "*"' ;;
  esac
  opts=$(ls_ignore_options "$base")
  parent_dir=$(dirname "$mount_point")
  eval "ls -i $opts '$parent_dir'" | sed 's/ .*//'
}

while read dir; do
  readdir_inode=$(inode_via_readdir "$dir")
  test $? = 77 && continue
  stat_inode=$(timeout 1 stat --format=%i "$dir")
  # If stat fails or says the inode is 0, skip $dir.
  case $stat_inode in 0|'') continue;; esac
  test "$readdir_inode" = "$stat_inode" || fail=1
done < mount_points

Exit $fail
