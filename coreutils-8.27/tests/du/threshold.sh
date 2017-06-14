#!/bin/sh
# Exercise du's --threshold option.

# Copyright (C) 2013-2017 Free Software Foundation, Inc.

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

mkdir -p a/b a/c || framework_failure_

touch            a/b/0 || framework_failure_
printf '%1s' x > a/b/1 || framework_failure_
printf '%2s' x > a/b/2 || framework_failure_
printf '%3s' x > a/b/3 || framework_failure_

Ba=$(stat --format="%B * %b" a     | xargs expr)
Bb=$(stat --format="%B * %b" a/b   | xargs expr)
Bc=$(stat --format="%B * %b" a/c   | xargs expr)
B0=$(stat --format="%B * %b" a/b/0 | xargs expr)
B1=$(stat --format="%B * %b" a/b/1 | xargs expr)
B2=$(stat --format="%B * %b" a/b/2 | xargs expr)
B3=$(stat --format="%B * %b" a/b/3 | xargs expr)

Sa=$(stat --format=%s a    )
Sb=$(stat --format=%s a/b  )
Sc=$(stat --format=%s a/c  )
S0=$(stat --format=%s a/b/0)
S1=$(stat --format=%s a/b/1)
S2=$(stat --format=%s a/b/2)
S3=$(stat --format=%s a/b/3)

Bb0123=$(expr $Bb + $B0 + $B1 + $B2 + $B3)
Sb0123=$(expr $Sb + $S0 + $S1 + $S2 + $S3)

Bab0123=$(expr $Ba + $Bc + $Bb0123)
Sab0123=$(expr $Sa + $Sc + $Sb0123)

# Sanity checks
test $Ba -gt 4 || skip_ "block size of a directory is smaller than 4 bytes"
test $Bc -gt 4 || skip_ "block size of an empty directory is smaller than 4 \
bytes"
test $Sa -gt 4 || skip_ "apparent size of a directory is smaller than 4 bytes"
test $B1 -gt 4 || skip_ "block size of small file smaller than 4 bytes"
test $S3 -eq 3 || framework_failure_
test $S2 -eq 2 || framework_failure_
test $S1 -eq 1 || framework_failure_
test $S0 -eq 0 || framework_failure_
test $B0 -eq 0 || skip_ "block size of an empty file unequal Zero"
# block size of a/b/1 == a/b/2
test $B1 -eq $B2 || framework_failure_
# a is bigger than a/b.
test $Sab0123 -gt $Sb0123 || framework_failure_
test $Bab0123 -gt $Bb0123 || framework_failure_
# a/b is bigger than empty a/c.
test $Sb0123 -gt $Sc || framework_failure_
test $Bb0123 -gt $Bc || framework_failure_

# Exercise a bad argument: unparsable number.
cat <<EOF > exp
du: invalid --threshold argument 'SIZE'
EOF
du --threshold=SIZE a > out 2>&1 && fail=1
compare exp out || fail=1

cat <<EOF > exp
du: invalid -t argument 'SIZE'
EOF
du -t SIZE a > out 2>&1 && fail=1
compare exp out || fail=1

# Exercise a bad argument: -0 is not valid.
cat <<EOF > exp
du: invalid --threshold argument '-0'
EOF
du --threshold=-0 a > out 2>&1 && fail=1
compare exp out || fail=1

du -t -0 a > out 2>&1 && fail=1
compare exp out || fail=1

du -t-0 a > out 2>&1 && fail=1
compare exp out || fail=1

# Exercise a bad argument: empty argument.
cat <<EOF > exp
du: invalid --threshold argument ''
EOF
du --threshold= a > out 2>&1 && fail=1
compare exp out || fail=1

# Exercise a bad argument: no argument.
du --threshold > out.tmp 2>&1 && fail=1
sed 's/argument.*/argument/; s/option.*requires/option requires/' \
  < out.tmp > out || framework_failure_
cat <<EOF > exp
du: option requires an argument
Try 'du --help' for more information.
EOF
compare exp out || fail=1
rm -f out

dutest ()
{
  args="$1"
  exp="$2"

  rm -f exp out

  # Expected output.
  if [ "$exp" = "" ] ; then
    touch exp
  else
    printf "%s\n" $exp > exp
  fi

  rc=0
  du -B1 $args a > out1 2>&1 || { cat out1 ; rc=1 ; }

  # Remove the size column and sort the output.
  cut -f2- out1 | sort > out || framework_failure_

  compare exp out || { cat out1 ; rc=1 ; }
  return $rc
}

# Check numbers around the total size of the main directory 'a'.
# One byte greater than 'a'.
s=$(expr $Sab0123 + 1)  # apparent size
dutest "--app       -t $s"  ''                                  || fail=1
dutest "--app -a    -t $s"  ''                                  || fail=1
dutest "--app    -S -t $s"  ''                                  || fail=1
dutest "--app -a -S -t $s"  ''                                  || fail=1
dutest "--app       -t -$s" 'a a/b a/c'                         || fail=1
dutest "--app -a    -t -$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c' || fail=1
dutest "--app    -S -t -$s" 'a a/b a/c'                         || fail=1
dutest "--app -a -S -t -$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c' || fail=1
s=$(expr $Bab0123 + 1)  # block size
dutest "            -t $s"  ''                                  || fail=1
dutest "      -a    -t $s"  ''                                  || fail=1
dutest "         -S -t $s"  ''                                  || fail=1
dutest "      -a -S -t $s"  ''                                  || fail=1
dutest "            -t -$s" 'a a/b a/c'                         || fail=1
dutest "      -a    -t -$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c' || fail=1
dutest "         -S -t -$s" 'a a/b a/c'                         || fail=1
dutest "      -a -S -t -$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c' || fail=1

# Exactly the size of 'a'.
s=$Sab0123  # apparent size
dutest "--app       --th=$s"  'a'                                 || fail=1
dutest "--app -a    --th=$s"  'a'                                 || fail=1
dutest "--app    -S --th=$s"  ''                                  || fail=1
dutest "--app -a -S --th=$s"  ''                                  || fail=1
dutest "--app       --th=-$s" 'a a/b a/c'                         || fail=1
dutest "--app -a    --th=-$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c' || fail=1
dutest "--app    -S --th=-$s" 'a a/b a/c'                         || fail=1
dutest "--app -a -S --th=-$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c' || fail=1
s=$Bab0123  # block size
dutest "            --th=$s"  'a'                                 || fail=1
dutest "      -a    --th=$s"  'a'                                 || fail=1
dutest "         -S --th=$s"  ''                                  || fail=1
dutest "      -a -S --th=$s"  ''                                  || fail=1
dutest "            --th=-$s" 'a a/b a/c'                         || fail=1
dutest "      -a    --th=-$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c' || fail=1
dutest "         -S --th=-$s" 'a a/b a/c'                         || fail=1
dutest "      -a -S --th=-$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c' || fail=1

# One byte smaller than 'a'.
s=$(expr $Sab0123 - 1)  # apparent size
dutest "--app       --th=$s"  'a'                                 || fail=1
dutest "--app -a    --th=$s"  'a'                                 || fail=1
dutest "--app    -S --th=$s"  ''                                  || fail=1
dutest "--app -a -S --th=$s"  ''                                  || fail=1
dutest "--app       --th=-$s" 'a/b a/c'                           || fail=1
dutest "--app -a    --th=-$s" 'a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c'   || fail=1
dutest "--app    -S --th=-$s" 'a a/b a/c'                         || fail=1
dutest "--app -a -S --th=-$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c' || fail=1
s=$(expr $Bab0123 - 1)  # block size
dutest "            --th=$s"  'a'                                 || fail=1
dutest "      -a    --th=$s"  'a'                                 || fail=1
dutest "         -S --th=$s"  ''                                  || fail=1
dutest "      -a -S --th=$s"  ''                                  || fail=1
dutest "            --th=-$s" 'a/b a/c'                           || fail=1
dutest "      -a    --th=-$s" 'a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c'   || fail=1
dutest "         -S --th=-$s" 'a a/b a/c'                         || fail=1
dutest "      -a -S --th=-$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c' || fail=1


# Check numbers around the total size of the sub directory 'a/b'.
# One byte greater than 'a/b'.
s=$(expr $Sb0123 + 1)  # apparent size
dutest "--app       --th=$s"  'a'                                 || fail=1
dutest "--app -a    --th=$s"  'a'                                 || fail=1
dutest "--app    -S --th=$s"  ''                                  || fail=1
dutest "--app -a -S --th=$s"  ''                                  || fail=1
dutest "--app       --th=-$s" 'a/b a/c'                           || fail=1
dutest "--app -a    --th=-$s" 'a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c'   || fail=1
dutest "--app    -S --th=-$s" 'a a/b a/c'                         || fail=1
dutest "--app -a -S --th=-$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c' || fail=1
s=$(expr $Bb0123 + 1)  # block size
dutest "            --th=$s"  'a'                                  || fail=1
dutest "      -a    --th=$s"  'a'                                  || fail=1
dutest "         -S --th=$s"  ''                                   || fail=1
dutest "      -a -S --th=$s"  ''                                   || fail=1
dutest "            --th=-$s" 'a/b a/c'                            || fail=1
dutest "      -a    --th=-$s" 'a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c'    || fail=1
dutest "         -S --th=-$s" 'a a/b a/c'                          || fail=1
dutest "      -a -S --th=-$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c'  || fail=1

# Exactly the size of 'a/b'.
s=$Sb0123  # apparent size
dutest "--app       --th=$s"  'a a/b'                              || fail=1
dutest "--app -a    --th=$s"  'a a/b'                              || fail=1
dutest "--app    -S --th=$s"  'a/b'                                || fail=1
dutest "--app -a -S --th=$s"  'a/b'                                || fail=1
dutest "--app       --th=-$s" 'a/b a/c'                            || fail=1
dutest "--app -a    --th=-$s" 'a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c'    || fail=1
dutest "--app    -S --th=-$s" 'a a/b a/c'                          || fail=1
dutest "--app -a -S --th=-$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c'  || fail=1
s=$Bb0123  # block size
dutest "            --th=$s"  'a a/b'                              || fail=1
dutest "      -a    --th=$s"  'a a/b'                              || fail=1
dutest "         -S --th=$s"  'a/b'                                || fail=1
dutest "      -a -S --th=$s"  'a/b'                                || fail=1
dutest "            --th=-$s" 'a/b a/c'                            || fail=1
dutest "      -a    --th=-$s" 'a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c'    || fail=1
dutest "         -S --th=-$s" 'a a/b a/c'                          || fail=1
dutest "      -a -S --th=-$s" 'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c'  || fail=1

# One byte smaller than 'a/b'.
s=$(expr $Sb0123 - 1)  # apparent size
dutest "--app       --th=$s"  'a a/b'                              || fail=1
dutest "--app -a    --th=$s"  'a a/b'                              || fail=1
dutest "--app    -S --th=$s"  'a/b'                                || fail=1
dutest "--app -a -S --th=$s"  'a/b'                                || fail=1
dutest "--app       --th=-$s" 'a/c'                                || fail=1
dutest "--app -a    --th=-$s" 'a/b/0 a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "--app    -S --th=-$s" 'a a/c'                              || fail=1
dutest "--app -a -S --th=-$s" 'a a/b/0 a/b/1 a/b/2 a/b/3 a/c'      || fail=1
s=$(expr $Bb0123 - 1)  # block size
dutest "            --th=$s"  'a a/b'                              || fail=1
dutest "      -a    --th=$s"  'a a/b'                              || fail=1
dutest "         -S --th=$s"  'a/b'                                || fail=1
dutest "      -a -S --th=$s"  'a/b'                                || fail=1
dutest "            --th=-$s" 'a/c'                                || fail=1
dutest "      -a    --th=-$s" 'a/b/0 a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "         -S --th=-$s" 'a a/c'                              || fail=1
dutest "      -a -S --th=-$s" 'a a/b/0 a/b/1 a/b/2 a/b/3 a/c'      || fail=1


# Check numbers around the total size of the files a/b/[0123]'.
echo One byte greater than 'a/b/3'.
s=$(expr $S3 + 1)  # apparent size
dutest "--app       --th=$s"  'a a/b a/c'                          || fail=1
dutest "--app -a    --th=$s"  'a a/b a/c'                          || fail=1
dutest "--app    -S --th=$s"  'a a/b a/c'                          || fail=1
dutest "--app -a -S --th=$s"  'a a/b a/c'                          || fail=1
dutest "--app       --th=-$s" ''                                   || fail=1
dutest "--app -a    --th=-$s" 'a/b/0 a/b/1 a/b/2 a/b/3'            || fail=1
dutest "--app    -S --th=-$s" ''                                   || fail=1
dutest "--app -a -S --th=-$s" 'a/b/0 a/b/1 a/b/2 a/b/3'            || fail=1
s=$(expr $B3 + 1)  # block size
dutest "            --th=$s"  'a a/b'                              || fail=1
dutest "      -a    --th=$s"  'a a/b'                              || fail=1
dutest "         -S --th=$s"  'a/b'                                || fail=1
dutest "      -a -S --th=$s"  'a/b'                                || fail=1
dutest "            --th=-$s" 'a/c'                                || fail=1
dutest "      -a    --th=-$s" 'a/b/0 a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "         -S --th=-$s" 'a a/c'                              || fail=1
dutest "      -a -S --th=-$s" 'a a/b/0 a/b/1 a/b/2 a/b/3 a/c'      || fail=1

# Exactly the size of 'a/b/3'.
echo Exactly the size of 'a/b/3'.
s=$S3  # apparent size
dutest "--app       --th=$s"  'a a/b a/c'                          || fail=1
dutest "--app -a    --th=$s"  'a a/b a/b/3 a/c'                    || fail=1
dutest "--app    -S --th=$s"  'a a/b a/c'                          || fail=1
dutest "--app -a -S --th=$s"  'a a/b a/b/3 a/c'                    || fail=1
dutest "--app       --th=-$s" ''                                   || fail=1
dutest "--app -a    --th=-$s" 'a/b/0 a/b/1 a/b/2 a/b/3'            || fail=1
dutest "--app    -S --th=-$s" ''                                   || fail=1
dutest "--app -a -S --th=-$s" 'a/b/0 a/b/1 a/b/2 a/b/3'            || fail=1
s=$B3  # block size
dutest "            --th=$s"  'a a/b a/c'                          || fail=1
dutest "      -a    --th=$s"  'a a/b a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "         -S --th=$s"  'a a/b a/c'                          || fail=1
dutest "      -a -S --th=$s"  'a a/b a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "            --th=-$s" 'a/c'                                || fail=1
dutest "      -a    --th=-$s" 'a/b/0 a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "         -S --th=-$s" 'a a/c'                              || fail=1
dutest "      -a -S --th=-$s" 'a a/b/0 a/b/1 a/b/2 a/b/3 a/c'      || fail=1

# Exactly the size of 'a/b/2'.
echo Exactly the size of 'a/b/2'.
s=$S2  # apparent size
dutest "--app       --th=$s"  'a a/b a/c'                          || fail=1
dutest "--app -a    --th=$s"  'a a/b a/b/2 a/b/3 a/c'              || fail=1
dutest "--app    -S --th=$s"  'a a/b a/c'                          || fail=1
dutest "--app -a -S --th=$s"  'a a/b a/b/2 a/b/3 a/c'              || fail=1
dutest "--app       --th=-$s" ''                                   || fail=1
dutest "--app -a    --th=-$s" 'a/b/0 a/b/1 a/b/2'                  || fail=1
dutest "--app    -S --th=-$s" ''                                   || fail=1
dutest "--app -a -S --th=-$s" 'a/b/0 a/b/1 a/b/2'                  || fail=1
s=$B2  # block size
dutest "            --th=$s"  'a a/b a/c'                          || fail=1
dutest "      -a    --th=$s"  'a a/b a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "         -S --th=$s"  'a a/b a/c'                          || fail=1
dutest "      -a -S --th=$s"  'a a/b a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "            --th=-$s" 'a/c'                                || fail=1
dutest "      -a    --th=-$s" 'a/b/0 a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "         -S --th=-$s" 'a a/c'                              || fail=1
dutest "      -a -S --th=-$s" 'a a/b/0 a/b/1 a/b/2 a/b/3 a/c'      || fail=1

# Exactly the size of 'a/b/1'.
echo Exactly the size of 'a/b/1'.
s=$S1  # apparent size
dutest "--app       --th=$s"  'a a/b a/c'                          || fail=1
dutest "--app -a    --th=$s"  'a a/b a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "--app    -S --th=$s"  'a a/b a/c'                          || fail=1
dutest "--app -a -S --th=$s"  'a a/b a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "--app       --th=-$s" ''                                   || fail=1
dutest "--app -a    --th=-$s" 'a/b/0 a/b/1'                        || fail=1
dutest "--app    -S --th=-$s" ''                                   || fail=1
dutest "--app -a -S --th=-$s" 'a/b/0 a/b/1'                        || fail=1
s=$B1  # block size
dutest "            --th=$s"  'a a/b a/c'                          || fail=1
dutest "      -a    --th=$s"  'a a/b a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "         -S --th=$s"  'a a/b a/c'                          || fail=1
dutest "      -a -S --th=$s"  'a a/b a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "            --th=-$s" 'a/c'                                || fail=1
dutest "      -a    --th=-$s" 'a/b/0 a/b/1 a/b/2 a/b/3 a/c'        || fail=1
dutest "         -S --th=-$s" 'a a/c'                              || fail=1
dutest "      -a -S --th=-$s" 'a a/b/0 a/b/1 a/b/2 a/b/3 a/c'      || fail=1

# Exactly the size of 'a/b/0'.
echo Exactly the size of 'a/b/0'.
s=$S0  # apparent size
dutest "--app       --th=$s"  'a a/b a/c'                          || fail=1
dutest "--app -a    --th=$s"  'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c'  || fail=1
dutest "--app    -S --th=$s"  'a a/b a/c'                          || fail=1
dutest "--app -a -S --th=$s"  'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c'  || fail=1
# (maximum tests (-0) not possible).
s=$B0  # block size
dutest "            --th=$s"  'a a/b a/c'                          || fail=1
dutest "      -a    --th=$s"  'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c'  || fail=1
dutest "         -S --th=$s"  'a a/b a/c'                          || fail=1
dutest "      -a -S --th=$s"  'a a/b a/b/0 a/b/1 a/b/2 a/b/3 a/c'  || fail=1
# (maximum tests (-0) not possible).

Exit $fail
