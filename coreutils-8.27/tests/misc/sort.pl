#!/usr/bin/perl

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

use strict;

my $limits = getlimits ();

my $prog = 'sort';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $mb_locale = $ENV{LOCALE_FR_UTF8};
! defined $mb_locale || $mb_locale eq 'none'
  and $mb_locale = 'C';

# Since each test is run with a file name and with redirected stdin,
# the name in the diagnostic is either the file name or "-".
# Normalize each diagnostic to use '-'.
my $normalize_filename = {ERR_SUBST => 's/^$prog: .*?:/$prog: -:/'};

my $no_file = "$prog: cannot read: no-file: No such file or directory\n";

my @Tests =
(
["n1", '-n', {IN=>".01\n0\n"}, {OUT=>"0\n.01\n"}],
["n2", '-n', {IN=>".02\n.01\n"}, {OUT=>".01\n.02\n"}],
["n3", '-n', {IN=>".02\n.00\n"}, {OUT=>".00\n.02\n"}],
["n4", '-n', {IN=>".02\n.000\n"}, {OUT=>".000\n.02\n"}],
["n5", '-n', {IN=>".021\n.029\n"}, {OUT=>".021\n.029\n"}],

["n6", '-n', {IN=>".02\n.0*\n"}, {OUT=>".0*\n.02\n"}],
["n7", '-n', {IN=>".02\n.*\n"}, {OUT=>".*\n.02\n"}],
["n8a", '-s -n -k1,1', {IN=>".0a\n.0b\n"}, {OUT=>".0a\n.0b\n"}],
["n8b", '-s -n -k1,1', {IN=>".0b\n.0a\n"}, {OUT=>".0b\n.0a\n"}],
["n9a", '-s -n -k1,1', {IN=>".000a\n.000b\n"}, {OUT=>".000a\n.000b\n"}],
["n9b", '-s -n -k1,1', {IN=>".000b\n.000a\n"}, {OUT=>".000b\n.000a\n"}],
["n10a", '-s -n -k1,1', {IN=>".00a\n.000b\n"}, {OUT=>".00a\n.000b\n"}],
["n10b", '-s -n -k1,1', {IN=>".00b\n.000a\n"}, {OUT=>".00b\n.000a\n"}],
["n11a", '-s -n -k1,1', {IN=>".01a\n.010\n"}, {OUT=>".01a\n.010\n"}],
["n11b", '-s -n -k1,1', {IN=>".010\n.01a\n"}, {OUT=>".010\n.01a\n"}],

# human readable suffixes
["h1", '-h',
 {IN=>"1Y\n1Z\n1E\n1P\n1T\n1G\n1M\n1K\n02\n1\nY\n-1k\n-1M\n-1G\n-1T\n"
      . "-1P\n-1E\n-1Z\n-1Y\n"},
 {OUT=>"-1Y\n-1Z\n-1E\n-1P\n-1T\n-1G\n-1M\n-1k\nY\n1\n02\n1K\n1M\n1G\n1T\n"
      . "1P\n1E\n1Z\n1Y\n"}],
["h2", '-h', {IN=>"1M\n-2G\n-3K"}, {OUT=>"-2G\n-3K\n1M\n"}],
# check that it works with powers of 1024
["h3", '-k 2,2h -k 1,1', {IN=>"a 1G\nb 1023M\n"}, {OUT=>"b 1023M\na 1G\n"}],
# decimal at end => allowed
["h4", '-h', {IN=>"1.E\n2.M\n"}, {OUT=>"2.M\n1.E\n"}],
# double decimal => ignore suffix
["h5", '-h', {IN=>"1..2E\n2..2M\n"}, {OUT=>"1..2E\n2..2M\n"}],
# "M" sorts before "G" regardless of the positive number attached.
["h6", '-h', {IN=>"1GiB\n1030MiB\n"}, {OUT=>"1030MiB\n1GiB\n"}],
# check option incompatibility
["h7", '-hn', {IN=>""}, {OUT=>""}, {EXIT=>2},
 {ERR=>"$prog: options '-hn' are incompatible\n"}],
# check key processing
["h8", '-n -k2,2h', {IN=>"1 1E\n2 2M\n"}, {OUT=>"2 2M\n1 1E\n"}],
# SI and IEC prefixes on separate keys allowed
["h9", '-h -k1,1 -k2,2', {IN=>"1M 1Mi\n1M 1Mi\n"}, {OUT=>"1M 1Mi\n1M 1Mi\n"}],
# This invalid SI and IEC prefix mixture is not significant so not noticed
["h10", '-h -k1,1 -k2,2', {IN=>"1M 2M\n2M 1Mi\n"}, {OUT=>"1M 2M\n2M 1Mi\n"}],

["01a", '', {IN=>"A\nB\nC\n"}, {OUT=>"A\nB\nC\n"}],
#
["02a", '-c', {IN=>"A\nB\nC\n"}, {OUT=>''}],
["02b", '-c', {IN=>"A\nC\nB\n"}, {OUT=>''}, {EXIT=>1},
 {ERR=>"$prog: -:3: disorder: B\n"}, $normalize_filename],
["02c", '-c -k1,1', {IN=>"a\na b\n"}, {OUT=>''}],
["02d", '-C', {IN=>"A\nB\nC\n"}, {OUT=>''}],
["02e", '-C', {IN=>"A\nC\nB\n"}, {OUT=>''}, {EXIT=>1}],
# This should fail because there are duplicate keys
["02m", '-cu', {IN=>"A\nA\n"}, {OUT=>''}, {EXIT=>1},
 {ERR=>"$prog: -:2: disorder: A\n"}, $normalize_filename],
["02n", '-cu', {IN=>"A\nB\n"}, {OUT=>''}],
["02o", '-cu', {IN=>"A\nB\nB\n"}, {OUT=>''}, {EXIT=>1},
 {ERR=>"$prog: -:3: disorder: B\n"}, $normalize_filename],
["02p", '-cu', {IN=>"B\nA\nB\n"}, {OUT=>''}, {EXIT=>1},
 {ERR=>"$prog: -:2: disorder: A\n"}, $normalize_filename],
["02q", '-c -k 1,1fR', {IN=>"ABC\nABc\nAbC\nAbc\naBC\naBc\nabC\nabc\n"}],
["02r", '-c -k 1,1fV', {IN=>"ABC\nABc\nAbC\nAbc\naBC\naBc\nabC\nabc\n"}],
["02s", '-c -k 1,1dfR',
                 {IN=>".ABC\n.ABc.\nA.bC\nA.bc.\naB.C\naB.c.\nabC.\nabc..\n"}],
#
["03a", '-k1', {IN=>"B\nA\n"}, {OUT=>"A\nB\n"}],
["03b", '-k1,1', {IN=>"B\nA\n"}, {OUT=>"A\nB\n"}],
["03c", '-k1 -k2', {IN=>"A b\nA a\n"}, {OUT=>"A a\nA b\n"}],
# Fail with a diagnostic when -k specifies field == 0.
["03d", '-k0', {EXIT=>2},
 {ERR=>"$prog: -: invalid field specification '0'\n"},
  $normalize_filename],
# Fail with a diagnostic when -k specifies character == 0.
["03e", '-k1.0', {EXIT=>2},
 {ERR=>"$prog: character offset is zero: invalid field specification '1.0'\n"}],
["03f", '-k1.1,-k0', {EXIT=>2},
 {ERR=>"$prog: invalid number after ',': invalid count at start of '-k0'\n"}],
# This is ok.
["03g", '-k1.1,1.0', {IN=>''}],
# This is equivalent to 3f.
["03h", '-k1.1,1', {IN=>''}],
# This too, is equivalent to 3f.
["03i", '-k1,1', {IN=>''}],
#
["04a", '-nc', {IN=>"2\n11\n"}],
["04b", '-n', {IN=>"11\n2\n"}, {OUT=>"2\n11\n"}],
["04c", '-k1n', {IN=>"11\n2\n"}, {OUT=>"2\n11\n"}],
["04d", '-k1', {IN=>"11\n2\n"}, {OUT=>"11\n2\n"}],
["04e", '-k2', {IN=>"ignored B\nz-ig A\n"}, {OUT=>"z-ig A\nignored B\n"}],
#
["05a", '-k1,2', {IN=>"A B\nA A\n"}, {OUT=>"A A\nA B\n"}],
["05b", '-k1,2', {IN=>"A B A\nA A Z\n"}, {OUT=>"A A Z\nA B A\n"}],
["05c", '-k1 -k2', {IN=>"A B A\nA A Z\n"}, {OUT=>"A A Z\nA B A\n"}],
["05d", '-k2,2', {IN=>"A B A\nA A Z\n"}, {OUT=>"A A Z\nA B A\n"}],
["05e", '-k2,2', {IN=>"A B Z\nA A A\n"}, {OUT=>"A A A\nA B Z\n"}],
["05f", '-k2,2', {IN=>"A B A\nA A Z\n"}, {OUT=>"A A Z\nA B A\n"}],
#
["06a", '-k 1,2', {IN=>"A B\nA A\n"}, {OUT=>"A A\nA B\n"}],
["06b", '-k 1,2', {IN=>"A B A\nA A Z\n"}, {OUT=>"A A Z\nA B A\n"}],
["06c", '-k 1 -k 2', {IN=>"A B A\nA A Z\n"}, {OUT=>"A A Z\nA B A\n"}],
["06d", '-k 2,2', {IN=>"A B A\nA A Z\n"}, {OUT=>"A A Z\nA B A\n"}],
["06e", '-k 2,2', {IN=>"A B Z\nA A A\n"}, {OUT=>"A A A\nA B Z\n"}],
["06f", '-k 2,2', {IN=>"A B A\nA A Z\n"}, {OUT=>"A A Z\nA B A\n"}],
#
["07a", '-k 2,3', {IN=>"9 a b\n7 a a\n"}, {OUT=>"7 a a\n9 a b\n"}],
["07b", '-k 2,3', {IN=>"a a b\nz a a\n"}, {OUT=>"z a a\na a b\n"}],
["07c", '-k 2,3', {IN=>"y k b\nz k a\n"}, {OUT=>"z k a\ny k b\n"}],
["07d", '+1 -3', {IN=>"y k b\nz k a\n"}, {OUT=>"z k a\ny k b\n"}],
# ensure a character position of 0 includes whole field
["07e", '-k 2,3.0', {IN=>"a a b\nz a a\n"}, {OUT=>"z a a\na a b\n"}],
# ensure fields with end position before start are ignored
["07f", '-n -k1.3,1.1', {IN=>"a 2\nb 1\n"}, {OUT=>"a 2\nb 1\n"}],
["07g", '-n -k2.2,1.2', {IN=>"aa 2\nbb 1\n"}, {OUT=>"aa 2\nbb 1\n"}],
["07h", '-k1.3nb,1.3', {IN=>"  a 2\n  b 1\n"}, {OUT=>"  a 2\n  b 1\n"}],
# ensure obsolescent key limits are handled correctly
["07i", '-s +0 -1', {IN=>"a c\na b\n"}, {OUT=>"a c\na b\n"}],
["07j", '-s +0 -1.0', {IN=>"a c\na b\n"}, {OUT=>"a c\na b\n"}],
["07k", '-s +0 -1.1', {IN=>"a c\na b\n"}, {OUT=>"a c\na b\n"}],
["07l", '-s +0 -1.2', {IN=>"a c\na b\n"}, {OUT=>"a b\na c\n"}],
["07m", '-s +0 -1.1b', {IN=>"a c\na b\n"}, {OUT=>"a b\na c\n"}],
#
# report an error for '.' without following char spec
["08a", '-k 2.,3', {EXIT=>2},
 {ERR=>"$prog: invalid number after '.': invalid count at start of ',3'\n"}],
# report an error for ',' without following POS2
["08b", '-k 2,', {EXIT=>2},
 {ERR=>"$prog: invalid number after ',': invalid count at start of ''\n"}],
#
# Test new -g option.
["09a", '-g', {IN=>"1e2\n2e1\n"}, {OUT=>"2e1\n1e2\n"}],
# Make sure -n works how we expect.
["09b", '-n', {IN=>"1e2\n2e1\n"}, {OUT=>"1e2\n2e1\n"}],
["09c", '-n', {IN=>"2e1\n1e2\n"}, {OUT=>"1e2\n2e1\n"}],
["09d", '-k2g', {IN=>"a 1e2\nb 2e1\n"}, {OUT=>"b 2e1\na 1e2\n"}],
#
# Bug reported by Roger Peel <R.Peel@ee.surrey.ac.uk>
["10a", '-t : -k 2.2,2.2', {IN=>":ba\n:ab\n"}, {OUT=>":ba\n:ab\n"}],
# Equivalent to above, but using obsolescent '+pos -pos' option syntax.
["10b", '-t : +1.1 -1.2', {IN=>":ba\n:ab\n"}, {OUT=>":ba\n:ab\n"}],
#
# The same as the preceding two, but with input lines reversed.
["10c", '-t : -k 2.2,2.2', {IN=>":ab\n:ba\n"}, {OUT=>":ba\n:ab\n"}],
# Equivalent to above, but using obsolescent '+pos -pos' option syntax.
["10d", '-t : +1.1 -1.2', {IN=>":ab\n:ba\n"}, {OUT=>":ba\n:ab\n"}],
# Try without -t...
# But note that we have to count the delimiting space at the beginning
# of each field that has it.
["10a0", '-k 2.3,2.3', {IN=>"z ba\nz ab\n"}, {OUT=>"z ba\nz ab\n"}],
["10a1", '-k 1.2,1.2', {IN=>"ba\nab\n"}, {OUT=>"ba\nab\n"}],
["10a2", '-b -k 2.2,2.2', {IN=>"z ba\nz ab\n"}, {OUT=>"z ba\nz ab\n"}],
#
# An even simpler example demonstrating the bug.
["10e", '-k 1.2,1.2', {IN=>"ab\nba\n"}, {OUT=>"ba\nab\n"}],
#
# The way sort works on these inputs (10f and 10g) seems wrong to me.
# See http://git.sv.gnu.org/gitweb/?p=coreutils.git;a=commitdiff;h=3c467c0d223
# POSIX doesn't seem to say one way or the other, but that's the way all
# other sort implementations work.
["10f", '-t : -k 1.3,1.3', {IN=>":ab\n:ba\n"}, {OUT=>":ba\n:ab\n"}],
["10g", '-k 1.4,1.4', {IN=>"a ab\nb ba\n"}, {OUT=>"b ba\na ab\n"}],
#
# Exercise bug re using -b to skip trailing blanks.
["11a", '-t: -k1,1b -k2,2', {IN=>"a\t:a\na :b\n"}, {OUT=>"a\t:a\na :b\n"}],
["11b", '-t: -k1,1b -k2,2', {IN=>"a :b\na\t:a\n"}, {OUT=>"a\t:a\na :b\n"}],
["11c", '-t: -k2,2b -k3,3', {IN=>"z:a\t:a\na :b\n"}, {OUT=>"z:a\t:a\na :b\n"}],
# Before 1.22m, the first key comparison reported equality.
# With 1.22m, they compare different: "a" sorts before "a\n",
# and the second key spec isn't even used.
["11d", '-t: -k2,2b -k3,3', {IN=>"z:a :b\na\t:a\n"}, {OUT=>"a\t:a\nz:a :b\n"}],
#
# Exercise bug re comparing '-' and integers.
["12a", '-n -t: +1', {IN=>"a:1\nb:-\n"}, {OUT=>"b:-\na:1\n"}],
["12b", '-n -t: +1', {IN=>"b:-\na:1\n"}, {OUT=>"b:-\na:1\n"}],
# Try some other (e.g. 'X') invalid character.
["12c", '-n -t: +1', {IN=>"a:1\nb:X\n"}, {OUT=>"b:X\na:1\n"}],
["12d", '-n -t: +1', {IN=>"b:X\na:1\n"}, {OUT=>"b:X\na:1\n"}],
# From Karl Heuer
["13a", '+0.1n', {IN=>"axx\nb-1\n"}, {OUT=>"b-1\naxx\n"}],
["13b", '+0.1n', {IN=>"b-1\naxx\n"}, {OUT=>"b-1\naxx\n"}],
#
# From Carl Johnson <carlj@cjlinux.home.org>
["14a", '-d -u', {IN=>"mal\nmal-\nmala\n"}, {OUT=>"mal\nmala\n"}],
# Be sure to fix the (translate && ignore) case in keycompare.
["14b", '-f -d -u', {IN=>"mal\nmal-\nmala\n"}, {OUT=>"mal\nmala\n"}],
#
# Experiment with -i.
["15a", '-i -u', {IN=>"a\na\1\n"}, {OUT=>"a\n"}],
["15b", '-i -u', {IN=>"a\n\1a\n"}, {OUT=>"a\n"}],
["15c", '-i -u', {IN=>"a\1\na\n"}, {OUT=>"a\1\n"}],
["15d", '-i -u', {IN=>"\1a\na\n"}, {OUT=>"\1a\n"}],
["15e", '-i -u', {IN=>"a\n\1\1\1\1\1a\1\1\1\1\n"}, {OUT=>"a\n"}],

# This would fail (printing only the 7) for 8.6..8.18.
# Use --parallel=1 for reproducibility, and a small buffer size
# to let us trigger the problem with a smaller input.
["unique-1", '--p=1 -S32b -u', {IN=>"7\n"x11 . "1\n"}, {OUT=>"1\n7\n"}],
# Demonstrate that 8.19's key-spec-adjusting code is required.
# These are more finicky in that they are arch-dependent.
["unique-key-i686",   '-u -k2,2 --p=1 -S32b',
  {IN=>"a 7\n"x10 . "b 1\n"}, {OUT=>"b 1\na 7\n"}],
["unique-key-x86_64", '-u -k2,2 --p=1 -S32b',
  {IN=>"a 7\n"x11 . "b 1\n"}, {OUT=>"b 1\na 7\n"}],
# Before 8.19, this would trigger a free-memory read.
["unique-free-mem-read", '-u --p=1 -S32b',
  {IN=>"a\n"."b"x900 ."\n"},
 {OUT=>"a\n"."b"x900 ."\n"}],

# From Erick Branderhorst -- fixed around 1.19e
["16a", '-f',
 {IN=>"éminence\nüberhaupt\n's-Gravenhage\naëroclub\nAag\naagtappels\n"},
 {OUT=>"'s-Gravenhage\nAag\naagtappels\naëroclub\néminence\nüberhaupt\n"}],

# This provokes a one-byte memory overrun of a malloc'd block for versions
# of sort from textutils-1.19p and before.
["17", '-c', {IN=>"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx\n"}],

# POSIX says -n no longer implies -b, so here we're comparing ' 9' and '10'.
["18a", '-k1.1,1.2n', {IN=>" 901\n100\n"}, {OUT=>" 901\n100\n"}],

# Just like above, because the global '-b' has no effect on the
# key specifier when a key-specific option ('n' in this case) is used.
["18b", '-b -k1.1,1.2n', {IN=>" 901\n100\n"}, {OUT=>" 901\n100\n"}],

# Here we're comparing ' 90' and '10', because the 'b' on the key-end specifier
# makes sort ignore leading blanks when determining that key's *end*.
["18c", '-k1.1,1.2nb', {IN=>" 901\n100\n"}, {OUT=>"100\n 901\n"}],

# Here we're comparing '9' and '10', because the 'b' on the key-start specifier
# makes sort ignore leading blanks when determining that key's *start*.
["18d", '-k1.1b,1.2n', {IN=>" 901\n100\n"}, {OUT=>" 901\n100\n"}],

# This compares '90' and '10', as it ignores leading blanks for both
# key start and key end.
["18e", '-nb -k1.1,1.2', {IN=>" 901\n100\n"}, {OUT=>"100\n 901\n"}],

# When ignoring leading blanks for end position, ensure blanks from
# next field are not included in the sort.  I.e., order should not change here.
["18f", '-k1,1b', {IN=>"a  y\na z\n"}, {OUT=>"a  y\na z\n"}],

# When ignoring leading blanks for start position, ensure blanks from
# next field are not included in the sort.  I.e., order should not change here.
# This was noticed as an issue on fedora 8 (only in multibyte locales).
["18g", '-k1b,1', {IN=>"a  y\na z\n"}, {OUT=>"a  y\na z\n"},
 {ENV => "LC_ALL=$mb_locale"}],

# This looks odd, but works properly -- 2nd keyspec is never
# used because all lines are different.
["19a", '+0 +1nr', {IN=>"b 2\nb 1\nb 3\n"}, {OUT=>"b 1\nb 2\nb 3\n"}],

# The test *intended* by the author of the above, but using the
# more-intuitive POSIX-style -k options.
["19b", '-k1,1 -k2nr', {IN=>"b 2\nb 1\nb 3\n"}, {OUT=>"b 3\nb 2\nb 1\n"}],

# This test failed when sort-1.22 was compiled on a Next x86 system
# without optimization.  Without optimization gcc uses the buggy version
# of memcmp in the Next C library.  With optimization, gcc uses its
# (working) builtin version.  Test case form William Lewis.
["20a", '',
 {IN=>"_________U__free\n_________U__malloc\n_________U__abort\n"
      . "_________U__memcpy\n_________U__memset\n"
      . "_________U_dyld_stub_binding_helper\n_________U__malloc\n"
      . "_________U___iob\n_________U__abort\n_________U__fprintf\n"},
 {OUT=>"_________U___iob\n_________U__abort\n_________U__abort\n"
       . "_________U__fprintf\n_________U__free\n_________U__malloc\n"
       . "_________U__malloc\n_________U__memcpy\n_________U__memset\n"
       . "_________U_dyld_stub_binding_helper\n"}],

# Demonstrate that folding changes the ordering of e.g. A, a, and _
# because while they normally (in the C locale) collate like A, _, a,
# when using -f, 'a' is compared as if it were 'A'.
["21a", '', {IN=>"A\na\n_\n"}, {OUT=>"A\n_\na\n"}],
["21b", '-f', {IN=>"A\na\n_\n"}, {OUT=>"A\na\n_\n"}],
["21c", '-f', {IN=>"a\nA\n_\n"}, {OUT=>"A\na\n_\n"}],
["21d", '-f', {IN=>"_\na\nA\n"}, {OUT=>"A\na\n_\n"}],
["21e", '-f', {IN=>"a\n_\nA\n"}, {OUT=>"A\na\n_\n"}],
["21f", '-fs', {IN=>"A\na\n_\n"}, {OUT=>"A\na\n_\n"}],
["21g", '-fu', {IN=>"a\n_\n"}, {OUT=>"a\n_\n"}],

# This test failed until 1.22f.  From Zvi Har'El.
["22a", '-k 2,2fd -k 1,1r', {IN=>"3 b\n4 B\n"}, {OUT=>"4 B\n3 b\n"}],
["22b", '-k 2,2d  -k 1,1r', {IN=>"3 b\n4 b\n"}, {OUT=>"4 b\n3 b\n"}],

# This fails in Fedora 20, per Göran Uddeborg in: https://bugs.gnu.org/18540
["23", '-s -k1,1 -t/', {IN=>"a b/x\na-b-c/x\n"}, {OUT=>"a b/x\na-b-c/x\n"},
 {ENV => "LC_ALL=$mb_locale"}],

["no-file1", 'no-file', {EXIT=>2}, {ERR=>$no_file}],
# This test failed until 1.22f.  Sort didn't give an error.
# From Will Edgington.
["o-no-file1", qw(-o no-file no-file), {EXIT=>2}, {ERR=>$no_file}],

["create-empty", qw(-o no/such/file /dev/null), {EXIT=>2},
 {ERR=>"$prog: open failed: no/such/file: No such file or directory\n"}],

# From Paul Eggert.  This was fixed in textutils-1.22k.
["neg-nls", '-n', {IN=>"-1\n-9\n"}, {OUT=>"-9\n-1\n"}],

# From Paul Eggert.  This was fixed in textutils-1.22m.
# The bug was visible only when using the internationalized sorting code
# (i.e., not when configured with --disable-nls).
["nul-nls", '', {IN=>"\0b\n\0a\n"}, {OUT=>"\0a\n\0b\n"}],

# Paul Eggert wrote:
# A previous version of POSIX incorrectly required that the newline
# at the end of the input line contributed to the sort, which would
# mean that an empty line should sort after a line starting with a tab
# (because \t precedes \n in the ASCII collating sequence).
# GNU 'sort' was altered to do this, but was changed back once it
# was discovered to be a POSIX bug (and the POSIX bug was fixed).
# Check that 'sort' conforms to the fixed POSIX, not to the buggy one.
["use-nl", '', {IN=>"\n\t\n"}, {OUT=>"\n\t\n"}],

# Specifying two -o options should evoke a failure
["o2", qw(-o x -o y), {EXIT=>2},
 {ERR=>"foo\n"}, {ERR_SUBST => 's/^$prog: .*/foo/'}],

# Specifying incompatible options should evoke a failure.
["incompat1", '-in', {EXIT=>2},
 {ERR=>"$prog: options '-in' are incompatible\n"}],
["incompat2", '-nR', {EXIT=>2},
 {ERR=>"$prog: options '-nR' are incompatible\n"}],
["incompat3", '-dfgiMnR', {EXIT=>2},
 {ERR=>"$prog: options '-dfgMnR' are incompatible\n"}],
["incompat4", qw(-c -o /dev/null), {EXIT=>2},
 {ERR=>"$prog: options '-co' are incompatible\n"}],
["incompat5", qw(-C -o /dev/null), {EXIT=>2},
 {ERR=>"$prog: options '-Co' are incompatible\n"}],
["incompat6", '-cC', {EXIT=>2},
 {ERR=>"$prog: options '-cC' are incompatible\n"}],
["incompat7", qw(--sort=random -n), {EXIT=>2},
 {ERR=>"$prog: options '-nR' are incompatible\n"}],

# -t '\0' is accepted, as of coreutils-5.0.91
['nul-tab', "-k2,2 -t '\\0'",
 {IN=>"a\0z\01\nb\0y\02\n"}, {OUT=>"b\0y\02\na\0z\01\n"}],

# fields > SIZE_MAX are silently interpreted as SIZE_MAX
["bigfield1", "-k $limits->{UINTMAX_OFLOW}",
 {IN=>"2\n1\n"}, {OUT=>"1\n2\n"}],
["bigfield2", "-k $limits->{SIZE_OFLOW}",
 {IN=>"2\n1\n"}, {OUT=>"1\n2\n"}],

# Using an old-style key-specifying option like +1 with an invalid
# ordering-option character would cause sort to try to free an invalid
# (non-malloc'd) pointer.  This bug affects coreutils-6.5 through 6.9.
['obs-inval', '+1x', {EXIT=>2},
 {ERR=>"foo\n"}, {ERR_SUBST => 's/^$prog: .*/foo/'}],

# Exercise the code that enlarges the line buffer.
['realloc-buf', '-S1', {IN=>'a'x4000 ."\n"}, {OUT=>'a'x4000 ."\n"}],
['realloc-buf-2', '-S1', {IN=>'a'x5 ."\n"}, {OUT=>'a'x5 ."\n"}],

["sort-numeric", '--sort=numeric', {IN=>".01\n0\n"}, {OUT=>"0\n.01\n"}],
["sort-gennum", '--sort=general-numeric',
  {IN=>"1e2\n2e1\n"}, {OUT=>"2e1\n1e2\n"}],

# -m with output file also used as an input file
# In coreutils-7.2, this caused a segfault.
# This test looks a little strange.  Here's why:
# since we're using "-o f", standard output will be empty, hence OUT=>''
# We still want to ensure that the output file, "f" has expected contents,
# hence the added CMP=> directive.
["output-is-input", '-m -o f', {IN=> {f=> "a\n"}}, {OUT=>''},
 {CMP=> ["a\n", {'f'=> undef}]} ],
["output-is-input-2", '-m -o f', {OUT=>''},
 {IN=> {f=> "a\n"}}, {IN=> {g=> "b\n"}}, {IN=> {h=> "c\n"}},
 {CMP=> ["a\nb\nc\n", {'f'=> undef}]} ],
["output-is-input-3", '-m -o f', {OUT=>''},
 {IN=> {g=> "a\n"}}, {IN=> {h=> "b\n"}}, {IN=> {f=> "c\n"}},
 {CMP=> ["a\nb\nc\n", {'f'=> undef}]} ],

# --zero-terminated
['zero-1', '-z', {IN=>"2\0001\000"}, {OUT=>"1\0002\000"}],
['zero-2', '-z -k2,2', {IN=>"1\n2\0002\n1\000"}, {OUT=>"2\n1\0001\n2\000"}],
['zero-3', '-zb -k2,2', {IN=>"1\n\n2\0002\n1\0"}, {OUT=>"2\n1\0001\n\n2\0"}],
);

# Add _POSIX2_VERSION=199209 to the environment of each test
# that uses an old-style option like +1.
foreach my $t (@Tests)
  {
    foreach my $e (@$t)
      {
        !ref $e && $e =~ /\+\d/
          and push (@$t, {ENV=>'_POSIX2_VERSION=199209'}), last;
      }
  }

@Tests = triple_test \@Tests;

# Remember that triple_test creates from each test with exactly one "IN"
# file two more tests (.p and .r suffix on name) corresponding to reading
# input from a file and from a pipe.  The pipe-reading test would fail
# due to a race condition about 1 in 20 times.
# Remove the IN_PIPE version of the "output-is-input" test above.
# The others aren't susceptible because they have three inputs each.
@Tests = grep {$_->[0] ne 'output-is-input.p'} @Tests;

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
