#!/bin/sh
# Exercise the 8.17 ls bug with coloring relative-named symlinks in "/".

# Copyright (C) 2012-2017 Free Software Foundation, Inc.

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
print_ver_ ls test

symlink_to_rel=
for i in /*; do
  # Skip non-symlinks:
  env test -h "$i" || continue

  # Skip dangling symlinks:
  env test -e "$i" || continue

  # Skip any symlink-to-absolute-name:
  case $(readlink "$i") in /*) continue ;; esac

  symlink_to_rel=$i
  break
done

test -z "$symlink_to_rel" \
  && skip_ no relative symlink in /

e='\33'
color_code='01;36'
c_pre="$e[0m$e[${color_code}m"
c_post="$e[0m"
printf "$c_pre$symlink_to_rel$c_post\n" > exp || framework_failure_

env TERM=xterm LS_COLORS="ln=$color_code:or=1;31;42" \
  ls -d --color=always "$symlink_to_rel" > out || fail=1

compare exp out || fail=1

Exit $fail
