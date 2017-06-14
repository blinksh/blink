#!/bin/sh
# Make sure all of these programs work properly
# when invoked with --help or --version.

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

# Terminate any background processes
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

expected_failure_status_chroot=125
expected_failure_status_env=125
expected_failure_status_nice=125
expected_failure_status_nohup=125
expected_failure_status_stdbuf=125
expected_failure_status_timeout=125
expected_failure_status_printenv=2
expected_failure_status_tty=3
expected_failure_status_sort=2
expected_failure_status_expr=3
expected_failure_status_lbracket=2
expected_failure_status_dir=2
expected_failure_status_ls=2
expected_failure_status_vdir=2

expected_failure_status_cmp=2
expected_failure_status_zcmp=2
expected_failure_status_sdiff=2
expected_failure_status_diff3=2
expected_failure_status_diff=2
expected_failure_status_zdiff=2
expected_failure_status_zgrep=2
expected_failure_status_zegrep=2
expected_failure_status_zfgrep=2

expected_failure_status_grep=2
expected_failure_status_egrep=2
expected_failure_status_fgrep=2

test "$built_programs" \
  || fail_ "built_programs not specified!?!"

test "$VERSION" \
  || fail_ "set envvar VERSION; it is required for a PATH sanity-check"

# Extract version from --version output of the first program
for i in $built_programs; do
  v=$(env $i --version | sed -n '1s/.* //p;q')
  break
done

# Ensure that it matches $VERSION.
test "x$v" = "x$VERSION" \
  || fail_ "--version-\$VERSION mismatch"

for i in $built_programs; do

  # Skip 'test'; it doesn't accept --help or --version.
  test $i = test && continue

  # false fails even when invoked with --help or --version.
  # true and false are tested with these options separately.
  test $i = false || test $i = true && continue

  # The just-built install executable is always named 'ginstall'.
  test $i = install && i=ginstall

  # Make sure they exit successfully, under normal conditions.
  env $i --help    >/dev/null || fail=1
  env $i --version >/dev/null || fail=1

  # Make sure they fail upon 'disk full' error.
  if test -w /dev/full && test -c /dev/full; then
    test $i = [ && prog=lbracket || prog=$(echo $i|sed "s/$EXEEXT$//")
    eval "expected=\$expected_failure_status_$prog"
    test x$expected = x && expected=1

    returns_ $expected env $i --help    >/dev/full 2>/dev/null &&
    returns_ $expected env $i --version >/dev/full 2>/dev/null ||
    {
      fail=1
      env $i --help >/dev/full 2>/dev/null
      status=$?
      echo "*** $i: bad exit status '$status' (expected $expected)," 1>&2
      echo "  with --help or --version output redirected to /dev/full" 1>&2
    }
  fi
done

bigZ_in=bigZ-in.Z
zin=zin.gz
zin2=zin2.gz

tmp=tmp-$$
tmp_in=in-$$
tmp_in2=in2-$$
tmp_dir=dir-$$
tmp_out=out-$$
mkdir $tmp || fail=1
cd $tmp || fail=1

comm_setup () { args="$tmp_in $tmp_in"; }
csplit_setup () { args="$tmp_in //"; }
cut_setup () { args='-f 1'; }
join_setup () { args="$tmp_in $tmp_in"; }
tr_setup () { args='a a'; }

chmod_setup () { args="a+x $tmp_in"; }
# Punt on these.
chgrp_setup () { args=--version; }
chown_setup () { args=--version; }
mkfifo_setup () { args=--version; }
mknod_setup () { args=--version; }
# Punt on uptime, since it fails (e.g., failing to get boot time)
# on some systems, and we shouldn't let that stop 'make check'.
uptime_setup () { args=--version; }

# Create a file in the current directory, not in $TMPDIR.
mktemp_setup () { args=mktemp.XXXX; }

cmp_setup () { args="$tmp_in $tmp_in2"; }

# Tell dd not to print the line with transfer rate and total.
# The transfer rate would vary between runs.
dd_setup () { args=status=noxfer; }

zdiff_setup () { args="$zin $zin2"; }
zcmp_setup () { args="$zin $zin2"; }
zcat_setup () { args=$zin; }
gunzip_setup () { args=$zin; }
zmore_setup () { args=$zin; }
zless_setup () { args=$zin; }
znew_setup () { args=$bigZ_in; }
zforce_setup () { args=$zin; }
zgrep_setup () { args="z $zin"; }
zegrep_setup () { args="z $zin"; }
zfgrep_setup () { args="z $zin"; }
gzexe_setup () { args=$tmp_in; }

# We know that $tmp_in contains a "0"
grep_setup () { args="0 $tmp_in"; }
egrep_setup () { args="0 $tmp_in"; }
fgrep_setup () { args="0 $tmp_in"; }

diff_setup () { args="$tmp_in $tmp_in2"; }
sdiff_setup () { args="$tmp_in $tmp_in2"; }
diff3_setup () { args="$tmp_in $tmp_in2 $tmp_in2"; }
cp_setup () { args="$tmp_in $tmp_in2"; }
ln_setup () { args="$tmp_in ln-target"; }
ginstall_setup () { args="$tmp_in $tmp_in2"; }
mv_setup () { args="$tmp_in $tmp_in2"; }
mkdir_setup () { args=$tmp_dir/subdir; }
realpath_setup () { args=$tmp_in; }
rmdir_setup () { args=$tmp_dir; }
rm_setup () { args=$tmp_in; }
shred_setup () { args=$tmp_in; }
touch_setup () { args=$tmp_in2; }
truncate_setup () { args="--reference=$tmp_in $tmp_in2"; }

mkid_setup () { printf 'f(){}\ntypedef int t;\n' > f.c; args=. ; }
lid_setup () { args=; }
fid_setup () { args=f.c; }
fnid_setup () { args=; }
xtokid_setup () { args=; }
aid_setup () { args=f; }
eid_setup () { args=--version; }
gid_setup () { args=f; }
defid_setup () { args=t; }

basename_setup () { args=$tmp_in; }
dirname_setup () { args=$tmp_in; }
expr_setup () { args=foo; }

# Punt, in case GNU 'id' hasn't been installed yet.
groups_setup () { args=--version; }

pathchk_setup () { args=$tmp_in; }
yes_setup () { args=--version; }
logname_setup () { args=--version; }
nohup_setup () { args=--version; }
printf_setup () { args=foo; }
seq_setup () { args=10; }
sleep_setup () { args=0; }
stdbuf_setup () { args="-oL true"; }
timeout_setup () { args=--version; }

# I'd rather not run sync, since it spins up disks that I've
# deliberately caused to spin down (but not unmounted).
sync_setup () { args=--version; }

test_setup () { args=foo; }

# This is necessary in the unusual event that there is
# no valid entry in /etc/mtab.
df_setup () { args=/; }

# This is necessary in the unusual event that getpwuid (getuid ()) fails.
id_setup () { args=-u; }

# Use env to avoid invoking built-in sleep of Solaris 11's /bin/sh.
kill_setup () {
  external=env
  $external sleep 10m & pid=$!
  args=$pid
}

link_setup () { args="$tmp_in link-target"; }
unlink_setup () { args=$tmp_in; }

readlink_setup () {
  ln -s . slink
  args=slink;
}

stat_setup () { args=$tmp_in; }
unlink_setup () { args=$tmp_in; }
lbracket_setup () { args=": ]"; }

parted_setup () { args="-s $tmp_in mklabel gpt"
  dd if=/dev/null of=$tmp_in seek=2000; }

# Ensure that each program "works" (exits successfully) when doing
# something more than --help or --version.
for i in $built_programs; do
  # Skip these.
  case $i in chroot|stty|tty|false|chcon|runcon|coreutils) continue;; esac

  rm -rf $tmp_in $tmp_in2 $tmp_dir $tmp_out $bigZ_in $zin $zin2
  echo z |gzip > $zin
  cp $zin $zin2
  cp $zin $bigZ_in

  # This is sort of kludgey: use numbers so this is valid input for factor,
  # and two tokens so it's valid input for tsort.
  echo 2147483647 0 > $tmp_in
  # Make $tmp_in2 identical. Then, using $tmp_in and $tmp_in2 as arguments
  # to the likes of cmp and diff makes them exit successfully.
  cp $tmp_in $tmp_in2
  mkdir $tmp_dir
  # echo ================== $i
  test $i = [ && prog=lbracket || prog=$(echo $i|sed "s/$EXEEXT$//")
  if type ${prog}_setup > /dev/null 2>&1; then
    ${prog}_setup
  else
    args=
  fi
  if env $i $args < $tmp_in > $tmp_out; then
    : # ok
  else
    echo FAIL: $i
    fail=1
  fi
  rm -rf $tmp_in $tmp_in2 $tmp_out $tmp_dir
done

Exit $fail
