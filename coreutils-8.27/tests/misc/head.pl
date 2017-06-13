#!/usr/bin/perl
# test head

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

my $prog = 'head';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $in = join ('', map { "$_\n" } 0..600);
my $in_1024 = substr $in, 0, 1024;

# FIXME: set this properly
my $x32_bit_long = 0;

my @Tests =
(
  ['idem-0', {IN=>''}, {OUT=>''}],
  ['idem-1', {IN=>'a'}, {OUT=>'a'}],
  ['idem-2', {IN=>"\n"}, {OUT=>"\n"}],
  ['idem-3', {IN=>"a\n"}, {OUT=>"a\n"}],

  ['basic-10',
   {IN=>"1\n2\n3\n4\n5\n6\n7\n8\n9\n0\n"},
   {OUT=>"1\n2\n3\n4\n5\n6\n7\n8\n9\n0\n"}],

  ['basic-09',
   {IN=>"1\n2\n3\n4\n5\n6\n7\n8\n9\n"},
   {OUT=>"1\n2\n3\n4\n5\n6\n7\n8\n9\n"}],

  ['basic-11',
   {IN=>"1\n2\n3\n4\n5\n6\n7\n8\n9\n0\nb\n"},
   {OUT=>"1\n2\n3\n4\n5\n6\n7\n8\n9\n0\n"}],

  ['obs-0', '-1', {IN=>"1\n2\n"}, {OUT=>"1\n"}],
  ['obs-1', '-1c', {IN=>''}, {OUT=>''}],
  ['obs-2', '-1c', {IN=>'12'}, {OUT=>'1'}],
  ['obs-3', '-14c', {IN=>'1234567890abcdefg'}, {OUT=>'1234567890abcd'}],
  ['obs-4', '-2b', {IN=>$in}, {OUT=>$in_1024}],
  ['obs-5', '-1k', {IN=>$in}, {OUT=>$in_1024}],

  # This test fails for textutils-1.22, because head let 4096m overflow to 0
  # and did not fail.  Now head fails with a diagnostic.
  # Disable this test because it fails on systems with 64-bit uintmax_t.
  # ['fail-0', qw(-n 4096m), {IN=>"a\n"}, {EXIT=>1}],

  # In spite of its name, this test passes -- just to contrast with the above.
  ['fail-1', qw(-n 2048m), {IN=>"a\n"}, {OUT=>"a\n"}],

  # Make sure we don't break like AIX 4.3.1 on files with \0 in them.
  ['null-1', {IN=>"a\0a\n"}, {OUT=>"a\0a\n"}],

  # Make sure counts are interpreted as decimal.
  # Before 2.0f, these would have been interpreted as octal
  ['no-oct-1', '-08',  {IN=>"\n"x12}, {OUT=>"\n"x8}],
  ['no-oct-2', '-010', {IN=>"\n"x12}, {OUT=>"\n"x10}],
  ['no-oct-3', '-n 08', {IN=>"\n"x12}, {OUT=>"\n"x8}],
  ['no-oct-4', '-c 08', {IN=>"\n"x12}, {OUT=>"\n"x8}],

  # --zero-terminated
  ['zero-1', '-z -n 1',  {IN=>"x\0y"}, {OUT=>"x\0"}],
  ['zero-2', '-z -n 2',  {IN=>"x\0y"}, {OUT=>"x\0y"}],
);

@Tests = triple_test \@Tests;

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
