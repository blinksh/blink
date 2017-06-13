#!/usr/bin/perl
# Test whether programs exit upon a single EOF from a tty.
# Ensure that e.g., cat exits upon a single EOF (^D) from a tty.
# Do the same for all programs that can read stdin,
# require no arguments and that write to standard output.

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
(my $ME = $0) =~ s|.*/||;

# Some older versions of Expect.pm (e.g. 1.07) lack the log_user method,
# so check for that, too.
eval { require Expect; Expect->require_version('1.11') };
$@
  and CuSkip::skip "$ME: this script requires Perl's Expect package >=1.11\n";

{
  my $fail = 0;
  my @stdin_reading_commands = qw(
    base32
    base64
    cat
    cksum
    dd
    expand
    fmt
    fold
    head
    md5sum
    nl
    od
    paste
    pr
    ptx
    sha1sum
    sha224sum
    sha256sum
    sha384sum
    sha512sum
    shuf
    sort
    sum
    tac
    tail
    tee
    tsort
    unexpand
    uniq
    wc
  );
  my $stderr = 'tty-eof.err';
  foreach my $cmd ((@stdin_reading_commands), 'cut -f2',
                   'numfmt --invalid=ignore')
    {
      my $exp = new Expect;
      $exp->log_user(0);
      $ENV{built_programs} =~ /\b$cmd\b/ || next;
      $exp->spawn("$cmd 2> $stderr")
        or (warn "$ME: cannot run '$cmd': $!\n"), $fail=1, next;
      # No input for cut -f2.
      $cmd =~ /^cut/
        or $exp->send("a b\n");
      $exp->send("\cD");  # This is Control-D.  FIXME: what if that's not EOF?
      $exp->expect (0, '-re', "^a b\\r?\$");
      my $found = $exp->expect (1, '-re', "^.+\$");
      $found and warn "F: $found: " . $exp->exp_match () . "\n";
      $exp->expect(10, 'eof');
      # Expect no output from cut, since we gave it no input.
      defined $found || $cmd =~ /^cut/
        or (warn "$ME: $cmd didn't produce expected output\n"),
          $fail=1, next;
      defined $exp->exitstatus
        or (warn "$ME: $cmd didn't exit after ^D from standard input\n"),
          $fail=1, next;
      my $s = $exp->exitstatus;
      $s == 0
        or (warn "$ME: $cmd exited with status $s (expected 0)\n"),
          $fail=1;
      $exp->hard_close();

      # dd normally writes to stderr.  If it exits successfully, we're done.
      $cmd eq 'dd' && $s == 0
        and next;

      if (-s $stderr)
        {
          warn "$ME: $cmd wrote to stderr:\n";
          system "cat $stderr";
          $fail = 1;
        }
    }
  continue
    {
      unlink $stderr
        or warn "$ME: failed to remove stderr file from $cmd, $stderr: $!\n";
    }

  exit $fail
}
