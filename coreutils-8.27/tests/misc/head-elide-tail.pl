#!/usr/bin/perl
# Exercise head's --bytes=-N option.

# Copyright (C) 2003-2017 Free Software Foundation, Inc.

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

(my $program_name = $0) =~ s|.*/||;

$ENV{PROG} = 'head';

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

# This should match the definition in head.c.
my $READ_BUFSIZE = 8192;

my @Tests =
  (
   # Elide the exact size of the file.
   ['elide-b1', "--bytes=-2", {IN=>"a\n"}, {OUT=>''}],
   # Elide more than the size of the file.
   ['elide-b2', "--bytes=-2", {IN=>"a"},   {OUT=>''}],
   # Leave just one byte.
   ['elide-b3', "--bytes=-2", {IN=>"abc"}, {OUT=>'a'}],
   # Make it so the elided bytes straddle the end of the first
   # $READ_BUFSIZE block.
   ['elide-b4', "--bytes=-2",
    {IN=> 'a' x ($READ_BUFSIZE-3) . "\nbcd"},
    {OUT=>'a' x ($READ_BUFSIZE-3) . "\nb"}],
   # Make it so the elided bytes straddle the end of the 2nd
   # $READ_BUFSIZE block.
   ['elide-b5', "--bytes=-2",
    {IN=> 'a' x (2 * $READ_BUFSIZE - 2) . 'bcd'},
    {OUT=>'a' x (2 * $READ_BUFSIZE - 2) . 'b'}],

   ['elide-l0', "--lines=-1", {IN=>''}, {OUT=>''}],
   ['elide-l1', "--lines=-1", {IN=>"a\n"}, {OUT=>''}],
   ['elide-l2', "--lines=-1", {IN=>"a"}, {OUT=>''}],
   ['elide-l3', "--lines=-1", {IN=>"a\nb"}, {OUT=>"a\n"}],
   ['elide-l4', "--lines=-1", {IN=>"a\nb\n"}, {OUT=>"a\n"}],
   ['elide-l5', "--lines=-0", {IN=>"a\nb\n"}, {OUT=>"a\nb\n"}],
   ['elide-l6', "--lines=-0", {IN=>"a\nb"}, {OUT=>"a\nb"}],
  );

if ($ENV{RUN_EXPENSIVE_TESTS})
  {
    # Brute force: use all combinations of file sizes [0..20] and
    # number of bytes to elide [0..20].  For better coverage, recompile
    # head with -DHEAD_TAIL_PIPE_READ_BUFSIZE=4 and
    # -DHEAD_TAIL_PIPE_BYTECOUNT_THRESHOLD=8
    my $s = "abcdefghijklmnopqrst";
    for my $file_size (0..20)
      {
        for my $n_elide (0..20)
          {
            my $input = substr $s, 0, $file_size;
            my $out_len = $n_elide < $file_size ? $file_size - $n_elide : 0;
            my $output = substr $input, 0, $out_len;
            my $t = ["elideb$file_size-$n_elide", "--bytes=-$n_elide",
                     {IN=>$input}, {OUT=>$output}];
            push @Tests, $t;
            my @u = @$t;
            # Insert the ---presume-input-pipe option.
            $u[0] .= 'p';
            $u[1] .= ' ---presume-input-pipe';
            push @Tests, \@u;
          }
      }

    $s =~ s/(.)/$1\n/g;
    $s .= 'u'; # test without trailing '\n'
    for my $file_size (0..21)
      {
        for my $n_elide (0..21)
          {
            my $input = substr $s, 0, 2 * $file_size;
            my $out_len = $n_elide < $file_size ? $file_size - $n_elide : 0;
            my $output = substr $input, 0, 2 * $out_len;
            my $t = ["elidel$file_size-$n_elide", "--lines=-$n_elide",
                     {IN=>$input}, {OUT=>$output}];
            push @Tests, $t;
            my @u = @$t;
            # Insert the ---presume-input-pipe option.
            $u[0] .= 'p';
            $u[1] .= ' ---presume-input-pipe';
            push @Tests, \@u;
          }
      }
  }

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = $ENV{PROG} || die "$0: \$PROG not specified in environment\n";
my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
