/* Substitute for <netinet/in.h>.
   Copyright (C) 2007-2017 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, see <http://www.gnu.org/licenses/>.  */

#ifndef _@GUARD_PREFIX@_NETINET_IN_H

#if __GNUC__ >= 3
@PRAGMA_SYSTEM_HEADER@
#endif
@PRAGMA_COLUMNS@

#if @HAVE_NETINET_IN_H@

/* On many platforms, <netinet/in.h> assumes prior inclusion of
   <sys/types.h>.  */
# include <sys/types.h>

/* The include_next requires a split double-inclusion guard.  */
# @INCLUDE_NEXT@ @NEXT_NETINET_IN_H@

#endif

#ifndef _@GUARD_PREFIX@_NETINET_IN_H
#define _@GUARD_PREFIX@_NETINET_IN_H

#if !@HAVE_NETINET_IN_H@

/* A platform that lacks <netinet/in.h>.  */

# include <sys/socket.h>

#endif

#endif /* _@GUARD_PREFIX@_NETINET_IN_H */
#endif /* _@GUARD_PREFIX@_NETINET_IN_H */
