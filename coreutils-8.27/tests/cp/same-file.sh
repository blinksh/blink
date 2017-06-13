#!/bin/sh
# Test some of cp's options and how cp handles situations in
# which a naive implementation might overwrite the source file.

# Copyright (C) 1998-2017 Free Software Foundation, Inc.

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

# Unset CDPATH.  Otherwise, output from the 'cd dir' command
# can make this test fail.
(unset CDPATH) >/dev/null 2>&1 && unset CDPATH

VERSION_CONTROL=numbered; export VERSION_CONTROL

# Determine whether a hard link to a symlink points to the symlink
# itself or to its referent.  For example, the link from FreeBSD6.1
# does dereference a symlink, but the one from Linux does not.
ln -s no-such dangling-slink
ln dangling-slink hard-link > /dev/null 2>&1 \
  && hard_link_to_symlink_does_the_deref=no \
  || hard_link_to_symlink_does_the_deref=yes
rm -f no-such dangling-slink hard-link

test $hard_link_to_symlink_does_the_deref = yes \
    && remove_these_sed='/^0 -[bf]*l .*sl1 ->/d; /hlsl/d' \
    || remove_these_sed='/^ELIDE NO TEST OUTPUT/d'

exec 3>&1 1> actual

# FIXME: This should be bigger: like more than 8k
contents=XYZ

for args in 'foo symlink' 'symlink foo' 'foo foo' 'sl1 sl2' \
            'foo hardlink' 'hlsl sl2'; do
  for options in '' -d -f -df --rem -b -bd -bf -bdf \
                 -l -dl -fl -dfl -bl -bdl -bfl -bdfl; do
    case $args$options in
      # These tests are not portable.
      # They all involve making a hard link to a symbolic link.
      # In the past, we've skipped the tests that are not portable,
      # by doing "continue" here and eliminating the corresponding
      # expected output lines below.  Don't do that anymore.
      'symlink foo'-dfl)
        continue;;
      'symlink foo'-bdl)
        continue;;
      'symlink foo'-bdfl)
        continue;;
      'sl1 sl2'-dfl)
        continue;;
      'sl1 sl2'-bd*l)
        continue;;
      'sl1 sl2'-dl)
        continue;;
    esac

    # cont'd  Instead, skip them only on systems for which link does
    # dereference a symlink.  Detect and skip such tests here.
    case $hard_link_to_symlink_does_the_deref:$args:$options in
      'yes:sl1 sl2:-fl')
        continue ;;
      'yes:sl1 sl2:-bl')
        continue ;;
      'yes:sl1 sl2:-bfl')
        continue ;;
      yes:hlsl*)
        continue ;;
    esac

    rm -rf dir
    mkdir dir
    cd dir
    echo $contents > foo
    case "$args" in *symlink*) ln -s foo symlink ;; esac
    case "$args" in *hardlink*) ln foo hardlink ;; esac
    case "$args" in *sl1*) ln -s foo sl1;; esac
    case "$args" in *sl2*) ln -s foo sl2;; esac
    case "$args" in *hlsl*) ln sl2 hlsl;; esac
    (
      (
        # echo 1>&2 cp $options $args
        cp $options $args 2>_err
        echo $? $options

        # Normalize the program name and diagnostics in the error output,
        # and put brackets around the output.
        if test -s _err; then
          sed '
            s/^[^:]*:\([^:]*\).*/cp:\1/
            1s/^/[/
            $s/$/]/
          ' _err
        fi
        # Strip off all but the file names.
        ls=$(ls -gG --ignore=_err . \
             | sed \
                -e '/^total /d' \
                -e 's/^[^ ]*  *[^ ]*  *[^ ]*  *[^ ]*  *[^ ]*  *[^ ]*  *//')
        echo "($ls)"
        # Make sure the original is unchanged and that
        # the destination is a copy.
        for f in $args; do
          if test -f $f; then
            case "$(cat $f)" in
              "$contents") ;;
              *) echo cp FAILED;;
            esac
          else
            echo symlink-loop
          fi
        done
      ) | tr '\n' ' '
      echo
    ) | sed 's/  *$//'
    cd ..
  done
  echo
done

cat <<\EOF | sed "$remove_these_sed" > expected
1 [cp: 'foo' and 'symlink' are the same file] (foo symlink -> foo)
1 -d [cp: 'foo' and 'symlink' are the same file] (foo symlink -> foo)
1 -f [cp: 'foo' and 'symlink' are the same file] (foo symlink -> foo)
1 -df [cp: 'foo' and 'symlink' are the same file] (foo symlink -> foo)
0 --rem (foo symlink)
0 -b (foo symlink symlink.~1~ -> foo)
0 -bd (foo symlink symlink.~1~ -> foo)
0 -bf (foo symlink symlink.~1~ -> foo)
0 -bdf (foo symlink symlink.~1~ -> foo)
1 -l [cp: cannot create hard link 'symlink' to 'foo'] (foo symlink -> foo)
1 -dl [cp: cannot create hard link 'symlink' to 'foo'] (foo symlink -> foo)
0 -fl (foo symlink)
0 -dfl (foo symlink)
0 -bl (foo symlink symlink.~1~ -> foo)
0 -bdl (foo symlink symlink.~1~ -> foo)
0 -bfl (foo symlink symlink.~1~ -> foo)
0 -bdfl (foo symlink symlink.~1~ -> foo)

1 [cp: 'symlink' and 'foo' are the same file] (foo symlink -> foo)
1 -d [cp: 'symlink' and 'foo' are the same file] (foo symlink -> foo)
1 -f [cp: 'symlink' and 'foo' are the same file] (foo symlink -> foo)
1 -df [cp: 'symlink' and 'foo' are the same file] (foo symlink -> foo)
1 --rem [cp: 'symlink' and 'foo' are the same file] (foo symlink -> foo)
1 -b [cp: 'symlink' and 'foo' are the same file] (foo symlink -> foo)
0 -bd (foo -> foo foo.~1~ symlink -> foo) symlink-loop symlink-loop
1 -bf [cp: 'symlink' and 'foo' are the same file] (foo symlink -> foo)
0 -bdf (foo -> foo foo.~1~ symlink -> foo) symlink-loop symlink-loop
0 -l (foo symlink -> foo)
0 -dl (foo symlink -> foo)
0 -fl (foo symlink -> foo)
0 -bl (foo symlink -> foo)
0 -bfl (foo symlink -> foo)

1 [cp: 'foo' and 'foo' are the same file] (foo)
1 -d [cp: 'foo' and 'foo' are the same file] (foo)
1 -f [cp: 'foo' and 'foo' are the same file] (foo)
1 -df [cp: 'foo' and 'foo' are the same file] (foo)
1 --rem [cp: 'foo' and 'foo' are the same file] (foo)
1 -b [cp: 'foo' and 'foo' are the same file] (foo)
1 -bd [cp: 'foo' and 'foo' are the same file] (foo)
0 -bf (foo foo.~1~)
0 -bdf (foo foo.~1~)
0 -l (foo)
0 -dl (foo)
0 -fl (foo)
0 -dfl (foo)
0 -bl (foo)
0 -bdl (foo)
0 -bfl (foo foo.~1~)
0 -bdfl (foo foo.~1~)

1 [cp: 'sl1' and 'sl2' are the same file] (foo sl1 -> foo sl2 -> foo)
0 -d (foo sl1 -> foo sl2 -> foo)
1 -f [cp: 'sl1' and 'sl2' are the same file] (foo sl1 -> foo sl2 -> foo)
0 -df (foo sl1 -> foo sl2 -> foo)
0 --rem (foo sl1 -> foo sl2)
0 -b (foo sl1 -> foo sl2 sl2.~1~ -> foo)
0 -bd (foo sl1 -> foo sl2 -> foo sl2.~1~ -> foo)
0 -bf (foo sl1 -> foo sl2 sl2.~1~ -> foo)
0 -bdf (foo sl1 -> foo sl2 -> foo sl2.~1~ -> foo)
1 -l [cp: cannot create hard link 'sl2' to 'sl1'] (foo sl1 -> foo sl2 -> foo)
0 -fl (foo sl1 -> foo sl2)
0 -bl (foo sl1 -> foo sl2 sl2.~1~ -> foo)
0 -bfl (foo sl1 -> foo sl2 sl2.~1~ -> foo)

1 [cp: 'foo' and 'hardlink' are the same file] (foo hardlink)
1 -d [cp: 'foo' and 'hardlink' are the same file] (foo hardlink)
1 -f [cp: 'foo' and 'hardlink' are the same file] (foo hardlink)
1 -df [cp: 'foo' and 'hardlink' are the same file] (foo hardlink)
0 --rem (foo hardlink)
0 -b (foo hardlink hardlink.~1~)
0 -bd (foo hardlink hardlink.~1~)
0 -bf (foo hardlink hardlink.~1~)
0 -bdf (foo hardlink hardlink.~1~)
0 -l (foo hardlink)
0 -dl (foo hardlink)
0 -fl (foo hardlink)
0 -dfl (foo hardlink)
0 -bl (foo hardlink)
0 -bdl (foo hardlink)
0 -bfl (foo hardlink)
0 -bdfl (foo hardlink)

1 [cp: 'hlsl' and 'sl2' are the same file] (foo hlsl -> foo sl2 -> foo)
0 -d (foo hlsl -> foo sl2 -> foo)
1 -f [cp: 'hlsl' and 'sl2' are the same file] (foo hlsl -> foo sl2 -> foo)
0 -df (foo hlsl -> foo sl2 -> foo)
0 --rem (foo hlsl -> foo sl2)
0 -b (foo hlsl -> foo sl2 sl2.~1~ -> foo)
0 -bd (foo hlsl -> foo sl2 -> foo sl2.~1~ -> foo)
0 -bf (foo hlsl -> foo sl2 sl2.~1~ -> foo)
0 -bdf (foo hlsl -> foo sl2 -> foo sl2.~1~ -> foo)
1 -l [cp: cannot create hard link 'sl2' to 'hlsl'] (foo hlsl -> foo sl2 -> foo)
0 -dl (foo hlsl -> foo sl2 -> foo)
0 -fl (foo hlsl -> foo sl2)
0 -dfl (foo hlsl -> foo sl2 -> foo)
0 -bl (foo hlsl -> foo sl2 sl2.~1~ -> foo)
0 -bdl (foo hlsl -> foo sl2 -> foo)
0 -bfl (foo hlsl -> foo sl2 sl2.~1~ -> foo)
0 -bdfl (foo hlsl -> foo sl2 -> foo)

EOF

exec 1>&3 3>&-

compare expected actual 1>&2 || fail=1

Exit $fail
