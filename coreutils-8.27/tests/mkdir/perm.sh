#!/bin/sh
# Verify that mkdir's '-m MODE' option works properly
# with various umask settings.

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
print_ver_ mkdir
skip_if_setgid_
require_no_default_acl_ .

working_umask_or_skip_


#                         parent        parent/dir
# umask   -m option   resulting perm  resulting perm
tests='
    000  :   empty    : drwxrwxrwx : drwxrwxrwx :
    000  :   -m 016   : drwxrwxrwx : d-----xrw- :
    077  :   empty    : drwx------ : drwx------ :
    050  :   empty    : drwx-w-rwx : drwx-w-rwx :
    050  :   -m 312   : drwx-w-rwx : d-wx--x-w- :
    160  :   empty    : drwx--xrwx : drw---xrwx :
    160  :   -m 743   : drwx--xrwx : drwxr---wx :
    027  :   -m =+x   : drwxr-x--- : d--x--x--- :
    027  :   -m =+X   : drwxr-x--- : d--x--x--- :
    -    :   -        : last       : last       :
    '
colon_tests=$(echo $tests | sed 's/^ *//; s/ *: */:/g')

for p in empty -p; do
  test _$p = _empty && p=

  old_IFS=$IFS
  IFS=':'
  set $colon_tests
  IFS=$old_IFS

  while :; do
    test "$VERBOSE" = yes && set -x
    umask=$1 mode=$2 parent_perms=$3 sub_perms=$4
    test "_$mode" = _empty && mode=
    test $sub_perms = last && break
    # echo p=$p umask=$1 mode=$2 parent_perms=$3 sub_perms=$4
    shift; shift; shift; shift
    umask $umask

    # If we're not using -p, then create the parent manually,
    # and adjust expectations accordingly.
    test x$p = x &&
      {
        mkdir -m =,u=rwx parent || fail=1
        parent_perms=drwx------
      }

    mkdir $p $mode parent/sub || fail=1

    perms=$(stat --printf %A parent)
    test "$parent_perms" = "$perms" \
      || { fail=1; echo parent: expected $parent_perms, got $perms; }

    perms=$(stat --printf %A parent/sub)
    test "$sub_perms" = "$perms" \
      || { fail=1; echo parent/sub: expected $sub_perms, got $perms; }

    chmod -R u+rwx parent
    rm -rf parent || fail=1
  done
done

Exit $fail
