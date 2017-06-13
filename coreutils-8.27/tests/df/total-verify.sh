#!/bin/sh
# Ensure "df --total" computes accurate totals

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

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ df
require_perl_

# Protect against inaccessible remote mounts etc.
timeout 10 df || skip_ "df fails"

cat <<\EOF > check-df || framework_failure_
my ($total, $used, $avail) = (0, 0, 0);
while (<>)
  {
    $. == 1
      and next;  # skip first (header) line
    # Recognize df output lines like these:
    # /dev/sdc1                  0       0       0    -  /c
    # tmpfs                1536000   12965 1523035    1% /tmp
    # total                5285932  787409 4498523   15% -
    /^(.*?) +(-?\d+|-) +(-?\d+|-) +(-?\d+|-) +(?:-|[0-9]+%) (.*)$/
      or die "$0: invalid input line\n: $_";
    if ($1 eq 'total' && $5 eq '-')
      {
        $total == $2 or die "$total != $2";
        $used  == $3 or die "$used  != $3";
        $avail == $4 or die "$avail != $4";
        my $line = <>;
        defined $line
          and die "$0: extra line(s) after totals\n";
        exit 0;
      }
    $total += $2 unless $2 eq '-';
    $used  += $3 unless $3 eq '-';
    $avail += $4 unless $4 eq '-';
  }
die "$0: missing line of totals\n";
EOF

# Use --block-size=512 to keep df from printing rounded-to-kilobyte
# numbers which wouldn't necessarily add up to the displayed total.
df --total -P --block-size=512 > space || framework_failure_
cat space  # this helps when debugging any test failure
df --total -i -P               > inode || framework_failure_
cat inode

$PERL check-df space || fail=1
$PERL check-df inode || fail=1

test "$fail" = 1 && dump_mount_list_

Exit $fail
