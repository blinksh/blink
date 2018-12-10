/*-
 * See the file LICENSE for redistribution information.
 *
 * Copyright (c) 1996,2008 Oracle.  All rights reserved.
 */
/*
 * Copyright (c) 1987, 1993, 1994
 *    The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $Id: getopt.c,v 12.8 2008/03/12 17:50:25 mbrey Exp $
 */

// #include "db_config.h"
#include "bk_getopts.h"
// #include "db_int.h"
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "ios_error.h"

__thread int    __db_getopt_reset;    /* global reset for VxWorks. */

// Not __thread unless I rename them.
// Try with thread
__thread int    thread_opterr = 1,        /* if error message should be printed */
 thread_optind = 1,        /* index into parent argv vector */
 thread_optopt,            /* character checked for validity */
 thread_optreset;        /* reset getopt */
__thread char    * thread_optarg;        /* argument associated with option */

#undef    BADCH
#define    BADCH    (int)'?'
#undef    BADARG
#define    BADARG    (int)':'
#undef    EMSG
#define    EMSG    ""

/*
 * getopt --
 *    Parse argc/argv argument vector.
 *
 * PUBLIC: #ifndef HAVE_GETOPT
 * PUBLIC: int getopt __P((int, char * const *, const char *));
 * PUBLIC: #endif
 */
int
thread_getopt(
int nargc,
char * const *nargv,
const char *ostr) {
  static char *progname;
  static char *place = EMSG;        /* option letter processing */
  char *oli;                /* option letter list index */
  
  /*
   * VxWorks needs to be able to repeatedly call getopt from multiple
   * programs within its global name space. And so does iOS.
   */
  if (__db_getopt_reset) {
    __db_getopt_reset = 0;
    
    thread_opterr = thread_optind = 1;
    thread_optopt = thread_optreset = 0;
    thread_optarg = NULL;
    progname = NULL;
    place = EMSG;
  }
  if (!progname) {
    // if ((progname = __db_rpath(*nargv)) == NULL)
    progname = *nargv;
    // else
    //    ++progname;
  }
  
  if (thread_optreset || !*place) {        /* update scanning pointer */
    thread_optreset = 0;
    if (thread_optind >= nargc || *(place = nargv[thread_optind]) != '-') {
      place = EMSG;
      return (EOF);
    }
    if (place[1] && *++place == '-') {    /* found "--" */
      ++thread_optind;
      place = EMSG;
      return (EOF);
    }
  }                    /* option letter okay? */
  if ((thread_optopt = (int)*place++) == (int)':' ||
      !(oli = strchr(ostr, thread_optopt))) {
    /*
     * if the user didn't specify '-' as an option,
     * assume it means EOF.
     */
    if (thread_optopt == (int)'-')
      return (EOF);
    if (!*place)
      ++thread_optind;
    if (thread_opterr && *ostr != ':')
      (void)fprintf(thread_stderr,
                    "%s: illegal option -- %c\n", progname, thread_optopt);
    return (BADCH);
  }
  if (*++oli != ':') {            /* don't need argument */
    thread_optarg = NULL;
    if (!*place)
      ++thread_optind;
  }
  else {                    /* need an argument */
    if (*place)            /* no white space */
      thread_optarg = place;
    else if (nargc <= ++thread_optind) {    /* no arg */
      place = EMSG;
      if (*ostr == ':')
        return (BADARG);
      if (thread_opterr)
        (void)fprintf(thread_stderr,
                      "%s: option requires an argument -- %c\n",
                      progname, thread_optopt);
      return (BADCH);
    }
    else                /* white space */
      thread_optarg = nargv[thread_optind];
    place = EMSG;
    ++thread_optind;
  }
  return (thread_optopt);            /* dump back option letter */
}
