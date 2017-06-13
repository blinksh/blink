#!/usr/bin/perl
# Make sure that rm -r '' fails.

# Copyright (C) 1998-2017 Free Software Foundation, Inc.

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

# On SunOS 4.1.3, running rm -r '' in a nonempty directory may
# actually remove files with names of entries in the current directory
# but relative to '/' rather than relative to the current directory.

use strict;

(my $program_name = $0) =~ s|.*/||;

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my $prog = 'rm';

# FIXME: copied from misc/ls-misc; factor into Coreutils.pm?
sub mk_file(@)
{
  foreach my $f (@_)
    {
      open (F, '>', $f) && close F
        or die "creating $f: $!\n";
    }
}

my @Tests =
    (
     # test-name options input expected-output
     #
     ['empty-name-1', "''", {EXIT => 1},
      {ERR => "$prog: cannot remove '': No such file or directory\n"}],

     ['empty-name-2', "a '' b", {EXIT => 1},
      {ERR => "$prog: cannot remove '': No such file or directory\n"},
      {PRE => sub { mk_file qw(a b) }},
      {POST => sub {-f 'a' || -f 'b' and die "a or b remain\n" }},
     ],
    );

my $save_temps = $ENV{SAVE_TEMPS};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;
