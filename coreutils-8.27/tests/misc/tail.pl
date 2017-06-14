#!/usr/bin/perl
# Test tail.

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

my $prog = 'tail';
my $normalize_strerror = "s/': .*/'/";

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my @tv = (
# test name, options, input, expected output, expected return code
#
['obs-plus-c1', '+2c', 'abcd', 'bcd', 0],
['obs-plus-c2', '+8c', 'abcd', '', 0],
['obs-c3', '-1c', 'abcd', 'd', 0],
['obs-c4', '-9c', 'abcd', 'abcd', 0],
['obs-c5', '-12c', 'x' . ('y' x 12) . 'z', ('y' x 11) . 'z', 0],

['obs-l1', '-1l', 'x', 'x', 0],
['obs-l2', '-1l', "x\ny\n", "y\n", 0],
['obs-l3', '-1l', "x\ny", "y", 0],
['obs-plus-l4', '+1l', "x\ny\n", "x\ny\n", 0],
['obs-plus-l5', '+2l', "x\ny\n", "y\n", 0],

# Same as -l tests, but without the 'l'.
['obs-1', '-1', 'x', 'x', 0],
['obs-2', '-1', "x\ny\n", "y\n", 0],
['obs-3', '-1', "x\ny", "y", 0],
['obs-plus-4', '+1', "x\ny\n", "x\ny\n", 0],
['obs-plus-5', '+2', "x\ny\n", "y\n", 0],

# This is equivalent to +10c
['obs-plus-x1', '+c', 'x' . ('y' x 10) . 'z', 'yyz', 0],
# This is equivalent to +10l
['obs-plus-x2', '+l', "x\n" . ("y\n" x 10) . 'z', "y\ny\nz", 0],
# With no number, this is like -10l
['obs-l', '-l', "x\n" . ("y\n" x 10) . 'z', ("y\n" x 9) . 'z', 0],

['obs-b', '-b', "x\n" x (512 * 10 / 2 + 1), "x\n" x (512 * 10 / 2), 0],

['err-1', '+cl', '', '', 1,
 "$prog: cannot open '+cl' for reading: No such file or directory\n"],

['err-2', '-cl', '', '', 1,
 "$prog: invalid number of bytes: 'l'\n", $normalize_strerror],

['err-3', '+2cz', '', '', 1,
 "$prog: cannot open '+2cz' for reading: No such file or directory\n"],

# This should get 'tail: invalid option -- 2'
['err-4', '-2cX', '', '', 1,
 "$prog: option used in invalid context -- 2\n"],

# Since the number is larger than 2^64, this should provoke
# the diagnostic: 'tail: 99999999999999999999: invalid number of bytes'
# on all systems... probably, for now, maybe.
['err-5', '-c99999999999999999999', '', '', 1,
 "$prog: invalid number of bytes: '99999999999999999999'\n",
 $normalize_strerror],
['err-6', '-c --', '', '', 1,
 "$prog: invalid number of bytes: '-'\n", $normalize_strerror],

# Same as -n 10
['minus-1', '-', '', '', 0],
['minus-2', '-', "x\n" . ("y\n" x 10) . 'z', ("y\n" x 9) . 'z', 0],

['c-2', '-c 2', "abcd\n", "d\n", 0],
['c-2-minus', '-c 2 --', "abcd\n", "d\n", 0],
['c2', '-c2', "abcd\n", "d\n", 0],
['c2-minus', '-c2 --', "abcd\n", "d\n", 0],

['n-1', '-n 10', "x\n" . ("y\n" x 10) . 'z', ("y\n" x 9) . 'z', 0],
['n-2', '-n -10', "x\n" . ("y\n" x 10) . 'z', ("y\n" x 9) . 'z', 0],
['n-3', '-n +10', "x\n" . ("y\n" x 10) . 'z', "y\ny\nz", 0],

# Accept +0 as synonym for +1.
['n-4',  '-n +0', "y\n" x 5, "y\n" x 5, 0],
['n-4a', '-n +1', "y\n" x 5, "y\n" x 5, 0],

# Note that -0 is *not* a synonym for -1.
['n-5',  '-n -0', "y\n" x 5, '', 0],
['n-5a', '-n -1', "y\n" x 5, "y\n", 0],
['n-5b', '-n  0', "y\n" x 5, '', 0],

# With textutils-1.22, this failed.
['f-pipe-1', '-f -n 1', "a\nb\n", "b\n", 0],

# --zero-terminated
['zero-1', '-z -n 1', "x\0y", "y", 0],
['zero-2', '-z -n 2', "x\0y", "x\0y", 0],
);

my @Tests;

foreach my $t (@tv)
  {
    my ($test_name, $flags, $in, $exp, $ret, $err_msg, $err_sub) = @$t;
    my $e = [$test_name, $flags, {IN=>$in}, {OUT=>$exp}];
    $ret
      and push @$e, {EXIT=>$ret}, {ERR=>$err_msg}, {ERR_SUBST=>$err_sub};

    $test_name =~ /^minus-/
      and push @$e, {ENV=>'_POSIX2_VERSION=199209'};

    $test_name =~ /^(err-6|c-2)$/
      and push @$e, {ENV=>'_POSIX2_VERSION=200112'};

    $test_name =~ /^obs-plus-/
      and push @$e, {ENV=>'_POSIX2_VERSION=200809'};

    $test_name =~ /^f-pipe-/
      and push @$e, {ENV=>'POSIXLY_CORRECT=1'};

    push @Tests, $e;
  }

@Tests = triple_test \@Tests;

# If you run the minus* tests with a FILE arg they'd hang.
# If you run the err-1 or err-3 tests with a FILE, they'd misinterpret
# the arg unless we are using the obsolete form.
@Tests = grep { $_->[0] !~ /^(minus|err-[13])/ || $_->[0] =~ /\.[rp]$/ } @Tests;

# Using redirection or a file would make this hang.
@Tests = grep { $_->[0] !~ /^f-/ || $_->[0] =~ /\.p$/ } @Tests;

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
