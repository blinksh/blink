#!/bin/sh
# Test whether mv -n works as documented (not overwrite target).

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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


# test miscellaneous combinations of -f -i -n parameters
touch a b || framework_failure_
echo "'a' -> 'b'" > out_move
> out_empty

# ask for overwrite, answer no
touch a b || framework_failure_
echo n | mv -vi a b 2>/dev/null > out1 || fail=1
compare out1 out_empty || fail=1

# ask for overwrite, answer yes
touch a b || framework_failure_
echo y | mv -vi a b 2>/dev/null > out2 || fail=1
compare out2 out_move || fail=1

# -n wins (as the last option)
touch a b || framework_failure_
echo y | mv -vin a b 2>/dev/null > out3 || fail=1
compare out3 out_empty || fail=1

# -n wins (as the last option)
touch a b || framework_failure_
echo y | mv -vfn a b 2>/dev/null > out4 || fail=1
compare out4 out_empty || fail=1

# -n wins (as the last option)
touch a b || framework_failure_
echo y | mv -vifn a b 2>/dev/null > out5 || fail=1
compare out5 out_empty || fail=1

# options --backup and --no-clobber are mutually exclusive
touch a || framework_failure_
returns_ 1 mv -bn a b 2>/dev/null || fail=1

Exit $fail
