/* id -- print real and effective UIDs and GIDs
   Copyright (C) 1989-2017 Free Software Foundation, Inc.

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

/* Written by Arnold Robbins.
   Major rewrite by David MacKenzie, djm@gnu.ai.mit.edu. */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include <pwd.h>
#include <grp.h>
#include <getopt.h>
#include <selinux/selinux.h>

#include "system.h"
#include "die.h"
#include "error.h"
#include "mgetgroups.h"
#include "quote.h"
#include "group-list.h"
#include "smack.h"
#include "userspec.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "id"

#undef usage
#define usage id_usage
static void id_usage (int status);

#define AUTHORS \
  proper_name ("Arnold Robbins"), \
  proper_name ("David MacKenzie")

/* If nonzero, output only the SELinux context.  */
static bool just_context = 0;

static void print_user (uid_t uid);
static void print_full_info (const char *username);

/* If true, output user/group name instead of ID number. -n */
static bool use_name = false;

/* The real and effective IDs of the user to print. */
static uid_t ruid, euid;
static gid_t rgid, egid;

/* True unless errors have been encountered.  */
static bool ok = true;

/* The SELinux context.  Start with a known invalid value so print_full_info
   knows when 'context' has not been set to a meaningful value.  */
static char *context = NULL;

static struct option const longopts[] =
{
  {"context", no_argument, NULL, 'Z'},
  {"group", no_argument, NULL, 'g'},
  {"groups", no_argument, NULL, 'G'},
  {"name", no_argument, NULL, 'n'},
  {"real", no_argument, NULL, 'r'},
  {"user", no_argument, NULL, 'u'},
  {"zero", no_argument, NULL, 'z'},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

void
id_usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("Usage: %s [OPTION]... [USER]\n\r"), program_name);
      fputs (_("\
Print user and group information for the specified USER,\n\r\
or (when USER omitted) for the current user.\n\r\
\n\r"),
             stdout);
      fputs (_("\
  -a             ignore, for compatibility with other versions\n\r\
  -Z, --context  print only the security context of the process\n\r\
  -g, --group    print only the effective group ID\n\r\
  -G, --groups   print all group IDs\n\r\
  -n, --name     print a name instead of a number, for -ugG\n\r\
  -r, --real     print the real ID instead of the effective ID, with -ugG\n\r\
  -u, --user     print only the effective user ID\n\r\
  -z, --zero     delimit entries with NUL characters, not whitespace;\n\r\
                   not permitted in default format\n\r\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\r\
Without any OPTION, print some useful set of identified information.\n\r\
"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  // exit (status);
}

int
id_main (int argc, char **argv)
{
  int optc;
  int selinux_enabled = (is_selinux_enabled () > 0);
  bool smack_enabled = is_smack_enabled ();
  bool opt_zero = false;
  char *pw_name = NULL;

  /* If true, output the list of all group IDs. -G */
  bool just_group_list = false;
  /* If true, output only the group ID(s). -g */
  bool just_group = false;
  /* If true, output real UID/GID instead of default effective UID/GID. -r */
  bool use_real = false;
  /* If true, output only the user ID(s). -u */
  bool just_user = false;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  while ((optc = getopt_long (argc, argv, "agnruzGZ", longopts, NULL)) != -1)
    {
      switch (optc)
        {
        case 'a':
          /* Ignore -a, for compatibility with SVR4.  */
          break;

        case 'Z':
          /* politely decline if we're not on a SELinux/SMACK-enabled kernel. */
#ifdef HAVE_SMACK
          if (!selinux_enabled && !smack_enabled)
            die (EXIT_FAILURE, 0,
                 _("--context (-Z) works only on "
                   "an SELinux/SMACK-enabled kernel"));
#else
          if (!selinux_enabled)
            die (EXIT_FAILURE, 0,
                 _("--context (-Z) works only on an SELinux-enabled kernel"));
#endif
          just_context = true;
          break;

        case 'g':
          just_group = true;
          break;
        case 'n':
          use_name = true;
          break;
        case 'r':
          use_real = true;
          break;
        case 'u':
          just_user = true;
          break;
        case 'z':
          opt_zero = true;
          break;
        case 'G':
          just_group_list = true;
          break;
        case_GETOPT_HELP_CHAR;
                return EXIT_SUCCESS;
        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);
                return EXIT_SUCCESS;
        default:
          usage (EXIT_FAILURE);
                return EXIT_FAILURE;
        }
    }

  size_t n_ids = argc - optind;
  if (1 < n_ids)
    {
      error (0, 0, _("extra operand %s"), quote (argv[optind + 1]));
      usage (EXIT_FAILURE);
    }

  if (n_ids && just_context)
    die (EXIT_FAILURE, 0,
         _("cannot print security context when user specified"));

  if (just_user + just_group + just_group_list + just_context > 1)
    die (EXIT_FAILURE, 0, _("cannot print \"only\" of more than one choice"));

  bool default_format = ! (just_user
                           || just_group
                           || just_group_list
                           || just_context);

  if (default_format && (use_real || use_name))
    die (EXIT_FAILURE, 0,
         _("cannot print only names or real IDs in default format"));

  if (default_format && opt_zero)
    die (EXIT_FAILURE, 0,
         _("option --zero not permitted in default format"));

  /* If we are on a SELinux/SMACK-enabled kernel, no user is specified, and
     either --context is specified or none of (-u,-g,-G) is specified,
     and we're not in POSIXLY_CORRECT mode, get our context.  Otherwise,
     leave the context variable alone - it has been initialized to an
     invalid value that will be not displayed in print_full_info().  */
  if (n_ids == 0
      && (just_context
          || (default_format && ! getenv ("POSIXLY_CORRECT"))))
    {
      /* Report failure only if --context (-Z) was explicitly requested.  */
      if ((selinux_enabled && getcon (&context) && just_context)
          || (smack_enabled
              && smack_new_label_from_self (&context) < 0
              && just_context))
        die (EXIT_FAILURE, 0, _("can't get process context"));
    }

  if (n_ids == 1)
    {
      struct passwd *pwd = NULL;
      const char *spec = argv[optind];
      /* Disallow an empty spec here as parse_user_spec() doesn't
         give an error for that as it seems it's a valid way to
         specify a noop or "reset special bits" depending on the system.  */
      if (*spec)
        {
          if (parse_user_spec (spec, &euid, NULL, NULL, NULL) == NULL)
            {
              /* parse_user_spec will only extract a numeric spec,
                 so we lookup that here to verify and also retrieve
                 the PW_NAME used subsequently in group lookup.  */
              pwd = getpwuid (euid);
            }
        }
      if (pwd == NULL)
        die (EXIT_FAILURE, 0, _("%s: no such user"), quote (spec));
      pw_name = xstrdup (pwd->pw_name);
      ruid = euid = pwd->pw_uid;
      rgid = egid = pwd->pw_gid;
    }
  else
    {
      /* POSIX says identification functions (getuid, getgid, and
         others) cannot fail, but they can fail under GNU/Hurd and a
         few other systems.  Test for failure by checking errno.  */
      uid_t NO_UID = -1;
      gid_t NO_GID = -1;

      if (just_user ? !use_real
          : !just_group && !just_group_list && !just_context)
        {
          errno = 0;
          euid = geteuid ();
          if (euid == NO_UID && errno)
            die (EXIT_FAILURE, errno, _("cannot get effective UID"));
        }

      if (just_user ? use_real
          : !just_group && (just_group_list || !just_context))
        {
          errno = 0;
          ruid = getuid ();
          if (ruid == NO_UID && errno)
            die (EXIT_FAILURE, errno, _("cannot get real UID"));
        }

      if (!just_user && (just_group || just_group_list || !just_context))
        {
          errno = 0;
          egid = getegid ();
          if (egid == NO_GID && errno)
            die (EXIT_FAILURE, errno, _("cannot get effective GID"));

          errno = 0;
          rgid = getgid ();
          if (rgid == NO_GID && errno)
            die (EXIT_FAILURE, errno, _("cannot get real GID"));
        }
    }

  if (just_user)
    {
      print_user (use_real ? ruid : euid);
    }
  else if (just_group)
    {
      if (!print_group (use_real ? rgid : egid, use_name))
        ok = false;
    }
  else if (just_group_list)
    {
      if (!print_group_list (pw_name, ruid, rgid, egid, use_name,
                             opt_zero ? '\0' : ' '))
        ok = false;
    }
  else if (just_context)
    {
      fputs (context, stdout);
    }
  else
    {
      print_full_info (pw_name);
    }
  putchar (opt_zero ? '\0' : '\n');
  putchar (opt_zero ? '\0' : '\r');

  IF_LINT (free (pw_name));
  return ok ? EXIT_SUCCESS : EXIT_FAILURE;
}

/* Convert a gid_t to string.  Do not use this function directly.
   Instead, use it via the gidtostr macro.
   Beware that it returns a pointer to static storage.  */
static char *
gidtostr_ptr (gid_t const *gid)
{
  static char buf[INT_BUFSIZE_BOUND (uintmax_t)];
  return umaxtostr (*gid, buf);
}
#define gidtostr(g) gidtostr_ptr (&(g))

/* Convert a uid_t to string.  Do not use this function directly.
   Instead, use it via the uidtostr macro.
   Beware that it returns a pointer to static storage.  */
static char *
uidtostr_ptr (uid_t const *uid)
{
  static char buf[INT_BUFSIZE_BOUND (uintmax_t)];
  return umaxtostr (*uid, buf);
}
#define uidtostr(u) uidtostr_ptr (&(u))

/* Print the name or value of user ID UID. */

static void
print_user (uid_t uid)
{
  struct passwd *pwd = NULL;

  if (use_name)
    {
      pwd = getpwuid (uid);
      if (pwd == NULL)
        {
          error (0, 0, _("cannot find name for user ID %s"),
                 uidtostr (uid));
          ok = false;
        }
    }

  char *s = pwd ? pwd->pw_name : uidtostr (uid);
  fputs (s, stdout);
}

/* Print all of the info about the user's user and group IDs. */

static void
print_full_info (const char *username)
{
  struct passwd *pwd;
  struct group *grp;

  printf (_("uid=%s"), uidtostr (ruid));
  pwd = getpwuid (ruid);
  if (pwd)
    printf ("(%s)", pwd->pw_name);

  printf (_(" gid=%s"), gidtostr (rgid));
  grp = getgrgid (rgid);
  if (grp)
    printf ("(%s)", grp->gr_name);

  if (euid != ruid)
    {
      printf (_(" euid=%s"), uidtostr (euid));
      pwd = getpwuid (euid);
      if (pwd)
        printf ("(%s)", pwd->pw_name);
    }

  if (egid != rgid)
    {
      printf (_(" egid=%s"), gidtostr (egid));
      grp = getgrgid (egid);
      if (grp)
        printf ("(%s)", grp->gr_name);
    }

  {
    gid_t *groups;
    int i;

    gid_t primary_group;
    if (username)
      primary_group = pwd ? pwd->pw_gid : -1;
    else
      primary_group = egid;

    int n_groups = xgetgroups (username, primary_group, &groups);
    if (n_groups < 0)
      {
        if (username)
          error (0, errno, _("failed to get groups for user %s"),
                 quote (username));
        else
          error (0, errno, _("failed to get groups for the current process"));
        ok = false;
        return;
      }

    if (n_groups > 0)
      fputs (_(" groups="), stdout);
    for (i = 0; i < n_groups; i++)
      {
        if (i > 0)
          putchar (',');
        fputs (gidtostr (groups[i]), stdout);
        grp = getgrgid (groups[i]);
        if (grp)
          printf ("(%s)", grp->gr_name);
      }
    free (groups);
  }

  /* POSIX mandates the precise output format, and that it not include
     any context=... part, so skip that if POSIXLY_CORRECT is set.  */
  if (context)
    printf (_(" context=%s"), context);
}
