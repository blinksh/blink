/* Test of thread-local storage in multithreaded situations.
   Copyright (C) 2005, 2008-2017 Free Software Foundation, Inc.

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

/* Written by Bruno Haible <bruno@clisp.org>, 2005.  */

#include <config.h>

#if USE_POSIX_THREADS || USE_SOLARIS_THREADS || USE_PTH_THREADS || USE_WINDOWS_THREADS

#if USE_POSIX_THREADS
# define TEST_POSIX_THREADS 1
#endif
#if USE_SOLARIS_THREADS
# define TEST_SOLARIS_THREADS 1
#endif
#if USE_PTH_THREADS
# define TEST_PTH_THREADS 1
#endif
#if USE_WINDOWS_THREADS
# define TEST_WINDOWS_THREADS 1
#endif

/* Whether to help the scheduler through explicit yield().
   Uncomment this to see if the operating system has a fair scheduler.  */
#define EXPLICIT_YIELD 1

/* Whether to print debugging messages.  */
#define ENABLE_DEBUGGING 0

/* Number of simultaneous threads.  */
#define THREAD_COUNT 16

/* Number of operations performed in each thread.  */
#define REPEAT_COUNT 50000

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "glthread/tls.h"
#include "glthread/thread.h"
#include "glthread/yield.h"

#if ENABLE_DEBUGGING
# define dbgprintf printf
#else
# define dbgprintf if (0) printf
#endif

#if EXPLICIT_YIELD
# define yield() gl_thread_yield ()
#else
# define yield()
#endif

static void
perhaps_yield (void)
{
  /* Call yield () only with a certain probability, otherwise with GNU Pth
     the sequence of thread activations is too predictable.  */
  if ((((unsigned int) rand () >> 3) % 4) == 0)
    yield ();
}


/* ----------------------- Test thread-local storage ----------------------- */

#define KEYS_COUNT 4

static gl_tls_key_t mykeys[KEYS_COUNT];

static void *
worker_thread (void *arg)
{
  unsigned int id = (unsigned int) (unsigned long) arg;
  int i, j, repeat;
  unsigned int values[KEYS_COUNT];

  dbgprintf ("Worker %p started\n", gl_thread_self_pointer ());

  /* Initialize the per-thread storage.  */
  for (i = 0; i < KEYS_COUNT; i++)
    {
      values[i] = (((unsigned int) rand () >> 3) % 1000000) * THREAD_COUNT + id;
      /* Hopefully no arithmetic overflow.  */
      if ((values[i] % THREAD_COUNT) != id)
        abort ();
    }
  perhaps_yield ();

  /* Verify that the initial value is NULL.  */
  dbgprintf ("Worker %p before initial verify\n", gl_thread_self_pointer ());
  for (i = 0; i < KEYS_COUNT; i++)
    if (gl_tls_get (mykeys[i]) != NULL)
      abort ();
  dbgprintf ("Worker %p after  initial verify\n", gl_thread_self_pointer ());
  perhaps_yield ();

  /* Initialize the per-thread storage.  */
  dbgprintf ("Worker %p before first tls_set\n", gl_thread_self_pointer ());
  for (i = 0; i < KEYS_COUNT; i++)
    {
      unsigned int *ptr = (unsigned int *) malloc (sizeof (unsigned int));
      *ptr = values[i];
      gl_tls_set (mykeys[i], ptr);
    }
  dbgprintf ("Worker %p after  first tls_set\n", gl_thread_self_pointer ());
  perhaps_yield ();

  /* Shuffle around the pointers.  */
  for (repeat = REPEAT_COUNT; repeat > 0; repeat--)
    {
      dbgprintf ("Worker %p doing value swapping\n", gl_thread_self_pointer ());
      i = ((unsigned int) rand () >> 3) % KEYS_COUNT;
      j = ((unsigned int) rand () >> 3) % KEYS_COUNT;
      if (i != j)
        {
          void *vi = gl_tls_get (mykeys[i]);
          void *vj = gl_tls_get (mykeys[j]);

          gl_tls_set (mykeys[i], vj);
          gl_tls_set (mykeys[j], vi);
        }
      perhaps_yield ();
    }

  /* Verify that all the values are from this thread.  */
  dbgprintf ("Worker %p before final verify\n", gl_thread_self_pointer ());
  for (i = 0; i < KEYS_COUNT; i++)
    if ((*(unsigned int *) gl_tls_get (mykeys[i]) % THREAD_COUNT) != id)
      abort ();
  dbgprintf ("Worker %p after  final verify\n", gl_thread_self_pointer ());
  perhaps_yield ();

  dbgprintf ("Worker %p dying.\n", gl_thread_self_pointer ());
  return NULL;
}

static void
test_tls (void)
{
  int pass, i;

  for (pass = 0; pass < 2; pass++)
    {
      gl_thread_t threads[THREAD_COUNT];

      if (pass == 0)
        for (i = 0; i < KEYS_COUNT; i++)
          gl_tls_key_init (mykeys[i], free);
      else
        for (i = KEYS_COUNT - 1; i >= 0; i--)
          gl_tls_key_init (mykeys[i], free);

      /* Spawn the threads.  */
      for (i = 0; i < THREAD_COUNT; i++)
        threads[i] = gl_thread_create (worker_thread, NULL);

      /* Wait for the threads to terminate.  */
      for (i = 0; i < THREAD_COUNT; i++)
        gl_thread_join (threads[i], NULL);

      for (i = 0; i < KEYS_COUNT; i++)
        gl_tls_key_destroy (mykeys[i]);
    }
}


/* -------------------------------------------------------------------------- */

int
main ()
{
#if TEST_PTH_THREADS
  if (!pth_init ())
    abort ();
#endif

  printf ("Starting test_tls ..."); fflush (stdout);
  test_tls ();
  printf (" OK\n"); fflush (stdout);

  return 0;
}

#else

/* No multithreading available.  */

#include <stdio.h>

int
main ()
{
  fputs ("Skipping test: multithreading not enabled\n", stderr);
  return 77;
}

#endif
