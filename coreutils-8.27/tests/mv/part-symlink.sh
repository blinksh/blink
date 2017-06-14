#!/bin/sh
# make sure cp and mv can handle many combinations of local and
# other-partition regular/symlink'd files.

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
print_ver_ cp mv

cleanup_() { rm -rf "$other_partition_tmpdir"; }
. "$abs_srcdir/tests/other-fs-tmpdir"

# On NFS on Linux 2.6.9 at least we get:
# mv: preserving permissions for 'rem_sl': Operation not supported
require_local_dir_

pwd_tmp=$(pwd)

# Unset CDPATH.  Otherwise, output from the 'cd dir' command
# can make this test fail.
(unset CDPATH) >/dev/null 2>&1 && unset CDPATH


# Four cases:
# local regular file w/symlink on another partition
#   (loc_reg, rem_sl)
#   (rem_sl, loc_reg)
# local symlink to regular file on another partition
#   (loc_sl, rem_reg)
#   (rem_reg, loc_sl)

# Exercise those four cases for each of
# cp and mv, with lots of combinations of options.

exec 1> actual

# FIXME: This should be bigger: like more than 8k
contents=XYZ

loc_reg=loc_reg
loc_sl=loc_sl
rem_reg=$other_partition_tmpdir/rem_reg
rem_sl=$other_partition_tmpdir/rem_sl

for copy in cp mv; do
  for args in \
      'loc_reg rem_sl' \
      'rem_sl loc_reg' \
      'loc_sl rem_reg' \
      'rem_reg loc_sl' \
      ; do
    for options in '' --rem '--rem -d' '--rem -b' -b -bd -d; do
      case "$options" in *d*|*--rem*) test $copy = mv && continue;; esac
      rm -rf dir || fail=1
      rm -f "$other_partition_tmpdir"/* || fail=1
      mkdir dir || fail=1
      cd dir || fail=1
      case "$args" in *loc_reg*) reg_abs="$(pwd)/$loc_reg" ;; esac
      case "$args" in *rem_reg*) reg_abs=$rem_reg ;; esac
      case "$args" in *loc_sl*) slink=$loc_sl ;; esac
      case "$args" in *rem_sl*) slink=$rem_sl ;; esac

      echo $contents > "$reg_abs" || fail=1
      ln -nsf "$reg_abs" $slink || fail=1
      actual_args=$(echo $args|sed 's,^,$,;s/ / $/')
      actual_args=$(eval echo $actual_args)

      (
        (
          # echo 1>&2 cp $options $args
          $copy $options $actual_args 2>.err
          copy_status=$?
          echo $copy_status $copy $options $args

          # Normalize the program name in the error output,
          # remove any site-dependent part of other-partition file name,
          # and put brackets around the output.
          test -s .err \
            && {
            echo ' [' | tr -d '\n'
            sed 's/^[^:][^:]*\(..\):/\1:/;s,'"$other_partition_tmpdir/,," .err |
              tr -d '\n'
            echo ']'
            }
          # Strip off all but the file names.
          # Remove any site-dependent part of each file name.
          ls=$(ls -gG --ignore=.err . \
               | sed \
                  -e '/^total /d' \
                  -e "s,$other_partition_tmpdir/,," \
                  -e "s,$pwd_tmp/,," \
                  -e 's/^[^ ]*  *[^ ]*  *[^ ]*  *[^ ]*  *[^ ]*  *[^ ]*  *//')
          ls2=$(cd "$other_partition_tmpdir" && ls -gG --ignore=.err . \
                | sed \
                  -e '/^total /d' \
                  -e "s,$other_partition_tmpdir/,," \
                  -e "s,$pwd_tmp/,," \
                  -e 's/^[^ ]*  *[^ ]*  *[^ ]*  *[^ ]*  *[^ ]*  *[^ ]*  *//')
          echo " ("$ls") ("$ls2")"

          # If the command failed, then it must not have changed the files.
          if test $copy_status != 0; then
            for f in $actual_args; do
              test -f $f ||
                { echo " $copy FAILED but removed $f"; continue; }
              case "$(cat $f)" in
                "$contents") ;;
                *) echo " $copy FAILED but modified $f";;
              esac
            done
          fi

          if test $copy = cp; then
            # Make sure the original is unchanged and that
            # the destination is a copy.
            for f in $actual_args; do
              if test -f $f; then
                if test $copy_status != 0; then
                  test
                fi
                case "$(cat $f)" in
                  "$contents") ;;
                  *) echo " $copy FAILED";;
                esac
              else
                echo " symlink-loop"
              fi
            done
          fi
        )
      ) | sed 's/  *$//'
      cd ..
    done
    echo
  done
done

test $fail = 1 &&
  { (exit 1); exit; }

cat <<\EOF > expected
1 cp loc_reg rem_sl
 [cp: 'loc_reg' and 'rem_sl' are the same file]
 (loc_reg) (rem_sl -> dir/loc_reg)
0 cp --rem loc_reg rem_sl
 (loc_reg) (rem_sl)
0 cp --rem -d loc_reg rem_sl
 (loc_reg) (rem_sl)
0 cp --rem -b loc_reg rem_sl
 (loc_reg) (rem_sl rem_sl~ -> dir/loc_reg)
0 cp -b loc_reg rem_sl
 (loc_reg) (rem_sl rem_sl~ -> dir/loc_reg)
0 cp -bd loc_reg rem_sl
 (loc_reg) (rem_sl rem_sl~ -> dir/loc_reg)
1 cp -d loc_reg rem_sl
 [cp: 'loc_reg' and 'rem_sl' are the same file]
 (loc_reg) (rem_sl -> dir/loc_reg)

1 cp rem_sl loc_reg
 [cp: 'rem_sl' and 'loc_reg' are the same file]
 (loc_reg) (rem_sl -> dir/loc_reg)
1 cp --rem rem_sl loc_reg
 [cp: 'rem_sl' and 'loc_reg' are the same file]
 (loc_reg) (rem_sl -> dir/loc_reg)
1 cp --rem -d rem_sl loc_reg
 [cp: 'rem_sl' and 'loc_reg' are the same file]
 (loc_reg) (rem_sl -> dir/loc_reg)
1 cp --rem -b rem_sl loc_reg
 [cp: 'rem_sl' and 'loc_reg' are the same file]
 (loc_reg) (rem_sl -> dir/loc_reg)
1 cp -b rem_sl loc_reg
 [cp: 'rem_sl' and 'loc_reg' are the same file]
 (loc_reg) (rem_sl -> dir/loc_reg)
0 cp -bd rem_sl loc_reg
 (loc_reg -> dir/loc_reg loc_reg~) (rem_sl -> dir/loc_reg)
 symlink-loop
 symlink-loop
1 cp -d rem_sl loc_reg
 [cp: 'rem_sl' and 'loc_reg' are the same file]
 (loc_reg) (rem_sl -> dir/loc_reg)

1 cp loc_sl rem_reg
 [cp: 'loc_sl' and 'rem_reg' are the same file]
 (loc_sl -> rem_reg) (rem_reg)
1 cp --rem loc_sl rem_reg
 [cp: 'loc_sl' and 'rem_reg' are the same file]
 (loc_sl -> rem_reg) (rem_reg)
1 cp --rem -d loc_sl rem_reg
 [cp: 'loc_sl' and 'rem_reg' are the same file]
 (loc_sl -> rem_reg) (rem_reg)
1 cp --rem -b loc_sl rem_reg
 [cp: 'loc_sl' and 'rem_reg' are the same file]
 (loc_sl -> rem_reg) (rem_reg)
1 cp -b loc_sl rem_reg
 [cp: 'loc_sl' and 'rem_reg' are the same file]
 (loc_sl -> rem_reg) (rem_reg)
0 cp -bd loc_sl rem_reg
 (loc_sl -> rem_reg) (rem_reg -> rem_reg rem_reg~)
 symlink-loop
 symlink-loop
1 cp -d loc_sl rem_reg
 [cp: 'loc_sl' and 'rem_reg' are the same file]
 (loc_sl -> rem_reg) (rem_reg)

1 cp rem_reg loc_sl
 [cp: 'rem_reg' and 'loc_sl' are the same file]
 (loc_sl -> rem_reg) (rem_reg)
0 cp --rem rem_reg loc_sl
 (loc_sl) (rem_reg)
0 cp --rem -d rem_reg loc_sl
 (loc_sl) (rem_reg)
0 cp --rem -b rem_reg loc_sl
 (loc_sl loc_sl~ -> rem_reg) (rem_reg)
0 cp -b rem_reg loc_sl
 (loc_sl loc_sl~ -> rem_reg) (rem_reg)
0 cp -bd rem_reg loc_sl
 (loc_sl loc_sl~ -> rem_reg) (rem_reg)
1 cp -d rem_reg loc_sl
 [cp: 'rem_reg' and 'loc_sl' are the same file]
 (loc_sl -> rem_reg) (rem_reg)

0 mv loc_reg rem_sl
 () (rem_sl)
0 mv -b loc_reg rem_sl
 () (rem_sl rem_sl~ -> dir/loc_reg)

1 mv rem_sl loc_reg
 [mv: 'rem_sl' and 'loc_reg' are the same file]
 (loc_reg) (rem_sl -> dir/loc_reg)
0 mv -b rem_sl loc_reg
 (loc_reg -> dir/loc_reg loc_reg~) ()

1 mv loc_sl rem_reg
 [mv: 'loc_sl' and 'rem_reg' are the same file]
 (loc_sl -> rem_reg) (rem_reg)
0 mv -b loc_sl rem_reg
 () (rem_reg -> rem_reg rem_reg~)

0 mv rem_reg loc_sl
 (loc_sl) ()
0 mv -b rem_reg loc_sl
 (loc_sl loc_sl~ -> rem_reg) ()

EOF

# Redirect to stderr, since stdout is already taken.
compare expected actual 1>&2 || fail=1

Exit $fail
