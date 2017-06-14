#!/bin/sh
# exercise sort's --sort=version option

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
print_ver_ sort

cat > in << _EOF_
gcc-c++-10.fc9.tar.gz
gcc-c++-10.8.12-0.7rc2.fc9.tar.bz2
glibc-2-0.1.beta1.fc10.rpm
glibc-common-5-0.2.beta2.fc9.ebuild
glibc-common-5-0.2b.deb
glibc-common-11b.ebuild
glibc-common-11-0.6rc2.ebuild
libstdc++-0.5.8.11-0.7rc2.fc10.tar.gz
libstdc++-4a.fc8.tar.gz
libstdc++-4.10.4.20040204svn.rpm
libstdc++-devel-3.fc8.ebuild
libstdc++-devel-3a.fc9.tar.gz
libstdc++-devel-8.fc8.deb
libstdc++-devel-8.6.2-0.4b.fc8
nss_ldap-1-0.2b.fc9.tar.bz2
nss_ldap-1-0.6rc2.fc8.tar.gz
nss_ldap-1.0-0.1a.tar.gz
nss_ldap-10beta1.fc8.tar.gz
nss_ldap-10.11.8.6.20040204cvs.fc10.ebuild
string start 5.0.0 end of str
string start 5.1.0 end of str
string start 5.10.0 end of str
string start 5.2.0 end of str
string start 5.20.0 end of str
string start 5.3.0 end of str
string start 5.30.0 end of str
string start 5.4.0 end of str
string start 5.40.0 end of str
string start 5.5.0 end of str
string start 5.50.0 end of str
string start 5.6.0 end of str
string start 5.60.0 end of str
string start 5.7.0 end of str
string start 5.70.0 end of str
string start 5.8.0 end of str
string start 5.80.0 end of str
string start 5.9.0 end of str
string start 5.90.0 end of str
_EOF_

cat > exp << _EOF_
gcc-c++-10.fc9.tar.gz
gcc-c++-10.8.12-0.7rc2.fc9.tar.bz2
glibc-2-0.1.beta1.fc10.rpm
glibc-common-5-0.2.beta2.fc9.ebuild
glibc-common-5-0.2b.deb
glibc-common-11b.ebuild
glibc-common-11-0.6rc2.ebuild
libstdc++-0.5.8.11-0.7rc2.fc10.tar.gz
libstdc++-4a.fc8.tar.gz
libstdc++-4.10.4.20040204svn.rpm
libstdc++-devel-3.fc8.ebuild
libstdc++-devel-3a.fc9.tar.gz
libstdc++-devel-8.fc8.deb
libstdc++-devel-8.6.2-0.4b.fc8
nss_ldap-1-0.2b.fc9.tar.bz2
nss_ldap-1-0.6rc2.fc8.tar.gz
nss_ldap-1.0-0.1a.tar.gz
nss_ldap-10beta1.fc8.tar.gz
nss_ldap-10.11.8.6.20040204cvs.fc10.ebuild
string start 5.0.0 end of str
string start 5.1.0 end of str
string start 5.2.0 end of str
string start 5.3.0 end of str
string start 5.4.0 end of str
string start 5.5.0 end of str
string start 5.6.0 end of str
string start 5.7.0 end of str
string start 5.8.0 end of str
string start 5.9.0 end of str
string start 5.10.0 end of str
string start 5.20.0 end of str
string start 5.30.0 end of str
string start 5.40.0 end of str
string start 5.50.0 end of str
string start 5.60.0 end of str
string start 5.70.0 end of str
string start 5.80.0 end of str
string start 5.90.0 end of str
_EOF_

sort --sort=version -o out in || fail=1
compare exp out || fail=1
Exit $fail
