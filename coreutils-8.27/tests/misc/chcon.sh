#!/bin/sh
# exercise chcon

# Copyright (C) 2007-2017 Free Software Foundation, Inc.

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
print_ver_ chcon
require_root_
require_selinux_
skip_if_mcstransd_is_running_
mls_enabled_ || skip_ 'MLS is disabled'

mkdir -p d/sub/s2 || framework_failure_
touch f g d/sub/1 d/sub/2 || framework_failure_


# Set to a specified context.
# Use root:object_r:tmp_t:s0.  It is special in that
# it works even when mcstransd isn't running.
u1=root
r1=object_r
t1=tmp_t
range=s0
ctx=$u1:$r1:$t1:$range
chcon $ctx f || fail=1
stat --printf='f|%C\n' f > out || fail=1

# Use --reference.
chcon --ref=f g || fail=1
stat --printf='g|%C\n' g >> out || fail=1

# Change the individual parts of the context, one by one.
u2=user_u
r2=object_r
t2=unlabeled_t
for i in --user=$u2 --role=$r2 --type=$t2 --range=$range; do
  chcon $i f || fail=1
  stat --printf="f|$i|"'%C\n' f >> out || fail=1
done

# Same, but change back using the short-named options.
for i in -u$u1 -r$r1 -t$t1; do
  chcon $i f || fail=1
  stat --printf="f|$i|"'%C\n' f >> out || fail=1
done

cat <<EOF > exp || fail=1
f|$ctx
g|$ctx
f|--user=$u2|$u2:$r1:$t1:$range
f|--role=$r2|$u2:$r2:$t1:$range
f|--type=$t2|$u2:$r2:$t2:$range
f|--range=$range|$u2:$r2:$t2:$range
f|-uroot|root:object_r:$t2:$range
f|-robject_r|root:object_r:$t2:$range
f|-ttmp_t|root:object_r:tmp_t:$range
EOF

compare exp out || fail=1

chcon --verbose -u$u1 f > out || fail=1
echo "changing security context of 'f'" > exp
compare exp out || fail=1

Exit $fail
