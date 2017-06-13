/* sig2str.c -- convert between signal names and numbers

   Copyright (C) 2002, 2004, 2006, 2009-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Written by Paul Eggert.  */

#include "config.h"

#include <limits.h>
#include <signal.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "sig2str.h"

#ifndef SIGRTMIN
# define SIGRTMIN 0
# undef SIGRTMAX
#endif
#ifndef SIGRTMAX
# define SIGRTMAX (SIGRTMIN - 1)
#endif

#define NUMNAME(name) { SIG##name, #name }

/* Signal names and numbers.  Put the preferred name first.  */
static struct numname { int num; char const name[8]; } numname_table[] =
  {
    /* Signals required by POSIX 1003.1-2001 base, listed in
       traditional numeric order where possible.  */
#ifdef SIGHUP
    NUMNAME (HUP),
#endif
#ifdef SIGINT
    NUMNAME (INT),
#endif
#ifdef SIGQUIT
    NUMNAME (QUIT),
#endif
#ifdef SIGILL
    NUMNAME (ILL),
#endif
#ifdef SIGTRAP
    NUMNAME (TRAP),
#endif
#ifdef SIGABRT
    NUMNAME (ABRT),
#endif
#ifdef SIGFPE
    NUMNAME (FPE),
#endif
#ifdef SIGKILL
    NUMNAME (KILL),
#endif
#ifdef SIGSEGV
    NUMNAME (SEGV),
#endif
    /* On Haiku, SIGSEGV == SIGBUS, but we prefer SIGSEGV to match
       strsignal.c output, so SIGBUS must be listed second.  */
#ifdef SIGBUS
    NUMNAME (BUS),
#endif
#ifdef SIGPIPE
    NUMNAME (PIPE),
#endif
#ifdef SIGALRM
    NUMNAME (ALRM),
#endif
#ifdef SIGTERM
    NUMNAME (TERM),
#endif
#ifdef SIGUSR1
    NUMNAME (USR1),
#endif
#ifdef SIGUSR2
    NUMNAME (USR2),
#endif
#ifdef SIGCHLD
    NUMNAME (CHLD),
#endif
#ifdef SIGURG
    NUMNAME (URG),
#endif
#ifdef SIGSTOP
    NUMNAME (STOP),
#endif
#ifdef SIGTSTP
    NUMNAME (TSTP),
#endif
#ifdef SIGCONT
    NUMNAME (CONT),
#endif
#ifdef SIGTTIN
    NUMNAME (TTIN),
#endif
#ifdef SIGTTOU
    NUMNAME (TTOU),
#endif

    /* Signals required by POSIX 1003.1-2001 with the XSI extension.  */
#ifdef SIGSYS
    NUMNAME (SYS),
#endif
#ifdef SIGPOLL
    NUMNAME (POLL),
#endif
#ifdef SIGVTALRM
    NUMNAME (VTALRM),
#endif
#ifdef SIGPROF
    NUMNAME (PROF),
#endif
#ifdef SIGXCPU
    NUMNAME (XCPU),
#endif
#ifdef SIGXFSZ
    NUMNAME (XFSZ),
#endif

    /* Unix Version 7.  */
#ifdef SIGIOT
    NUMNAME (IOT),      /* Older name for ABRT.  */
#endif
#ifdef SIGEMT
    NUMNAME (EMT),
#endif

    /* USG Unix.  */
#ifdef SIGPHONE
    NUMNAME (PHONE),
#endif
#ifdef SIGWIND
    NUMNAME (WIND),
#endif

    /* Unix System V.  */
#ifdef SIGCLD
    NUMNAME (CLD),
#endif
#ifdef SIGPWR
    NUMNAME (PWR),
#endif

    /* GNU/Linux 2.2 and Solaris 8.  */
#ifdef SIGCANCEL
    NUMNAME (CANCEL),
#endif
#ifdef SIGLWP
    NUMNAME (LWP),
#endif
#ifdef SIGWAITING
    NUMNAME (WAITING),
#endif
#ifdef SIGFREEZE
    NUMNAME (FREEZE),
#endif
#ifdef SIGTHAW
    NUMNAME (THAW),
#endif
#ifdef SIGLOST
    NUMNAME (LOST),
#endif
#ifdef SIGWINCH
    NUMNAME (WINCH),
#endif

    /* GNU/Linux 2.2.  */
#ifdef SIGINFO
    NUMNAME (INFO),
#endif
#ifdef SIGIO
    NUMNAME (IO),
#endif
#ifdef SIGSTKFLT
    NUMNAME (STKFLT),
#endif

    /* AIX 5L.  */
#ifdef SIGDANGER
    NUMNAME (DANGER),
#endif
#ifdef SIGGRANT
    NUMNAME (GRANT),
#endif
#ifdef SIGMIGRATE
    NUMNAME (MIGRATE),
#endif
#ifdef SIGMSG
    NUMNAME (MSG),
#endif
#ifdef SIGPRE
    NUMNAME (PRE),
#endif
#ifdef SIGRETRACT
    NUMNAME (RETRACT),
#endif
#ifdef SIGSAK
    NUMNAME (SAK),
#endif
#ifdef SIGSOUND
    NUMNAME (SOUND),
#endif

    /* Older AIX versions.  */
#ifdef SIGALRM1
    NUMNAME (ALRM1),    /* unknown; taken from Bash 2.05 */
#endif
#ifdef SIGKAP
    NUMNAME (KAP),      /* Older name for SIGGRANT.  */
#endif
#ifdef SIGVIRT
    NUMNAME (VIRT),     /* unknown; taken from Bash 2.05 */
#endif
#ifdef SIGWINDOW
    NUMNAME (WINDOW),   /* Older name for SIGWINCH.  */
#endif

    /* BeOS */
#ifdef SIGKILLTHR
    NUMNAME (KILLTHR),
#endif

    /* Older HP-UX versions.  */
#ifdef SIGDIL
    NUMNAME (DIL),
#endif

    /* Korn shell and Bash, of uncertain vintage.  */
    { 0, "EXIT" }
  };

#define NUMNAME_ENTRIES (sizeof numname_table / sizeof numname_table[0])

/* ISDIGIT differs from isdigit, as follows:
   - Its arg may be any int or unsigned int; it need not be an unsigned char
     or EOF.
   - It's typically faster.
   POSIX says that only '0' through '9' are digits.  Prefer ISDIGIT to
   isdigit unless it's important to use the locale's definition
   of "digit" even when the host does not conform to POSIX.  */
#define ISDIGIT(c) ((unsigned int) (c) - '0' <= 9)

/* Convert the signal name SIGNAME to a signal number.  Return the
   signal number if successful, -1 otherwise.  */

static int
str2signum (char const *signame)
{
  if (ISDIGIT (*signame))
    {
      char *endp;
      long int n = strtol (signame, &endp, 10);
      if (! *endp && n <= SIGNUM_BOUND)
        return n;
    }
  else
    {
      unsigned int i;
      for (i = 0; i < NUMNAME_ENTRIES; i++)
        if (strcmp (numname_table[i].name, signame) == 0)
          return numname_table[i].num;

      {
        char *endp;
        int rtmin = SIGRTMIN;
        int rtmax = SIGRTMAX;

        if (0 < rtmin && strncmp (signame, "RTMIN", 5) == 0)
          {
            long int n = strtol (signame + 5, &endp, 10);
            if (! *endp && 0 <= n && n <= rtmax - rtmin)
              return rtmin + n;
          }
        else if (0 < rtmax && strncmp (signame, "RTMAX", 5) == 0)
          {
            long int n = strtol (signame + 5, &endp, 10);
            if (! *endp && rtmin - rtmax <= n && n <= 0)
              return rtmax + n;
          }
      }
    }

  return -1;
}

/* Convert the signal name SIGNAME to the signal number *SIGNUM.
   Return 0 if successful, -1 otherwise.  */

int
str2sig (char const *signame, int *signum)
{
  *signum = str2signum (signame);
  return *signum < 0 ? -1 : 0;
}

/* Convert SIGNUM to a signal name in SIGNAME.  SIGNAME must point to
   a buffer of at least SIG2STR_MAX bytes.  Return 0 if successful, -1
   otherwise.  */

int
sig2str (int signum, char *signame)
{
  unsigned int i;
  for (i = 0; i < NUMNAME_ENTRIES; i++)
    if (numname_table[i].num == signum)
      {
        strcpy (signame, numname_table[i].name);
        return 0;
      }

  {
    int rtmin = SIGRTMIN;
    int rtmax = SIGRTMAX;
    int base, delta;

    if (! (rtmin <= signum && signum <= rtmax))
      return -1;

    if (signum <= rtmin + (rtmax - rtmin) / 2)
      {
        strcpy (signame, "RTMIN");
        base = rtmin;
      }
    else
      {
        strcpy (signame, "RTMAX");
        base = rtmax;
      }

    delta = signum - base;
    if (delta != 0)
      sprintf (signame + 5, "%+d", delta);
    return 0;
  }
}
