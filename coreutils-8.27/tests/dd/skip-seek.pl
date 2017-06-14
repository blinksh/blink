#!/usr/bin/perl
# Test dd's skip and seek options.

# Copyright (C) 2000-2017 Free Software Foundation, Inc.

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
my $out = 'out';

my @Tests =
    (
     [
      'sk-seek1',
      qw (bs=1 skip=1 seek=2 conv=notrunc count=3 status=noxfer of=@AUX@ < ),
      {IN=> '0123456789abcdef'},
      {AUX=> 'zyxwvutsrqponmlkji'},
      {OUT=> ''},
      {ERR=> "3+0 records in\n3+0 records out\n"},
      {CMP=> ['zy123utsrqponmlkji', {'@AUX@'=> undef}]},
     ],
     [
      'sk-seek2',
      qw (bs=5 skip=1 seek=1 conv=notrunc count=1 status=noxfer of=@AUX@ < ),
      {IN=> '0123456789abcdef'},
      {AUX=> 'zyxwvutsrqponmlkji'},
      {OUT=> ''},
      {ERR=> "1+0 records in\n1+0 records out\n"},
      {CMP=> ['zyxwv56789ponmlkji', {'@AUX@'=> undef}]},
     ],
     [
      'sk-seek3',
      qw (bs=5 skip=1 seek=1 count=1 status=noxfer of=@AUX@ < ),
      {IN=> '0123456789abcdef'},
      {AUX=> 'zyxwvutsrqponmlkji'},
      {OUT=> ''},
      {ERR=> "1+0 records in\n1+0 records out\n"},
      {CMP=> ['zyxwv56789', {'@AUX@'=> undef}]},
     ],
     [
      # Before fileutils-4.0.45, the last 10 bytes of output
      # were these "\0\0\0\0\0\0\0\0  ".
      'block-sync-1', qw(ibs=10 cbs=10 status=noxfer), 'conv=block,sync', '<',
      {IN=> "01234567\nabcdefghijkl\n"},
      {OUT=> "01234567  abcdefghij          "},
      {ERR=> "2+1 records in\n0+1 records out\n1 truncated record\n"},
     ],
     [
      # Before coreutils-5.93, this would output just "c\n".
      'sk-seek4', qw(bs=1 skip=1 status=noxfer),
      {IN_PIPE=> "abc\n"},
      {OUT=> "bc\n"},
      {ERR=> "3+0 records in\n3+0 records out\n"},
     ],
    );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = 'dd';
my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
