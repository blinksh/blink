#!/usr/bin/perl
# Exercise od

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

(my $program_name = $0) =~ s|.*/||;

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

# Use a file in /proc whose size is not likely to
# change between the wc and od invocations.
my $proc_file = '/proc/version';
-f $proc_file
  or $proc_file = '/dev/null';

# Count the bytes in $proc_file, _by reading_.
my $len = 0;
open FH, '<', $proc_file
  or die "$program_name: can't open '$proc_file' for reading: $!\n";
while (defined (my $line = <FH>))
  {
    $len += length $line;
  }
close FH;
my $proc_file_byte_count = $len;

my @Tests =
    (
     # Skip the exact length of the input file.
     # Up to coreutils-6.9, this would ignore the "-j 1".
     ['j-bug1', '-c -j 1 -An', {IN=>{g=>'a'}}, {OUT=>''}],
     ['j-bug2', '-c -j 2 -An', {IN=>{g=>'a'}}, {IN=>{h=>'b'}}, {OUT=>''}],
     # Skip the sum of the lengths of the first three inputs.
     ['j-bug3', '-c -j 3 -An', {IN=>{g=>'a'}}, {IN=>{h=>'b'}},
                                               {IN=>{i=>'c'}}, {OUT=>''}],
     # Skip the sum of the lengths of the first three inputs, printing the 4th.
     ['j-bug4', '-c -j 3 -An', {IN=>{g=>'a'}}, {IN=>{h=>'b'}},
                               {IN=>{i=>'c'}}, {IN=>{j=>'d'}}, {OUT=>"   d\n"}],

     # Ensure that od -j doesn't fseek across a nonempty file in /proc,
     # even if the kernel reports that the file has stat.st_size = 0.
     ['j-proc', "-An -c -j $proc_file_byte_count $proc_file",
                               {IN=>{f2=>'e'}}, {OUT=>"   e\n"}],

     # Ensure that a large width does not cause trouble.
     # From coreutils-7.0 through coreutils-8.21, these would print
     # approximately 128KiB of padding.
     ['wide-a',   '-a -w65537 -An', {IN=>{g=>'x'}}, {OUT=>"   x\n"}],
     ['wide-c',   '-c -w65537 -An', {IN=>{g=>'x'}}, {OUT=>"   x\n"}],
     ['wide-x', '-tx1 -w65537 -An', {IN=>{g=>'B'}}, {OUT=>" 42\n"}],
    );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = 'od';
my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
