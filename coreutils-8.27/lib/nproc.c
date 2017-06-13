/* Detect the number of processors.

   Copyright (C) 2009-2017 Free Software Foundation, Inc.

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

/* Written by Glen Lenker and Bruno Haible.  */

#include "config.h"
#include "nproc.h"

#include <limits.h>
#include <stdlib.h>
#include <unistd.h>

#if HAVE_PTHREAD_GETAFFINITY_NP && 0
# include <pthread.h>
# include <sched.h>
#endif
#if HAVE_SCHED_GETAFFINITY_LIKE_GLIBC || HAVE_SCHED_GETAFFINITY_NP
# include <sched.h>
#endif

#include <sys/types.h>

#if HAVE_SYS_PSTAT_H
# include <sys/pstat.h>
#endif

#if HAVE_SYS_SYSMP_H
# include <sys/sysmp.h>
#endif

#if HAVE_SYS_PARAM_H
# include <sys/param.h>
#endif

#if HAVE_SYS_SYSCTL_H
# include <sys/sysctl.h>
#endif

#if (defined _WIN32 || defined __WIN32__) && ! defined __CYGWIN__
# define WIN32_LEAN_AND_MEAN
# include <windows.h>
#endif

#include "c-ctype.h"

#include "minmax.h"

#define ARRAY_SIZE(a) (sizeof (a) / sizeof ((a)[0]))

/* Return the number of processors available to the current process, based
   on a modern system call that returns the "affinity" between the current
   process and each CPU.  Return 0 if unknown or if such a system call does
   not exist.  */
static unsigned long
num_processors_via_affinity_mask (void)
{
  /* glibc >= 2.3.3 with NPTL and NetBSD 5 have pthread_getaffinity_np,
     but with different APIs.  Also it requires linking with -lpthread.
     Therefore this code is not enabled.
     glibc >= 2.3.4 has sched_getaffinity whereas NetBSD 5 has
     sched_getaffinity_np.  */
#if HAVE_PTHREAD_GETAFFINITY_NP && defined __GLIBC__ && 0
  {
    cpu_set_t set;

    if (pthread_getaffinity_np (pthread_self (), sizeof (set), &set) == 0)
      {
        unsigned long count;

# ifdef CPU_COUNT
        /* glibc >= 2.6 has the CPU_COUNT macro.  */
        count = CPU_COUNT (&set);
# else
        size_t i;

        count = 0;
        for (i = 0; i < CPU_SETSIZE; i++)
          if (CPU_ISSET (i, &set))
            count++;
# endif
        if (count > 0)
          return count;
      }
  }
#elif HAVE_PTHREAD_GETAFFINITY_NP && defined __NetBSD__ && 0
  {
    cpuset_t *set;

    set = cpuset_create ();
    if (set != NULL)
      {
        unsigned long count = 0;

        if (pthread_getaffinity_np (pthread_self (), cpuset_size (set), set)
            == 0)
          {
            cpuid_t i;

            for (i = 0;; i++)
              {
                int ret = cpuset_isset (i, set);
                if (ret < 0)
                  break;
                if (ret > 0)
                  count++;
              }
          }
        cpuset_destroy (set);
        if (count > 0)
          return count;
      }
  }
#elif HAVE_SCHED_GETAFFINITY_LIKE_GLIBC /* glibc >= 2.3.4 */
  {
    cpu_set_t set;

    if (sched_getaffinity (0, sizeof (set), &set) == 0)
      {
        unsigned long count;

# ifdef CPU_COUNT
        /* glibc >= 2.6 has the CPU_COUNT macro.  */
        count = CPU_COUNT (&set);
# else
        size_t i;

        count = 0;
        for (i = 0; i < CPU_SETSIZE; i++)
          if (CPU_ISSET (i, &set))
            count++;
# endif
        if (count > 0)
          return count;
      }
  }
#elif HAVE_SCHED_GETAFFINITY_NP /* NetBSD >= 5 */
  {
    cpuset_t *set;

    set = cpuset_create ();
    if (set != NULL)
      {
        unsigned long count = 0;

        if (sched_getaffinity_np (getpid (), cpuset_size (set), set) == 0)
          {
            cpuid_t i;

            for (i = 0;; i++)
              {
                int ret = cpuset_isset (i, set);
                if (ret < 0)
                  break;
                if (ret > 0)
                  count++;
              }
          }
        cpuset_destroy (set);
        if (count > 0)
          return count;
      }
  }
#endif

#if (defined _WIN32 || defined __WIN32__) && ! defined __CYGWIN__
  { /* This works on native Windows platforms.  */
    DWORD_PTR process_mask;
    DWORD_PTR system_mask;

    if (GetProcessAffinityMask (GetCurrentProcess (),
                                &process_mask, &system_mask))
      {
        DWORD_PTR mask = process_mask;
        unsigned long count = 0;

        for (; mask != 0; mask = mask >> 1)
          if (mask & 1)
            count++;
        if (count > 0)
          return count;
      }
  }
#endif

  return 0;
}


/* Return the total number of processors.  Here QUERY must be one of
   NPROC_ALL, NPROC_CURRENT.  The result is guaranteed to be at least 1.  */
static unsigned long int
num_processors_ignoring_omp (enum nproc_query query)
{
  /* On systems with a modern affinity mask system call, we have
         sysconf (_SC_NPROCESSORS_CONF)
            >= sysconf (_SC_NPROCESSORS_ONLN)
               >= num_processors_via_affinity_mask ()
     The first number is the number of CPUs configured in the system.
     The second number is the number of CPUs available to the scheduler.
     The third number is the number of CPUs available to the current process.

     Note! On Linux systems with glibc, the first and second number come from
     the /sys and /proc file systems (see
     glibc/sysdeps/unix/sysv/linux/getsysstats.c).
     In some situations these file systems are not mounted, and the sysconf
     call returns 1, which does not reflect the reality.  */

  if (query == NPROC_CURRENT)
    {
      /* Try the modern affinity mask system call.  */
      {
        unsigned long nprocs = num_processors_via_affinity_mask ();

        if (nprocs > 0)
          return nprocs;
      }

#if defined _SC_NPROCESSORS_ONLN
      { /* This works on glibc, Mac OS X 10.5, FreeBSD, AIX, OSF/1, Solaris,
           Cygwin, Haiku.  */
        long int nprocs = sysconf (_SC_NPROCESSORS_ONLN);
        if (nprocs > 0)
          return nprocs;
      }
#endif
    }
  else /* query == NPROC_ALL */
    {
#if defined _SC_NPROCESSORS_CONF
      { /* This works on glibc, Mac OS X 10.5, FreeBSD, AIX, OSF/1, Solaris,
           Cygwin, Haiku.  */
        long int nprocs = sysconf (_SC_NPROCESSORS_CONF);

# if __GLIBC__ >= 2 && defined __linux__
        /* On Linux systems with glibc, this information comes from the /sys and
           /proc file systems (see glibc/sysdeps/unix/sysv/linux/getsysstats.c).
           In some situations these file systems are not mounted, and the
           sysconf call returns 1.  But we wish to guarantee that
           num_processors (NPROC_ALL) >= num_processors (NPROC_CURRENT).  */
        if (nprocs == 1)
          {
            unsigned long nprocs_current = num_processors_via_affinity_mask ();

            if (nprocs_current > 0)
              nprocs = nprocs_current;
          }
# endif

        if (nprocs > 0)
          return nprocs;
      }
#endif
    }

#if HAVE_PSTAT_GETDYNAMIC
  { /* This works on HP-UX.  */
    struct pst_dynamic psd;
    if (pstat_getdynamic (&psd, sizeof psd, 1, 0) >= 0)
      {
        /* The field psd_proc_cnt contains the number of active processors.
           In newer releases of HP-UX 11, the field psd_max_proc_cnt includes
           deactivated processors.  */
        if (query == NPROC_CURRENT)
          {
            if (psd.psd_proc_cnt > 0)
              return psd.psd_proc_cnt;
          }
        else
          {
            if (psd.psd_max_proc_cnt > 0)
              return psd.psd_max_proc_cnt;
          }
      }
  }
#endif

#if HAVE_SYSMP && defined MP_NAPROCS && defined MP_NPROCS
  { /* This works on IRIX.  */
    /* MP_NPROCS yields the number of installed processors.
       MP_NAPROCS yields the number of processors available to unprivileged
       processes.  */
    int nprocs =
      sysmp (query == NPROC_CURRENT && getpid () != 0
             ? MP_NAPROCS
             : MP_NPROCS);
    if (nprocs > 0)
      return nprocs;
  }
#endif

  /* Finally, as fallback, use the APIs that don't distinguish between
     NPROC_CURRENT and NPROC_ALL.  */

#if HAVE_SYSCTL && defined HW_NCPU
  { /* This works on Mac OS X, FreeBSD, NetBSD, OpenBSD.  */
    int nprocs;
    size_t len = sizeof (nprocs);
    static int mib[2] = { CTL_HW, HW_NCPU };

    if (sysctl (mib, ARRAY_SIZE (mib), &nprocs, &len, NULL, 0) == 0
        && len == sizeof (nprocs)
        && 0 < nprocs)
      return nprocs;
  }
#endif

#if (defined _WIN32 || defined __WIN32__) && ! defined __CYGWIN__
  { /* This works on native Windows platforms.  */
    SYSTEM_INFO system_info;
    GetSystemInfo (&system_info);
    if (0 < system_info.dwNumberOfProcessors)
      return system_info.dwNumberOfProcessors;
  }
#endif

  return 1;
}

/* Parse OMP environment variables without dependence on OMP.
   Return 0 for invalid values.  */
static unsigned long int
parse_omp_threads (char const* threads)
{
  unsigned long int ret = 0;

  if (threads == NULL)
    return ret;

  /* The OpenMP spec says that the value assigned to the environment variables
     "may have leading and trailing white space".  */
  while (*threads != '\0' && c_isspace (*threads))
    threads++;

  /* Convert it from positive decimal to 'unsigned long'.  */
  if (c_isdigit (*threads))
    {
      char *endptr = NULL;
      unsigned long int value = strtoul (threads, &endptr, 10);

      if (endptr != NULL)
        {
          while (*endptr != '\0' && c_isspace (*endptr))
            endptr++;
          if (*endptr == '\0')
            return value;
          /* Also accept the first value in a nesting level,
             since we can't determine the nesting level from env vars.  */
          else if (*endptr == ',')
            return value;
        }
    }

  return ret;
}

unsigned long int
num_processors (enum nproc_query query)
{
  unsigned long int omp_env_limit = ULONG_MAX;

  if (query == NPROC_CURRENT_OVERRIDABLE)
    {
      unsigned long int omp_env_threads;
      /* Honor the OpenMP environment variables, recognized also by all
         programs that are based on OpenMP.  */
      omp_env_threads = parse_omp_threads (getenv ("OMP_NUM_THREADS"));
      omp_env_limit = parse_omp_threads (getenv ("OMP_THREAD_LIMIT"));
      if (! omp_env_limit)
        omp_env_limit = ULONG_MAX;

      if (omp_env_threads)
        return MIN (omp_env_threads, omp_env_limit);

      query = NPROC_CURRENT;
    }
  /* Here query is one of NPROC_ALL, NPROC_CURRENT.  */
  {
    unsigned long nprocs = num_processors_ignoring_omp (query);
    return MIN (nprocs, omp_env_limit);
  }
}
