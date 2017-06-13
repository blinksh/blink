/* GNU's pinky.
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

/* Created by hacking who.c by Kaveh Ghazi ghazi@caip.rutgers.edu */

#include <config.h>
#include <getopt.h>
#include <pwd.h>
#include <stdio.h>

#include <sys/types.h>
#include "system.h"

#include "canon-host.h"
#include "die.h"
#include "error.h"
#include "hard-locale.h"
#include "readutmp.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "pinky"

#define AUTHORS \
  proper_name ("Joseph Arceneaux"), \
  proper_name ("David MacKenzie"), \
  proper_name ("Kaveh Ghazi")

/* If true, display the hours:minutes since each user has touched
   the keyboard, or blank if within the last minute, or days followed
   by a 'd' if not within the last day. */
static bool include_idle = true;

/* If true, display a line at the top describing each field. */
static bool include_heading = true;

/* if true, display the user's full name from pw_gecos. */
static bool include_fullname = true;

/* if true, display the user's ~/.project file when doing long format. */
static bool include_project = true;

/* if true, display the user's ~/.plan file when doing long format. */
static bool include_plan = true;

/* if true, display the user's home directory and shell
   when doing long format. */
static bool include_home_and_shell = true;

/* if true, use the "short" output format. */
static bool do_short_format = true;

/* if true, display the ut_host field. */
#ifdef HAVE_UT_HOST
static bool include_where = true;
#endif

/* The strftime format to use for login times, and its expected
   output width.  */
static char const *time_format;
static int time_format_width;

static struct option const longopts[] =
{
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

/* Count and return the number of ampersands in STR.  */

static size_t _GL_ATTRIBUTE_PURE
count_ampersands (const char *str)
{
  size_t count = 0;
  do
    {
      if (*str == '&')
        count++;
    } while (*str++);
  return count;
}

/* Create a string (via xmalloc) which contains a full name by substituting
   for each ampersand in GECOS_NAME the USER_NAME string with its first
   character capitalized.  The caller must ensure that GECOS_NAME contains
   no ','s.  The caller also is responsible for free'ing the return value of
   this function.  */

static char *
create_fullname (const char *gecos_name, const char *user_name)
{
  size_t rsize = strlen (gecos_name) + 1;
  char *result;
  char *r;
  size_t ampersands = count_ampersands (gecos_name);

  if (ampersands != 0)
    {
      size_t ulen = strlen (user_name);
      size_t product = ampersands * ulen;
      rsize += product - ampersands;
      if (xalloc_oversized (ulen, ampersands) || rsize < product)
        xalloc_die ();
    }

  r = result = xmalloc (rsize);

  while (*gecos_name)
    {
      if (*gecos_name == '&')
        {
          const char *uname = user_name;
          if (islower (to_uchar (*uname)))
            *r++ = toupper (to_uchar (*uname++));
          while (*uname)
            *r++ = *uname++;
        }
      else
        {
          *r++ = *gecos_name;
        }

      gecos_name++;
    }
  *r = 0;

  return result;
}

/* Return a string representing the time between WHEN and the time
   that this function is first run. */

static const char *
idle_string (time_t when)
{
  static time_t now = 0;
  static char buf[INT_STRLEN_BOUND (long int) + 2];
  time_t seconds_idle;

  if (now == 0)
    time (&now);

  seconds_idle = now - when;
  if (seconds_idle < 60)	/* One minute. */
    return "     ";
  if (seconds_idle < (24 * 60 * 60))	/* One day. */
    {
      int hours = seconds_idle / (60 * 60);
      int minutes = (seconds_idle % (60 * 60)) / 60;
      sprintf (buf, "%02d:%02d", hours, minutes);
    }
  else
    {
      unsigned long int days = seconds_idle / (24 * 60 * 60);
      sprintf (buf, "%lud", days);
    }
  return buf;
}

/* Return a time string.  */
static const char *
time_string (const STRUCT_UTMP *utmp_ent)
{
  static char buf[INT_STRLEN_BOUND (intmax_t) + sizeof "-%m-%d %H:%M"];

  /* Don't take the address of UT_TIME_MEMBER directly.
     Ulrich Drepper wrote:
     "... GNU libc (and perhaps other libcs as well) have extended
     utmp file formats which do not use a simple time_t ut_time field.
     In glibc, ut_time is a macro which selects for backward compatibility
     the tv_sec member of a struct timeval value."  */
  time_t t = UT_TIME_MEMBER (utmp_ent);
  struct tm *tmp = localtime (&t);

  if (tmp)
    {
      strftime (buf, sizeof buf, time_format, tmp);
      return buf;
    }
  else
    return timetostr (t, buf);
}

/* Display a line of information about UTMP_ENT. */

static void
print_entry (const STRUCT_UTMP *utmp_ent)
{
  struct stat stats;
  time_t last_change;
  char mesg;

#define DEV_DIR_WITH_TRAILING_SLASH "/dev/"
#define DEV_DIR_LEN (sizeof (DEV_DIR_WITH_TRAILING_SLASH) - 1)

  char line[sizeof (utmp_ent->ut_line) + DEV_DIR_LEN + 1];
  char *p = line;

  /* Copy ut_line into LINE, prepending '/dev/' if ut_line is not
     already an absolute file name.  Some system may put the full,
     absolute file name in ut_line.  */
  if ( ! IS_ABSOLUTE_FILE_NAME (utmp_ent->ut_line))
    p = stpcpy (p, DEV_DIR_WITH_TRAILING_SLASH);
  stzncpy (p, utmp_ent->ut_line, sizeof (utmp_ent->ut_line));

  if (stat (line, &stats) == 0)
    {
      mesg = (stats.st_mode & S_IWGRP) ? ' ' : '*';
      last_change = stats.st_atime;
    }
  else
    {
      mesg = '?';
      last_change = 0;
    }

  printf ("%-8.*s", UT_USER_SIZE, UT_USER (utmp_ent));

  if (include_fullname)
    {
      struct passwd *pw;
      char name[UT_USER_SIZE + 1];

      stzncpy (name, UT_USER (utmp_ent), UT_USER_SIZE);
      pw = getpwnam (name);
      if (pw == NULL)
        /* TRANSLATORS: Real name is unknown; at most 19 characters. */
        printf (" %19s", _("        ???"));
      else
        {
          char *const comma = strchr (pw->pw_gecos, ',');
          char *result;

          if (comma)
            *comma = '\0';

          result = create_fullname (pw->pw_gecos, pw->pw_name);
          printf (" %-19.19s", result);
          free (result);
        }
    }

  printf (" %c%-8.*s",
          mesg, (int) sizeof (utmp_ent->ut_line), utmp_ent->ut_line);

  if (include_idle)
    {
      if (last_change)
        printf (" %-6s", idle_string (last_change));
      else
        /* TRANSLATORS: Idle time is unknown; at most 5 characters. */
        printf (" %-6s", _("?????"));
    }

  printf (" %s", time_string (utmp_ent));

#ifdef HAVE_UT_HOST
  if (include_where && utmp_ent->ut_host[0])
    {
      char ut_host[sizeof (utmp_ent->ut_host) + 1];
      char *host = NULL;
      char *display = NULL;

      /* Copy the host name into UT_HOST, and ensure it's nul terminated. */
      stzncpy (ut_host, utmp_ent->ut_host, sizeof (utmp_ent->ut_host));

      /* Look for an X display.  */
      display = strchr (ut_host, ':');
      if (display)
        *display++ = '\0';

      if (*ut_host)
        /* See if we can canonicalize it.  */
        host = canon_host (ut_host);
      if ( ! host)
        host = ut_host;

      if (display)
        printf (" %s:%s", host, display);
      else
        printf (" %s", host);

      if (host != ut_host)
        free (host);
    }
#endif

  putchar ('\n');
}

/* Display a verbose line of information about UTMP_ENT. */

static void
print_long_entry (const char name[])
{
  struct passwd *pw;

  pw = getpwnam (name);

  printf (_("Login name: "));
  printf ("%-28s", name);

  printf (_("In real life: "));
  if (pw == NULL)
    {
      /* TRANSLATORS: Real name is unknown; no hard limit. */
      printf (" %s", _("???\n"));
      return;
    }
  else
    {
      char *const comma = strchr (pw->pw_gecos, ',');
      char *result;

      if (comma)
        *comma = '\0';

      result = create_fullname (pw->pw_gecos, pw->pw_name);
      printf (" %s", result);
      free (result);
    }

  putchar ('\n');

  if (include_home_and_shell)
    {
      printf (_("Directory: "));
      printf ("%-29s", pw->pw_dir);
      printf (_("Shell: "));
      printf (" %s", pw->pw_shell);
      putchar ('\n');
    }

  if (include_project)
    {
      FILE *stream;
      char buf[1024];
      const char *const baseproject = "/.project";
      char *const project =
        xmalloc (strlen (pw->pw_dir) + strlen (baseproject) + 1);
      stpcpy (stpcpy (project, pw->pw_dir), baseproject);

      stream = fopen (project, "r");
      if (stream)
        {
          size_t bytes;

          printf (_("Project: "));

          while ((bytes = fread (buf, 1, sizeof (buf), stream)) > 0)
            fwrite (buf, 1, bytes, stdout);
          fclose (stream);
        }

      free (project);
    }

  if (include_plan)
    {
      FILE *stream;
      char buf[1024];
      const char *const baseplan = "/.plan";
      char *const plan =
        xmalloc (strlen (pw->pw_dir) + strlen (baseplan) + 1);
      stpcpy (stpcpy (plan, pw->pw_dir), baseplan);

      stream = fopen (plan, "r");
      if (stream)
        {
          size_t bytes;

          printf (_("Plan:\n"));

          while ((bytes = fread (buf, 1, sizeof (buf), stream)) > 0)
            fwrite (buf, 1, bytes, stdout);
          fclose (stream);
        }

      free (plan);
    }

  putchar ('\n');
}

/* Print the username of each valid entry and the number of valid entries
   in UTMP_BUF, which should have N elements. */

static void
print_heading (void)
{
  printf ("%-8s", _("Login"));
  if (include_fullname)
    printf (" %-19s", _("Name"));
  printf (" %-9s", _(" TTY"));
  if (include_idle)
    printf (" %-6s", _("Idle"));
  printf (" %-*s", time_format_width, _("When"));
#ifdef HAVE_UT_HOST
  if (include_where)
    printf (" %s", _("Where"));
#endif
  putchar ('\n');
}

/* Display UTMP_BUF, which should have N entries. */

static void
scan_entries (size_t n, const STRUCT_UTMP *utmp_buf,
              const int argc_names, char *const argv_names[])
{
  if (hard_locale (LC_TIME))
    {
      time_format = "%Y-%m-%d %H:%M";
      time_format_width = 4 + 1 + 2 + 1 + 2 + 1 + 2 + 1 + 2;
    }
  else
    {
      time_format = "%b %e %H:%M";
      time_format_width = 3 + 1 + 2 + 1 + 2 + 1 + 2;
    }

  if (include_heading)
    print_heading ();

  while (n--)
    {
      if (IS_USER_PROCESS (utmp_buf))
        {
          if (argc_names)
            {
              int i;

              for (i = 0; i < argc_names; i++)
                if (STREQ_LEN (UT_USER (utmp_buf), argv_names[i], UT_USER_SIZE))
                  {
                    print_entry (utmp_buf);
                    break;
                  }
            }
          else
            print_entry (utmp_buf);
        }
      utmp_buf++;
    }
}

/* Display a list of who is on the system, according to utmp file FILENAME. */

static void
short_pinky (const char *filename,
             const int argc_names, char *const argv_names[])
{
  size_t n_users;
  STRUCT_UTMP *utmp_buf = NULL;

  if (read_utmp (filename, &n_users, &utmp_buf, 0) != 0)
    die (EXIT_FAILURE, errno, "%s", quotef (filename));

  scan_entries (n_users, utmp_buf, argc_names, argv_names);

  IF_LINT (free (utmp_buf));
}

static void
long_pinky (const int argc_names, char *const argv_names[])
{
  int i;

  for (i = 0; i < argc_names; i++)
    print_long_entry (argv_names[i]);
}

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("Usage: %s [OPTION]... [USER]...\n"), program_name);
      fputs (_("\
\n\
  -l              produce long format output for the specified USERs\n\
  -b              omit the user's home directory and shell in long format\n\
  -h              omit the user's project file in long format\n\
  -p              omit the user's plan file in long format\n\
  -s              do short format output, this is the default\n\
"), stdout);
      fputs (_("\
  -f              omit the line of column headings in short format\n\
  -w              omit the user's full name in short format\n\
  -i              omit the user's full name and remote host in short format\n\
  -q              omit the user's full name, remote host and idle time\n\
                  in short format\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      printf (_("\
\n\
A lightweight 'finger' program;  print user information.\n\
The utmp file will be %s.\n\
"), UTMP_FILE);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

int
main (int argc, char **argv)
{
  int optc;
  int n_users;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  while ((optc = getopt_long (argc, argv, "sfwiqbhlp", longopts, NULL)) != -1)
    {
      switch (optc)
        {
        case 's':
          do_short_format = true;
          break;

        case 'l':
          do_short_format = false;
          break;

        case 'f':
          include_heading = false;
          break;

        case 'w':
          include_fullname = false;
          break;

        case 'i':
          include_fullname = false;
#ifdef HAVE_UT_HOST
          include_where = false;
#endif
          break;

        case 'q':
          include_fullname = false;
#ifdef HAVE_UT_HOST
          include_where = false;
#endif
          include_idle = false;
          break;

        case 'h':
          include_project = false;
          break;

        case 'p':
          include_plan = false;
          break;

        case 'b':
          include_home_and_shell = false;
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          usage (EXIT_FAILURE);
        }
    }

  n_users = argc - optind;

  if (!do_short_format && n_users == 0)
    {
      error (0, 0, _("no username specified; at least one must be\
 specified when using -l"));
      usage (EXIT_FAILURE);
    }

  if (do_short_format)
    short_pinky (UTMP_FILE, n_users, argv + optind);
  else
    long_pinky (n_users, argv + optind);

  return EXIT_SUCCESS;
}
