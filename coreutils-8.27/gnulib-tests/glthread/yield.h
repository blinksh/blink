/* Yielding the processor to other threads and processes.
   Copyright (C) 2005-2017 Free Software Foundation, Inc.

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

/* This file contains a primitive for yielding the processor to other threads.
     extern void gl_thread_yield (void);
 */

#ifndef _GLTHREAD_YIELD_H
#define _GLTHREAD_YIELD_H

#include <errno.h>

/* ========================================================================= */

#if USE_POSIX_THREADS

/* Use the POSIX threads library.  */

# include <sched.h>

# ifdef __cplusplus
extern "C" {
# endif

# define gl_thread_yield() \
    sched_yield ()

# ifdef __cplusplus
}
# endif

#endif

/* ========================================================================= */

#if USE_PTH_THREADS

/* Use the GNU Pth threads library.  */

# include <pth.h>

# ifdef __cplusplus
extern "C" {
# endif

# define gl_thread_yield() \
    pth_yield (NULL)

# ifdef __cplusplus
}
# endif

#endif

/* ========================================================================= */

#if USE_SOLARIS_THREADS

/* Use the old Solaris threads library.  */

# include <thread.h>

# ifdef __cplusplus
extern "C" {
# endif

# define gl_thread_yield() \
    thr_yield ()

# ifdef __cplusplus
}
# endif

#endif

/* ========================================================================= */

#if USE_WINDOWS_THREADS

# define WIN32_LEAN_AND_MEAN  /* avoid including junk */
# include <windows.h>

# ifdef __cplusplus
extern "C" {
# endif

# define gl_thread_yield() \
    Sleep (0)

# ifdef __cplusplus
}
# endif

#endif

/* ========================================================================= */

#if !(USE_POSIX_THREADS || USE_PTH_THREADS || USE_SOLARIS_THREADS || USE_WINDOWS_THREADS)

/* Provide dummy implementation if threads are not supported.  */

# define gl_thread_yield() 0

#endif

/* ========================================================================= */

#endif /* _GLTHREAD_YIELD_H */
