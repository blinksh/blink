#!/usr/bin/perl
# Test "tsort".

# Copyright (C) 1999-2017 Free Software Foundation, Inc.

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

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my @Tests =
  (
   ['cycle-1', {IN => {f => "t b\nt s\ns t\n"}}, {OUT => "s\nt\nb\n"},
    {EXIT => 1},
    {ERR => "tsort: f: input contains a loop:\ntsort: s\ntsort: t\n"} ],
   ['cycle-2', {IN => {f => "t x\nt s\ns t\n"}}, {OUT => "s\nt\nx\n"},
    {EXIT => 1},
    {ERR => "tsort: f: input contains a loop:\ntsort: s\ntsort: t\n"} ],

   ['posix-1', {IN => "a b c c d e\ng g\nf g e f\nh h\n"},
    {OUT => "a\nc\nd\nh\nb\ne\nf\ng\n"}],
   ['posix-2', {IN => "b a\nd c\nz h x h r h\n"},
    {OUT => "b\nd\nr\nx\nz\na\nc\nh\n"}],

   ['linear-1', {IN => "a b b c c d d e e f f g\n"},
    {OUT => "a\nb\nc\nd\ne\nf\ng\n"}],

   ['tree-1', {IN => "a b b c c d d e e f f g\nc x x y y z\n"},
    {OUT => "a\nb\nc\nx\nd\ny\ne\nz\nf\ng\n"}],
   ['tree-2', {IN => "a b b c c d d e e f f g\nc x x y y z\nf r r s s t\n"},
    {OUT => "a\nb\nc\nx\nd\ny\ne\nz\nf\nr\ng\ns\nt\n"}],

   # Before coreutils-5.0.1, given an odd number of input tokens,
   # tsort would accept that and treat the input as if an additional
   # copy of the final token were appended.
   ['odd', {IN => "a\n"},
    {EXIT => 1},
    {ERR => "tsort: odd.1: input contains an odd number of tokens\n"}],

   ['only-one', {IN => {f => ""}}, {IN => {g => ""}},
    {EXIT => 1},
    {ERR => "tsort: extra operand 'g'\n"
     . "Try 'tsort --help' for more information.\n"}],
  );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = 'tsort';
my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
