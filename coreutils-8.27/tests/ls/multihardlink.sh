#!/bin/sh
# Ensure "ls --color" properly colorizes hard linked files.

# Copyright (C) 2008-2017 Free Software Foundation, Inc.

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
print_ver_ ls
working_umask_or_skip_

touch file file1 || framework_failure_
ln file1 file2 || skip_ "can't create hard link"
code_mh='44;37'
code_ex='01;32'
code_png='01;35'
c0=$(printf '\033[0m')
c_mh=$(printf '\033[%sm' $code_mh)
c_ex=$(printf '\033[%sm' $code_ex)
c_png=$(printf '\033[%sm' $code_png)

# regular file - not hard linked
LS_COLORS="mh=$code_mh" ls -U1 --color=always file > out || fail=1
printf "file\n" > out_ok || framework_failure_
compare out out_ok || fail=1

# hard links
LS_COLORS="mh=$code_mh" ls -U1 --color=always file1 file2 > out || fail=1
printf "$c0${c_mh}file1$c0
${c_mh}file2$c0
" > out_ok || framework_failure_
compare out out_ok || fail=1

# hard links and png (hard link coloring takes precedence)
mv file2 file2.png || framework_failure_
LS_COLORS="mh=$code_mh:*.png=$code_png" ls -U1 --color=always file1 file2.png \
  > out || fail=1
printf "$c0${c_mh}file1$c0
${c_mh}file2.png$c0
" > out_ok || framework_failure_
compare out out_ok || fail=1

# hard links and exe (exe coloring takes precedence)
chmod a+x file2.png || framework_failure_
LS_COLORS="mh=$code_mh:*.png=$code_png:ex=$code_ex" \
  ls -U1 --color=always file1 file2.png > out || fail=1
chmod a-x file2.png || framework_failure_
printf "$c0${c_ex}file1$c0
${c_ex}file2.png$c0
" > out_ok || framework_failure_
compare out out_ok || fail=1

# hard links and png (hard link coloring disabled => png coloring enabled)
LS_COLORS="mh=00:*.png=$code_png" ls -U1 --color=always file1 file2.png > out \
  || fail=1
printf "file1
$c0${c_png}file2.png$c0
" > out_ok || framework_failure_
compare out out_ok || fail=1

# hard links and png (hard link coloring not enabled explicitly => png coloring)
LS_COLORS="*.png=$code_png" ls -U1 --color=always file1 file2.png > out \
  || fail=1
printf "file1
$c0${c_png}file2.png$c0
" > out_ok || framework_failure_
compare out out_ok || fail=1

Exit $fail
