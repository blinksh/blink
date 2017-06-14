#!/usr/bin/perl
# Test paste.

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

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $prog = 'paste';
my $msg = "$prog: delimiter list ends with an unescaped backslash: ";

my @Tests =
  (
   # Ensure that paste properly handles files lacking a final newline.
   ['no-nl-1', {IN=>"a"},   {IN=>"b"},   {OUT=>"a\tb\n"}],
   ['no-nl-2', {IN=>"a\n"}, {IN=>"b"},   {OUT=>"a\tb\n"}],
   ['no-nl-3', {IN=>"a"},   {IN=>"b\n"}, {OUT=>"a\tb\n"}],
   ['no-nl-4', {IN=>"a\n"}, {IN=>"b\n"}, {OUT=>"a\tb\n"}],

   ['zno-nl-1', '-z', {IN=>"a"},   {IN=>"b"},   {OUT=>"a\tb\0"}],
   ['zno-nl-2', '-z', {IN=>"a\0"}, {IN=>"b"},   {OUT=>"a\tb\0"}],
   ['zno-nl-3', '-z', {IN=>"a"},   {IN=>"b\0"}, {OUT=>"a\tb\0"}],
   ['zno-nl-4', '-z', {IN=>"a\0"}, {IN=>"b\0"}, {OUT=>"a\tb\0"}],

   # Same as above, but with a two lines in each input file and
   # the addition of the -d option to make SPACE be the output delimiter.
   ['no-nla1', '-d" "', {IN=>"1\na"},   {IN=>"2\nb"},   {OUT=>"1 2\na b\n"}],
   ['no-nla2', '-d" "', {IN=>"1\na\n"}, {IN=>"2\nb"},   {OUT=>"1 2\na b\n"}],
   ['no-nla3', '-d" "', {IN=>"1\na"},   {IN=>"2\nb\n"}, {OUT=>"1 2\na b\n"}],
   ['no-nla4', '-d" "', {IN=>"1\na\n"}, {IN=>"2\nb\n"}, {OUT=>"1 2\na b\n"}],

   ['zno-nla1', '-zd" "', {IN=>"1\0a"},   {IN=>"2\0b"},   {OUT=>"1 2\0a b\0"}],
   ['zno-nla2', '-zd" "', {IN=>"1\0a\0"}, {IN=>"2\0b"},   {OUT=>"1 2\0a b\0"}],
   ['zno-nla3', '-zd" "', {IN=>"1\0a"},   {IN=>"2\0b\0"}, {OUT=>"1 2\0a b\0"}],
   ['zno-nla4', '-zd" "', {IN=>"1\0a\0"}, {IN=>"2\0b\0"}, {OUT=>"1 2\0a b\0"}],

   # Specifying a delimiter with a trailing backslash would overrun a
   # malloc'd buffer.
   ['delim-bs1', q!-d'\'!, {IN=>{'a'x50=>''}}, {EXIT => 1},
    # We print a single backslash into the expected output
    {ERR => $msg . q!\\! . "\n"} ],

   # Prior to coreutils-5.1.2, this sort of abuse would make paste
   # scribble on command-line arguments.  With paste from coreutils-5.1.0,
   # this example would mangle the first file name argument, if it contains
   # accepted backslash-escapes:
   # $ paste -d\\ '123\b\b\b.....@' 2>&1 |cat -A
   # paste: 23^H^H^H.....@...@: No such file or directory$
   ['delim-bs2', q!-d'\'!, {IN=>{'123\b\b\b.....@'=>''}}, {EXIT => 1},
    {ERR => $msg . q!\\! . "\n"} ],
  );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
