#!/bin/sh
# Make sure the permission-preserving code in copy.c (mv, cp, install) works.

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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

very_expensive_

umask 037


# Now, try it with 'mv', with combinations of --force, no-f and
# existing-destination and not.
for u in 31 37 2; do
  echo umask: $u
  umask $u
  for cmd in mv 'cp -p' cp; do
    for force in '' -f; do
      for existing_dest in yes no; do
        for g_perm in r w x rw wx xr rwx; do
          for o_perm in r w x rw wx xr rwx; do
            touch src || exit 1
            chmod u=r,g=rx,o= src || exit 1
            expected_perms=$(stat --format=%A src)
            rm -f dest
            test $existing_dest = yes && {
              touch dest || exit 1
              chmod u=rw,g=$g_perm,o=$o_perm dest || exit 1
              }
            $cmd $force src dest || exit 1
            test "$cmd" = mv && test -f src && exit 1
            test "$cmd" = cp && { test -f src || exit 1; }
            actual_perms=$(stat --format=%A dest)

            case "$cmd:$force:$existing_dest" in
              cp:*:yes)
                _g_perm=$(echo rwx|sed 's/[^'$g_perm']/-/g')
                _o_perm=$(echo rwx|sed 's/[^'$o_perm']/-/g')
                expected_perms=-rw-$_g_perm$_o_perm
                ;;
              cp:*:no)
                test $u = 37 &&
                  expected_perms=$(
                    echo $expected_perms | sed 's/.....$/-----/'
                  )
                test $u = 31 &&
                  expected_perms=$(
                    echo $expected_perms | sed 's/..\(..\).$/--\1-/'
                  )
                ;;
            esac
            test _$actual_perms = _$expected_perms || exit 1
            # Perform only one iteration when there's no existing destination.
            test $existing_dest = no && break 3
          done
        done
      done
    done
  done
done

Exit $fail
