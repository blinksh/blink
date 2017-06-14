#!/usr/bin/perl
# exercise the 'invalid option' handling code in each program

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

require 5.003;
use strict;

# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

my %exit_status =
  (
    ls => 2,
    dir => 2,
    vdir => 2,
    test => 2,
    chroot => 125,
    echo => 0,
    env => 125,
    expr => 0,
    nice => 125,
    nohup => 125,
    sort => 2,
    stdbuf => 125,
    test => 0,
    timeout => 125,
    true => 0,
    tty => 2,
    printf => 0,
    printenv => 2,
  );

my %expected_out =
  (
    echo => "-/\n",
    expr => "-/\n",
    printf => "-/",
  );

my %expected_err =
  (
    false => '',
    stty => '',
  );

my $fail = 0;
my @built_programs = split ' ', $ENV{built_programs};
foreach my $prog (@built_programs)
  {
    $prog eq '['
      and next;

    my $try = "Try '$prog --help' for more information.\n";
    my $x = $exit_status{$prog};
    defined $x
      or $x = 1;

    my $out = $expected_out{$prog};
    defined $out
      or $out = '';

    my $err = $expected_err{$prog};
    defined $err
      or $err = $x == 0 ? '' : "$prog: invalid option -- /\n$try";

    # Accommodate different syntax in glibc's getopt
    # diagnostics by filtering out single quotes.
    # Also accommodate BSD getopt.
    my $err_subst = "s,'/',/,; s,unknown,invalid,";

    # Depending on how this script is run, stty emits different
    # diagnostics.  Don't bother checking them.
    $prog eq 'stty'
      and $err_subst = 's/(.|\n)*//ms';

    my @Tests = (["$prog-invalid-opt", '-/', {OUT=>$out},
                  {ERR_SUBST => $err_subst},
                  {EXIT=>$x}, {ERR=>$err}]);

    my $save_temps = $ENV{DEBUG};
    my $verbose = $ENV{VERBOSE};

    my $f = run_tests ($prog, \$prog, \@Tests, $save_temps, $verbose);
    $f
      and $fail = 1;
  }

exit $fail;
