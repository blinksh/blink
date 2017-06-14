#!/bin/sh
# Verify that the credentials are changed correctly.

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
print_ver_ chroot

require_root_

EXIT_CANCELED=125

grep '^#define HAVE_SETGROUPS 1' "$CONFIG_HEADER" >/dev/null \
  && HAVE_SETGROUPS=1

root=$(id -nu 0) || skip_ "Couldn't look up root username"

# verify numeric IDs looked up similarly to names
NON_ROOT_UID=$(id -u $NON_ROOT_USERNAME)
NON_ROOT_GROUP=$NON_ROOT_GID # Used where we want name lookups to occur

# "uid:" is supported (unlike chown etc.) since we treat it like "uid"
chroot --userspec=$NON_ROOT_UID: / true || fail=1

# verify that invalid groups are diagnosed
for g in ' ' ',' '0trail'; do
  returns_ $EXIT_CANCELED chroot --groups="$g" / id -G >invalid || fail=1
  compare /dev/null invalid || fail=1
done

# Verify that root credentials are kept.
test $(chroot / whoami) = "$root" || fail=1
test "$(groups)" = "$(chroot / groups)" || fail=1

# Verify that credentials are changed correctly.
whoami_after_chroot=$(
  chroot --userspec=$NON_ROOT_USERNAME:$NON_ROOT_GROUP / whoami
)
test "$whoami_after_chroot" != "$root" || fail=1

# Verify that when specifying only a group we don't change the
# list of supplemental groups
test "$(chroot --userspec=:$NON_ROOT_GROUP / id -G)" = \
     "$NON_ROOT_GID $(id -G)" || fail=1

if ! test "$HAVE_SETGROUPS"; then
  Exit $fail
fi


# Verify that there are no additional groups.
id_G_after_chroot=$(
  chroot --userspec=$NON_ROOT_USERNAME:$NON_ROOT_GROUP \
    --groups=$NON_ROOT_GROUP / id -G
)
test "$id_G_after_chroot" = $NON_ROOT_GID || fail=1

# Verify that when specifying only the user name we get all their groups
test "$(chroot --userspec=$NON_ROOT_USERNAME / id -G)" = \
     "$(id -G $NON_ROOT_USERNAME)" || fail=1

# Ditto with trailing : on the user name.
test "$(chroot --userspec=$NON_ROOT_USERNAME: / id -G)" = \
     "$(id -G $NON_ROOT_USERNAME)" || fail=1

# Verify that when specifying only the user and clearing supplemental groups
# that we only get the primary group
test "$(chroot --userspec=$NON_ROOT_USERNAME --groups='' / id -G)" = \
     $NON_ROOT_GID || fail=1

# Verify that when specifying only the UID we get all their groups
test "$(chroot --userspec=$NON_ROOT_UID / id -G)" = \
     "$(id -G $NON_ROOT_USERNAME)" || fail=1

# Verify that when specifying only the user and clearing supplemental groups
# that we only get the primary group. Note this variant with prepended '+'
# results in no lookups in the name database which could be useful depending
# on your chroot setup.
test "$(chroot --userspec=+$NON_ROOT_UID:+$NON_ROOT_GID --groups='' / id -G)" =\
     $NON_ROOT_GID || fail=1

# Verify that when specifying only a group we get the current user ID
test "$(chroot --userspec=:$NON_ROOT_GROUP / id -u)" = "$(id -u)" \
  || fail=1

# verify that arbitrary numeric IDs are supported
test "$(chroot --userspec=1234:+5678 --groups=' +8765,4321' / id -G)" \
  || fail=1

# demonstrate that extraneous commas are supported
test "$(chroot --userspec=1234:+5678 --groups=',8765,,4321,' / id -G)" \
  || fail=1

# demonstrate that --groups is not cumulative
test "$(chroot --groups='invalid ignored' --groups='' / id -G)" \
  || fail=1

if ! id -u +12342; then
  # Ensure supplemental groups cleared from some arbitrary unknown ID
  test "$(chroot --userspec=+12342:+5678 / id -G)" = '5678' || fail=1

  # Ensure we fail when we don't know what groups to set for an unknown ID
  returns_ $EXIT_CANCELED chroot --userspec=+12342 / true || fail=1
fi

Exit $fail
