#!/bin/sh
# Verify that --preserve-root works.

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

. "${srcdir=.}/tests/init.sh"; path_prepend_ ./src
print_ver_ chown
skip_if_root_

mkdir d && ln -s / d/slink-to-root


# Even if --preserve-root were to malfunction, allowing the chown or
# chgrp to traverse through "/", since we're running as non-root,
# they would be very unlikely to cause any changes.
chown -R --preserve-root 0 / >  out 2>&1 && fail=1
chgrp -R --preserve-root 0 / >> out 2>&1 && fail=1

# Here, if --preserve-root were to malfunction, chmod could make changes,
# but only to files owned and unreadable by the user running this test,
# and then, only to make them readable by owner.
chmod -R --preserve-root u+r / >> out 2>&1 && fail=1

# With -RHh, --preserve-root should trigger nothing,
# since the symlink in question is not a command line argument.
# Contrary to the above commands, these two should succeed.
echo '==== test -RHh' >> out
chown -RHh --preserve-root $(id -u) d >> out 2>&1 || fail=1
chgrp -RHh --preserve-root $(id -g) d >> out 2>&1 || fail=1

# These must fail.
echo '==== test -RLh' >> out
chown -RLh --preserve-root $(id -u) d >> out 2>&1 && fail=1
chgrp -RLh --preserve-root $(id -g) d >> out 2>&1 && fail=1

cat <<\EOF > exp || fail=1
chown: it is dangerous to operate recursively on '/'
chown: use --no-preserve-root to override this failsafe
chgrp: it is dangerous to operate recursively on '/'
chgrp: use --no-preserve-root to override this failsafe
chmod: it is dangerous to operate recursively on '/'
chmod: use --no-preserve-root to override this failsafe
==== test -RHh
==== test -RLh
chown: it is dangerous to operate recursively on 'd/slink-to-root' (same as '/')
chown: use --no-preserve-root to override this failsafe
chgrp: it is dangerous to operate recursively on 'd/slink-to-root' (same as '/')
chgrp: use --no-preserve-root to override this failsafe
EOF

compare exp out || fail=1

Exit $fail
