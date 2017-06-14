#!/usr/bin/perl
# Test that timeout handles blocked SIGALRM from its parent.

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

(my $ME = $0) =~ s|.*/||;

eval { require POSIX; };
$@
  and CuSkip::skip "$ME: this script requires Perl's POSIX module\n";

use POSIX qw(:signal_h);
my $sigset = POSIX::SigSet->new(SIGALRM); # define the signals to block
my $old_sigset = POSIX::SigSet->new;      # where the old sigmask will be kept
unless (defined sigprocmask(SIG_BLOCK, $sigset, $old_sigset)) {
  CuSkip::skip "$ME: sigprocmask failed; skipped";
}

my @Tests =
    (
     # test-name, [option, option, ...] {OUT=>"expected-output"}
     #

     ['block-alrm',  ".1 sleep 10", {EXIT => 124}],
    );

my $save_temps = $ENV{DEBUG};
my $verbose = $ENV{VERBOSE};

my $prog = 'timeout';
my $fail = run_tests ($ME, $prog, \@Tests, $save_temps, $verbose);

exit $fail;
