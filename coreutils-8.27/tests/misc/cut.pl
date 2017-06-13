#!/usr/bin/perl
# Test "cut".

# Copyright (C) 2006-2017 Free Software Foundation, Inc.

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

(my $ME = $0) =~ s|.*/||;

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $mb_locale = $ENV{LOCALE_FR_UTF8};
! defined $mb_locale || $mb_locale eq 'none'
  and $mb_locale = 'C';

my $prog = 'cut';
my $try = "Try '$prog --help' for more information.\n";
my $from_field1 = "$prog: fields are numbered from 1\n$try";
my $from_pos1 =   "$prog: byte/character positions are numbered from 1\n$try";
my $inval_fld = "$prog: invalid field range\n$try";
my $inval_pos = "$prog: invalid byte or character range\n$try";
my $no_endpoint = "$prog: invalid range with no endpoint: -\n$try";
my $nofield = "$prog: an input delimiter may be specified only when " .
              "operating on fields\n$try";

my @Tests =
 (
  # Provoke a double-free in cut from coreutils-6.7.
  ['dbl-free', '-f2-', {IN=>{f=>'x'}}, {IN=>{g=>'y'}}, {OUT=>"x\ny\n"}],

  # This failed (as it should) even before coreutils-6.9.90,
  # but cut from 6.9.90 produces a more useful diagnostic.
  ['zero-1', '-b0',   {ERR=>$from_pos1}, {EXIT => 1} ],

  # Up to coreutils-6.9, specifying a range of 0-2 was not an error.
  # It was treated just like "-2".
  ['zero-2', '-f0-2', {ERR=>$from_field1}, {EXIT => 1} ],

  # Up to coreutils-8.20, specifying a range of 0- was not an error.
  ['zero-3b', '-b0-', {ERR=>$from_pos1}, {EXIT => 1} ],
  ['zero-3c', '-c0-', {ERR=>$from_pos1}, {EXIT => 1} ],
  ['zero-3f', '-f0-', {ERR=>$from_field1}, {EXIT => 1} ],

  ['1', '-d:', '-f1,3-', {IN=>"a:b:c\n"}, {OUT=>"a:c\n"}],
  ['2', '-d:', '-f1,3-', {IN=>"a:b:c\n"}, {OUT=>"a:c\n"}],
  ['3', qw(-d: -f2-), {IN=>"a:b:c\n"}, {OUT=>"b:c\n"}],
  ['4', qw(-d: -f4), {IN=>"a:b:c\n"}, {OUT=>"\n"}],
  ['5', qw(-d: -f4), {IN=>""}, {OUT=>""}],
  ['6', '-c4', {IN=>"123\n"}, {OUT=>"\n"}],
  ['7', '-c4', {IN=>"123"}, {OUT=>"\n"}],
  ['8', '-c4', {IN=>"123\n1"}, {OUT=>"\n\n"}],
  ['9', '-c4', {IN=>""}, {OUT=>""}],
  ['a', qw(-s -d:), '-f3-', {IN=>"a:b:c\n"}, {OUT=>"c\n"}],
  ['b', qw(-s -d:), '-f2,3', {IN=>"a:b:c\n"}, {OUT=>"b:c\n"}],
  ['c', qw(-s -d:), '-f1,3', {IN=>"a:b:c\n"}, {OUT=>"a:c\n"}],
  # Trailing colon should not be output
  ['d', qw(-s -d:), '-f1,3', {IN=>"a:b:c:\n"}, {OUT=>"a:c\n"}],
  ['e', qw(-s -d:), '-f3-', {IN=>"a:b:c:\n"}, {OUT=>"c:\n"}],
  ['f', qw(-s -d:), '-f3-4', {IN=>"a:b:c:\n"}, {OUT=>"c:\n"}],
  ['g', qw(-s -d:), '-f3,4', {IN=>"a:b:c:\n"}, {OUT=>"c:\n"}],
  # Make sure -s suppresses non-delimited lines
  ['h', qw(-s -d:), '-f2,3', {IN=>"abc\n"}, {OUT=>""}],
  #
  ['i', qw(-d: -f1-3), {IN=>":::\n"}, {OUT=>"::\n"}],
  ['j', qw(-d: -f1-4), {IN=>":::\n"}, {OUT=>":::\n"}],
  ['k', qw(-d: -f2-3), {IN=>":::\n"}, {OUT=>":\n"}],
  ['l', qw(-d: -f2-4), {IN=>":::\n"}, {OUT=>"::\n"}],
  ['m', qw(-s -d: -f1-3), {IN=>":::\n"}, {OUT=>"::\n"}],
  ['n', qw(-s -d: -f1-4), {IN=>":::\n"}, {OUT=>":::\n"}],
  ['o', qw(-s -d: -f2-3), {IN=>":::\n"}, {OUT=>":\n"}],
  ['p', qw(-s -d: -f2-4), {IN=>":::\n"}, {OUT=>"::\n"}],
  ['q', qw(-s -d: -f2-4), {IN=>":::\n:\n"}, {OUT=>"::\n\n"}],
  ['r', qw(-s -d: -f2-4), {IN=>":::\n:1\n"}, {OUT=>"::\n1\n"}],
  ['s', qw(-s -d: -f1-4), {IN=>":::\n:a\n"}, {OUT=>":::\n:a\n"}],
  ['t', qw(-s -d: -f3-), {IN=>":::\n:1\n"}, {OUT=>":\n\n"}],
  # Make sure it handles empty input properly, with and without -s.
  ['u', qw(-s -f3-), {IN=>""}, {OUT=>""}],
  ['v', '-f3-', {IN=>""}, {OUT=>""}],
  # Make sure it handles empty input properly.
  ['w', qw(-b 1), {IN=>""}, {OUT=>""}],
  ['x', qw(-s -d: -f2-4), {IN=>":\n"}, {OUT=>"\n"}],
  # Errors
  # -s may be used only with -f
  ['y', qw(-s -b4), {IN=>":\n"}, {OUT=>""}, {EXIT=>1},
   {ERR=>"$prog: suppressing non-delimited lines makes sense\n"
    . "\tonly when operating on fields\n$try"}],
  # You must specify bytes or fields (or chars)
  ['z', '', {IN=>":\n"}, {OUT=>""}, {EXIT=>1},
   {ERR=>"$prog: you must specify a list of bytes, characters, or fields\n$try"}
  ],
  # Empty field list
  ['empty-fl', qw(-f ''), {IN=>":\n"}, {OUT=>""}, {EXIT=>1},
   {ERR=>$from_field1}],
  # Missing field list
  ['missing-fl', qw(-f --), {IN=>":\n"}, {OUT=>""}, {EXIT=>1},
   {ERR=>$inval_fld}],
  # Empty byte list
  ['empty-bl', qw(-b ''), {IN=>":\n"}, {OUT=>""}, {EXIT=>1}, {ERR=>$from_pos1}],
  # Missing byte list
  ['missing-bl', qw(-b --), {IN=>":\n"}, {OUT=>""}, {EXIT=>1},
   {ERR=>$inval_pos}],

  # This test fails with cut from textutils-1.22.
  ['empty-f1', '-f1', {IN=>""}, {OUT=>""}],

  ['empty-f2', '-f2', {IN=>""}, {OUT=>""}],

  ['o-delim', qw(-d: --out=_), '-f2,3', {IN=>"a:b:c\n"}, {OUT=>"b_c\n"}],
  ['nul-idelim', qw(-d '' --out=_), '-f2,3', {IN=>"a\0b\0c\n"}, {OUT=>"b_c\n"}],
  ['nul-odelim', qw(-d: --out=), '-f2,3', {IN=>"a:b:c\n"}, {OUT=>"b\0c\n"}],
  ['multichar-od', qw(-d: --out=_._), '-f2,3', {IN=>"a:b:c\n"},
   {OUT=>"b_._c\n"}],

  # Ensure delim is not allowed without a field
  # Prior to 8.21, a NUL delim was allowed without a field
  ['delim-no-field1', qw(-d ''), '-b1', {EXIT=>1}, {ERR=>$nofield}],
  ['delim-no-field2', qw(-d:), '-b1', {EXIT=>1}, {ERR=>$nofield}],

  # Prior to 1.22i, you couldn't use a delimiter that would sign-extend.
  ['8bit-delim', '-d', "\255", '--out=_', '-f2,3', {IN=>"a\255b\255c\n"},
   {OUT=>"b_c\n"}],

  # newline processing for fields
  ['newline-1', '-f1-', {IN=>"a\nb"}, {OUT=>"a\nb\n"}],
  ['newline-2', '-f1-', {IN=>""}, {OUT=>""}],
  ['newline-3', '-d:', '-f1', {IN=>"a:1\nb:2\n"}, {OUT=>"a\nb\n"}],
  ['newline-4', '-d:', '-f1', {IN=>"a:1\nb:2"}, {OUT=>"a\nb\n"}],
  ['newline-5', '-d:', '-f2', {IN=>"a:1\nb:2\n"}, {OUT=>"1\n2\n"}],
  ['newline-6', '-d:', '-f2', {IN=>"a:1\nb:2"}, {OUT=>"1\n2\n"}],
  ['newline-7', '-s', '-d:', '-f1', {IN=>"a:1\nb:2"}, {OUT=>"a\nb\n"}],
  ['newline-8', '-s', '-d:', '-f1', {IN=>"a:1\nb:2\n"}, {OUT=>"a\nb\n"}],
  ['newline-9', '-s', '-d:', '-f1', {IN=>"a1\nb2"}, {OUT=>""}],
  ['newline-10', '-s', '-d:', '-f1,2', {IN=>"a:1\nb:2"}, {OUT=>"a:1\nb:2\n"}],
  ['newline-11', '-s', '-d:', '-f1,2', {IN=>"a:1\nb:2\n"}, {OUT=>"a:1\nb:2\n"}],
  ['newline-12', '-s', '-d:', '-f1', {IN=>"a:1\nb:"}, {OUT=>"a\nb\n"}],
  ['newline-13', '-d:', '-f1-', {IN=>"a1:\n:"}, {OUT=>"a1:\n:\n"}],
  # newline processing for fields when -d == '\n'
  ['newline-14', "-d'\n'", '-f1', {IN=>"a:1\nb:"}, {OUT=>"a:1\n"}],
  ['newline-15', '-s', "-d'\n'", '-f1', {IN=>"a:1\nb:"}, {OUT=>"a:1\n"}],
  ['newline-16', '-s', "-d'\n'", '-f2', {IN=>"\nb"}, {OUT=>"b\n"}],
  ['newline-17', '-s', "-d'\n'", '-f1', {IN=>"\nb"}, {OUT=>"\n"}],
  ['newline-18', "-d'\n'", '-f2', {IN=>"\nb"}, {OUT=>"b\n"}],
  ['newline-19', "-d'\n'", '-f1', {IN=>"\nb"}, {OUT=>"\n"}],
  ['newline-20', '-s', "-d'\n'", '-f1-', {IN=>"\n"}, {OUT=>"\n"}],
  ['newline-21', '-s', "-d'\n'", '-f1-', {IN=>"\nb"}, {OUT=>"\nb\n"}],
  ['newline-22', "-d'\n'", '-f1-', {IN=>"\nb"}, {OUT=>"\nb\n"}],
  ['newline-23', "-d'\n'", '-f1-', '--ou=:', {IN=>"a\nb\n"}, {OUT=>"a:b\n"}],
  ['newline-24', "-d'\n'", '-f1,2', '--ou=:', {IN=>"a\nb\n"}, {OUT=>"a:b\n"}],

  # --zero-terminated
  ['zerot-1', "-z", '-c1', {IN=>"ab\0cd\0"}, {OUT=>"a\0c\0"}],
  ['zerot-2', "-z", '-c1', {IN=>"ab\0cd"}, {OUT=>"a\0c\0"}],
  ['zerot-3', '-z -f1-', {IN=>""}, {OUT=>""}],
  ['zerot-4', '-z -d:', '-f1', {IN=>"a:1\0b:2"}, {OUT=>"a\0b\0"}],
  ['zerot-5', '-z -d:', '-f1-', {IN=>"a1:\0:"}, {OUT=>"a1:\0:\0"}],
  ['zerot-6', "-z -d ''", '-f1,2', '--ou=:', {IN=>"a\0b\0"}, {OUT=>"a:b\0"}],

  # New functionality:
  ['out-delim1', '-c1-3,5-', '--output-d=:', {IN=>"abcdefg\n"},
   {OUT=>"abc:efg\n"}],
  # A totally overlapped field shouldn't change anything:
  ['out-delim2', '-c1-3,2,5-', '--output-d=:', {IN=>"abcdefg\n"},
   {OUT=>"abc:efg\n"}],
  # Partial overlap: index '2' is not at the start of a range.
  ['out-delim3', '-c1-3,2-4,6', '--output-d=:', {IN=>"abcdefg\n"},
   {OUT=>"abcd:f\n"}],
  ['out-delim3a', '-c1-3,2-4,6-', '--output-d=:', {IN=>"abcdefg\n"},
   {OUT=>"abcd:fg\n"}],
  # Ensure that the following two commands produce the same output.
  # Before an off-by-1 fix, the output from the former would not contain a ':'.
  ['out-delim4', '-c4-,2-3', '--output-d=:',
   {IN=>"abcdefg\n"}, {OUT=>"bc:defg\n"}],
  ['out-delim5', '-c2-3,4-', '--output-d=:',
   {IN=>"abcdefg\n"}, {OUT=>"bc:defg\n"}],
  # This test would fail for cut from coreutils-5.0.1 and earlier.
  ['out-delim6', '-c2,1-3', '--output-d=:', {IN=>"abc\n"}, {OUT=>"abc\n"}],
  #
  ['od-abut', '-b1-2,3-4', '--output-d=:', {IN=>"abcd\n"}, {OUT=>"ab:cd\n"}],
  ['od-overlap', '-b1-2,2', '--output-d=:', {IN=>"abc\n"}, {OUT=>"ab\n"}],
  ['od-overlap2', '-b1-2,2-', '--output-d=:', {IN=>"abc\n"}, {OUT=>"abc\n"}],
  ['od-overlap3', '-b1-3,2-', '--output-d=:', {IN=>"abcd\n"}, {OUT=>"abcd\n"}],
  ['od-overlap4', '-b1-3,2-3', '--output-d=:', {IN=>"abcd\n"}, {OUT=>"abc\n"}],
  ['od-overlap5', '-b1-3,1-4', '--output-d=:',
   {IN=>"abcde\n"}, {OUT=>"abcd\n"}],

  # None of the following invalid ranges provoked an error up to coreutils-6.9.
  ['inval1', qw(-f 2-0), {IN=>''}, {OUT=>''}, {EXIT=>1},
   {ERR=>"$prog: invalid decreasing range\n$try"}],
  ['inval2', qw(-f -), {IN=>''}, {OUT=>''}, {EXIT=>1}, {ERR=>$no_endpoint}],
  ['inval3', '-f', '4,-', {IN=>''}, {OUT=>''}, {EXIT=>1}, {ERR=>$no_endpoint}],
  ['inval4', '-f', '1-2,-', {IN=>''}, {OUT=>''}, {EXIT=>1},
   {ERR=>$no_endpoint}],
  ['inval5', '-f', '1-,-', {IN=>''}, {OUT=>''}, {EXIT=>1}, {ERR=>$no_endpoint}],
  ['inval6', '-f', '-1,-', {IN=>''}, {OUT=>''}, {EXIT=>1}, {ERR=>$no_endpoint}],
  # This would evoke a segfault from 5.3.0..8.10
  ['big-unbounded-b', '--output-d=:', '-b1234567890-', {IN=>''}, {OUT=>''}],
  ['big-unbounded-b2a', '--output-d=:', '-b1,9-',      {IN=>'123456789'},
    {OUT=>"1:9\n"}],
  ['big-unbounded-b2b', '--output-d=:', '-b1,1234567890-', {IN=>''}, {OUT=>''}],
  ['big-unbounded-c', '--output-d=:', '-c1234567890-', {IN=>''}, {OUT=>''}],
  ['big-unbounded-f', '--output-d=:', '-f1234567890-', {IN=>''}, {OUT=>''}],

  ['overlapping-unbounded-1', '-b3-,2-', {IN=>"1234\n"}, {OUT=>"234\n"}],
  ['overlapping-unbounded-2', '-b2-,3-', {IN=>"1234\n"}, {OUT=>"234\n"}],

  # When printing output delimiters, and with one or more ranges subsumed
  # by a to-EOL range, cut 8.20 and earlier would print extraneous delimiters.
  ['EOL-subsumed-1', '--output-d=: -b2-,3,4-4,5',
                                         {IN=>"123456\n"}, {OUT=>"23456\n"}],
  ['EOL-subsumed-2', '--output-d=: -b3,4-4,5,2-',
                                         {IN=>"123456\n"}, {OUT=>"23456\n"}],
  ['EOL-subsumed-3', '--complement -b3,4-4,5,2-',
                                         {IN=>"123456\n"}, {OUT=>"1\n"}],
  ['EOL-subsumed-4', '--output-d=: -b1-2,2-3,3-',
                                        {IN=>"1234\n"}, {OUT=>"1234\n"}],
 );

if ($mb_locale ne 'C')
  {
    # Duplicate each test vector, appending "-mb" to the test name and
    # inserting {ENV => "LC_ALL=$mb_locale"} in the copy, so that we
    # provide coverage for the distro-added multi-byte code paths.
    my @new;
    foreach my $t (@Tests)
      {
        my @new_t = @$t;
        my $test_name = shift @new_t;

        push @new, ["$test_name-mb", @new_t, {ENV => "LC_ALL=$mb_locale"}];
      }
    push @Tests, @new;
  }


@Tests = triple_test \@Tests;

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($ME, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
