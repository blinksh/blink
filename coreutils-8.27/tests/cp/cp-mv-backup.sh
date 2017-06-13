#!/bin/sh
# Test basic --backup functionality for both cp and mv.

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
print_ver_ cp

umask 022

# Be careful to close $actual before removing the containing directory.
# Use '1>&2' rather than '1<&-' since the latter appears not to work
# with /bin/sh from powerpc-ibm-aix4.2.0.0.

actual=actual
expected=expected

exec 3>&1 1> $actual

for prog in cp mv; do
  for initial_files in 'x' 'x y' 'x y y~' 'x y y.~1~' 'x y y~ y.~1~'; do
    for opt in none off  numbered t  existing nil  simple never; do
      touch $initial_files
        $prog --backup=$opt x y || fail=1
      echo $initial_files $opt: $(ls [xy]*); rm -f x y y~ y.~?~
    done
  done
done

cat <<\EOF > $expected-tmp
x none: x y
x off: x y
x numbered: x y
x t: x y
x existing: x y
x nil: x y
x simple: x y
x never: x y
x y none: x y
x y off: x y
x y numbered: x y y.~1~
x y t: x y y.~1~
x y existing: x y y~
x y nil: x y y~
x y simple: x y y~
x y never: x y y~
x y y~ none: x y y~
x y y~ off: x y y~
x y y~ numbered: x y y.~1~ y~
x y y~ t: x y y.~1~ y~
x y y~ existing: x y y~
x y y~ nil: x y y~
x y y~ simple: x y y~
x y y~ never: x y y~
x y y.~1~ none: x y y.~1~
x y y.~1~ off: x y y.~1~
x y y.~1~ numbered: x y y.~1~ y.~2~
x y y.~1~ t: x y y.~1~ y.~2~
x y y.~1~ existing: x y y.~1~ y.~2~
x y y.~1~ nil: x y y.~1~ y.~2~
x y y.~1~ simple: x y y.~1~ y~
x y y.~1~ never: x y y.~1~ y~
x y y~ y.~1~ none: x y y.~1~ y~
x y y~ y.~1~ off: x y y.~1~ y~
x y y~ y.~1~ numbered: x y y.~1~ y.~2~ y~
x y y~ y.~1~ t: x y y.~1~ y.~2~ y~
x y y~ y.~1~ existing: x y y.~1~ y.~2~ y~
x y y~ y.~1~ nil: x y y.~1~ y.~2~ y~
x y y~ y.~1~ simple: x y y.~1~ y~
x y y~ y.~1~ never: x y y.~1~ y~
EOF

sed 's/: x/:/' $expected-tmp |cat $expected-tmp - > $expected

exec 1>&3 3>&-

compare $expected $actual || fail=1

Exit $fail
