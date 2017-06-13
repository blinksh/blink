#!/usr/bin/perl

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

use strict;
use Data::Dumper;

my $limits = getlimits ();

my $prog = 'csplit';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

# Input from 'seq 6'
my $IN_SEQ_6 =<<EOF;
1
2
3
4
5
6
EOF

# Input from a possible run of 'uniq --group'
# (groups separated by empty lines)
my $IN_UNIQ =<<EOF;
a
a
YY

XX
b
b
YY

XX
c
YY

XX
d
d
d
EOF

# Standard Coreutils::run_tests() structure, except the addition of
# "OUTPUTS" array, containing the expected content of the output files.
# See code below for conversion into PRE/CMP/POST checks.
my @csplit_tests =
(
  # without --suppress-matched,
  # the newline (matched line) appears in the output files
  ["re-base", "-q - '/^\$/' '{*}'", {IN_PIPE => $IN_UNIQ},
    {OUTPUTS => [ "a\na\nYY\n", "\nXX\nb\nb\nYY\n","\nXX\nc\nYY\n",
                  "\nXX\nd\nd\nd\n" ] }],

  # the newline (matched line) does not appears in the output files
  ["re-1", " --suppress-matched -q - '/^\$/' '{*}'", {IN_PIPE => $IN_UNIQ},
    {OUTPUTS => ["a\na\nYY\n", "XX\nb\nb\nYY\n", "XX\nc\nYY\n",
                 "XX\nd\nd\nd\n"]}],

  # the 'XX' (matched line + offset 1) does not appears in the output files.
  # the newline appears in the files (before each split, at the end of the file)
  ["re-2", "--suppress-matched -q - '/^\$/1' '{*}'", {IN_PIPE => $IN_UNIQ},
    {OUTPUTS => ["a\na\nYY\n\n","b\nb\nYY\n\n","c\nYY\n\n","d\nd\nd\n"]}],

  # the 'YY' (matched line + offset of -1) does not appears in the output files
  # the newline appears in the files (as the first line of the new split)
  ["re-3", " --suppress-matched -q - '/^\$/-1' '{*}'", {IN_PIPE => $IN_UNIQ},
    {OUTPUTS => ["a\na\n", "\nXX\nb\nb\n", "\nXX\nc\n", "\nXX\nd\nd\nd\n"]}],

  # Test two consecutive matched lines
  # without suppress-matched, the second file should contain a single newline.
  ["re-4.1", "-q - '/^\$/' '{*}'", {IN_PIPE => "a\n\n\nb\n"},
    {OUTPUTS => [ "a\n", "\n", "\nb\n" ]}],
  # suppress-matched will cause the second file to be empty.
  ["re-4.2", "--suppress-match -q - '/^\$/' '{*}'", {IN_PIPE => "a\n\n\nb\n"},
    {OUTPUTS => [ "a\n", "", "b\n" ]}],
  # suppress-matched + elide-empty should output just two files.
  ["re-4.3", "--suppress-match -zq - '/^\$/' '{*}'", {IN_PIPE => "a\n\n\nb\n"},
    {OUTPUTS => [ "a\n", "b\n" ]}],


  # Test a matched-line as the last line
  # default: last file with newline should be created.
  ["re-5.1", "-q - '/^\$/' '{*}'", {IN_PIPE => "a\n\nb\n\n"},
    {OUTPUTS => [ "a\n", "\nb\n", "\n" ]}],
  # suppress-matched - last empty files should be created.
  ["re-5.2", "--suppress-match -q - '/^\$/' '{*}'", {IN_PIPE => "a\n\nb\n\n"},
    {OUTPUTS => [ "a\n", "b\n", "" ]}],
  # suppress-matched + elide-empty: just two files should be created.
  ["re-5.3", "--suppress-match -zq - '/^\$/' '{*}'", {IN_PIPE => "a\n\nb\n\n"},
    {OUTPUTS => [ "a\n", "b\n" ]}],

  # without suppress-matched,
  # the matched lines (2/4/6) appears in the output files
  ["int-base",    '-q - 2 4 6', {IN_PIPE => $IN_SEQ_6},
    {OUTPUTS => [ "1\n", "2\n3\n", "4\n5\n", "6\n" ]}],
  # suppress matched - the matching lines (2/4/6) should not appear.
  ["int-1", '--suppress-matched -q - 2 4 6', {IN_PIPE => $IN_SEQ_6},
    {OUTPUTS => [ "1\n", "3\n", "5\n", "" ]}],
  # suppress matched + elide-empty
  ["int-2", '--suppress-matched -zq - 2 4 6', {IN_PIPE => $IN_SEQ_6},
    {OUTPUTS => [ "1\n", "3\n", "5\n" ]}],
);



=pod
The following loop translate the above @Tests to a Cureutils::run_tests()
compatible structure. It converts "OUTPUTS" key into "CMP" + "POST" keys:
1. Each element in the OUTPUTS key is expected to be an output file
   from csplit (named xx00, xx01, xx02...)
   create a "CMP" key for each one, with the output and the filename.
2. Add a "POST" key, ensuring no extra files have been created.
   (e.g. if there are 4 expected outputs, xx00 to xx03,
    ensure xx04 doesn't exist).
3. Add a "PRE" key, deleting all existing 'xx*' files.

Example:

Before conversion:
   my @csplit_tests =
   (
     ["1", '-z -q - 2 4 6',
       {IN_PIPE => "1\n2\n3\n4\n5\n6\n"},
       {OUTPUTS => [ "1\n", "2\n3\n", "4\n5\n", "6\n" ],
     ]
   )

After conversion:

   my @csplit_tests =
   (
     ["1", '-z -q - 2 4 6',
       {IN_PIPE => "1\n2\n3\n4\n5\n6\n"},
       {PRE => sub { unlink glob './xx??' ; }},
       {CMP => ["1\n",    {'xx00'=> undef}]},
       {CMP => ["2\n3\n", {'xx01'=> undef}]},
       {CMP => ["4\n5\n", {'xx02'=> undef}]},
       {CMP => ["6\n",    {'xx03'=> undef}]},
       {POST => sub { die "extra file" if -e 'xx04'}},
     ],
    );
=cut
my @Tests;
foreach my $t (@csplit_tests)
  {
    my ($test_name, $cmdline, @others) = @$t;
    my $new_ent = [$test_name, $cmdline];

    my $out_file_num = 0 ;

    foreach my $e (@others)
      {
        die "Internal error: expecting a hash (e.g. IN_PIPE/OUTPUTS/ERR)" .
            "in test '$test_name', got $e"
            unless ref $e && (ref $e eq 'HASH');

        my ($key, $value) = each %$e;
        if ($key eq 'OUTPUTS')
          {
            # Convert each expected OUTPUT to a 'CMP' key.
            foreach my $output (@$value)
              {
                my $filename = sprintf("xx%02d",$out_file_num++);
                my $cmp = {CMP => [ $output, { $filename => undef}]};
                push @$new_ent, $cmp;
              }

            # Add a 'POST' check
            # Ensure no extra files have been created.
            my $filename = sprintf("xx%02d",$out_file_num++);
            my $post = { POST => sub { die "Test failed: an extraneous file " .
                                "'$filename' has been created\n"
                                if -e $filename; } } ;
            push @$new_ent, $post;

            # before running each test, cleanup the 'xx00' files
            # from previous runs.
            my $pre = { PRE => sub { unlink glob "./xx??"; } };
            push @$new_ent, $pre;
          }
        else
          {
            # pass other entities as-is (e.g. OUT, ERR, OUT_SUBST, EXIT)
            # run_tests() will know how to handle them.
            push @$new_ent, $e;
          }
      }

    push @Tests, $new_ent;
  }

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($prog, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
