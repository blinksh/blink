package CuSkip;
# Skip a test: emit diag to log and to stderr, and exit 77

# Copyright (C) 2011-2017 Free Software Foundation, Inc.

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
use warnings;

our $ME = $0 || "<???>";

# Emit a diagnostic both to stderr and to $stderr_fileno_.
# FIXME: don't hard-code that value (9), since it's already defined in init.cfg.
sub skip ($)
{
  my ($msg) = @_;
  my $stderr_fileno_ = 9;
  warn $msg;
  open FH, ">&$stderr_fileno_"
    or warn "$ME: failed to dup stderr\n";
  print FH $msg;
  close FH
    or warn "$ME: failed to close FD $stderr_fileno_\n";
  exit 77;
}

1;
