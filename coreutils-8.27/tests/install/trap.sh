#!/bin/sh
# Ensure that 'install -s' doesn't infloop when its parent
# process traps CHLD signal.

# Copyright (C) 2004-2017 Free Software Foundation, Inc.

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
require_trap_signame_


# Use a subshell and an exec to work around a bug in FreeBSD 5.0 /bin/sh.
(
  trap '' CHLD

  # Before 2004-04-21, install would infloop, in the 'while (wait...' loop:
  exec ginstall -s "$abs_top_builddir/src/ginstall$EXEEXT" .
)

Exit $fail
