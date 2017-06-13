/* uname -- print system information

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

/* Written by David MacKenzie <djm@gnu.ai.mit.edu> */

#include <config.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/utsname.h>
#include <getopt.h>

#if HAVE_SYSINFO && HAVE_SYS_SYSTEMINFO_H
# include <sys/systeminfo.h>
#endif

#undef usage
#define usage uname_usage
static void uname_usage (int status);

#if HAVE_SYS_SYSCTL_H
# if HAVE_SYS_PARAM_H
#  include <sys/param.h> /* needed for OpenBSD 3.0 */
# endif
# include <sys/sysctl.h>
# ifdef HW_MODEL
#  ifdef HW_MACHINE_ARCH
/* E.g., FreeBSD 4.5, NetBSD 1.5.2 */
#   define UNAME_HARDWARE_PLATFORM HW_MODEL
#   define UNAME_PROCESSOR HW_MACHINE_ARCH
#  else
/* E.g., OpenBSD 3.0 */
#   define UNAME_PROCESSOR HW_MODEL
#  endif
# endif
#endif

#ifdef __APPLE__
# include <mach/machine.h>
# include <mach-o/arch.h>
#endif

#include "system.h"
#include "die.h"
#include "error.h"
#include "quote.h"
// #include "uname.h"
#include "uname-uname.c"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME (uname_mode == UNAME_UNAME ? "uname" : "arch")

#define AUTHORS proper_name ("David MacKenzie")
#define ARCH_AUTHORS "David MacKenzie", "Karel Zak"

/* Values that are bitwise or'd into 'toprint'. */
/* Kernel name. */
#define PRINT_KERNEL_NAME 1

/* Node name on a communications network. */
#define PRINT_NODENAME 2

/* Kernel release. */
#define PRINT_KERNEL_RELEASE 4

/* Kernel version. */
#define PRINT_KERNEL_VERSION 8

/* Machine hardware name. */
#define PRINT_MACHINE 16

/* Processor type. */
#define PRINT_PROCESSOR 32

/* Hardware platform.  */
#define PRINT_HARDWARE_PLATFORM 64

/* Operating system.  */
#define PRINT_OPERATING_SYSTEM 128

static struct option const uname_long_options[] =
{
  {"all", no_argument, NULL, 'a'},
  {"kernel-name", no_argument, NULL, 's'},
  {"sysname", no_argument, NULL, 's'},	/* Obsolescent.  */
  {"nodename", no_argument, NULL, 'n'},
  {"kernel-release", no_argument, NULL, 'r'},
  {"release", no_argument, NULL, 'r'},  /* Obsolescent.  */
  {"kernel-version", no_argument, NULL, 'v'},
  {"machine", no_argument, NULL, 'm'},
  {"processor", no_argument, NULL, 'p'},
  {"hardware-platform", no_argument, NULL, 'i'},
  {"operating-system", no_argument, NULL, 'o'},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

static struct option const arch_long_options[] =
{
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

void
uname_usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("Usage: %s [OPTION]...\n\r\r"), program_name);

      if (uname_mode == UNAME_UNAME)
        {
          fputs (_("\
Print certain system information.  With no OPTION, same as -s.\n\r\r\
\n\r\r\
  -a, --all                print all information, in the following order,\n\r\r\
                             except omit -p and -i if unknown:\n\r\r\
  -s, --kernel-name        print the kernel name\n\r\r\
  -n, --nodename           print the network node hostname\n\r\r\
  -r, --kernel-release     print the kernel release\n\r\r\
"), stdout);
          fputs (_("\
  -v, --kernel-version     print the kernel version\n\r\r\
  -m, --machine            print the machine hardware name\n\r\r\
  -p, --processor          print the processor type (non-portable)\n\r\r\
  -i, --hardware-platform  print the hardware platform (non-portable)\n\r\r\
  -o, --operating-system   print the operating system\n\r\r\
"), stdout);
        }
      else
        {
          fputs (_("\
Print machine architecture.\n\r\r\
\n\r\r\
"), stdout);
        }

      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  // exit (status);
}

/* Print ELEMENT, preceded by a space if something has already been
   printed.  */

static void
print_element (char const *element)
{
  static bool printed;
  if (printed)
    putchar (' ');
  printed = true;
  fputs (element, stdout);
}


/* Set all the option flags according to the switches specified.
   Return the mask indicating which elements to print.  */

static int
decode_switches (int argc, char **argv)
{
  int c;
  unsigned int toprint = 0;

  if (uname_mode == UNAME_ARCH)
    {
      while ((c = getopt_long (argc, argv, "",
                               arch_long_options, NULL)) != -1)
        {
          switch (c)
            {
            case_GETOPT_HELP_CHAR;

            case_GETOPT_VERSION_CHAR (PROGRAM_NAME, ARCH_AUTHORS);

            default:
              uname_usage (EXIT_FAILURE);
                    return -1;
            }
        }
      toprint = PRINT_MACHINE;
    }
  else
    {
      while ((c = getopt_long (argc, argv, "asnrvmpio",
                               uname_long_options, NULL)) != -1)
        {
          switch (c)
            {
            case 'a':
              toprint = UINT_MAX;
              break;

            case 's':
              toprint |= PRINT_KERNEL_NAME;
              break;

            case 'n':
              toprint |= PRINT_NODENAME;
              break;

            case 'r':
              toprint |= PRINT_KERNEL_RELEASE;
              break;

            case 'v':
              toprint |= PRINT_KERNEL_VERSION;
              break;

            case 'm':
              toprint |= PRINT_MACHINE;
              break;

            case 'p':
              toprint |= PRINT_PROCESSOR;
              break;

            case 'i':
              toprint |= PRINT_HARDWARE_PLATFORM;
              break;

            case 'o':
              toprint |= PRINT_OPERATING_SYSTEM;
              break;

            case_GETOPT_HELP_CHAR;

            case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

            default:
              uname_usage (EXIT_FAILURE);
              return -1;
            }
        }
    }

  if (argc != optind)
    {
      error (0, 0, _("extra operand %s"), quote (argv[optind]));
      uname_usage (EXIT_FAILURE);
      return -1;
    }

  return toprint;
}

int
uname_main (int argc, char **argv)
{
  static char const unknown[] = "unknown";

  /* Mask indicating which elements to print. */
  unsigned int toprint = 0;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  toprint = decode_switches (argc, argv);

  if (toprint == 0)
    toprint = PRINT_KERNEL_NAME;

  if (toprint
       & (PRINT_KERNEL_NAME | PRINT_NODENAME | PRINT_KERNEL_RELEASE
          | PRINT_KERNEL_VERSION | PRINT_MACHINE))
    {
      struct utsname name;

      if (uname (&name) == -1)
        die (EXIT_FAILURE, errno, _("cannot get system name"));

      if (toprint & PRINT_KERNEL_NAME)
        print_element (name.sysname);
      if (toprint & PRINT_NODENAME)
        print_element (name.nodename);
      if (toprint & PRINT_KERNEL_RELEASE)
        print_element (name.release);
      if (toprint & PRINT_KERNEL_VERSION)
        print_element (name.version);
      if (toprint & PRINT_MACHINE)
        print_element (name.machine);
    }

  if (toprint & PRINT_PROCESSOR)
    {
      char const *element = unknown;
#if HAVE_SYSINFO && defined SI_ARCHITECTURE
      {
        static char processor[257];
        if (0 <= sysinfo (SI_ARCHITECTURE, processor, sizeof processor))
          element = processor;
      }
#endif
#ifdef UNAME_PROCESSOR
      if (element == unknown)
        {
          static char processor[257];
          size_t s = sizeof processor;
          static int mib[] = { CTL_HW, UNAME_PROCESSOR };
          if (sysctl (mib, 2, processor, &s, 0, 0) >= 0)
            element = processor;

# ifdef __APPLE__
          /* This kludge works around a bug in Mac OS X.  */
          if (element == unknown)
            {
              cpu_type_t cputype;
              size_t cs = sizeof cputype;
              NXArchInfo const *ai;
              if (sysctlbyname ("hw.cputype", &cputype, &cs, NULL, 0) == 0
                  && (ai = NXGetArchInfoFromCpuType (cputype,
                                                     CPU_SUBTYPE_MULTIPLE))
                  != NULL)
                element = ai->name;

              /* Hack "safely" around the ppc vs. powerpc return value. */
              if (cputype == CPU_TYPE_POWERPC
                  && STRNCMP_LIT (element, "ppc") == 0)
                element = "powerpc";
            }
# endif
        }
#endif
      if (! (toprint == UINT_MAX && element == unknown))
        print_element (element);
    }

  if (toprint & PRINT_HARDWARE_PLATFORM)
    {
      char const *element = unknown;
#if HAVE_SYSINFO && defined SI_PLATFORM
      {
        static char hardware_platform[257];
        if (0 <= sysinfo (SI_PLATFORM,
                          hardware_platform, sizeof hardware_platform))
          element = hardware_platform;
      }
#endif
#ifdef UNAME_HARDWARE_PLATFORM
      if (element == unknown)
        {
          static char hardware_platform[257];
          size_t s = sizeof hardware_platform;
          static int mib[] = { CTL_HW, UNAME_HARDWARE_PLATFORM };
          if (sysctl (mib, 2, hardware_platform, &s, 0, 0) >= 0)
            element = hardware_platform;
        }
#endif
      if (! (toprint == UINT_MAX && element == unknown))
        print_element (element);
    }

  if (toprint & PRINT_OPERATING_SYSTEM)
    print_element (HOST_OPERATING_SYSTEM);

  putchar ('\n');
  putchar ('\r');

  return EXIT_SUCCESS;
}
