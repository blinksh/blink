/* Host name canonicalization

   Copyright (C) 2005-2017 Free Software Foundation, Inc.

   Written by Derek Price <derek@ximbiot.com>.

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

#include "config.h"

#include "canon-host.h"

#include <string.h>
#include <netdb.h>

/* Store the last error for the single-threaded version of this function.  */
static int last_cherror;

/* Single-threaded of wrapper for canon_host_r.  After a NULL return, error
   messages may be retrieved via ch_strerror().  */
char *
canon_host (const char *host)
{
  return canon_host_r (host, &last_cherror);
}

/* Return a malloc'd string containing the canonical hostname associated with
   HOST, or NULL if a canonical name cannot be determined.  On NULL return,
   if CHERROR is not NULL, set *CHERROR to an error code as returned by
   getaddrinfo().  Use ch_strerror_r() or gai_strerror() to convert a *CHERROR
   value to a string suitable for error messages.

   WARNINGS
     HOST must be a string representation of a resolvable name for this host.
     Strings containing an IP address in dotted decimal notation will be
     returned as-is, without further resolution.

     The use of the word "canonical" in this context is unfortunate but
     entrenched.  The value returned by this function will be the end result
     of the resolution of any CNAME chains in the DNS.  There may only be one
     such value for any given hostname, though the actual IP address
     referenced by this value and the device using that IP address may each
     actually have any number of such "canonical" hostnames.  See the POSIX
     getaddrinfo spec <http://www.opengroup.org/susv3xsh/getaddrinfo.html">,
     RFC 1034 <http://www.faqs.org/rfcs/rfc1034.html>, & RFC 2181
     <http://www.faqs.org/rfcs/rfc2181.html> for more on what this confusing
     term really refers to. */
char *
canon_host_r (char const *host, int *cherror)
{
  char *retval = NULL;
  static struct addrinfo hints;
  struct addrinfo *res = NULL;
  int status;

  hints.ai_flags = AI_CANONNAME;
  status = getaddrinfo (host, NULL, &hints, &res);
  if (!status)
    {
      /* http://lists.gnu.org/archive/html/bug-coreutils/2006-09/msg00300.html
         says Darwin 7.9.0 getaddrinfo returns 0 but sets
         res->ai_canonname to NULL.  */
      retval = strdup (res->ai_canonname ? res->ai_canonname : host);
      if (!retval && cherror)
        *cherror = EAI_MEMORY;
      freeaddrinfo (res);
    }
  else if (cherror)
    *cherror = status;

  return retval;
}

/* Return a string describing the last error encountered by canon_host.  */
const char *
ch_strerror (void)
{
  return gai_strerror (last_cherror);
}
