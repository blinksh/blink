#!/bin/sh
# Ensure "install -C" works. (basic tests)

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
skip_if_setgid_
skip_if_nondefault_group_

# Note if a group is not specified, install(1) will assume that a file
# would be installed with the current user's group ID, and thus if the
# file is the same except that it does have a different group due to
# its parent directory being g+s for example, then the copy will be
# done again redundantly in a futile attempt to reset the group ID to
# that of the current user.
#
#  install -d -g wheel -m 2775 test  # Create setgid dir
#  touch test/a                      # Create source
#  install -Cv -m664 test/a test/i1  # install source with mode
#  install -Cv -m664 test/i1 test/i2 # install dest
#  install -Cv -m664 test/i1 test/i2 # again to see redundant install
#
# Similarly if an existing file exists that is the same and has the
# current users group ID, but when an actual install of the file would
# reset to a different group ID due to the directory being g+s for example,
# then the install will not be done when it should.
#
#  install -Cv -m664 -g "$(id -nrg)" test/i1 test/i2 # set i2 to uesr's gid
#  install -Cv -m664 test/i1 test/i2 # this should install but doesn't
#
# Therefore we skip the test in the presence of setgid dirs
# An additional complication on HFS is that it...

mode1=0644
mode2=0755
mode3=2755


echo test > a || framework_failure_
echo "'a' -> 'b'" > out_installed_first || framework_failure_
echo "removed 'b'
'a' -> 'b'" > out_installed_second || framework_failure_
> out_empty || framework_failure_

# destination file does not exist
ginstall -Cv -m$mode1 a b > out || fail=1
compare out out_installed_first || fail=1

# destination file exists
ginstall -Cv -m$mode1 a b > out || fail=1
compare out out_empty || fail=1

# destination file exists (long option)
ginstall -v --compare -m$mode1 a b > out || fail=1
compare out out_empty || fail=1

# destination file exists but -C is not given
ginstall -v -m$mode1 a b > out || fail=1
compare out out_installed_second || fail=1

# option -C ignored if any non-permission mode should be set
ginstall -Cv -m$mode3 a b > out || fail=1
compare out out_installed_second || fail=1
ginstall -Cv -m$mode3 a b > out || fail=1
compare out out_installed_second || fail=1

# files are not regular files
ln -s a c || framework_failure_
ln -s b d || framework_failure_
ginstall -Cv -m$mode1 c d > out || fail=1
echo "removed 'd'
'c' -> 'd'" > out_installed_second_cd
compare out out_installed_second_cd || fail=1

# destination file exists but content differs
echo test1 > a || framework_failure_
ginstall -Cv -m$mode1 a b > out || fail=1
compare out out_installed_second || fail=1
ginstall -Cv -m$mode1 a b > out || fail=1
compare out out_empty || fail=1

# destination file exists but content differs (same size)
echo test2 > a || framework_failure_
ginstall -Cv -m$mode1 a b > out || fail=1
compare out out_installed_second || fail=1
ginstall -Cv -m$mode1 a b > out || fail=1
compare out out_empty || fail=1

# destination file exists but mode differs
ginstall -Cv -m$mode2 a b > out || fail=1
compare out out_installed_second || fail=1
ginstall -Cv -m$mode2 a b > out || fail=1
compare out out_empty || fail=1

# options -C and --preserve-timestamps are mutually exclusive
returns_ 1 ginstall -C --preserve-timestamps a b || fail=1

# options -C and --strip are mutually exclusive
returns_ 1 ginstall -C --strip --strip-program=echo a b || fail=1

Exit $fail
