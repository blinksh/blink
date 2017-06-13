/* uname replacement.
   Copyright (C) 2009-2017 Free Software Foundation, Inc.

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

#include <config.h>

/* Specification.  */
#include <sys/utsname.h>

/* This file provides an implementation only for the native Windows API.  */
#if (defined _WIN32 || defined __WIN32__) && ! defined __CYGWIN__

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <windows.h>

/* Mingw headers don't have all the platform codes.  */
#ifndef VER_PLATFORM_WIN32_CE
# define VER_PLATFORM_WIN32_CE 3
#endif

/* Some headers don't have all the processor architecture codes.  */
#ifndef PROCESSOR_ARCHITECTURE_AMD64
# define PROCESSOR_ARCHITECTURE_AMD64 9
#endif
#ifndef PROCESSOR_ARCHITECTURE_IA32_ON_WIN64
# define PROCESSOR_ARCHITECTURE_IA32_ON_WIN64 10
#endif

/* Mingw headers don't have the latest processor codes.  */
#ifndef PROCESSOR_AMD_X8664
# define PROCESSOR_AMD_X8664 8664
#endif

int
uname (struct utsname *buf)
{
  OSVERSIONINFO version;
  OSVERSIONINFOEX versionex;
  BOOL have_versionex; /* indicates whether versionex is filled */
  const char *super_version;

  /* Preparation: Fill version and, if possible, also versionex.
     But try to call GetVersionEx only once in the common case.  */
  versionex.dwOSVersionInfoSize = sizeof (OSVERSIONINFOEX);
  have_versionex = GetVersionEx ((OSVERSIONINFO *) &versionex);
  if (have_versionex)
    {
      /* We know that OSVERSIONINFO is a subset of OSVERSIONINFOEX.  */
      memcpy (&version, &versionex, sizeof (OSVERSIONINFO));
    }
  else
    {
      version.dwOSVersionInfoSize = sizeof (OSVERSIONINFO);
      if (!GetVersionEx (&version))
        abort ();
    }

  /* Fill in nodename.  */
  if (gethostname (buf->nodename, sizeof (buf->nodename)) < 0)
    strcpy (buf->nodename, "localhost");

  /* Determine major-major Windows version.  */
  if (version.dwPlatformId == VER_PLATFORM_WIN32_NT)
    {
      /* Windows NT or newer.  */
      super_version = "NT";
    }
  else if (version.dwPlatformId == VER_PLATFORM_WIN32_CE)
    {
      /* Windows CE or Embedded CE.  */
      super_version = "CE";
    }
  else if (version.dwPlatformId == VER_PLATFORM_WIN32_WINDOWS)
    {
      /* Windows 95/98/ME.  */
      switch (version.dwMinorVersion)
        {
        case 0:
          super_version = "95";
          break;
        case 10:
          super_version = "98";
          break;
        case 90:
          super_version = "ME";
          break;
        default:
          super_version = "";
          break;
        }
    }
  else
    super_version = "";

  /* Fill in sysname.  */
#ifdef __MINGW32__
  /* Returns a string compatible with the MSYS uname.exe program,
     so that no further changes are needed to GNU config.guess.
     For example,
       $ ./uname.exe -s      => MINGW32_NT-5.1
   */
  sprintf (buf->sysname, "MINGW32_%s-%u.%u", super_version,
           (unsigned int) version.dwMajorVersion,
           (unsigned int) version.dwMinorVersion);
#else
  sprintf (buf->sysname, "Windows%s", super_version);
#endif

  /* Fill in release, version.  */
  /* The MSYS uname.exe programs uses strings from a modified Cygwin runtime:
       $ ./uname.exe -r      => 1.0.11(0.46/3/2)
       $ ./uname.exe -v      => 2008-08-25 23:40
     There is no point in imitating this behaviour.  */
  if (version.dwPlatformId == VER_PLATFORM_WIN32_NT)
    {
      /* Windows NT or newer.  */
      struct windows_version
        {
          int major;
          int minor;
          unsigned int server_offset;
          const char *name;
        };

      /* Storing the workstation and server version names in a single
         stream does not waste memory when they are the same.  These
         macros abstract the representation.  VERSION1 is used if
         version.wProductType does not matter, VERSION2 if it does.  */
      #define VERSION1(major, minor, name) \
        { major, minor, 0, name }
      #define VERSION2(major, minor, workstation, server) \
        { major, minor, sizeof workstation, workstation "\0" server }
      static const struct windows_version versions[] =
        {
          VERSION2 (3, -1, "Windows NT Workstation", "Windows NT Server"),
          VERSION2 (4, -1, "Windows NT Workstation", "Windows NT Server"),
          VERSION1 (5, 0, "Windows 2000"),
          VERSION1 (5, 1, "Windows XP"),
          VERSION1 (5, 2, "Windows Server 2003"),
          VERSION2 (6, 0, "Windows Vista", "Windows Server 2008"),
          VERSION2 (6, 1, "Windows 7", "Windows Server 2008 R2"),
          VERSION2 (-1, -1, "Windows", "Windows Server")
        };
      const char *base;
      const struct windows_version *v = versions;

      /* Find a version that matches ours.  The last element is a
         wildcard that always ends the loop.  */
      while ((v->major != version.dwMajorVersion && v->major != -1)
             || (v->minor != version.dwMinorVersion && v->minor != -1))
        v++;

      if (have_versionex && versionex.wProductType != VER_NT_WORKSTATION)
        base = v->name + v->server_offset;
      else
        base = v->name;
      if (v->major == -1 || v->minor == -1)
        sprintf (buf->release, "%s %u.%u",
                 base,
                 (unsigned int) version.dwMajorVersion,
                 (unsigned int) version.dwMinorVersion);
      else
        strcpy (buf->release, base);
    }
  else if (version.dwPlatformId == VER_PLATFORM_WIN32_CE)
    {
      /* Windows CE or Embedded CE.  */
      sprintf (buf->release, "Windows CE %u.%u",
               (unsigned int) version.dwMajorVersion,
               (unsigned int) version.dwMinorVersion);
    }
  else
    {
      /* Windows 95/98/ME.  */
      sprintf (buf->release, "Windows %s", super_version);
    }
  strcpy (buf->version, version.szCSDVersion);

  /* Fill in machine.  */
  {
    SYSTEM_INFO info;

    GetSystemInfo (&info);
    /* Check for Windows NT or CE, since the info.wProcessorLevel is
       garbage on Windows 95. */
    if (version.dwPlatformId == VER_PLATFORM_WIN32_NT
        || version.dwPlatformId == VER_PLATFORM_WIN32_CE)
      {
        /* Windows NT or newer, or Windows CE or Embedded CE.  */
        switch (info.wProcessorArchitecture)
          {
          case PROCESSOR_ARCHITECTURE_AMD64:
            strcpy (buf->machine, "x86_64");
            break;
          case PROCESSOR_ARCHITECTURE_IA64:
            strcpy (buf->machine, "ia64");
            break;
          case PROCESSOR_ARCHITECTURE_INTEL:
            strcpy (buf->machine, "i386");
            if (info.wProcessorLevel >= 3)
              buf->machine[1] =
                '0' + (info.wProcessorLevel <= 6 ? info.wProcessorLevel : 6);
            break;
          case PROCESSOR_ARCHITECTURE_IA32_ON_WIN64:
            strcpy (buf->machine, "i686");
            break;
          case PROCESSOR_ARCHITECTURE_MIPS:
            strcpy (buf->machine, "mips");
            break;
          case PROCESSOR_ARCHITECTURE_ALPHA:
          case PROCESSOR_ARCHITECTURE_ALPHA64:
            strcpy (buf->machine, "alpha");
            break;
          case PROCESSOR_ARCHITECTURE_PPC:
            strcpy (buf->machine, "powerpc");
            break;
          case PROCESSOR_ARCHITECTURE_SHX:
            strcpy (buf->machine, "sh");
            break;
          case PROCESSOR_ARCHITECTURE_ARM:
            strcpy (buf->machine, "arm");
            break;
          default:
            strcpy (buf->machine, "unknown");
            break;
          }
      }
    else
      {
        /* Windows 95/98/ME.  */
        switch (info.dwProcessorType)
          {
          case PROCESSOR_AMD_X8664:
            strcpy (buf->machine, "x86_64");
            break;
          case PROCESSOR_INTEL_IA64:
            strcpy (buf->machine, "ia64");
            break;
          default:
            if (info.dwProcessorType % 100 == 86)
              sprintf (buf->machine, "i%u",
                       (unsigned int) info.dwProcessorType);
            else
              strcpy (buf->machine, "unknown");
            break;
          }
      }
  }

  return 0;
}

#endif
