/* stty -- change and print terminal line settings
   Copyright (C) 1990-2017 Free Software Foundation, Inc.

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

/* Usage: stty [-ag] [--all] [--save] [-F device] [--file=device] [setting...]

   Options:
   -a, --all    Write all current settings to stdout in human-readable form.
   -g, --save   Write all current settings to stdout in stty-readable form.
   -F, --file   Open and use the specified device instead of stdin

   If no args are given, write to stdout the baud rate and settings that
   have been changed from their defaults.  Mode reading and changes
   are done on the specified device, or stdin if none was specified.

   David MacKenzie <djm@gnu.ai.mit.edu> */

#include <config.h>

#ifdef TERMIOS_NEEDS_XOPEN_SOURCE
# define _XOPEN_SOURCE
#endif

#include <stdio.h>
#include <sys/types.h>

#include <termios.h>
#if HAVE_STROPTS_H
# include <stropts.h>
#endif
#include <sys/ioctl.h>

#ifdef WINSIZE_IN_PTEM
# include <sys/stream.h>
# include <sys/ptem.h>
#endif
#ifdef GWINSZ_IN_SYS_PTY
# include <sys/tty.h>
# include <sys/pty.h>
#endif
#include <getopt.h>
#include <stdarg.h>
#include <assert.h>

#include "system.h"
#include "die.h"
#include "error.h"
#include "fd-reopen.h"
#include "quote.h"
#include "xdectoint.h"
#include "xstrtol.h"

/* The official name of this program (e.g., no 'g' prefix).  */
#define PROGRAM_NAME "stty"

#define AUTHORS proper_name ("David MacKenzie")

#ifndef _POSIX_VDISABLE
# define _POSIX_VDISABLE 0
#endif

#define Control(c) ((c) & 0x1f)
/* Canonical values for control characters. */
#ifndef CINTR
# define CINTR Control ('c')
#endif
#ifndef CQUIT
# define CQUIT 28
#endif
#ifndef CERASE
# define CERASE 127
#endif
#ifndef CKILL
# define CKILL Control ('u')
#endif
#ifndef CEOF
# define CEOF Control ('d')
#endif
#ifndef CEOL
# define CEOL _POSIX_VDISABLE
#endif
#ifndef CSTART
# define CSTART Control ('q')
#endif
#ifndef CSTOP
# define CSTOP Control ('s')
#endif
#ifndef CSUSP
# define CSUSP Control ('z')
#endif
#if defined VEOL2 && !defined CEOL2
# define CEOL2 _POSIX_VDISABLE
#endif
/* Some platforms have VSWTC, others VSWTCH.  In both cases, this control
   character is initialized by CSWTCH, if present.  */
#if defined VSWTC && !defined VSWTCH
# define VSWTCH VSWTC
#endif
/* ISC renamed swtch to susp for termios, but we'll accept either name.  */
#if defined VSUSP && !defined VSWTCH
# define VSWTCH VSUSP
# if defined CSUSP && !defined CSWTCH
#  define CSWTCH CSUSP
# endif
#endif
#if defined VSWTCH && !defined CSWTCH
# define CSWTCH _POSIX_VDISABLE
#endif

/* SunOS >= 5.3 loses (^Z doesn't work) if 'swtch' is the same as 'susp'.
   So the default is to disable 'swtch.'  */
#if defined __sun
# undef CSWTCH
# define CSWTCH _POSIX_VDISABLE
#endif

#if defined VWERSE && !defined VWERASE	/* AIX-3.2.5 */
# define VWERASE VWERSE
#endif
#if defined VDSUSP && !defined CDSUSP
# define CDSUSP Control ('y')
#endif
#if !defined VREPRINT && defined VRPRNT /* Irix 4.0.5 */
# define VREPRINT VRPRNT
#endif
#if defined VREPRINT && !defined CRPRNT
# define CRPRNT Control ('r')
#endif
#if defined CREPRINT && !defined CRPRNT
# define CRPRNT Control ('r')
#endif
#if defined VWERASE && !defined CWERASE
# define CWERASE Control ('w')
#endif
#if defined VLNEXT && !defined CLNEXT
# define CLNEXT Control ('v')
#endif
#if defined VDISCARD && !defined VFLUSHO
# define VFLUSHO VDISCARD
#endif
#if defined VFLUSH && !defined VFLUSHO	/* Ultrix 4.2 */
# define VFLUSHO VFLUSH
#endif
#if defined CTLECH && !defined ECHOCTL	/* Ultrix 4.3 */
# define ECHOCTL CTLECH
#endif
#if defined TCTLECH && !defined ECHOCTL	/* Ultrix 4.2 */
# define ECHOCTL TCTLECH
#endif
#if defined CRTKIL && !defined ECHOKE	/* Ultrix 4.2 and 4.3 */
# define ECHOKE CRTKIL
#endif
#if defined VFLUSHO && !defined CFLUSHO
# define CFLUSHO Control ('o')
#endif
#if defined VSTATUS && !defined CSTATUS
# define CSTATUS Control ('t')
#endif

/* Which speeds to set.  */
enum speed_setting
  {
    input_speed, output_speed, both_speeds
  };

/* What to output and how.  */
enum output_type
  {
    changed, all, recoverable	/* Default, -a, -g.  */
  };

/* Which member(s) of 'struct termios' a mode uses.  */
enum mode_type
  {
    control, input, output, local, combination
  };

/* Flags for 'struct mode_info'. */
#define SANE_SET 1		/* Set in 'sane' mode. */
#define SANE_UNSET 2		/* Unset in 'sane' mode. */
#define REV 4			/* Can be turned off by prepending '-'. */
#define OMIT 8			/* Don't display value. */
#define NO_SETATTR 16		/* tcsetattr not used to set mode bits.  */

/* Each mode.  */
struct mode_info
  {
    const char *name;		/* Name given on command line.  */
    enum mode_type type;	/* Which structure element to change. */
    char flags;			/* Setting and display options.  */
    unsigned long bits;		/* Bits to set for this mode.  */
    unsigned long mask;		/* Other bits to turn off for this mode.  */
  };

static struct mode_info const mode_info[] =
{
  {"parenb", control, REV, PARENB, 0},
  {"parodd", control, REV, PARODD, 0},
#ifdef CMSPAR
  {"cmspar", control, REV, CMSPAR, 0},
#endif
  {"cs5", control, 0, CS5, CSIZE},
  {"cs6", control, 0, CS6, CSIZE},
  {"cs7", control, 0, CS7, CSIZE},
  {"cs8", control, 0, CS8, CSIZE},
  {"hupcl", control, REV, HUPCL, 0},
  {"hup", control, REV | OMIT, HUPCL, 0},
  {"cstopb", control, REV, CSTOPB, 0},
  {"cread", control, SANE_SET | REV, CREAD, 0},
  {"clocal", control, REV, CLOCAL, 0},
#ifdef CRTSCTS
  {"crtscts", control, REV, CRTSCTS, 0},
#endif
#ifdef CDTRDSR
  {"cdtrdsr", control, REV, CDTRDSR, 0},
#endif

  {"ignbrk", input, SANE_UNSET | REV, IGNBRK, 0},
  {"brkint", input, SANE_SET | REV, BRKINT, 0},
  {"ignpar", input, REV, IGNPAR, 0},
  {"parmrk", input, REV, PARMRK, 0},
  {"inpck", input, REV, INPCK, 0},
  {"istrip", input, REV, ISTRIP, 0},
  {"inlcr", input, SANE_UNSET | REV, INLCR, 0},
  {"igncr", input, SANE_UNSET | REV, IGNCR, 0},
  {"icrnl", input, SANE_SET | REV, ICRNL, 0},
  {"ixon", input, REV, IXON, 0},
  {"ixoff", input, SANE_UNSET | REV, IXOFF, 0},
  {"tandem", input, REV | OMIT, IXOFF, 0},
#ifdef IUCLC
  {"iuclc", input, SANE_UNSET | REV, IUCLC, 0},
#endif
#ifdef IXANY
  {"ixany", input, SANE_UNSET | REV, IXANY, 0},
#endif
#ifdef IMAXBEL
  {"imaxbel", input, SANE_SET | REV, IMAXBEL, 0},
#endif
#ifdef IUTF8
  {"iutf8", input, SANE_UNSET | REV, IUTF8, 0},
#endif

  {"opost", output, SANE_SET | REV, OPOST, 0},
#ifdef OLCUC
  {"olcuc", output, SANE_UNSET | REV, OLCUC, 0},
#endif
#ifdef OCRNL
  {"ocrnl", output, SANE_UNSET | REV, OCRNL, 0},
#endif
#ifdef ONLCR
  {"onlcr", output, SANE_SET | REV, ONLCR, 0},
#endif
#ifdef ONOCR
  {"onocr", output, SANE_UNSET | REV, ONOCR, 0},
#endif
#ifdef ONLRET
  {"onlret", output, SANE_UNSET | REV, ONLRET, 0},
#endif
#ifdef OFILL
  {"ofill", output, SANE_UNSET | REV, OFILL, 0},
#endif
#ifdef OFDEL
  {"ofdel", output, SANE_UNSET | REV, OFDEL, 0},
#endif
#ifdef NLDLY
  {"nl1", output, SANE_UNSET, NL1, NLDLY},
  {"nl0", output, SANE_SET, NL0, NLDLY},
#endif
#ifdef CRDLY
  {"cr3", output, SANE_UNSET, CR3, CRDLY},
  {"cr2", output, SANE_UNSET, CR2, CRDLY},
  {"cr1", output, SANE_UNSET, CR1, CRDLY},
  {"cr0", output, SANE_SET, CR0, CRDLY},
#endif
#ifdef TABDLY
# ifdef TAB3
  {"tab3", output, SANE_UNSET, TAB3, TABDLY},
# endif
# ifdef TAB2
  {"tab2", output, SANE_UNSET, TAB2, TABDLY},
# endif
# ifdef TAB1
  {"tab1", output, SANE_UNSET, TAB1, TABDLY},
# endif
# ifdef TAB0
  {"tab0", output, SANE_SET, TAB0, TABDLY},
# endif
#else
# ifdef OXTABS
  {"tab3", output, SANE_UNSET, OXTABS, 0},
# endif
#endif
#ifdef BSDLY
  {"bs1", output, SANE_UNSET, BS1, BSDLY},
  {"bs0", output, SANE_SET, BS0, BSDLY},
#endif
#ifdef VTDLY
  {"vt1", output, SANE_UNSET, VT1, VTDLY},
  {"vt0", output, SANE_SET, VT0, VTDLY},
#endif
#ifdef FFDLY
  {"ff1", output, SANE_UNSET, FF1, FFDLY},
  {"ff0", output, SANE_SET, FF0, FFDLY},
#endif

  {"isig", local, SANE_SET | REV, ISIG, 0},
  {"icanon", local, SANE_SET | REV, ICANON, 0},
#ifdef IEXTEN
  {"iexten", local, SANE_SET | REV, IEXTEN, 0},
#endif
  {"echo", local, SANE_SET | REV, ECHO, 0},
  {"echoe", local, SANE_SET | REV, ECHOE, 0},
  {"crterase", local, REV | OMIT, ECHOE, 0},
  {"echok", local, SANE_SET | REV, ECHOK, 0},
  {"echonl", local, SANE_UNSET | REV, ECHONL, 0},
  {"noflsh", local, SANE_UNSET | REV, NOFLSH, 0},
#ifdef XCASE
  {"xcase", local, SANE_UNSET | REV, XCASE, 0},
#endif
#ifdef TOSTOP
  {"tostop", local, SANE_UNSET | REV, TOSTOP, 0},
#endif
#ifdef ECHOPRT
  {"echoprt", local, SANE_UNSET | REV, ECHOPRT, 0},
  {"prterase", local, REV | OMIT, ECHOPRT, 0},
#endif
#ifdef ECHOCTL
  {"echoctl", local, SANE_SET | REV, ECHOCTL, 0},
  {"ctlecho", local, REV | OMIT, ECHOCTL, 0},
#endif
#ifdef ECHOKE
  {"echoke", local, SANE_SET | REV, ECHOKE, 0},
  {"crtkill", local, REV | OMIT, ECHOKE, 0},
#endif
#ifdef FLUSHO
  {"flusho", local, SANE_UNSET | REV, FLUSHO, 0},
#endif
#if defined TIOCEXT
  {"extproc", local, SANE_UNSET | REV | NO_SETATTR, EXTPROC, 0},
#elif defined EXTPROC
  {"extproc", local, SANE_UNSET | REV, EXTPROC, 0},
#endif

  {"evenp", combination, REV | OMIT, 0, 0},
  {"parity", combination, REV | OMIT, 0, 0},
  {"oddp", combination, REV | OMIT, 0, 0},
  {"nl", combination, REV | OMIT, 0, 0},
  {"ek", combination, OMIT, 0, 0},
  {"sane", combination, OMIT, 0, 0},
  {"cooked", combination, REV | OMIT, 0, 0},
  {"raw", combination, REV | OMIT, 0, 0},
  {"pass8", combination, REV | OMIT, 0, 0},
  {"litout", combination, REV | OMIT, 0, 0},
  {"cbreak", combination, REV | OMIT, 0, 0},
#ifdef IXANY
  {"decctlq", combination, REV | OMIT, 0, 0},
#endif
#if defined TABDLY || defined OXTABS
  {"tabs", combination, REV | OMIT, 0, 0},
#endif
#if defined XCASE && defined IUCLC && defined OLCUC
  {"lcase", combination, REV | OMIT, 0, 0},
  {"LCASE", combination, REV | OMIT, 0, 0},
#endif
  {"crt", combination, OMIT, 0, 0},
  {"dec", combination, OMIT, 0, 0},

  {NULL, control, 0, 0, 0}
};

/* Control character settings.  */
struct control_info
  {
    const char *name;		/* Name given on command line.  */
    cc_t saneval;		/* Value to set for 'stty sane'.  */
    size_t offset;		/* Offset in c_cc.  */
  };

/* Control characters. */

static struct control_info const control_info[] =
{
  {"intr", CINTR, VINTR},
  {"quit", CQUIT, VQUIT},
  {"erase", CERASE, VERASE},
  {"kill", CKILL, VKILL},
  {"eof", CEOF, VEOF},
  {"eol", CEOL, VEOL},
#ifdef VEOL2
  {"eol2", CEOL2, VEOL2},
#endif
#ifdef VSWTCH
  {"swtch", CSWTCH, VSWTCH},
#endif
  {"start", CSTART, VSTART},
  {"stop", CSTOP, VSTOP},
  {"susp", CSUSP, VSUSP},
#ifdef VDSUSP
  {"dsusp", CDSUSP, VDSUSP},
#endif
#ifdef VREPRINT
  {"rprnt", CRPRNT, VREPRINT},
#else
# ifdef CREPRINT /* HPUX 10.20 needs this */
  {"rprnt", CRPRNT, CREPRINT},
# endif
#endif
#ifdef VWERASE
  {"werase", CWERASE, VWERASE},
#endif
#ifdef VLNEXT
  {"lnext", CLNEXT, VLNEXT},
#endif
#ifdef VFLUSHO
  {"flush", CFLUSHO, VFLUSHO},   /* deprecated compat option.  */
  {"discard", CFLUSHO, VFLUSHO},
#endif
#ifdef VSTATUS
  {"status", CSTATUS, VSTATUS},
#endif

  /* These must be last because of the display routines. */
  {"min", 1, VMIN},
  {"time", 0, VTIME},
  {NULL, 0, 0}
};

static char const *visible (cc_t ch);
static unsigned long int baud_to_value (speed_t speed);
static bool recover_mode (char const *arg, struct termios *mode);
static int screen_columns (void);
static bool set_mode (struct mode_info const *info, bool reversed,
                      struct termios *mode);
static unsigned long int integer_arg (const char *s, unsigned long int max);
static speed_t string_to_baud (const char *arg);
static tcflag_t *mode_type_flag (enum mode_type type, struct termios *mode);
static void display_all (struct termios *mode, char const *device_name);
static void display_changed (struct termios *mode);
static void display_recoverable (struct termios *mode);
static void display_settings (enum output_type output_type,
                              struct termios *mode,
                              const char *device_name);
static void display_speed (struct termios *mode, bool fancy);
static void display_window_size (bool fancy, char const *device_name);
static void sane_mode (struct termios *mode);
static void set_control_char (struct control_info const *info,
                              const char *arg,
                              struct termios *mode);
static void set_speed (enum speed_setting type, const char *arg,
                       struct termios *mode);
static void set_window_size (int rows, int cols, char const *device_name);

/* The width of the screen, for output wrapping. */
static int max_col;

/* Current position, to know when to wrap. */
static int current_col;

/* Default "drain" mode for tcsetattr.  */
static int tcsetattr_options = TCSADRAIN;

static struct option const longopts[] =
{
  {"all", no_argument, NULL, 'a'},
  {"save", no_argument, NULL, 'g'},
  {"file", required_argument, NULL, 'F'},
  {GETOPT_HELP_OPTION_DECL},
  {GETOPT_VERSION_OPTION_DECL},
  {NULL, 0, NULL, 0}
};

static void wrapf (const char *message, ...)
     __attribute__ ((__format__ (__printf__, 1, 2)));

/* Print format string MESSAGE and optional args.
   Wrap to next line first if it won't fit.
   Print a space first unless MESSAGE will start a new line. */

static void
wrapf (const char *message,...)
{
  va_list args;
  char *buf;
  int buflen;

  va_start (args, message);
  buflen = vasprintf (&buf, message, args);
  va_end (args);

  if (buflen < 0)
    xalloc_die ();

  if (0 < current_col)
    {
      if (max_col - current_col < buflen)
        {
          putchar ('\n');
          current_col = 0;
        }
      else
        {
          putchar (' ');
          current_col++;
        }
    }

  fputs (buf, stdout);
  free (buf);
  current_col += buflen;
}

void
usage (int status)
{
  if (status != EXIT_SUCCESS)
    emit_try_help ();
  else
    {
      printf (_("\
Usage: %s [-F DEVICE | --file=DEVICE] [SETTING]...\n\
  or:  %s [-F DEVICE | --file=DEVICE] [-a|--all]\n\
  or:  %s [-F DEVICE | --file=DEVICE] [-g|--save]\n\
"),
              program_name, program_name, program_name);
      fputs (_("\
Print or change terminal characteristics.\n\
"), stdout);

      emit_mandatory_arg_note ();

      fputs (_("\
  -a, --all          print all current settings in human-readable form\n\
  -g, --save         print all current settings in a stty-readable form\n\
  -F, --file=DEVICE  open and use the specified DEVICE instead of stdin\n\
"), stdout);
      fputs (HELP_OPTION_DESCRIPTION, stdout);
      fputs (VERSION_OPTION_DESCRIPTION, stdout);
      fputs (_("\
\n\
Optional - before SETTING indicates negation.  An * marks non-POSIX\n\
settings.  The underlying system defines which settings are available.\n\
"), stdout);
      fputs (_("\
\n\
Special characters:\n"), stdout);
#ifdef VFLUSHO
      fputs (_("\
 * discard CHAR  CHAR will toggle discarding of output\n\
"), stdout);
#endif
#ifdef VDSUSP
      fputs (_("\
 * dsusp CHAR    CHAR will send a terminal stop signal once input flushed\n\
"), stdout);
#endif
      fputs (_("\
   eof CHAR      CHAR will send an end of file (terminate the input)\n\
   eol CHAR      CHAR will end the line\n\
"), stdout);
#ifdef VEOL2
      fputs (_("\
 * eol2 CHAR     alternate CHAR for ending the line\n\
"), stdout);
#endif
      fputs (_("\
   erase CHAR    CHAR will erase the last character typed\n\
   intr CHAR     CHAR will send an interrupt signal\n\
   kill CHAR     CHAR will erase the current line\n\
"), stdout);
#ifdef VLNEXT
      fputs (_("\
 * lnext CHAR    CHAR will enter the next character quoted\n\
"), stdout);
#endif
#ifdef VSTATUS
      fputs (_("\
 * status CHAR   CHAR will send an info signal\n\
"), stdout);
#endif
      fputs (_("\
   quit CHAR     CHAR will send a quit signal\n\
"), stdout);
#if defined CREPRINT || defined VREPRINT
      fputs (_("\
 * rprnt CHAR    CHAR will redraw the current line\n\
"), stdout);
#endif
      fputs (_("\
   start CHAR    CHAR will restart the output after stopping it\n\
   stop CHAR     CHAR will stop the output\n\
   susp CHAR     CHAR will send a terminal stop signal\n\
"), stdout);
#ifdef VSWTCH
      fputs (_("\
 * swtch CHAR    CHAR will switch to a different shell layer\n\
"), stdout);
#endif
#ifdef VWERASE
      fputs (_("\
 * werase CHAR   CHAR will erase the last word typed\n\
"), stdout);
#endif
      fputs (_("\
\n\
Special settings:\n\
   N             set the input and output speeds to N bauds\n\
"), stdout);
#ifdef TIOCGWINSZ
      fputs (_("\
 * cols N        tell the kernel that the terminal has N columns\n\
 * columns N     same as cols N\n\
"), stdout);
#endif
      printf (_("\
 * [-]drain      wait for transmission before applying settings (%s by default)\
\n"), tcsetattr_options == TCSADRAIN ? _("on") : _("off"));
      fputs (_("\
   ispeed N      set the input speed to N\n\
"), stdout);
#ifdef HAVE_C_LINE
      fputs (_("\
 * line N        use line discipline N\n\
"), stdout);
#endif
      fputs (_("\
   min N         with -icanon, set N characters minimum for a completed read\n\
   ospeed N      set the output speed to N\n\
"), stdout);
#ifdef TIOCGWINSZ
      fputs (_("\
 * rows N        tell the kernel that the terminal has N rows\n\
 * size          print the number of rows and columns according to the kernel\n\
"), stdout);
#endif
      fputs (_("\
   speed         print the terminal speed\n\
   time N        with -icanon, set read timeout of N tenths of a second\n\
"), stdout);
      fputs (_("\
\n\
Control settings:\n\
   [-]clocal     disable modem control signals\n\
   [-]cread      allow input to be received\n\
"), stdout);
#ifdef CRTSCTS
      fputs (_("\
 * [-]crtscts    enable RTS/CTS handshaking\n\
"), stdout);
#endif
#ifdef CDTRDSR
      fputs (_("\
 * [-]cdtrdsr    enable DTR/DSR handshaking\n\
"), stdout);
#endif
      fputs (_("\
   csN           set character size to N bits, N in [5..8]\n\
"), stdout);
      fputs (_("\
   [-]cstopb     use two stop bits per character (one with '-')\n\
   [-]hup        send a hangup signal when the last process closes the tty\n\
   [-]hupcl      same as [-]hup\n\
   [-]parenb     generate parity bit in output and expect parity bit in input\n\
   [-]parodd     set odd parity (or even parity with '-')\n\
"), stdout);
#ifdef CMSPAR
      fputs (_("\
 * [-]cmspar     use \"stick\" (mark/space) parity\n\
"), stdout);
#endif
      fputs (_("\
\n\
Input settings:\n\
   [-]brkint     breaks cause an interrupt signal\n\
   [-]icrnl      translate carriage return to newline\n\
   [-]ignbrk     ignore break characters\n\
   [-]igncr      ignore carriage return\n\
   [-]ignpar     ignore characters with parity errors\n\
"), stdout);
#ifdef IMAXBEL
      fputs (_("\
 * [-]imaxbel    beep and do not flush a full input buffer on a character\n\
"), stdout);
#endif
      fputs (_("\
   [-]inlcr      translate newline to carriage return\n\
   [-]inpck      enable input parity checking\n\
   [-]istrip     clear high (8th) bit of input characters\n\
"), stdout);
#ifdef IUTF8
      fputs (_("\
 * [-]iutf8      assume input characters are UTF-8 encoded\n\
"), stdout);
#endif
#ifdef IUCLC
      fputs (_("\
 * [-]iuclc      translate uppercase characters to lowercase\n\
"), stdout);
#endif
#ifdef IXANY
      fputs (_("\
 * [-]ixany      let any character restart output, not only start character\n\
"), stdout);
#endif
      fputs (_("\
   [-]ixoff      enable sending of start/stop characters\n\
   [-]ixon       enable XON/XOFF flow control\n\
   [-]parmrk     mark parity errors (with a 255-0-character sequence)\n\
   [-]tandem     same as [-]ixoff\n\
"), stdout);
      fputs (_("\
\n\
Output settings:\n\
"), stdout);
#ifdef BSDLY
      fputs (_("\
 * bsN           backspace delay style, N in [0..1]\n\
"), stdout);
#endif
#ifdef CRDLY
      fputs (_("\
 * crN           carriage return delay style, N in [0..3]\n\
"), stdout);
#endif
#ifdef FFDLY
      fputs (_("\
 * ffN           form feed delay style, N in [0..1]\n\
"), stdout);
#endif
#ifdef NLDLY
      fputs (_("\
 * nlN           newline delay style, N in [0..1]\n\
"), stdout);
#endif
#ifdef OCRNL
      fputs (_("\
 * [-]ocrnl      translate carriage return to newline\n\
"), stdout);
#endif
#ifdef OFDEL
      fputs (_("\
 * [-]ofdel      use delete characters for fill instead of NUL characters\n\
"), stdout);
#endif
#ifdef OFILL
      fputs (_("\
 * [-]ofill      use fill (padding) characters instead of timing for delays\n\
"), stdout);
#endif
#ifdef OLCUC
      fputs (_("\
 * [-]olcuc      translate lowercase characters to uppercase\n\
"), stdout);
#endif
#ifdef ONLCR
      fputs (_("\
 * [-]onlcr      translate newline to carriage return-newline\n\
"), stdout);
#endif
#ifdef ONLRET
      fputs (_("\
 * [-]onlret     newline performs a carriage return\n\
"), stdout);
#endif
#ifdef ONOCR
      fputs (_("\
 * [-]onocr      do not print carriage returns in the first column\n\
"), stdout);
#endif
      fputs (_("\
   [-]opost      postprocess output\n\
"), stdout);
#if defined TABDLY || defined OXTABS
      fputs (_("\
 * tabN          horizontal tab delay style, N in [0..3]\n\
 * tabs          same as tab0\n\
 * -tabs         same as tab3\n\
"), stdout);
#endif
#ifdef VTDLY
      fputs (_("\
 * vtN           vertical tab delay style, N in [0..1]\n\
"), stdout);
#endif
      fputs (_("\
\n\
Local settings:\n\
   [-]crterase   echo erase characters as backspace-space-backspace\n\
"), stdout);
#ifdef ECHOKE
      fputs (_("\
 * crtkill       kill all line by obeying the echoprt and echoe settings\n\
 * -crtkill      kill all line by obeying the echoctl and echok settings\n\
"), stdout);
#endif
#ifdef ECHOCTL
      fputs (_("\
 * [-]ctlecho    echo control characters in hat notation ('^c')\n\
"), stdout);
#endif
      fputs (_("\
   [-]echo       echo input characters\n\
"), stdout);
#ifdef ECHOCTL
      fputs (_("\
 * [-]echoctl    same as [-]ctlecho\n\
"), stdout);
#endif
      fputs (_("\
   [-]echoe      same as [-]crterase\n\
   [-]echok      echo a newline after a kill character\n\
"), stdout);
#ifdef ECHOKE
      fputs (_("\
 * [-]echoke     same as [-]crtkill\n\
"), stdout);
#endif
      fputs (_("\
   [-]echonl     echo newline even if not echoing other characters\n\
"), stdout);
#ifdef ECHOPRT
      fputs (_("\
 * [-]echoprt    echo erased characters backward, between '\\' and '/'\n\
"), stdout);
#endif
#if defined EXTPROC || defined TIOCEXT
      fputs (_("\
 * [-]extproc    enable \"LINEMODE\"; useful with high latency links\n\
"), stdout);
#endif
#if defined FLUSHO
      fputs (_("\
 * [-]flusho     discard output\n\
"), stdout);
#endif
      printf (_("\
   [-]icanon     enable special characters: %s\n\
   [-]iexten     enable non-POSIX special characters\n\
"), "erase, kill"
#ifdef VWERASE
    ", werase"
#endif
#if defined CREPRINT || defined VREPRINT
    ", rprnt"
#endif
);
      fputs (_("\
   [-]isig       enable interrupt, quit, and suspend special characters\n\
   [-]noflsh     disable flushing after interrupt and quit special characters\n\
"), stdout);
#ifdef ECHOPRT
      fputs (_("\
 * [-]prterase   same as [-]echoprt\n\
"), stdout);
#endif
#ifdef TOSTOP
      fputs (_("\
 * [-]tostop     stop background jobs that try to write to the terminal\n\
"), stdout);
#endif
#ifdef XCASE
      fputs (_("\
 * [-]xcase      with icanon, escape with '\\' for uppercase characters\n\
"), stdout);
#endif
      fputs (_("\
\n\
Combination settings:\n\
"), stdout);
#if defined XCASE && defined IUCLC && defined OLCUC
      fputs (_("\
 * [-]LCASE      same as [-]lcase\n\
"), stdout);
#endif
      fputs (_("\
   cbreak        same as -icanon\n\
   -cbreak       same as icanon\n\
"), stdout);
      fputs (_("\
   cooked        same as brkint ignpar istrip icrnl ixon opost isig\n\
                 icanon, eof and eol characters to their default values\n\
   -cooked       same as raw\n\
"), stdout);
      printf (_("\
   crt           same as %s\n\
"), "echoe"
#ifdef ECHOCTL
    " echoctl"
#endif
#ifdef ECHOKE
    " echoke"
#endif
);
      printf (_("\
   dec           same as %s intr ^c erase 0177\n\
                 kill ^u\n\
"), "echoe"
#ifdef ECHOCTL
    " echoctl"
#endif
#ifdef ECHOKE
    " echoke"
#endif
#ifdef IXANY
    " -ixany"
#endif
);
#ifdef IXANY
      fputs (_("\
 * [-]decctlq    same as [-]ixany\n\
"), stdout);
#endif
      fputs (_("\
   ek            erase and kill characters to their default values\n\
   evenp         same as parenb -parodd cs7\n\
   -evenp        same as -parenb cs8\n\
"), stdout);
#if defined XCASE && defined IUCLC && defined OLCUC
      fputs (_("\
 * [-]lcase      same as xcase iuclc olcuc\n\
"), stdout);
#endif
      fputs (_("\
   litout        same as -parenb -istrip -opost cs8\n\
   -litout       same as parenb istrip opost cs7\n\
"), stdout);
      printf (_("\
   nl            same as %s\n\
   -nl           same as %s\n\
"), "-icrnl"
#ifdef ONLCR
   " -onlcr"
#endif
  , "icrnl -inlcr -igncr"
#ifdef ONLCR
   " onlcr"
#endif
#ifdef OCRNL
   " -ocrnl"
#endif
#ifdef ONLRET
   " -onlret"
#endif
);
      fputs (_("\
   oddp          same as parenb parodd cs7\n\
   -oddp         same as -parenb cs8\n\
   [-]parity     same as [-]evenp\n\
   pass8         same as -parenb -istrip cs8\n\
   -pass8        same as parenb istrip cs7\n\
"), stdout);
      printf (_("\
   raw           same as -ignbrk -brkint -ignpar -parmrk -inpck -istrip\n\
                 -inlcr -igncr -icrnl -ixon -ixoff -icanon -opost\n\
                 -isig%s min 1 time 0\n\
   -raw          same as cooked\n\
"),
#ifdef IUCLC
   " -iuclc"
#endif
#ifdef IXANY
   " -ixany"
#endif
#ifdef IMAXBEL
   " -imaxbel"
#endif
#ifdef XCASE
   " -xcase"
#endif
);
      printf (_("\
   sane          same as cread -ignbrk brkint -inlcr -igncr icrnl\n\
                 icanon iexten echo echoe echok -echonl -noflsh\n\
                 %s\n\
                 %s\n\
                 %s,\n\
                 all special characters to their default values\n\
"),
   "-ixoff"
#ifdef IUTF8
   " -iutf8"
#endif
#ifdef IUCLC
   " -iuclc"
#endif
#ifdef IXANY
   " -ixany"
#endif
#ifdef IMAXBEL
   " imaxbel"
#endif
#ifdef XCASE
   " -xcase"
#endif
#ifdef OLCUC
   " -olcuc"
#endif
#ifdef OCRNL
   " -ocrnl"
#endif

 , "opost"
#ifdef OFILL
   " -ofill"
#endif
#ifdef ONLCR
   " onlcr"
#endif
#ifdef ONOCR
   " -onocr"
#endif
#ifdef ONLRET
   " -onlret"
#endif
#ifdef NLDLY
   " nl0"
#endif
#ifdef CRDLY
   " cr0"
#endif
#ifdef TAB0
   " tab0"
#endif
#ifdef BSDLY
   " bs0"
#endif
#ifdef VTDLY
   " vt0"
#endif
#ifdef FFDLY
   " ff0"
#endif

 , "isig"
#ifdef TOSTOP
   " -tostop"
#endif
#ifdef OFDEL
   " -ofdel"
#endif
#ifdef ECHOPRT
   " -echoprt"
#endif
#ifdef ECHOCTL
   " echoctl"
#endif
#ifdef ECHOKE
   " echoke"
#endif
#ifdef EXTPROC
   " -extproc"
#endif
#ifdef FLUSHO
   " -flusho"
#endif
);
      fputs (_("\
\n\
Handle the tty line connected to standard input.  Without arguments,\n\
prints baud rate, line discipline, and deviations from stty sane.  In\n\
settings, CHAR is taken literally, or coded as in ^c, 0x37, 0177 or\n\
127; special values ^- or undef used to disable special characters.\n\
"), stdout);
      emit_ancillary_info (PROGRAM_NAME);
    }
  exit (status);
}


/* Apply specified settings to MODE, and update
   SPEED_WAS_SET and REQUIRE_SET_ATTR as required.
   If CHECKING is true, this function doesn't interact
   with a device, and only validates specified settings.  */

static void
apply_settings (bool checking, const char *device_name,
                char * const *settings, int n_settings,
                struct termios *mode, bool *speed_was_set,
                bool *require_set_attr)
{
  for (int k = 1; k < n_settings; k++)
    {
      char const *arg = settings[k];
      bool match_found = false;
      bool not_set_attr = false;
      bool reversed = false;
      int i;

      if (! arg)
        continue;

      if (arg[0] == '-')
        {
          ++arg;
          reversed = true;
        }
      if (STREQ (arg, "drain"))
        {
          tcsetattr_options = reversed ? TCSANOW : TCSADRAIN;
          continue;
        }
      for (i = 0; mode_info[i].name != NULL; ++i)
        {
          if (STREQ (arg, mode_info[i].name))
            {
              if ((mode_info[i].flags & NO_SETATTR) == 0)
                {
                  match_found = set_mode (&mode_info[i], reversed, mode);
                  *require_set_attr = true;
                }
              else
                match_found = not_set_attr = true;
              break;
            }
        }
      if (!match_found && reversed)
        {
          error (0, 0, _("invalid argument %s"), quote (arg - 1));
          usage (EXIT_FAILURE);
        }
      if (!match_found)
        {
          for (i = 0; control_info[i].name != NULL; ++i)
            {
              if (STREQ (arg, control_info[i].name))
                {
                  if (k == n_settings - 1)
                    {
                      error (0, 0, _("missing argument to %s"), quote (arg));
                      usage (EXIT_FAILURE);
                    }
                  match_found = true;
                  ++k;
                  set_control_char (&control_info[i], settings[k], mode);
                  *require_set_attr = true;
                  break;
                }
            }
        }
      if (!match_found || not_set_attr)
        {
          if (STREQ (arg, "ispeed"))
            {
              if (k == n_settings - 1)
                {
                  error (0, 0, _("missing argument to %s"), quote (arg));
                  usage (EXIT_FAILURE);
                }
              ++k;
              if (checking)
                continue;
              set_speed (input_speed, settings[k], mode);
              *speed_was_set = true;
              *require_set_attr = true;
            }
          else if (STREQ (arg, "ospeed"))
            {
              if (k == n_settings - 1)
                {
                  error (0, 0, _("missing argument to %s"), quote (arg));
                  usage (EXIT_FAILURE);
                }
              ++k;
              if (checking)
                continue;
              set_speed (output_speed, settings[k], mode);
              *speed_was_set = true;
              *require_set_attr = true;
            }
#ifdef TIOCEXT
          /* This is the BSD interface to "extproc".
            Even though it's an lflag, an ioctl is used to set it.  */
          else if (STREQ (arg, "extproc"))
            {
              int val = ! reversed;

              if (checking)
                continue;

              if (ioctl (STDIN_FILENO, TIOCEXT, &val) != 0)
                {
                  die (EXIT_FAILURE, errno, _("%s: error setting %s"),
                       quotef_n (0, device_name), quote_n (1, arg));
                }
            }
#endif
#ifdef TIOCGWINSZ
          else if (STREQ (arg, "rows"))
            {
              if (k == n_settings - 1)
                {
                  error (0, 0, _("missing argument to %s"), quote (arg));
                  usage (EXIT_FAILURE);
                }
              ++k;
              if (checking)
                continue;
              set_window_size (integer_arg (settings[k], INT_MAX), -1,
                               device_name);
            }
          else if (STREQ (arg, "cols")
                   || STREQ (arg, "columns"))
            {
              if (k == n_settings - 1)
                {
                  error (0, 0, _("missing argument to %s"), quote (arg));
                  usage (EXIT_FAILURE);
                }
              ++k;
              if (checking)
                continue;
              set_window_size (-1, integer_arg (settings[k], INT_MAX),
                               device_name);
            }
          else if (STREQ (arg, "size"))
            {
              if (checking)
                continue;
              max_col = screen_columns ();
              current_col = 0;
              display_window_size (false, device_name);
            }
#endif
#ifdef HAVE_C_LINE
          else if (STREQ (arg, "line"))
            {
              unsigned long int value;
              if (k == n_settings - 1)
                {
                  error (0, 0, _("missing argument to %s"), quote (arg));
                  usage (EXIT_FAILURE);
                }
              ++k;
              mode->c_line = value = integer_arg (settings[k], ULONG_MAX);
              if (mode->c_line != value)
                error (0, 0, _("invalid line discipline %s"),
                       quote (settings[k]));
              *require_set_attr = true;
            }
#endif
          else if (STREQ (arg, "speed"))
            {
              if (checking)
                continue;
              max_col = screen_columns ();
              display_speed (mode, false);
            }
          else if (string_to_baud (arg) != (speed_t) -1)
            {
              if (checking)
                continue;
              set_speed (both_speeds, arg, mode);
              *speed_was_set = true;
              *require_set_attr = true;
            }
          else
            {
              if (! recover_mode (arg, mode))
                {
                  error (0, 0, _("invalid argument %s"), quote (arg));
                  usage (EXIT_FAILURE);
                }
              *require_set_attr = true;
            }
        }
    }
}

int
main (int argc, char **argv)
{
  /* Initialize to all zeroes so there is no risk memcmp will report a
     spurious difference in an uninitialized portion of the structure.  */
  static struct termios mode;

  enum output_type output_type;
  int optc;
  int argi = 0;
  int opti = 1;
  bool require_set_attr;
  bool speed_was_set _GL_UNUSED;
  bool verbose_output;
  bool recoverable_output;
  bool noargs = true;
  char *file_name = NULL;
  const char *device_name;

  initialize_main (&argc, &argv);
  set_program_name (argv[0]);
  setlocale (LC_ALL, "");
  bindtextdomain (PACKAGE, LOCALEDIR);
  textdomain (PACKAGE);

  atexit (close_stdout);

  output_type = changed;
  verbose_output = false;
  recoverable_output = false;

  /* Don't print error messages for unrecognized options.  */
  opterr = 0;

  /* If any new options are ever added to stty, the short options MUST
     NOT allow any ambiguity with the stty settings.  For example, the
     stty setting "-gagFork" would not be feasible, since it will be
     parsed as "-g -a -g -F ork".  If you change anything about how
     stty parses options, be sure it still works with combinations of
     short and long options, --, POSIXLY_CORRECT, etc.  */

  while ((optc = getopt_long (argc - argi, argv + argi, "-agF:",
                              longopts, NULL))
         != -1)
    {
      switch (optc)
        {
        case 'a':
          verbose_output = true;
          output_type = all;
          break;

        case 'g':
          recoverable_output = true;
          output_type = recoverable;
          break;

        case 'F':
          if (file_name)
            die (EXIT_FAILURE, 0, _("only one device may be specified"));
          file_name = optarg;
          break;

        case_GETOPT_HELP_CHAR;

        case_GETOPT_VERSION_CHAR (PROGRAM_NAME, AUTHORS);

        default:
          /* Consider "drain" as an option rather than a setting,
             to support: alias stty='stty -drain'  etc.  */
          if (! STREQ (argv[argi + opti], "-drain")
              && ! STREQ (argv[argi + opti], "drain"))
            noargs = false;

          /* Skip the argument containing this unrecognized option;
             the 2nd pass will analyze it.  */
          argi += opti;

          /* Restart getopt_long from the first unskipped argument.  */
          opti = 1;
          optind = 0;

          break;
        }

      /* Clear fully-parsed arguments, so they don't confuse the 2nd pass.  */
      while (opti < optind)
        argv[argi + opti++] = NULL;
    }

  /* Specifying both -a and -g gets an error.  */
  if (verbose_output && recoverable_output)
    die (EXIT_FAILURE, 0,
         _("the options for verbose and stty-readable output styles are\n"
           "mutually exclusive"));

  /* Specifying any other arguments with -a or -g gets an error.  */
  if (!noargs && (verbose_output || recoverable_output))
    die (EXIT_FAILURE, 0,
         _("when specifying an output style, modes may not be set"));

  device_name = file_name ? file_name : _("standard input");

  if (!noargs && !verbose_output && !recoverable_output)
    {
      static struct termios check_mode;
      apply_settings (/* checking= */ true, device_name, argv, argc,
                      &check_mode, &speed_was_set, &require_set_attr);
    }

  if (file_name)
    {
      int fdflags;
      if (fd_reopen (STDIN_FILENO, device_name, O_RDONLY | O_NONBLOCK, 0) < 0)
        die (EXIT_FAILURE, errno, "%s", quotef (device_name));
      if ((fdflags = fcntl (STDIN_FILENO, F_GETFL)) == -1
          || fcntl (STDIN_FILENO, F_SETFL, fdflags & ~O_NONBLOCK) < 0)
        die (EXIT_FAILURE, errno, _("%s: couldn't reset non-blocking mode"),
             quotef (device_name));
    }

  if (tcgetattr (STDIN_FILENO, &mode))
    die (EXIT_FAILURE, errno, "%s", quotef (device_name));

  if (verbose_output || recoverable_output || noargs)
    {
      max_col = screen_columns ();
      current_col = 0;
      display_settings (output_type, &mode, device_name);
      return EXIT_SUCCESS;
    }

  speed_was_set = false;
  require_set_attr = false;
  apply_settings (/* checking= */ false, device_name, argv, argc,
                  &mode, &speed_was_set, &require_set_attr);

  if (require_set_attr)
    {
      /* Initialize to all zeroes so there is no risk memcmp will report a
         spurious difference in an uninitialized portion of the structure.  */
      static struct termios new_mode;

      if (tcsetattr (STDIN_FILENO, tcsetattr_options, &mode))
        die (EXIT_FAILURE, errno, "%s", quotef (device_name));

      /* POSIX (according to Zlotnick's book) tcsetattr returns zero if
         it performs *any* of the requested operations.  This means it
         can report 'success' when it has actually failed to perform
         some proper subset of the requested operations.  To detect
         this partial failure, get the current terminal attributes and
         compare them to the requested ones.  */

      if (tcgetattr (STDIN_FILENO, &new_mode))
        die (EXIT_FAILURE, errno, "%s", quotef (device_name));

      /* Normally, one shouldn't use memcmp to compare structures that
         may have 'holes' containing uninitialized data, but we have been
         careful to initialize the storage of these two variables to all
         zeroes.  One might think it more efficient simply to compare the
         modified fields, but that would require enumerating those fields --
         and not all systems have the same fields in this structure.  */

      if (memcmp (&mode, &new_mode, sizeof (mode)) != 0)
        {
#ifdef CIBAUD
          /* SunOS 4.1.3 (at least) has the problem that after this sequence,
             tcgetattr (&m1); tcsetattr (&m1); tcgetattr (&m2);
             sometimes (m1 != m2).  The only difference is in the four bits
             of the c_cflag field corresponding to the baud rate.  To save
             Sun users a little confusion, don't report an error if this
             happens.  But suppress the error only if we haven't tried to
             set the baud rate explicitly -- otherwise we'd never give an
             error for a true failure to set the baud rate.  */

          new_mode.c_cflag &= (~CIBAUD);
          if (speed_was_set || memcmp (&mode, &new_mode, sizeof (mode)) != 0)
#endif
            {
              die (EXIT_FAILURE, 0,
                   _("%s: unable to perform all requested operations"),
                   quotef (device_name));
#ifdef TESTING
              {
                size_t i;
                printf ("new_mode: mode\n");
                for (i = 0; i < sizeof (new_mode); i++)
                  printf ("0x%02x: 0x%02x\n",
                          *(((unsigned char *) &new_mode) + i),
                          *(((unsigned char *) &mode) + i));
              }
#endif
            }
        }
    }

  return EXIT_SUCCESS;
}

/* Return false if not applied because not reversible; otherwise
   return true.  */

static bool
set_mode (struct mode_info const *info, bool reversed, struct termios *mode)
{
  tcflag_t *bitsp;

  if (reversed && (info->flags & REV) == 0)
    return false;

  bitsp = mode_type_flag (info->type, mode);

  if (bitsp == NULL)
    {
      /* Combination mode. */
      if (STREQ (info->name, "evenp") || STREQ (info->name, "parity"))
        {
          if (reversed)
            mode->c_cflag = (mode->c_cflag & ~PARENB & ~CSIZE) | CS8;
          else
            mode->c_cflag = (mode->c_cflag & ~PARODD & ~CSIZE) | PARENB | CS7;
        }
      else if (STREQ (info->name, "oddp"))
        {
          if (reversed)
            mode->c_cflag = (mode->c_cflag & ~PARENB & ~CSIZE) | CS8;
          else
            mode->c_cflag = (mode->c_cflag & ~CSIZE) | CS7 | PARODD | PARENB;
        }
      else if (STREQ (info->name, "nl"))
        {
          if (reversed)
            {
              mode->c_iflag = (mode->c_iflag | ICRNL) & ~INLCR & ~IGNCR;
              mode->c_oflag = (mode->c_oflag
#ifdef ONLCR
                               | ONLCR
#endif
                )
#ifdef OCRNL
                & ~OCRNL
#endif
#ifdef ONLRET
                & ~ONLRET
#endif
                ;
            }
          else
            {
              mode->c_iflag = mode->c_iflag & ~ICRNL;
#ifdef ONLCR
              mode->c_oflag = mode->c_oflag & ~ONLCR;
#endif
            }
        }
      else if (STREQ (info->name, "ek"))
        {
          mode->c_cc[VERASE] = CERASE;
          mode->c_cc[VKILL] = CKILL;
        }
      else if (STREQ (info->name, "sane"))
        sane_mode (mode);
      else if (STREQ (info->name, "cbreak"))
        {
          if (reversed)
            mode->c_lflag |= ICANON;
          else
            mode->c_lflag &= ~ICANON;
        }
      else if (STREQ (info->name, "pass8"))
        {
          if (reversed)
            {
              mode->c_cflag = (mode->c_cflag & ~CSIZE) | CS7 | PARENB;
              mode->c_iflag |= ISTRIP;
            }
          else
            {
              mode->c_cflag = (mode->c_cflag & ~PARENB & ~CSIZE) | CS8;
              mode->c_iflag &= ~ISTRIP;
            }
        }
      else if (STREQ (info->name, "litout"))
        {
          if (reversed)
            {
              mode->c_cflag = (mode->c_cflag & ~CSIZE) | CS7 | PARENB;
              mode->c_iflag |= ISTRIP;
              mode->c_oflag |= OPOST;
            }
          else
            {
              mode->c_cflag = (mode->c_cflag & ~PARENB & ~CSIZE) | CS8;
              mode->c_iflag &= ~ISTRIP;
              mode->c_oflag &= ~OPOST;
            }
        }
      else if (STREQ (info->name, "raw") || STREQ (info->name, "cooked"))
        {
          if ((info->name[0] == 'r' && reversed)
              || (info->name[0] == 'c' && !reversed))
            {
              /* Cooked mode. */
              mode->c_iflag |= BRKINT | IGNPAR | ISTRIP | ICRNL | IXON;
              mode->c_oflag |= OPOST;
              mode->c_lflag |= ISIG | ICANON;
#if VMIN == VEOF
              mode->c_cc[VEOF] = CEOF;
#endif
#if VTIME == VEOL
              mode->c_cc[VEOL] = CEOL;
#endif
            }
          else
            {
              /* Raw mode. */
              mode->c_iflag = 0;
              mode->c_oflag &= ~OPOST;
              mode->c_lflag &= ~(ISIG | ICANON
#ifdef XCASE
                                 | XCASE
#endif
                );
              mode->c_cc[VMIN] = 1;
              mode->c_cc[VTIME] = 0;
            }
        }
#ifdef IXANY
      else if (STREQ (info->name, "decctlq"))
        {
          if (reversed)
            mode->c_iflag |= IXANY;
          else
            mode->c_iflag &= ~IXANY;
        }
#endif
#ifdef TABDLY
      else if (STREQ (info->name, "tabs"))
        {
          if (reversed)
            mode->c_oflag = (mode->c_oflag & ~TABDLY) | TAB3;
          else
            mode->c_oflag = (mode->c_oflag & ~TABDLY) | TAB0;
        }
#else
# ifdef OXTABS
      else if (STREQ (info->name, "tabs"))
        {
          if (reversed)
            mode->c_oflag = mode->c_oflag | OXTABS;
          else
            mode->c_oflag = mode->c_oflag & ~OXTABS;
        }
# endif
#endif
#if defined XCASE && defined IUCLC && defined OLCUC
      else if (STREQ (info->name, "lcase")
               || STREQ (info->name, "LCASE"))
        {
          if (reversed)
            {
              mode->c_lflag &= ~XCASE;
              mode->c_iflag &= ~IUCLC;
              mode->c_oflag &= ~OLCUC;
            }
          else
            {
              mode->c_lflag |= XCASE;
              mode->c_iflag |= IUCLC;
              mode->c_oflag |= OLCUC;
            }
        }
#endif
      else if (STREQ (info->name, "crt"))
        mode->c_lflag |= ECHOE
#ifdef ECHOCTL
          | ECHOCTL
#endif
#ifdef ECHOKE
          | ECHOKE
#endif
          ;
      else if (STREQ (info->name, "dec"))
        {
          mode->c_cc[VINTR] = 3;	/* ^C */
          mode->c_cc[VERASE] = 127;	/* DEL */
          mode->c_cc[VKILL] = 21;	/* ^U */
          mode->c_lflag |= ECHOE
#ifdef ECHOCTL
            | ECHOCTL
#endif
#ifdef ECHOKE
            | ECHOKE
#endif
            ;
#ifdef IXANY
          mode->c_iflag &= ~IXANY;
#endif
        }
    }
  else if (reversed)
    *bitsp = *bitsp & ~info->mask & ~info->bits;
  else
    *bitsp = (*bitsp & ~info->mask) | info->bits;

  return true;
}

static void
set_control_char (struct control_info const *info, const char *arg,
                  struct termios *mode)
{
  unsigned long int value;

  if (STREQ (info->name, "min") || STREQ (info->name, "time"))
    value = integer_arg (arg, TYPE_MAXIMUM (cc_t));
  else if (arg[0] == '\0' || arg[1] == '\0')
    value = to_uchar (arg[0]);
  else if (STREQ (arg, "^-") || STREQ (arg, "undef"))
    value = _POSIX_VDISABLE;
  else if (arg[0] == '^' && arg[1] != '\0')	/* Ignore any trailing junk. */
    {
      if (arg[1] == '?')
        value = 127;
      else
        value = to_uchar (arg[1]) & ~0140; /* Non-letters get weird results. */
    }
  else
    value = integer_arg (arg, TYPE_MAXIMUM (cc_t));
  mode->c_cc[info->offset] = value;
}

static void
set_speed (enum speed_setting type, const char *arg, struct termios *mode)
{
  speed_t baud;

  baud = string_to_baud (arg);
  if (type == input_speed || type == both_speeds)
    cfsetispeed (mode, baud);
  if (type == output_speed || type == both_speeds)
    cfsetospeed (mode, baud);
}

#ifdef TIOCGWINSZ

static int
get_win_size (int fd, struct winsize *win)
{
  int err = ioctl (fd, TIOCGWINSZ, (char *) win);
  return err;
}

static void
set_window_size (int rows, int cols, char const *device_name)
{
  struct winsize win;

  if (get_win_size (STDIN_FILENO, &win))
    {
      if (errno != EINVAL)
        die (EXIT_FAILURE, errno, "%s", quotef (device_name));
      memset (&win, 0, sizeof (win));
    }

  if (rows >= 0)
    win.ws_row = rows;
  if (cols >= 0)
    win.ws_col = cols;

# ifdef TIOCSSIZE
  /* Alexander Dupuy <dupuy@cs.columbia.edu> wrote:
     The following code deals with a bug in the SunOS 4.x (and 3.x?) kernel.
     This comment from sys/ttold.h describes Sun's twisted logic - a better
     test would have been (ts_lines > 64k || ts_cols > 64k || ts_cols == 0).
     At any rate, the problem is gone in Solaris 2.x.

     Unfortunately, the old TIOCSSIZE code does collide with TIOCSWINSZ,
     but they can be disambiguated by checking whether a "struct ttysize"
     structure's "ts_lines" field is greater than 64K or not.  If so,
     it's almost certainly a "struct winsize" instead.

     At any rate, the bug manifests itself when ws_row == 0; the symptom is
     that ws_row is set to ws_col, and ws_col is set to (ws_xpixel<<16)
     + ws_ypixel.  Since GNU stty sets rows and columns separately, this bug
     caused "stty rows 0 cols 0" to set rows to cols and cols to 0, while
     "stty cols 0 rows 0" would do the right thing.  On a little-endian
     machine like the sun386i, the problem is the same, but for ws_col == 0.

     The workaround is to do the ioctl once with row and col = 1 to set the
     pixel info, and then do it again using a TIOCSSIZE to set rows/cols.  */

  if (win.ws_row == 0 || win.ws_col == 0)
    {
      struct ttysize ttysz;

      ttysz.ts_lines = win.ws_row;
      ttysz.ts_cols = win.ws_col;

      win.ws_row = 1;
      win.ws_col = 1;

      if (ioctl (STDIN_FILENO, TIOCSWINSZ, (char *) &win))
        die (EXIT_FAILURE, errno, "%s", quotef (device_name));

      if (ioctl (STDIN_FILENO, TIOCSSIZE, (char *) &ttysz))
        die (EXIT_FAILURE, errno, "%s", quotef (device_name));
      return;
    }
# endif

  if (ioctl (STDIN_FILENO, TIOCSWINSZ, (char *) &win))
    die (EXIT_FAILURE, errno, "%s", quotef (device_name));
}

static void
display_window_size (bool fancy, char const *device_name)
{
  struct winsize win;

  if (get_win_size (STDIN_FILENO, &win))
    {
      if (errno != EINVAL)
        die (EXIT_FAILURE, errno, "%s", quotef (device_name));
      if (!fancy)
        die (EXIT_FAILURE, 0,
             _("%s: no size information for this device"),
             quotef (device_name));
    }
  else
    {
      wrapf (fancy ? "rows %d; columns %d;" : "%d %d\n",
             win.ws_row, win.ws_col);
      if (!fancy)
        current_col = 0;
    }
}
#endif

static int
screen_columns (void)
{
#ifdef TIOCGWINSZ
  struct winsize win;

  /* With Solaris 2.[123], this ioctl fails and errno is set to
     EINVAL for telnet (but not rlogin) sessions.
     On ISC 3.0, it fails for the console and the serial port
     (but it works for ptys).
     It can also fail on any system when stdout isn't a tty.
     In case of any failure, just use the default.  */
  if (get_win_size (STDOUT_FILENO, &win) == 0 && 0 < win.ws_col)
    return win.ws_col;
#endif
  {
    /* Use $COLUMNS if it's in [1..INT_MAX].  */
    char *col_string = getenv ("COLUMNS");
    long int n_columns;
    if (!(col_string != NULL
          && xstrtol (col_string, NULL, 0, &n_columns, "") == LONGINT_OK
          && 0 < n_columns
          && n_columns <= INT_MAX))
      n_columns = 80;
    return n_columns;
  }
}

static tcflag_t * _GL_ATTRIBUTE_PURE
mode_type_flag (enum mode_type type, struct termios *mode)
{
  switch (type)
    {
    case control:
      return &mode->c_cflag;

    case input:
      return &mode->c_iflag;

    case output:
      return &mode->c_oflag;

    case local:
      return &mode->c_lflag;

    case combination:
      return NULL;

    default:
      abort ();
    }
}

static void
display_settings (enum output_type output_type, struct termios *mode,
                  char const *device_name)
{
  switch (output_type)
    {
    case changed:
      display_changed (mode);
      break;

    case all:
      display_all (mode, device_name);
      break;

    case recoverable:
      display_recoverable (mode);
      break;
    }
}

static void
display_changed (struct termios *mode)
{
  int i;
  bool empty_line;
  tcflag_t *bitsp;
  unsigned long mask;
  enum mode_type prev_type = control;

  display_speed (mode, true);
#ifdef HAVE_C_LINE
  wrapf ("line = %d;", mode->c_line);
#endif
  putchar ('\n');
  current_col = 0;

  empty_line = true;
  for (i = 0; !STREQ (control_info[i].name, "min"); ++i)
    {
      if (mode->c_cc[control_info[i].offset] == control_info[i].saneval)
        continue;

#ifdef VFLUSHO
      /* 'flush' is the deprecated equivalent of 'discard'.  */
      if (STREQ (control_info[i].name, "flush"))
        continue;
#endif
      /* If swtch is the same as susp, don't print both.  */
#if VSWTCH == VSUSP
      if (STREQ (control_info[i].name, "swtch"))
        continue;
#endif
      /* If eof uses the same slot as min, only print whichever applies.  */
#if VEOF == VMIN
      if ((mode->c_lflag & ICANON) == 0
          && (STREQ (control_info[i].name, "eof")
              || STREQ (control_info[i].name, "eol")))
        continue;
#endif

      empty_line = false;
      wrapf ("%s = %s;", control_info[i].name,
             visible (mode->c_cc[control_info[i].offset]));
    }
  if ((mode->c_lflag & ICANON) == 0)
    {
      wrapf ("min = %lu; time = %lu;\n",
             (unsigned long int) mode->c_cc[VMIN],
             (unsigned long int) mode->c_cc[VTIME]);
    }
  else if (!empty_line)
    putchar ('\n');
  current_col = 0;

  empty_line = true;
  for (i = 0; mode_info[i].name != NULL; ++i)
    {
      if (mode_info[i].flags & OMIT)
        continue;
      if (mode_info[i].type != prev_type)
        {
          if (!empty_line)
            {
              putchar ('\n');
              current_col = 0;
              empty_line = true;
            }
          prev_type = mode_info[i].type;
        }

      bitsp = mode_type_flag (mode_info[i].type, mode);
      mask = mode_info[i].mask ? mode_info[i].mask : mode_info[i].bits;

      /* bitsp would be NULL only for "combination" modes, yet those
         are filtered out above via the OMIT flag.  Tell static analysis
         tools that it's ok to dereference bitsp here.  */
      assert (bitsp);

      if ((*bitsp & mask) == mode_info[i].bits)
        {
          if (mode_info[i].flags & SANE_UNSET)
            {
              wrapf ("%s", mode_info[i].name);
              empty_line = false;
            }
        }
      else if ((mode_info[i].flags & (SANE_SET | REV)) == (SANE_SET | REV))
        {
          wrapf ("-%s", mode_info[i].name);
          empty_line = false;
        }
    }
  if (!empty_line)
    putchar ('\n');
  current_col = 0;
}

static void
display_all (struct termios *mode, char const *device_name)
{
  int i;
  tcflag_t *bitsp;
  unsigned long mask;
  enum mode_type prev_type = control;

  display_speed (mode, true);
#ifdef TIOCGWINSZ
  display_window_size (true, device_name);
#endif
#ifdef HAVE_C_LINE
  wrapf ("line = %d;", mode->c_line);
#endif
  putchar ('\n');
  current_col = 0;

  for (i = 0; ! STREQ (control_info[i].name, "min"); ++i)
    {
#ifdef VFLUSHO
      /* 'flush' is the deprecated equivalent of 'discard'.  */
      if (STREQ (control_info[i].name, "flush"))
        continue;
#endif
      /* If swtch is the same as susp, don't print both.  */
#if VSWTCH == VSUSP
      if (STREQ (control_info[i].name, "swtch"))
        continue;
#endif
      /* If eof uses the same slot as min, only print whichever applies.  */
#if VEOF == VMIN
      if ((mode->c_lflag & ICANON) == 0
          && (STREQ (control_info[i].name, "eof")
              || STREQ (control_info[i].name, "eol")))
        continue;
#endif
      wrapf ("%s = %s;", control_info[i].name,
             visible (mode->c_cc[control_info[i].offset]));
    }
#if VEOF == VMIN
  if ((mode->c_lflag & ICANON) == 0)
#endif
    wrapf ("min = %lu; time = %lu;",
           (unsigned long int) mode->c_cc[VMIN],
           (unsigned long int) mode->c_cc[VTIME]);
  if (current_col != 0)
    putchar ('\n');
  current_col = 0;

  for (i = 0; mode_info[i].name != NULL; ++i)
    {
      if (mode_info[i].flags & OMIT)
        continue;
      if (mode_info[i].type != prev_type)
        {
          putchar ('\n');
          current_col = 0;
          prev_type = mode_info[i].type;
        }

      bitsp = mode_type_flag (mode_info[i].type, mode);
      mask = mode_info[i].mask ? mode_info[i].mask : mode_info[i].bits;
      assert (bitsp); /* See the identical assertion and comment above.  */
      if ((*bitsp & mask) == mode_info[i].bits)
        wrapf ("%s", mode_info[i].name);
      else if (mode_info[i].flags & REV)
        wrapf ("-%s", mode_info[i].name);
    }
  putchar ('\n');
  current_col = 0;
}

static void
display_speed (struct termios *mode, bool fancy)
{
  if (cfgetispeed (mode) == 0 || cfgetispeed (mode) == cfgetospeed (mode))
    wrapf (fancy ? "speed %lu baud;" : "%lu\n",
           baud_to_value (cfgetospeed (mode)));
  else
    wrapf (fancy ? "ispeed %lu baud; ospeed %lu baud;" : "%lu %lu\n",
           baud_to_value (cfgetispeed (mode)),
           baud_to_value (cfgetospeed (mode)));
  if (!fancy)
    current_col = 0;
}

static void
display_recoverable (struct termios *mode)
{
  size_t i;

  printf ("%lx:%lx:%lx:%lx",
          (unsigned long int) mode->c_iflag,
          (unsigned long int) mode->c_oflag,
          (unsigned long int) mode->c_cflag,
          (unsigned long int) mode->c_lflag);
  for (i = 0; i < NCCS; ++i)
    printf (":%lx", (unsigned long int) mode->c_cc[i]);
  putchar ('\n');
}

/* NOTE: identical to below, modulo use of tcflag_t */
static int
strtoul_tcflag_t (char const *s, int base, char **p, tcflag_t *result,
                  char delim)
{
  unsigned long ul;
  errno = 0;
  ul = strtoul (s, p, base);
  if (errno || **p != delim || *p == s || (tcflag_t) ul != ul)
    return -1;
  *result = ul;
  return 0;
}

/* NOTE: identical to above, modulo use of cc_t */
static int
strtoul_cc_t (char const *s, int base, char **p, cc_t *result, char delim)
{
  unsigned long ul;
  errno = 0;
  ul = strtoul (s, p, base);
  if (errno || **p != delim || *p == s || (cc_t) ul != ul)
    return -1;
  *result = ul;
  return 0;
}

/* Parse the output of display_recoverable.
   Return false if any part of it is invalid.  */
static bool
recover_mode (char const *arg, struct termios *mode)
{
  tcflag_t flag[4];
  char const *s = arg;
  size_t i;
  for (i = 0; i < 4; i++)
    {
      char *p;
      if (strtoul_tcflag_t (s, 16, &p, flag + i, ':') != 0)
        return false;
      s = p + 1;
    }
  mode->c_iflag = flag[0];
  mode->c_oflag = flag[1];
  mode->c_cflag = flag[2];
  mode->c_lflag = flag[3];

  for (i = 0; i < NCCS; ++i)
    {
      char *p;
      char delim = i < NCCS - 1 ? ':' : '\0';
      if (strtoul_cc_t (s, 16, &p, mode->c_cc + i, delim) != 0)
        return false;
      s = p + 1;
    }

  return true;
}

struct speed_map
{
  const char *string;		/* ASCII representation. */
  speed_t speed;		/* Internal form. */
  unsigned long int value;	/* Numeric value. */
};

static struct speed_map const speeds[] =
{
  {"0", B0, 0},
  {"50", B50, 50},
  {"75", B75, 75},
  {"110", B110, 110},
  {"134", B134, 134},
  {"134.5", B134, 134},
  {"150", B150, 150},
  {"200", B200, 200},
  {"300", B300, 300},
  {"600", B600, 600},
  {"1200", B1200, 1200},
  {"1800", B1800, 1800},
  {"2400", B2400, 2400},
  {"4800", B4800, 4800},
  {"9600", B9600, 9600},
  {"19200", B19200, 19200},
  {"38400", B38400, 38400},
  {"exta", B19200, 19200},
  {"extb", B38400, 38400},
#ifdef B57600
  {"57600", B57600, 57600},
#endif
#ifdef B115200
  {"115200", B115200, 115200},
#endif
#ifdef B230400
  {"230400", B230400, 230400},
#endif
#ifdef B460800
  {"460800", B460800, 460800},
#endif
#ifdef B500000
  {"500000", B500000, 500000},
#endif
#ifdef B576000
  {"576000", B576000, 576000},
#endif
#ifdef B921600
  {"921600", B921600, 921600},
#endif
#ifdef B1000000
  {"1000000", B1000000, 1000000},
#endif
#ifdef B1152000
  {"1152000", B1152000, 1152000},
#endif
#ifdef B1500000
  {"1500000", B1500000, 1500000},
#endif
#ifdef B2000000
  {"2000000", B2000000, 2000000},
#endif
#ifdef B2500000
  {"2500000", B2500000, 2500000},
#endif
#ifdef B3000000
  {"3000000", B3000000, 3000000},
#endif
#ifdef B3500000
  {"3500000", B3500000, 3500000},
#endif
#ifdef B4000000
  {"4000000", B4000000, 4000000},
#endif
  {NULL, 0, 0}
};

static speed_t _GL_ATTRIBUTE_PURE
string_to_baud (const char *arg)
{
  int i;

  for (i = 0; speeds[i].string != NULL; ++i)
    if (STREQ (arg, speeds[i].string))
      return speeds[i].speed;
  return (speed_t) -1;
}

static unsigned long int _GL_ATTRIBUTE_PURE
baud_to_value (speed_t speed)
{
  int i;

  for (i = 0; speeds[i].string != NULL; ++i)
    if (speed == speeds[i].speed)
      return speeds[i].value;
  return 0;
}

static void
sane_mode (struct termios *mode)
{
  int i;
  tcflag_t *bitsp;

  for (i = 0; control_info[i].name; ++i)
    {
#if VMIN == VEOF
      if (STREQ (control_info[i].name, "min"))
        break;
#endif
      mode->c_cc[control_info[i].offset] = control_info[i].saneval;
    }

  for (i = 0; mode_info[i].name != NULL; ++i)
    {
      if (mode_info[i].flags & NO_SETATTR)
        continue;

      if (mode_info[i].flags & SANE_SET)
        {
          bitsp = mode_type_flag (mode_info[i].type, mode);
          assert (bitsp); /* combination modes will not have SANE_SET.  */
          *bitsp = (*bitsp & ~mode_info[i].mask) | mode_info[i].bits;
        }
      else if (mode_info[i].flags & SANE_UNSET)
        {
          bitsp = mode_type_flag (mode_info[i].type, mode);
          assert (bitsp); /* combination modes will not have SANE_UNSET.  */
          *bitsp = *bitsp & ~mode_info[i].mask & ~mode_info[i].bits;
        }
    }
}

/* Return a string that is the printable representation of character CH.  */
/* Adapted from 'cat' by Torbjorn Granlund.  */

static const char *
visible (cc_t ch)
{
  static char buf[10];
  char *bpout = buf;

  if (ch == _POSIX_VDISABLE)
    return "<undef>";

  if (ch >= 32)
    {
      if (ch < 127)
        *bpout++ = ch;
      else if (ch == 127)
        {
          *bpout++ = '^';
          *bpout++ = '?';
        }
      else
        {
          *bpout++ = 'M';
          *bpout++ = '-';
          if (ch >= 128 + 32)
            {
              if (ch < 128 + 127)
                *bpout++ = ch - 128;
              else
                {
                  *bpout++ = '^';
                  *bpout++ = '?';
                }
            }
          else
            {
              *bpout++ = '^';
              *bpout++ = ch - 128 + 64;
            }
        }
    }
  else
    {
      *bpout++ = '^';
      *bpout++ = ch + 64;
    }
  *bpout = '\0';
  return (const char *) buf;
}

/* Parse string S as an integer, using decimal radix by default,
   but allowing octal and hex numbers as in C.  Reject values
   larger than MAXVAL.  */

static unsigned long int
integer_arg (const char *s, unsigned long int maxval)
{
  return xnumtoumax (s, 0, 0, maxval, "bB", _("invalid integer argument"), 0);
}
