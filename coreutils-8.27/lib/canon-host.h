/* Host name canonicalization

   Copyright (C) 2005, 2009-2017 Free Software Foundation, Inc.

   Written by Derek Price <derek@ximbiot.com>

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

#ifndef CANON_HOST_H
# define CANON_HOST_H 1

char *canon_host (char const *host);
char *canon_host_r (char const *host, int *cherror);

const char *ch_strerror (void);
# define ch_strerror_r(cherror) gai_strerror (cherror);

#endif /* !CANON_HOST_H */
