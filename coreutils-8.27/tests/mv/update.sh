#!/bin/sh
# make sure --update works as advertised

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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

echo old > old || framework_failure_
touch -d yesterday old || framework_failure_
echo new > new || framework_failure_


for interactive in '' -i; do
  for cp_or_mv in cp mv; do
    # This is a no-op, with no prompt.
    # With coreutils-6.9 and earlier, using --update with -i would
    # mistakenly elicit a prompt.
    $cp_or_mv $interactive --update old new < /dev/null > out 2>&1 || fail=1
    compare /dev/null out || fail=1
    case "$(cat new)" in new) ;; *) fail=1 ;; esac
    case "$(cat old)" in old) ;; *) fail=1 ;; esac
  done
done

# This will actually perform the rename.
mv --update new old || fail=1
test -f new && fail=1
case "$(cat old)" in new) ;; *) fail=1 ;; esac

# Restore initial conditions.
echo old > old || fail=1
touch -d yesterday old || fail=1
echo new > new || fail=1

# This will actually perform the copy.
cp --update new old || fail=1
case "$(cat old)" in new) ;; *) fail=1 ;; esac
case "$(cat new)" in new) ;; *) fail=1 ;; esac

Exit $fail
