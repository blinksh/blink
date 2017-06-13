#!/usr/bin/perl
# Test join.

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

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $prog = 'join';

my $delim = chr 0247;
sub t_subst ($)
{
  (my $s = $_[0]) =~ s/:/$delim/g;
  return $s;
}

my @tv = (
# test name
#     flags       file-1 file-2    expected output   expected return code
#
['1a', '-a1',      ["a 1\n", "b\n"],   "a 1\n",          0],
['1b', '-a2',      ["a 1\n", "b\n"],   "b\n",            0], # Got "\n"
['1c', '-a1 -a2',  ["a 1\n", "b\n"],   "a 1\nb\n",       0], # Got "a 1\n\n"
['1d', '-a1',      ["a 1\nb\n", "b\n"],   "a 1\nb\n",    0],
['1e', '-a2',      ["a 1\nb\n", "b\n"],   "b\n",         0],
['1f', '-a2',      ["b\n", "a\nb\n"], "a\nb\n",          0],

['2a', '-a1 -e .',  ["a\nb\nc\n", "a x y\nb\nc\n"], "a x y\nb\nc\n", 0],
['2b', '-a1 -e . -o 2.1,2.2,2.3',  ["a\nb\nc\n", "a x y\nb\nc\n"],
 "a x y\nb . .\nc . .\n", 0],
['2c', '-a1 -e . -o 2.1,2.2,2.3',  ["a\nb\nc\nd\n", "a x y\nb\nc\n"],
 "a x y\nb . .\nc . .\n. . .\n", 0],

['3a', '-t:', ["a:1\nb:1\n", "a:2:\nb:2:\n"], "a:1:2:\nb:1:2:\n", 0],

# operate on whole line (as sort does by default)
['3b', '-t ""', ["a 1\nb 1\n", "a 1\nb 2\n"], "a 1\n", 0],
# use NUL as the field delimiter
['3c', '-t "\\0"', ["a\0a\n", "a\0b\n"], "a\0a\0b\n", 0],

# Just like -a1 and -a2 when there are no pairable lines
['4a', '-v 1', ["a 1\n", "b\n"],   "a 1\n",          0],
['4b', '-v 2', ["a 1\n", "b\n"],   "b\n",            0],

['4c', '-v 1', ["a 1\nb\n", "b\n"],        "a 1\n",       0],
['4d', '-v 2', ["a 1\nb\n", "b\n"],        "",            0],
['4e', '-v 2', ["b\n",      "a 1\nb\n"],   "a 1\n",       0],
['5a', '-a1 -e - -o 1.1,2.2',
 ["a 1\nb 2\n",  "a 11\nb\n"], "a 11\nb -\n", 0],
['5b', '-a1 -e - -o 1.1,2.2',
 ["apr 15\naug 20\ndec 18\nfeb 05\n", "apr 06\naug 14\ndate\nfeb 15"],
 "apr 06\naug 14\ndec -\nfeb 15\n", 0],
['5c', '-a1 -e - -o 1.1,2.2',
 ["aug 20\ndec 18\n", "aug 14\ndate\nfeb 15"],
 "aug 14\ndec -\n", 0],
['5d', '-a1 -e - -o 1.1,2.2',
 ["dec 18\n",  ""], "dec -\n", 0],
['5e', '-a2 -e - -o 1.1,2.2',
 ["apr 15\naug 20\ndec 18\nfeb 05\n", "apr 06\naug 14\ndate\nfeb 15\n"],
 "apr 06\naug 14\n- -\nfeb 15\n", 0],
['5f', '-a2 -e - -o 2.2,1.1',
 ["apr 15\naug 20\ndec 18\nfeb 05\n", "apr 06\naug 14\ndate\nfeb 15\n"],
 "06 apr\n14 aug\n- -\n15 feb\n", 0],
['5g', '-a1 -e - -o 2.2,1.1',
 ["apr 15\naug 20\ndec 18\nfeb 05\n", "apr 06\naug 14\ndate\nfeb 15\n"],
 "06 apr\n14 aug\n- dec\n15 feb\n", 0],

['5h', '-a1 -e - -o 2.2,1.1',
 ["apr 15\naug 20\ndec 18\nfeb 05\n", "apr 06\naug 14\ndate\n"],
 "06 apr\n14 aug\n- dec\n- feb\n", 0],
['5i', '-a1 -e - -o 1.1,2.2',
 ["apr 15\naug 20\ndec 18\nfeb 05\n", "apr 06\naug 14\ndate\n"],
 "apr 06\naug 14\ndec -\nfeb -\n", 0],

['5j', '-a2 -e - -o 2.2,1.1',
 ["apr 15\naug 20\ndec 18\nfeb 05\n", "apr 06\naug 14\ndate\n"],
 "06 apr\n14 aug\n- -\n", 0],
['5k', '-a2 -e - -o 2.2,1.1',
 ["apr 15\naug 20\ndec 18\nfeb 05\n", "apr 06\naug 14\ndate\n"],
  "06 apr\n14 aug\n- -\n", 0],

['5l', '-a1 -e - -o 2.2,1.1',
 ["apr 15\naug 20\ndec 18\n", "apr 06\naug 14\ndate\nfeb 15\n"],
  "06 apr\n14 aug\n- dec\n", 0],
['5m', '-a2 -e - -o 2.2,1.1',
 ["apr 15\naug 20\ndec 18\n", "apr 06\naug 14\ndate\nfeb 15\n"],
  "06 apr\n14 aug\n- -\n15 -\n", 0],

['6a', '-e -',
 ["a 1\nb 2\nd 4\n", "a 21\nb 22\nc 23\nf 26\n"],
 "a 1 21\nb 2 22\n", 0],
['6b', '-a1 -e -',
 ["a 1\nb 2\nd 4\n", "a 21\nb 22\nc 23\nf 26\n"],
 "a 1 21\nb 2 22\nd 4\n", 0],
['6c', '-a1 -e -',
 ["a 21\nb 22\nc 23\nf 26\n", "a 1\nb 2\nd 4\n"],
 "a 21 1\nb 22 2\nc 23\nf 26\n", 0],

['7a', '-a1 -e . -o 2.7',
 ["a\nb\nc\n", "a x y\nb\nc\n"], ".\n.\n.\n", 0],

['8a', '-a1 -e . -o 0,1.2',
 ["a\nb\nc\nd G\n", "a x y\nb\nc\ne\n"],
 "a .\nb .\nc .\nd G\n", 0],
['8b', '-a1 -a2 -e . -o 0,1.2',
 ["a\nb\nc\nd G\n", "a x y\nb\nc\ne\n"],
 "a .\nb .\nc .\nd G\ne .\n", 0],

# From David Dyck
['9a', '', [" a 1\n b 2\n", " a Y\n b Z\n"], "a 1 Y\nb 2 Z\n", 0],

# -o 'auto'
['10a', '-a1 -a2 -e . -o auto',
 ["a 1 2\nb 1\nd 1 2\n", "a 3 4\nb 3 4\nc 3 4\n"],
 "a 1 2 3 4\nb 1 . 3 4\nc . . 3 4\nd 1 2 . .\n", 0],
['10b', '-a1 -a2 -j3 -e . -o auto',
 ["a 1 2\nb 1\nd 1 2\n", "a 3 4\nb 3 4\nc 3 4\n"],
 "2 a 1 . .\n. b 1 . .\n2 d 1 . .\n4 . . a 3\n4 . . b 3\n4 . . c 3\n"],
['10c', '-a1 -1 1 -2 4 -e. -o auto',
 ["a 1 2\nb 1\nd 1 2\n", "a 3 4\nb 3 4\nc 3 4\n"],
 "a 1 2 . . .\nb 1 . . . .\nd 1 2 . . .\n"],
['10d', '-a2 -1 1 -2 4 -e. -o auto',
 ["a 1 2\nb 1\nd 1 2\n", "a 3 4\nb 3 4\nc 3 4\n"],
 ". . . a 3 4\n. . . b 3 4\n. . . c 3 4\n"],
['10e', '-o auto',
 ["a 1 2\nb 1 2 discard\n", "a 3 4\nb 3 4 discard\n"],
 "a 1 2 3 4\nb 1 2 3 4\n"],
['10f', '-t, -o auto',
 ["a,1,,2\nb,1,2\n", "a,3,4\nb,3,4\n"],
 "a,1,,2,3,4\nb,1,2,,3,4\n"],

# For -v2, print the match field correctly with the default output format,
# when that match field is different between file 1 and file 2.  Fixed in 8.10
['v2-order', '-v2 -2 2', ["", "2 1\n"], "1 2\n", 0],

# From Tim Smithers: fixed in 1.22l
['trailing-sp', '-t: -1 1 -2 1', ["a:x \n", "a:y \n"], "a:x :y \n", 0],

# From Paul Eggert: fixed in 1.22n
['sp-vs-blank', '', ["\f 1\n", "\f 2\n"], "\f 1 2\n", 0],

# From Paul Eggert: fixed in 1.22n (this would fail on Solaris7,
# with LC_ALL set to en_US).
# Unfortunately, that Solaris7's en_US locale folds case (making
# the first input file sorted) is not portable, so this test would
# fail on e.g. Linux systems, because the input to join isn't sorted.
# ['lc-collate', '', ["a 1a\nB 1B\n", "B 2B\n"], "B 1B 2B\n", 0],

# Based on a report from Antonio Rendas.  Fixed in 2.0.9.
['8-bit-t', t_subst "-t:",
 [t_subst "a:1\nb:1\n", t_subst "a:2:\nb:2:\n"],
 t_subst "a:1:2:\nb:1:2:\n", 0],

# fields > SIZE_MAX are silently interpreted as SIZE_MAX
['bigfield1', "-1 $limits->{UINTMAX_OFLOW} -2 2",
 ["a\n", "b\n"], " a b\n", 0],
['bigfield2', "-1 $limits->{SIZE_OFLOW} -2 2",
 ["a\n", "b\n"], " a b\n", 0],

# FIXME: change this to ensure the diagnostic makes sense
['invalid-j', '-j x', {}, "", 1,
 "$prog: invalid field number: 'x'\n"],

# With ordering check, inputs in order
['chkodr-1', '--check-order',
  [" a 1\n b 2\n", " a Y\n b Z\n"], "a 1 Y\nb 2 Z\n", 0],

# Without check, inputs in order
['chkodr-2', '--nocheck-order',
 [" a 1\n b 2\n", " a Y\n b Z\n"], "a 1 Y\nb 2 Z\n", 0],

# Without check, both inputs out of order (in fact, in reverse order)
# but all pairable.  Support for this is a GNU extension.
['chkodr-3', '--nocheck-order',
 [" b 1\n a 2\n", " b Y\n a Z\n"], "b 1 Y\na 2 Z\n", 0],

# The extension should work without --nocheck-order, since that is the
# default.
['chkodr-4', '',
 [" b 1\n a 2\n", " b Y\n a Z\n"], "b 1 Y\na 2 Z\n", 0],

# With check, both inputs out of order (in fact, in reverse order)
['chkodr-5', '--check-order',
 [" b 1\n a 2\n", " b Y\n a Z\n"], "", 1,
 "$prog: chkodr-5.1:2: is not sorted:  a 2\n"],

# Similar, but with only file 2 not sorted.
['chkodr-5b', '--check-order',
 [" a 2\n b 1\n", " b Y\n a Z\n"], "", 1,
 "$prog: chkodr-5b.2:2: is not sorted:  a Z\n"],

# Similar, but with the offending line having length 0 (excluding newline).
['chkodr-5c', '--check-order',
 [" a 2\n b 1\n", " b Y\n\n"], "", 1,
 "$prog: chkodr-5c.2:2: is not sorted: \n"],

# Similar, but elicit a warning for each input file (without --check-order).
['chkodr-5d', '',
 ["a\nx\n\n", "b\ny\n\n"], "", 1,
 "$prog: chkodr-5d.1:3: is not sorted: \n" .
 "$prog: chkodr-5d.2:3: is not sorted: \n"],

# Similar, but make it so each offending line has no newline.
['chkodr-5e', '',
 ["a\nx\no", "b\ny\np"], "", 1,
 "$prog: chkodr-5e.1:3: is not sorted: o\n" .
 "$prog: chkodr-5e.2:3: is not sorted: p\n"],

# Without order check, both inputs out of order and some lines
# unpairable.  This is NOT supported by the GNU extension.  All that
# we really care about for this test is that the return status is
# zero, since that is the only way to actually verify that the
# --nocheck-order option had any effect.   We don't actually want to
# guarantee that join produces this output on stdout.
['chkodr-6', '--nocheck-order',
 [" b 1\n a 2\n", " b Y\n c Z\n"], "b 1 Y\n", 0],

# Before 6.10.143, this would mistakenly fail with the diagnostic:
# join: File 1 is not in sorted order
['chkodr-7', '-12', ["2 a\n1 b\n", "2 c\n1 d"], "", 0],

# After 8.9, join doesn't report disorder by default
# when comparing against an empty input file.
['chkodr-8', '', ["2 a\n1 b\n", ""], "", 0],

# Test '--header' feature
['header-1', '--header',
 [ "ID Name\n1 A\n2 B\n", "ID Color\n1 red\n"], "ID Name Color\n1 A red\n", 0],

# '--header' with '--check-order' : The header line is out-of-order but the
# actual data is in order. This join should succeed.
['header-2', '--header --check-order',
 ["ID Name\n1 A\n2 B\n", "ID Color\n2 green\n"],
 "ID Name Color\n2 B green\n", 0],

# '--header' with '--check-order' : The header line is out-of-order AND the
# actual data out-of-order. This join should fail.
['header-3', '--header --check-order',
 ["ID Name\n2 B\n1 A\n", "ID Color\n2 blue\n"], "ID Name Color\n", 1,
 "$prog: header-3.1:3: is not sorted: 1 A\n"],

# '--header' with specific output format '-o'.
# output header line should respect the requested format
['header-4', '--header -o "0,1.3,2.2"',
 ["ID Group Name\n1 Foo A\n2 Bar B\n", "ID Color\n2 blue\n"],
 "ID Name Color\n2 B blue\n", 0],

# '--header' always outputs headers from the first file
# even if the headers from the second file don't match
['header-5', '--header',
 [ "ID1 Name\n1 A\n2 B\n", "ID2 Color\n1 red\n"],
   "ID1 Name Color\n1 A red\n", 0],

# '--header' doesn't check order of a header
# even if there is no header in the second file
['header-6', '--header -a1',
 [ "ID1 Name\n1 A\n", ""],
   "ID1 Name\n1 A\n", 0],

# Zero-terminated lines
['z1', '-z',
 ["a\0c\0e\0", "a\0b\0c\0"], "a\0c\0", 0],

# not zero-terminated, but related to the code change:
#  the old readlinebuffer() auto-added '\n' to the last line.
#  the new readlinebuffer_delim() does not.
#  Ensure it doesn't matter.
['z2', '',
 ["a\nc\ne\n", "a\nb\nc"], "a\nc\n", 0],
['z3', '',
 ["a\nc\ne", "a\nb\nc"], "a\nc\n", 0],
# missing last NUL at the end of the last line (=end of file)
['z4', '-z',
 ["a\0c\0e", "a\0b\0c"], "a\0c\0", 0],
# With -z, embedded newlines are treated as field separators.
# Note '\n' are converted to ' ' in this case.
['z5', '-z -a1 -a2',
 ["a\n\n1\0c 3\0", "a 2\0b\n8\0c 9\0"], "a 1 2\0b 8\0c 3 9\0"],
# One can avoid field processing like:
['z6', '-z -t ""',
 ["a\n1\n\0", "a\n1\n\0"], "a\n1\n\0"],

);

# Convert the above old-style test vectors to the newer
# format used by Coreutils.pm.

my @Tests;
foreach my $t (@tv)
  {
    my ($test_name, $flags, $in, $exp, $ret, $err_msg) = @$t;
    my $new_ent = [$test_name, $flags];
    if (!ref $in)
      {
        push @$new_ent, {IN=>$in};
      }
    elsif (ref $in eq 'HASH')
      {
        # ignore
      }
    else
      {
        foreach my $e (@$in)
          {
            push @$new_ent, {IN=>$e};
          }
      }
    push @$new_ent, {OUT=>$exp};
    $ret
      and push @$new_ent, {EXIT=>$ret}, {ERR=>$err_msg};
    push @Tests, $new_ent;
  }

@Tests = triple_test \@Tests;

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
