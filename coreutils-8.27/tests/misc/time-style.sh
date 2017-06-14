#!/bin/sh
# Test --time-style in programs like 'ls'.

# Copyright (C) 2016-2017 Free Software Foundation, Inc.

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
print_ver_ du
print_ver_ ls
print_ver_ pr

echo hello >a || framework_failure_

# The tests assume this is an old timestamp in northern hemisphere summer.
TZ=UTC0 touch -d '1970-07-08 09:10:11' a || framework_failure_

for tz in UTC0 PST8 PST8PDT,M3.2.0,M11.1.0 XXXYYY-12:30; do
  for style in full-iso long-iso iso locale '+%Y-%m-%d %H:%M:%S %z (%Z)' \
               +%%b%b%%b%b; do
    test "$style" = locale ||
      TZ=$tz LC_ALL=C du --time --time-style="$style" a >>duout 2>>err || fail=1
    TZ=$tz LC_ALL=C ls -no --time-style="$style" a >>lsout 2>>err || fail=1
    case $style in
      (+*) TZ=$tz LC_ALL=C pr -D"$style" a >>prout 2>>err || fail=1 ;;
    esac
  done
done

sed 's/[^	]*	//' duout >dued || framework_failure_
sed 's/[^ ]* *[^ ]* *[^ ]* *[^ ]* *//' lsout >lsed || framework_failure_
sed '/^$/d' prout >pred || framework_failure_

cat <<\EOF > duexp || fail=1
1970-07-08 09:10:11.000000000 +0000	a
1970-07-08 09:10	a
1970-07-08	a
1970-07-08 09:10:11 +0000 (UTC)	a
%bJul%bJul	a
1970-07-08 01:10:11.000000000 -0800	a
1970-07-08 01:10	a
1970-07-08	a
1970-07-08 01:10:11 -0800 (PST)	a
%bJul%bJul	a
1970-07-08 02:10:11.000000000 -0700	a
1970-07-08 02:10	a
1970-07-08	a
1970-07-08 02:10:11 -0700 (PDT)	a
%bJul%bJul	a
1970-07-08 21:40:11.000000000 +1230	a
1970-07-08 21:40	a
1970-07-08	a
1970-07-08 21:40:11 +1230 (XXXYYY)	a
%bJul%bJul	a
EOF

cat <<\EOF > lsexp || fail=1
1970-07-08 09:10:11.000000000 +0000 a
1970-07-08 09:10 a
1970-07-08  a
Jul  8  1970 a
1970-07-08 09:10:11 +0000 (UTC) a
%bJul%bJul a
1970-07-08 01:10:11.000000000 -0800 a
1970-07-08 01:10 a
1970-07-08  a
Jul  8  1970 a
1970-07-08 01:10:11 -0800 (PST) a
%bJul%bJul a
1970-07-08 02:10:11.000000000 -0700 a
1970-07-08 02:10 a
1970-07-08  a
Jul  8  1970 a
1970-07-08 02:10:11 -0700 (PDT) a
%bJul%bJul a
1970-07-08 21:40:11.000000000 +1230 a
1970-07-08 21:40 a
1970-07-08  a
Jul  8  1970 a
1970-07-08 21:40:11 +1230 (XXXYYY) a
%bJul%bJul a
EOF

cat <<\EOF > prexp || fail=1
+1970-07-08 09:10:11 +0000 (UTC)                a                 Page 1
hello
+%bJul%bJul                           a                           Page 1
hello
+1970-07-08 01:10:11 -0800 (PST)                a                 Page 1
hello
+%bJul%bJul                           a                           Page 1
hello
+1970-07-08 02:10:11 -0700 (PDT)                a                 Page 1
hello
+%bJul%bJul                           a                           Page 1
hello
+1970-07-08 21:40:11 +1230 (XXXYYY)               a               Page 1
hello
+%bJul%bJul                           a                           Page 1
hello
EOF

compare duexp dued || fail=1
compare lsexp lsed || fail=1
compare prexp pred || fail=1
compare /dev/null err || fail=1

Exit $fail
