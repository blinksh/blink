#!/usr/bin/perl
# Basic tests for "fmt".

# Copyright (C) 2001-2017 Free Software Foundation, Inc.

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
my $normalize_strerror = "s/': .*/'/";

my @Tests =
    (
     ['8-bit-pfx', qw (-p 'ç'),
      {IN=> "ça\nçb\n"},
      {OUT=>"ça b\n"}],
     ['wide-1', '-w 32768',
      {ERR => "fmt: invalid width: '32768'\n"}, {EXIT => 1},
      {ERR_SUBST => $normalize_strerror}],
     ['wide-2', '-w 2147483647',
      {ERR => "fmt: invalid width: '2147483647'\n"}, {EXIT => 1},
      {ERR_SUBST => $normalize_strerror}],
     ['bad-suffix', '-72x',	{IN=> ''},
      {ERR => "fmt: invalid width: '72x'\n"}, {EXIT => 1}],
     ['no-file', 'no-such-file',
      {ERR => "fmt: cannot open 'no-such-file' for reading:"
       . " No such file or directory\n"}, {EXIT => 1}],
     ['obs-1', '-c -72',
      {ERR => "fmt: invalid option -- 7; -WIDTH is recognized only when it"
       . " is the first\noption; use -w N instead\n"
       . "Try 'fmt --help' for more information.\n" }, {EXIT => 1}],

     # With --prefix=P, do not remove leading space on lines without the prefix.
     ['pfx-1', qw (-p '>'),
      {IN=>  " 1\n  2\n\t3\n\t\t4\n> quoted\n> text\n"},
      {OUT=> " 1\n  2\n\t3\n\t\t4\n> quoted text\n"}],

     # Don't remove prefix from a prefix-only line.
     ['pfx-only', qw (-p '>'),
      {IN=>  ">\n"},
      {OUT=> ">\n"}],

     # With a multi-byte prefix, say, "foo", don't empty a line that
     # starts with a strict prefix (e.g. "fo") of that prefix.
     # With fmt from coreutils-6.7, it would mistakenly output an empty line.
     ['pfx-of-pfx', qw (-p 'foo'),
      {IN=>  "fo\n"},
      {OUT=> "fo\n"}],
);

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};
my $prog = 'fmt';
my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
