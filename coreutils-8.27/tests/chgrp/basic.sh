#!/bin/sh
# make sure chgrp is reasonable

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
print_ver_ chgrp
require_membership_in_two_groups_
require_local_dir_

set _ $groups; shift
g1=$1
g2=$2
mkdir d
touch f f2 d/f3
chgrp $g1 f || fail=1
chgrp $g2 f || fail=1
chgrp $g2 f2 || fail=1
chgrp -R $g1 d || fail=1

d_files='d d/f3'

chgrp $g1 f || fail=1  ; test $(stat --p=%g f) = $g1 || fail=1
chgrp $g2 f || fail=1  ; test $(stat --p=%g f) = $g2 || fail=1
chgrp $g2 f || fail=1  ; test $(stat --p=%g f) = $g2 || fail=1
chgrp '' f  || fail=1  ; test $(stat --p=%g f) = $g2 || fail=1
chgrp $g1 f || fail=1  ; test $(stat --p=%g f) = $g1 || fail=1
chgrp $g1 f || fail=1  ; test $(stat --p=%g f) = $g1 || fail=1
chgrp --reference=f2 f ; test $(stat --p=%g f) = $g2 || fail=1

chgrp -R $g2 d ||fail=1; test $(stat --p=%g: $d_files) = "$g2:$g2:" || fail=1
chgrp -R $g1 d ||fail=1; test $(stat --p=%g: $d_files) = "$g1:$g1:" || fail=1
chgrp -R $g2 d ||fail=1; test $(stat --p=%g: $d_files) = "$g2:$g2:" || fail=1
chgrp -R $g1 d ||fail=1; test $(stat --p=%g: $d_files) = "$g1:$g1:" || fail=1
chgrp $g2 d    ||fail=1; test $(stat --p=%g: $d_files) = "$g2:$g1:" || fail=1

rm -f f
touch f
ln -s f symlink
chgrp $g1 f
test $(stat --printf=%g f) = $g1 || fail=1

# This should not change the group of f.
chgrp -h $g2 symlink
test $(stat --printf=%g f) = $g1 || fail=1

# Don't fail if chgrp failed to set the group of a symlink.
# Some systems don't support that.
test $(stat --printf=%g symlink) = $g2 ||
  echo 'info: failed to set group of symlink' 1>&2

chown --from=:$g1 :$g2 f; test $(stat --printf=%g f) = $g2 || fail=1

# This *should* change the group of f.
# Though note that the diagnostic is misleading in that
# it says the 'group of 'symlink'' has been changed.
chgrp $g1 symlink; test $(stat --printf=%g f) = $g1 || fail=1
chown --from=:$g1 :$g2 f; test $(stat --printf=%g f) = $g2 || fail=1

# If -R is specified without -H or L, -h is assumed.
chgrp -h $g1 f symlink; test $(stat --printf=%g symlink) = $g1 || fail=1
chgrp -R $g2 symlink
chown --from=:$g1 :$g2 f; test $(stat --printf=%g f) = $g2 || fail=1

# Make sure we can change the group of inaccessible files.
chmod a-r f
chown --from=:$g2 :$g1 f; test $(stat --printf=%g f) = $g1 || fail=1
chmod 0 f
chown --from=:$g1 :$g2 f; test $(stat --printf=%g f) = $g2 || fail=1

# chown() must not be optimized away even when
# the file's owner and group already have the desired value.
rm -f f g
touch f g
chgrp $g1 f g
chgrp $g2 g
sleep 1
chgrp $g1 f

# The following no-change chgrp command is supposed to update f's ctime,
# but on OpenBSD and Darwin 7.9.0-8.11.1 (aka MacOS X 10.3.9 - 10.4.11)
# it appears to be a no-op for some file system types (at least NFS) so g's
# ctime is more recent.  This is not a big deal;
# this test works fine when the files are on a local file system (/tmp).
chgrp '' f
test "$(ls -C -c -t f g)" = 'f  g' || \
  {
    case $host_triplet in
      *openbsd*) echo ignoring known OpenBSD-specific chgrp failure 1>&2 ;;
      *darwin7.9.*|*darwin8.*)
        echo ignoring known MacOS X-specific chgrp failure 1>&2 ;;
      *) echo $host_triplet: no-change chgrp failed to update ctime 1>&2;
            fail=1 ;;
    esac
  }

Exit $fail
