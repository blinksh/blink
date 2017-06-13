/* Creating and controlling threads.
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

/* Written by Bruno Haible <bruno@clisp.org>, 2005.
   Based on GCC's gthr-posix.h, gthr-posix95.h, gthr-solaris.h,
   gthr-win32.h.  */

/* This file contains primitives for creating and controlling threads.

   Thread data type: gl_thread_t.

   Creating a thread:
       thread = gl_thread_create (func, arg);
   Or with control of error handling:
       err = glthread_create (&thread, func, arg);
       extern int glthread_create (gl_thread_t *result,
                                   void *(*func) (void *), void *arg);

   Querying and changing the signal mask of a thread (not supported on all
   platforms):
       gl_thread_sigmask (how, newmask, oldmask);
   Or with control of error handling:
       err = glthread_sigmask (how, newmask, oldmask);
       extern int glthread_sigmask (int how, const sigset_t *newmask, sigset_t *oldmask);

   Waiting for termination of another thread:
       gl_thread_join (thread, &return_value);
   Or with control of error handling:
       err = glthread_join (thread, &return_value);
       extern int glthread_join (gl_thread_t thread, void **return_value_ptr);

   Getting a reference to the current thread:
       current = gl_thread_self ();
       extern gl_thread_t gl_thread_self (void);

   Getting a reference to the current thread as a pointer, for debugging:
       ptr = gl_thread_self_pointer ();
       extern void * gl_thread_self_pointer (void);

   Terminating the current thread:
       gl_thread_exit (return_value);
       extern _Noreturn void gl_thread_exit (void *return_value);

   Requesting custom code to be executed at fork() time(not supported on all
   platforms):
       gl_thread_atfork (prepare_func, parent_func, child_func);
   Or with control of error handling:
       err = glthread_atfork (prepare_func, parent_func, child_func);
       extern int glthread_atfork (void (*prepare_func) (void),
                                   void (*parent_func) (void),
                                   void (*child_func) (void));
   Note that even on platforms where this is supported, use of fork() and
   threads together is problematic, see
     <http://lists.gnu.org/archive/html/bug-gnulib/2008-08/msg00062.html>
 */


#ifndef _GLTHREAD_THREAD_H
#define _GLTHREAD_THREAD_H

#include <errno.h>
#include <stdlib.h>

#ifndef _GL_INLINE_HEADER_BEGIN
 #error "Please include config.h first."
#endif
_GL_INLINE_HEADER_BEGIN
#ifndef _GLTHREAD_THREAD_INLINE
# define _GLTHREAD_THREAD_INLINE _GL_INLINE
#endif

/* ========================================================================= */

#if USE_POSIX_THREADS

/* Use the POSIX threads library.  */

# include <pthread.h>

# ifdef __cplusplus
extern "C" {
# endif

# if PTHREAD_IN_USE_DETECTION_HARD

/* The pthread_in_use() detection needs to be done at runtime.  */
#  define pthread_in_use() \
     glthread_in_use ()
extern int glthread_in_use (void);

# endif

# if USE_POSIX_THREADS_WEAK

/* Use weak references to the POSIX threads library.  */

/* Weak references avoid dragging in external libraries if the other parts
   of the program don't use them.  Here we use them, because we don't want
   every program that uses libintl to depend on libpthread.  This assumes
   that libpthread would not be loaded after libintl; i.e. if libintl is
   loaded first, by an executable that does not depend on libpthread, and
   then a module is dynamically loaded that depends on libpthread, libintl
   will not be multithread-safe.  */

/* The way to test at runtime whether libpthread is present is to test
   whether a function pointer's value, such as &pthread_mutex_init, is
   non-NULL.  However, some versions of GCC have a bug through which, in
   PIC mode, &foo != NULL always evaluates to true if there is a direct
   call to foo(...) in the same function.  To avoid this, we test the
   address of a function in libpthread that we don't use.  */

#  pragma weak pthread_create

#  ifdef __clang__
  /* Without this, clang complains that pthread_sigmask is never declared.  */
#   include <signal.h>
#  endif
#  pragma weak pthread_sigmask

#  pragma weak pthread_join
#  ifndef pthread_self
#   pragma weak pthread_self
#  endif
#  pragma weak pthread_exit
#  if HAVE_PTHREAD_ATFORK
#   pragma weak pthread_atfork
#  endif

#  if !PTHREAD_IN_USE_DETECTION_HARD
#   pragma weak pthread_cancel
#   define pthread_in_use() (pthread_cancel != NULL)
#  endif

# else

#  if !PTHREAD_IN_USE_DETECTION_HARD
#   define pthread_in_use() 1
#  endif

# endif

/* -------------------------- gl_thread_t datatype -------------------------- */

/* This choice of gl_thread_t assumes that
     pthread_equal (a, b)  is equivalent to  ((a) == (b)).
   This is the case on all platforms in use in 2008.  */
typedef pthread_t gl_thread_t;
# define glthread_create(THREADP, FUNC, ARG) \
    (pthread_in_use () ? pthread_create (THREADP, NULL, FUNC, ARG) : ENOSYS)
# define glthread_sigmask(HOW, SET, OSET) \
    (pthread_in_use () ? pthread_sigmask (HOW, SET, OSET) : 0)
# define glthread_join(THREAD, RETVALP) \
    (pthread_in_use () ? pthread_join (THREAD, RETVALP) : 0)
# ifdef PTW32_VERSION
   /* In pthreads-win32, pthread_t is a struct with a pointer field 'p' and
      other fields.  */
#  define gl_thread_self() \
     (pthread_in_use () ? pthread_self () : gl_null_thread)
#  define gl_thread_self_pointer() \
     (pthread_in_use () ? pthread_self ().p : NULL)
extern const gl_thread_t gl_null_thread;
# elif defined __MVS__
   /* On IBM z/OS, pthread_t is a struct with an 8-byte '__' field.
      The first three bytes of this field appear to uniquely identify a
      pthread_t, though not necessarily representing a pointer.  */
#  define gl_thread_self() \
     (pthread_in_use () ? pthread_self () : gl_null_thread)
#  define gl_thread_self_pointer() \
     (pthread_in_use () ? *((void **) pthread_self ().__) : NULL)
extern const gl_thread_t gl_null_thread;
# else
#  define gl_thread_self() \
     (pthread_in_use () ? pthread_self () : (pthread_t) NULL)
#  define gl_thread_self_pointer() \
     (pthread_in_use () ? (void *) pthread_self () : NULL)
# endif
# define gl_thread_exit(RETVAL) \
    (pthread_in_use () ? pthread_exit (RETVAL) : 0)

# if HAVE_PTHREAD_ATFORK
#  define glthread_atfork(PREPARE_FUNC, PARENT_FUNC, CHILD_FUNC) \
     (pthread_in_use () ? pthread_atfork (PREPARE_FUNC, PARENT_FUNC, CHILD_FUNC) : 0)
# else
#  define glthread_atfork(PREPARE_FUNC, PARENT_FUNC, CHILD_FUNC) 0
# endif

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

# if USE_PTH_THREADS_WEAK

/* Use weak references to the GNU Pth threads library.  */

#  pragma weak pth_init
#  pragma weak pth_spawn
#  pragma weak pth_sigmask
#  pragma weak pth_join
#  pragma weak pth_self
#  pragma weak pth_exit

#  pragma weak pth_cancel
#  define pth_in_use() (pth_cancel != NULL)

# else

#  define pth_in_use() 1

# endif
/* -------------------------- gl_thread_t datatype -------------------------- */

typedef pth_t gl_thread_t;
# define glthread_create(THREADP, FUNC, ARG) \
    (pth_in_use () ? (pth_init (), ((*(THREADP) = pth_spawn (NULL, FUNC, ARG)) ? 0 : errno)) : 0)
# define glthread_sigmask(HOW, SET, OSET) \
    (pth_in_use () ? (pth_init (), (pth_sigmask (HOW, SET, OSET) ? 0 : errno)) : 0)
# define glthread_join(THREAD, RETVALP) \
    (pth_in_use () ? (pth_init (), (pth_join (THREAD, RETVALP) ? 0 : errno)) : 0)
# define gl_thread_self() \
    (pth_in_use () ? (pth_init (), (void *) pth_self ()) : NULL)
# define gl_thread_self_pointer() \
    gl_thread_self ()
# define gl_thread_exit(RETVAL) \
    (pth_in_use () ? (pth_init (), pth_exit (RETVAL)) : 0)
# define glthread_atfork(PREPARE_FUNC, PARENT_FUNC, CHILD_FUNC) 0

# ifdef __cplusplus
}
# endif

#endif

/* ========================================================================= */

#if USE_SOLARIS_THREADS

/* Use the old Solaris threads library.  */

# include <thread.h>
# include <synch.h>

# ifdef __cplusplus
extern "C" {
# endif

# if USE_SOLARIS_THREADS_WEAK

/* Use weak references to the old Solaris threads library.  */

#  pragma weak thr_create
#  pragma weak thr_join
#  pragma weak thr_self
#  pragma weak thr_exit

#  pragma weak thr_suspend
#  define thread_in_use() (thr_suspend != NULL)

# else

#  define thread_in_use() 1

# endif

/* -------------------------- gl_thread_t datatype -------------------------- */

typedef thread_t gl_thread_t;
# define glthread_create(THREADP, FUNC, ARG) \
    (thread_in_use () ? thr_create (NULL, 0, FUNC, ARG, 0, THREADP) : 0)
# define glthread_sigmask(HOW, SET, OSET) \
    (thread_in_use () ? sigprocmask (HOW, SET, OSET) : 0)
# define glthread_join(THREAD, RETVALP) \
    (thread_in_use () ? thr_join (THREAD, NULL, RETVALP) : 0)
# define gl_thread_self() \
    (thread_in_use () ? (void *) thr_self () : NULL)
# define gl_thread_self_pointer() \
    gl_thread_self ()
# define gl_thread_exit(RETVAL) \
    (thread_in_use () ? thr_exit (RETVAL) : 0)
# define glthread_atfork(PREPARE_FUNC, PARENT_FUNC, CHILD_FUNC) 0

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

/* -------------------------- gl_thread_t datatype -------------------------- */

/* The gl_thread_t is a pointer to a structure in memory.
   Why not the thread handle?  If it were the thread handle, it would be hard
   to implement gl_thread_self() (since GetCurrentThread () returns a pseudo-
   handle, DuplicateHandle (GetCurrentThread ()) returns a handle that must be
   closed afterwards, and there is no function for quickly retrieving a thread
   handle from its id).
   Why not the thread id?  I tried it.  It did not work: Sometimes ids appeared
   that did not belong to running threads, and glthread_join failed with ESRCH.
 */
typedef struct gl_thread_struct *gl_thread_t;
# define glthread_create(THREADP, FUNC, ARG) \
    glthread_create_func (THREADP, FUNC, ARG)
# define glthread_sigmask(HOW, SET, OSET) \
    /* unsupported */ 0
# define glthread_join(THREAD, RETVALP) \
    glthread_join_func (THREAD, RETVALP)
# define gl_thread_self() \
    gl_thread_self_func ()
# define gl_thread_self_pointer() \
    gl_thread_self ()
# define gl_thread_exit(RETVAL) \
    gl_thread_exit_func (RETVAL)
# define glthread_atfork(PREPARE_FUNC, PARENT_FUNC, CHILD_FUNC) 0
extern int glthread_create_func (gl_thread_t *threadp, void * (*func) (void *), void *arg);
extern int glthread_join_func (gl_thread_t thread, void **retvalp);
extern gl_thread_t gl_thread_self_func (void);
extern int gl_thread_exit_func (void *retval);

# ifdef __cplusplus
}
# endif

#endif

/* ========================================================================= */

#if !(USE_POSIX_THREADS || USE_PTH_THREADS || USE_SOLARIS_THREADS || USE_WINDOWS_THREADS)

/* Provide dummy implementation if threads are not supported.  */

typedef int gl_thread_t;
# define glthread_create(THREADP, FUNC, ARG) ENOSYS
# define glthread_sigmask(HOW, SET, OSET) 0
# define glthread_join(THREAD, RETVALP) 0
# define gl_thread_self() 0
# define gl_thread_self_pointer() \
    ((void *) gl_thread_self ())
# define gl_thread_exit(RETVAL) 0
# define glthread_atfork(PREPARE_FUNC, PARENT_FUNC, CHILD_FUNC) 0

#endif

/* ========================================================================= */

/* Macros with built-in error handling.  */

#ifdef __cplusplus
extern "C" {
#endif

_GLTHREAD_THREAD_INLINE gl_thread_t
gl_thread_create (void *(*func) (void *arg), void *arg)
{
  gl_thread_t thread;
  int ret;

  ret = glthread_create (&thread, func, arg);
  if (ret != 0)
    abort ();
  return thread;
}
#define gl_thread_sigmask(HOW, SET, OSET)     \
   do                                         \
     {                                        \
       if (glthread_sigmask (HOW, SET, OSET)) \
         abort ();                            \
     }                                        \
   while (0)
#define gl_thread_join(THREAD, RETVAL)     \
   do                                      \
     {                                     \
       if (glthread_join (THREAD, RETVAL)) \
         abort ();                         \
     }                                     \
   while (0)
#define gl_thread_atfork(PREPARE, PARENT, CHILD)     \
   do                                                \
     {                                               \
       if (glthread_atfork (PREPARE, PARENT, CHILD)) \
         abort ();                                   \
     }                                               \
   while (0)

#ifdef __cplusplus
}
#endif

_GL_INLINE_HEADER_END

#endif /* _GLTHREAD_THREAD_H */
