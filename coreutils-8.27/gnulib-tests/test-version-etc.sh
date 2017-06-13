#! /bin/sh
# Test suite for version-etc.
# Copyright (C) 2009-2017 Free Software Foundation, Inc.
# This file is part of the GNUlib Library.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

TMP=ve-expected.tmp
LC_ALL=C
export LC_ALL
ERR=0

cat > $TMP <<EOT
test-version-etc (PROJECT) VERSION
COPYRIGHT Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Sergey Poznyakoff and Eric Blake.
EOT

./test-version-etc${EXEEXT} --version |
 sed '1s/test-version-etc (.*) .*/test-version-etc (PROJECT) VERSION/
      /^Packaged by/d
      2,3 s/Copyright (C) [0-9]\{4,4\}/COPYRIGHT/' |
 tr -d '\015' |
 diff -c $TMP - || ERR=1

rm $TMP

exit $ERR
