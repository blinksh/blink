#!/bin/sh
# Ensure dd treats '--' properly.
# Also test some flag values.

# Copyright (C) 1999-2017 Free Software Foundation, Inc.

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
print_ver_ dd

tmp_in=dd-in
tmp_in2=dd-in2
tmp_sym=dd-sym
tmp_out=dd-out

warn=0
echo data > $tmp_in || framework_failure_
ln $tmp_in $tmp_in2 || framework_failure_
ln -s $tmp_in $tmp_sym || framework_failure_

# check status=none suppresses all output to stderr
dd status=none if=$tmp_in of=/dev/null 2> err || fail=1
compare /dev/null err || fail=1
dd status=none if=$tmp_in skip=2 of=/dev/null 2> err || fail=1
compare /dev/null err || fail=1
# check later status=none overrides earlier status=noxfer
dd status=noxfer status=none if=$tmp_in of=/dev/null 2> err || fail=1
compare /dev/null err || fail=1
# check later status=noxfer overrides earlier status=none
dd status=none status=noxfer if=$tmp_in of=/dev/null 2> err || fail=1
compare /dev/null err && fail=1

dd if=$tmp_in of=$tmp_out 2> /dev/null || fail=1
compare $tmp_in $tmp_out || fail=1

rm $tmp_out
dd -- if=$tmp_in of=$tmp_out 2> /dev/null || fail=1
compare $tmp_in $tmp_out || fail=1

if dd oflag=append if=$tmp_in of=$tmp_out 2> /dev/null; then
  compare $tmp_in $tmp_out || fail=1
fi

case $(cat /dev/stdin <$tmp_in 2>/dev/null) in
(data)
  rm -f $tmp_out
  dd if=/dev/stdin of=$tmp_out <$tmp_in || fail=1
  compare $tmp_in $tmp_out || fail=1
esac

if dd iflag=nofollow if=$tmp_in count=0 2> /dev/null; then
  returns_ 1 dd iflag=nofollow if=$tmp_sym count=0 2> /dev/null || fail=1
fi

if dd iflag=directory if=. count=0 2> /dev/null; then
  dd iflag=directory count=0 <. 2> /dev/null || fail=1
  returns_ 1 dd iflag=directory count=0 <$tmp_in 2> /dev/null || fail=1
fi

old_ls=$(ls -u --full-time $tmp_in)
sleep 1
if dd iflag=noatime if=$tmp_in of=$tmp_out 2> /dev/null; then
  new_ls=$(ls -u --full-time $tmp_in)
  if test "x$old_ls" != "x$new_ls"; then
    cat >&2 <<EOF
=================================================================
$0: WARNING!!!
This operating system has the O_NOATIME file status flag,
but it is silently ignored in some cases.
Therefore, dd options like iflag=noatime may be silently ignored.
=================================================================
EOF
    warn=77
  fi
fi

if dd oflag=nolinks if=$tmp_in of=$tmp_out 2> /dev/null; then
  returns_ 1 dd iflag=nolinks if=$tmp_in > /dev/null 2>&1 || fail=1
  returns_ 1 dd iflag=nolinks < $tmp_in > /dev/null 2>&1 || fail=1
  dd oflag=nolinks < $tmp_in > $tmp_out 2>&1 || fail=1
fi

outbytes=$(echo x | dd bs=3 ibs=10 obs=10 conv=sync 2>/dev/null | wc -c)
test "$outbytes" -eq 3 || fail=1

# A delay is required to trigger a failure.
# There might be some missed failures but it's unlikely.
(echo a; sleep .1; echo b) \
  | env LC_ALL=C dd bs=4 status=noxfer iflag=fullblock >out 2>err || fail=1
printf 'a\nb\n' > out_ok || framework_failure_
echo "1+0 records in
1+0 records out" > err_ok || framework_failure_
compare out_ok out || fail=1
compare err_ok err || fail=1

test $fail -eq 0 && fail=$warn

# Check a warning is issued for ambiguous 0x... numbers
dd if=/dev/null count=0x1 seek=0x1 skip=0x1 status=none 2>err || fail=1
cat <<\EOF >exp
dd: warning: '0x' is a zero multiplier; use '00x' if that is intended
dd: warning: '0x' is a zero multiplier; use '00x' if that is intended
dd: warning: '0x' is a zero multiplier; use '00x' if that is intended
EOF
compare exp err || fail=1


Exit $fail
