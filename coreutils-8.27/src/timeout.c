/* timeout -- run a command with bounded time
   Copyright (C) 2008-2017 Free Software Foundation, Inc.

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


/* timeout - Start a command, and kill it if the specified timeout expires

   We try to behave like a shell starting a single (foreground) job,
   and will kill the job if we receive the alarm signal we setup.
   The exit status of the job is returned, or one of these errors:
     EXIT_TIMEDOUT      124      job timed out
     EXIT_CANCELED      125      internal error
     EXIT_CANNOT_INVOKE 126      error executing job
     EXIT_ENOENT        127      couldn't find job to exec

   Caveats:
     If user specifies the KILL (9) signal is to be sent on timeout,
     the monitor is killed and so exits with 128+9 rather than 124.

     If you start a command in the background, which reads from the tty
     and so is immediately sent SIGTTIN to stop, then the timeout
     process will ignore this so it can timeout the command as expected.
     This can be seen with 'timeout 10 dd&' for example.
     However if one brings this group to the foreground with the 'fg'
     command before the timer expires, the command will remain
     in the stop state as the shell doesn't send a SIGCONT
     because the timeout process (group leader) is already running.
     To get the command running again one can Ctrl-Z, and do fg again.
     Note one can Ctrl-C the whole job when in this state.
     I think this could be fixed but I'm not sure the extra
     complication is justified for this scenario.

   Written by Pádraig Brady.  */

#include <config.h>
#include <getopt.h>
#include <stdio.h>
#include <sys/types.h>
#include <signal.h>
#if HAVE_PRCTL
# include <sys/prctl.h>
#endif
#include <sys/wait.h>

#include "system.h"
#include "c-strtod.h"
#include "xstrtod.h"
#include "sig2str.h"
#include "operand2sig.h"
#include "error.h"
#include "quote.h"

#if HAVE_SETRLIMIT
/* FreeBSD 5.0 at least needs <sys/types.h> and <sys/time.h> included
   before <sys/resource.h>.  Currently "system.h" includes <sys/time.h>.  */
# include <sys/resource.h>
#endif

/* NonStop circa 2011 lacks both SA_RESTART and siginterrupt.  */
#ifndef SA_RESTART
# define SA_RESTART 0
#endif

#define PROGRAM_NAME "timeout"

#define AUTHORS proper_name ("Padraig Brady")

static int timed_out;
static int term_signal = SIGTERM;  /* same default as kill command.  */
static pid_t monitored_pid;
static double kill_after;
static bool foreground;      /* whether to use another program group.  */
static bool preserve_status; /* whether to use a timeout status or not.  */

/* for long options with no corresponding short option, use enum */
enum
{
      FOREGROUND_OPTION = CHAR_MAX + 1,
      PRESERVE_STATUS_OPTION
};

static struct option const long_options[] =
{
  {"kill-after", required_argument, NULL, 'k'},
  {"signal", required_argument, NULL, 's'},
  {"foreground", no_argument, NULL, FOREGROUND_OPTION},
  {"preserve-status", no_argument, NULL, PRESERVE_STATUS_OPTION},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

/* Start the timeout after which we'll receive a SIGALRM.
   Round DURATION up to the next representable value.
   Treat out-of-range values as if they were maximal,
   as that's more useful in practice than reporting an error.
   '0' means don't timeout.  */
static void
settimeout (double duration, bool warn)
{

/* timer_settime() provides potentially nanosecond resolution.
   setitimer() is more portable (to Darwin for example),
   but only provides microsecond resolution and thus is
   a little more awkward to use with timespecs, as well as being
   deprecated by POSIX.  Instead we fallback to single second
   resolution provided by alarm().  */

#if HAVE_TIMER_SETTIME
  struct timespec ts = dtotimespec (duration);
  struct itimerspec its = { {0, 0}, ts };
  timer_t timerid;
  if (timer_create (CLOCK_REALTIME, NULL, &timerid) == 0)
    {
      if (timer_settime (timerid, 0, &its, NULL) == 0)
        return;
      else
        {
          if (warn)
            error (0, errno, _("warning: timer_settime"));
          timer_delete (timerid);
        }
    }
  else if (warn && errno != ENOSYS)
    error (0, errno, _("warning: timer_create"));
#endif

  unsigned int timeint;
  if (UINT_MAX <= duration)
    timeint = UINT_MAX;
  else
    {
      unsigned int duration_floor = duration;
      timeint = duration_floor + (duration_floor < duration);
    }
  alarm (timeint);
}

/* send SIG avoiding the current process.  */

static int
send_sig (pid_t where, int sig)
{
  /* If sending to the group, then ignore the signal,
     so we don't go into a signal loop.  Note that this will ignore any of the
     signals registered in install_cleanup(), that are sent after we
     propagate the first one, which hopefully won't be an issue.  Note this
     process can be implicitly multithreaded due to some timer_settime()
     implementations, therefore a signal sent to the group, can be sent
     multiple times to this process.  */
  if (where == 0)
    signal (sig, SIG_IGN);
  return kill (where, sig);
}

/* Signal handler which is required for sigsuspend() to be interrupted
   whenever SIGCHLD is received.  */
static void
chld (int sig)
{
}


static void
cleanup (int sig)
{
  if (sig == SIGALRM)
    {
      timed_out = 1;
      sig = term_signal;
    }
  if (monitored_pid)
    {
      if (kill_after)
        {
          int saved_errno = errno; /* settimeout may reset.  */
          /* Start a new timeout after which we'll send SIGKILL.  */
          term_signal = SIGKILL;
          settimeout (kill_after, false);
          kill_after = 0; /* Don't let later signals reset kill alarm.  */
          errno = saved_errno;
        }

      /* Send the signal directly to the monitored child,
         in case it has itself become group leader,
         or is not running in a separate group.  */
      send_sig (monitored_pid, sig);

      /* The normal case is the job has remained in our
         newly created process group, so send to all processes in that.  */
      if (!foreground)
        {
          send_sig (0, sig);
          if (sig != SIGKILL && sig != SIGCONT)
            {
              send_sig (monitored_pid, SIGCONT);
              send_sig (0, SIGCONT);
            }
        }
    }
  else /* we're the child or the child is not exec'd yet.  */
    _exit (128 + sig);
}

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s [OPTION] DURATION COMMAND [ARG]...\n\
  or:  %s [OPTION]\n"), program_name, program_name);

      fputs (_("\
Start COMMAND, and kill it if still running after DURATION.\n\
"), stdout);

      emit_mandatory_arg_note ();

      fputs (_("\
      --preserve-status\n\
                 exit with the same status as COMMAND, even when the\n\
                   command times out\n\
      --foreground\n\
                 when not running timeout directly from a shell prompt,\n\
                   allow COMMAND to read from the TTY and get TTY signals;\n\
                   in this mode, children of COMMAND will not be timed out\n\
  -k, --kill-after=DURATION\n\
                 also send a KILL signal if COMMAND is still running\n\
                   this long after the initial signal was sent\n\
  -s, --signal=SIGNAL\n\
                 specify the signal to be sent on timeout;\n\
                   SIGNAL may be a name like 'HUP' or a number;\n\
                   see 'kill -l' for a list of signals\n"), stdout);

      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);

      fputs (_("\n\
DURATION is a floating point number with an optional suffix:\n\
's' for seconds (the default), 'm' for minutes, 'h' for hours \
or 'd' for days.\n"), stdout);

      fputs (_("\n\
If the command times out, and --preserve-status is not set, then exit with\n\
status 124.  Otherwise, exit with the status of COMMAND.  If no signal\n\
is specified, send the TERM signal upon timeout.  The TERM signal kills\n\
any process that does not block or catch that signal.  It may be necessary\n\
to use the KILL (9) signal, since this signal cannot be caught, in which\n\
case the exit status is 128+9 rather than 124.\n"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}

/* Given a floating point value *X, and a suffix character, SUFFIX_CHAR,
   scale *X by the multiplier implied by SUFFIX_CHAR.  SUFFIX_CHAR may
   be the NUL byte or 's' to denote seconds, 'm' for minutes, 'h' for
   hours, or 'd' for days.  If SUFFIX_CHAR is invalid, don't modify *X
   and return false.  Otherwise return true.  */

static bool
apply_time_suffix (double *x, char suffix_char)
{
  int multiplier;

  switch (suffix_char)
    {
    case 0:
    case 's':
      multiplier = 1;
      break;
    case 'm':
      multiplier = 60;
      break;
    case 'h':
      multiplier = 60 * 60;
      break;
    case 'd':
      multiplier = 60 * 60 * 24;
      break;
    default:
      return false;
    }

  *x *= multiplier;

  return true;
}

static double
parse_duration (const char* str)
{
  double duration;
  const char *ep;

  if (! (xstrtod (str, &ep, &duration, c_strtod) || errno == ERANGE)
      /* Nonnegative interval.  */
      || ! (0 <= duration)
      /* No extra chars after the number and an optional s,m,h,d char.  */
      || (*ep && *(ep + 1))
      /* Check any suffix char and update timeout based on the suffix.  */
      || !apply_time_suffix (&duration, *ep))
    {
      error (0, 0, _("invalid time interval %s"), quote (str));
      usage (EXIT_CANCELED);
    }

  return duration;
}

static void
install_sigchld (void)
{
  struct sigaction sa;
  sigemptyset (&sa.sa_mask);  /* Allow concurrent calls to handler */
  sa.sa_handler = chld;
  sa.sa_flags = SA_RESTART;   /* Restart syscalls if possible, as that's
                                 more likely to work cleanly.  */

  sigaction (SIGCHLD, &sa, NULL);
}

static void
install_cleanup (int sigterm)
{
  struct sigaction sa;
  sigemptyset (&sa.sa_mask);  /* Allow concurrent calls to handler */
  sa.sa_handler = cleanup;
  sa.sa_flags = SA_RESTART;   /* Restart syscalls if possible, as that's
                                 more likely to work cleanly.  */

  sigaction (SIGALRM, &sa, NULL); /* our timeout.  */
  sigaction (SIGINT, &sa, NULL);  /* Ctrl-C at terminal for example.  */
  sigaction (SIGQUIT, &sa, NULL); /* Ctrl-\ at terminal for example.  */
  sigaction (SIGHUP, &sa, NULL);  /* terminal closed for example.  */
  sigaction (SIGTERM, &sa, NULL); /* if we're killed, stop monitored proc.  */
  sigaction (sigterm, &sa, NULL); /* user specified termination signal.  */
}

/* Blocks all signals which were registered with cleanup
   as signal handler.  Return original mask in OLD_SET.  */
static void
block_cleanup (int sigterm, sigset_t *old_set)
{
  sigset_t block_set;
  sigemptyset (&block_set);
  sigaddset (&block_set, SIGALRM);
  sigaddset (&block_set, SIGINT);
  sigaddset (&block_set, SIGQUIT);
  sigaddset (&block_set, SIGHUP);
  sigaddset (&block_set, SIGTERM);
  sigaddset (&block_set, sigterm);
  if (sigprocmask (SIG_BLOCK, &block_set, old_set) != 0)
    error (0, errno, _("warning: sigprocmask"));
}

static void
unblock_signal (int sig)
{
  sigset_t unblock_set;
  sigemptyset (&unblock_set);
  sigaddset (&unblock_set, sig);
  if (sigprocmask (SIG_UNBLOCK, &unblock_set, NULL) != 0)
    error (0, errno, _("warning: sigprocmask"));
}

/* Try to disable core dumps for this process.
   Return TRUE if successful, FALSE otherwise.  */
static bool
disable_core_dumps (void)
{
#if HAVE_PRCTL && defined PR_SET_DUMPABLE
  if (prctl (PR_SET_DUMPABLE, 0) == 0)
    return true;

#elif HAVE_SETRLIMIT && defined RLIMIT_CORE
  /* Note this doesn't disable processing by a filter in
     /proc/sys/kernel/core_pattern on Linux.  */
  if (setrlimit (RLIMIT_CORE, &(struct rlimit) {0,0}) == 0)
    return true;

#else
  return false;
#endif

  error (0, errno, _("warning: disabling core dumps failed"));
  return false;
}

int
main (int argc, char **argv)
{
  double timeout;
  char signame[SIG2STR_MAX];
  int c;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  initialize_exit_failure (EXIT_CANCELED);
  atexit (close_stdout);

  while ((c = getopt_long (argc, argv, "+k:s:", long_options, NULL)) != -1)
    {
      switch (c)
        {
        case 'k':
          kill_after = parse_duration (optarg);
          break;

        case 's':
          term_signal = operand2sig (optarg, signame);
          if (term_signal == -1)
            usage (EXIT_CANCELED);
          break;

        case FOREGROUND_OPTION:
          foreground = true;
          break;

        case PRESERVE_STATUS_OPTION:
          preserve_status = true;
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          usage (EXIT_CANCELED);
          break;
        }
    }

  if (argc - optind < 2)
    usage (EXIT_CANCELED);

  timeout = parse_duration (argv[optind++]);

  argv += optind;

  /* Ensure we're in our own group so all subprocesses can be killed.
     Note we don't just put the child in a separate group as
     then we would need to worry about foreground and background groups
     and propagating signals between them.  */
  if (!foreground)
    setpgid (0, 0);

  /* Setup handlers before fork() so that we
     handle any signals caused by child, without races.  */
  install_cleanup (term_signal);
  signal (SIGTTIN, SIG_IGN);   /* Don't stop if background child needs tty.  */
  signal (SIGTTOU, SIG_IGN);   /* Don't stop if background child needs tty.  */
  install_sigchld ();          /* Interrupt sigsuspend() when child exits.   */

  monitored_pid = fork ();
  if (monitored_pid == -1)
    {
      error (0, errno, _("fork system call failed"));
      return EXIT_CANCELED;
    }
  else if (monitored_pid == 0)
    {                           /* child */
      /* exec doesn't reset SIG_IGN -> SIG_DFL.  */
      signal (SIGTTIN, SIG_DFL);
      signal (SIGTTOU, SIG_DFL);

      execvp (argv[0], argv);   /* FIXME: should we use "sh -c" ... here?  */

      /* exit like sh, env, nohup, ...  */
      int exit_status = errno == ENOENT ? EXIT_ENOENT : EXIT_CANNOT_INVOKE;
      error (0, errno, _("failed to run command %s"), quote (argv[0]));
      return exit_status;
    }
  else
    {
      pid_t wait_result;
      int status;

      /* We configure timers so that SIGALRM is sent on expiry.
         Therefore ensure we don't inherit a mask blocking SIGALRM.  */
      unblock_signal (SIGALRM);

      settimeout (timeout, true);

      /* Ensure we don't cleanup() after waitpid() reaps the child,
         to avoid sending signals to a possibly different process.  */
      sigset_t cleanup_set;
      block_cleanup (term_signal, &cleanup_set);

      while ((wait_result = waitpid (monitored_pid, &status, WNOHANG)) == 0)
        sigsuspend (&cleanup_set);  /* Wait with cleanup signals unblocked.  */

      if (wait_result < 0)
        {
          /* shouldn't happen.  */
          error (0, errno, _("error waiting for command"));
          status = EXIT_CANCELED;
        }
      else
        {
          if (WIFEXITED (status))
            status = WEXITSTATUS (status);
          else if (WIFSIGNALED (status))
            {
              int sig = WTERMSIG (status);
              if (WCOREDUMP (status))
                error (0, 0, _("the monitored command dumped core"));
              if (!timed_out && disable_core_dumps ())
                {
                  /* exit with the signal flag set.  */
                  signal (sig, SIG_DFL);
                  unblock_signal (sig);
                  raise (sig);
                }
              status = sig + 128; /* what sh returns for signaled processes.  */
            }
          else
            {
              /* shouldn't happen.  */
              error (0, 0, _("unknown status from command (%d)"), status);
              status = EXIT_FAILURE;
            }
        }

      if (timed_out && !preserve_status)
        status = EXIT_TIMEDOUT;
      return status;
    }
}
