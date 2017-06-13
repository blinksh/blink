/* GNU's uptime.
   Copyright (C) 1992-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Created by hacking who.c by Kaveh Ghazi ghazi@caip.rutgers.edu.  */

#include <config.h>
#include <getopt.h>
#include <stdio.h>

#include <sys/types.h>
#include "system.h"

#if HAVE_SYSCTL && HAVE_SYS_SYSCTL_H
# include <sys/sysctl.h>
#endif

#if HAVE_OS_H
# include <OS.h>
#endif

#include "c-strtod.h"
#include "die.h"
#include "error.h"
#include "long-options.h"
#include "quote.h"
#include "readutmp.h"
#include "fprintftime.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "uptime"

#define AUTHORS \
  proper_name ("Joseph Arceneaux"), \
  proper_name ("David MacKenzie"), \
  proper_name ("Kaveh Ghazi")

static void
print_uptime (size_t n, const STRUCT_UTMP *this)
{
  size_t entries = 0;
  time_t boot_time = 0;
  time_t time_now;
  time_t uptime = 0;
  long int updays;
  int uphours;
  int upmins;
  struct tm *tmn;
  double avg[3];
  int loads;
#ifdef HAVE_PROC_UPTIME
  FILE *fp;

  fp = fopen ("/proc/uptime", "r");
  if (fp != NULL)
    {
      char buf[BUFSIZ];
      char *b = fgets (buf, BUFSIZ, fp);
      if (b == buf)
        {
          char *end_ptr;
          double upsecs = c_strtod (buf, &end_ptr);
          if (buf != end_ptr)
            uptime = (0 <= upsecs && upsecs < TYPE_MAXIMUM (time_t)
                      ? upsecs : -1);
        }

      fclose (fp);
    }
#endif /* HAVE_PROC_UPTIME */

#if HAVE_SYSCTL && defined CTL_KERN && defined KERN_BOOTTIME
  {
    /* FreeBSD specific: fetch sysctl "kern.boottime".  */
    static int request[2] = { CTL_KERN, KERN_BOOTTIME };
    struct timeval result;
    size_t result_len = sizeof result;

    if (sysctl (request, 2, &result, &result_len, NULL, 0) >= 0)
      boot_time = result.tv_sec;
  }
#endif

#if HAVE_OS_H /* BeOS */
  {
    system_info si;

    get_system_info (&si);
    boot_time = si.boot_time / 1000000;
  }
#endif

#if HAVE_UTMPX_H || HAVE_UTMP_H
  /* Loop through all the utmp entries we just read and count up the valid
     ones, also in the process possibly gleaning boottime. */
  while (n--)
    {
      entries += IS_USER_PROCESS (this);
      if (UT_TYPE_BOOT_TIME (this))
        boot_time = UT_TIME_MEMBER (this);
      ++this;
    }
#else
  (void) n;
  (void) this;
#endif

  time_now = time (NULL);
#if defined HAVE_PROC_UPTIME
  if (uptime == 0)
#endif
    {
      if (boot_time == 0)
        die (EXIT_FAILURE, errno, _("couldn't get boot time"));
      uptime = time_now - boot_time;
    }
  updays = uptime / 86400;
  uphours = (uptime - (updays * 86400)) / 3600;
  upmins = (uptime - (updays * 86400) - (uphours * 3600)) / 60;
  tmn = localtime (&time_now);
  /* procps' version of uptime also prints the seconds field, but
     previous versions of coreutils don't. */
  if (tmn)
    /* TRANSLATORS: This prints the current clock time. */
    fprintftime (stdout, _(" %H:%M%P  "), tmn, 0, 0);
  else
    printf (_(" ??:????  "));
  if (uptime == (time_t) -1)
    printf (_("up ???? days ??:??,  "));
  else
    {
      if (0 < updays)
        printf (ngettext ("up %ld day %2d:%02d,  ",
                          "up %ld days %2d:%02d,  ",
                          select_plural (updays)),
                updays, uphours, upmins);
      else
        printf (_("up  %2d:%02d,  "), uphours, upmins);
    }
  printf (ngettext ("%lu user", "%lu users", select_plural (entries)),
          (unsigned long int) entries);

  loads = getloadavg (avg, 3);

  if (loads == -1)
    putchar ('\n');
  else
    {
      if (loads > 0)
        printf (_(",  load average: %.2f"), avg[0]);
      if (loads > 1)
        printf (", %.2f", avg[1]);
      if (loads > 2)
        printf (", %.2f", avg[2]);
      if (loads > 0)
        putchar ('\n');
    }
}

/* Display the system uptime and the number of users on the system,
   according to utmp file FILENAME.  Use read_utmp OPTIONS to read the
   utmp file.  */

static void
uptime (const char *filename, int options)
{
  size_t n_users;
  STRUCT_UTMP *utmp_buf = NULL;

#if HAVE_UTMPX_H || HAVE_UTMP_H
  if (read_utmp (filename, &n_users, &utmp_buf, options) != 0)
    die (EXIT_FAILURE, errno, "%s", quotef (filename));
#endif

  print_uptime (n_users, utmp_buf);

  IF_LINT (free (utmp_buf));
}

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("Usage: %s [OPTION]... [FILE]\n"), program_name);
      printf (_("\
Print the current time, the length of time the system has been up,\n\
the number of users on the system, and the average number of jobs\n\
in the run queue over the last 1, 5 and 15 minutes."));
#ifdef __linux__
      /* It would be better to introduce a configure test for this,
         but such a test is hard to write.  For the moment then, we
         have a hack which depends on the preprocessor used at compile
         time to tell us what the running kernel is.  Ugh.  */
      printf (_("  \
Processes in\n\
an uninterruptible sleep state also contribute to the load average.\n"));
#else
      printf (_("\n"));
#endif
      printf (_("\
If FILE is not specified, use %s.  %s as FILE is common.\n\
\n"),
              UTMP_FILE, WTMP_FILE);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

int
main (int argc, char **argv)
{
  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  parse_long_options (argc, argv, PROGRAM_NAME, PACKAGE_NAME, Version,
                      usage, AUTHORS, (char const *) NULL);
  if (getopt_long (argc, argv, "", NULL, NULL) != -1)
    usage (EXIT_FAILURE);

  switch (argc - optind)
    {
    case 0:			/* uptime */
      uptime (UTMP_FILE, READ_UTMP_CHECK_PIDS);
      break;

    case 1:			/* uptime <utmp file> */
      uptime (argv[optind], 0);
      break;

    default:			/* lose */
      error (0, 0, _("extra operand %s"), quote (argv[optind + 1]));
      usage (EXIT_FAILURE);
    }

  return EXIT_SUCCESS;
}
