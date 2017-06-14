/*	$NetBSD: uname.c,v 1.10 1998/11/09 13:24:05 kleink Exp $	*/

/*
 * Copyright (c) 1994 Winning Strategies, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by Winning Strategies, Inc.
 * 4. The name of Winning Strategies, Inc. may not be used to endorse or 
 *    promote products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <sys/cdefs.h>
#ifndef lint
__RCSID("$NetBSD: uname.c,v 1.10 1998/11/09 13:24:05 kleink Exp $");
#endif /* not lint */

#include <sys/param.h>
#include <limits.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <err.h>
#ifdef __APPLE__
#include <string.h>
#endif /* __APPLE__ */

#include <sys/sysctl.h>
#include <sys/utsname.h>

#ifdef __APPLE__
#include <get_compat.h>
#else  /* !__APPLE__ */
#define COMPAT_MODE(a,b) (1)
#endif /* __APPLE__ */

int	main __P((int, char **));
static void usage __P((void));

/* Note that PRINT_MACHINE_ARCH is excluded from PRINT_ALL! */
#define	PRINT_SYSNAME		0x01
#define	PRINT_NODENAME		0x02
#define	PRINT_RELEASE		0x04
#define	PRINT_VERSION		0x08
#define	PRINT_MACHINE		0x10
#define	PRINT_MACHINE_ARCH	0x20
#define	PRINT_ALL		\
    (PRINT_SYSNAME|PRINT_NODENAME|PRINT_RELEASE|PRINT_VERSION|PRINT_MACHINE)

int
main(argc, argv) 
	int argc;
	char **argv;
{
	struct utsname u;
#ifndef __APPLE__
	char machine_arch[SYS_NMLN];
#endif /* !__APPLE__ */
	int c;
	int space = 0;
	int print_mask = 0;

	(void)setlocale(LC_ALL, "");

	while ((c = getopt(argc,argv,"amnprsv")) != -1) {
		switch (c) {
		case 'a':
			print_mask |= PRINT_ALL;
#ifdef __APPLE__
			if (!COMPAT_MODE("bin/uname", "Unix2003")) {
				print_mask |= PRINT_MACHINE_ARCH;
			}
#endif /* __APPLE__ */
			break;
		case 'm':
			print_mask |= PRINT_MACHINE;
			break;
		case 'n':
			print_mask |= PRINT_NODENAME;
			break;
		case 'p':
			print_mask |= PRINT_MACHINE_ARCH;
			break;
		case 'r': 
			print_mask |= PRINT_RELEASE;
			break;
		case 's': 
			print_mask |= PRINT_SYSNAME;
			break;
		case 'v':
			print_mask |= PRINT_VERSION;
			break;
		default:
			usage();
			/* NOTREACHED */
		}
	}
	
	if (optind != argc) {
		usage();
		/* NOTREACHED */
	}

	if (!print_mask) {
		print_mask = PRINT_SYSNAME;
	}

	if (uname(&u) != 0) {
		err(EXIT_FAILURE, "uname");
		/* NOTREACHED */
	}
#ifndef __APPLE__
	if (print_mask & PRINT_MACHINE_ARCH) {
		int mib[2] = { CTL_HW, HW_MACHINE_ARCH };
		size_t len = sizeof (machine_arch);

		if (sysctl(mib, sizeof (mib) / sizeof (mib[0]), machine_arch,
		    &len, NULL, 0) < 0)
			err(EXIT_FAILURE, "sysctl");
	}
#endif /* !__APPLE__ */

#ifdef __APPLE__
	/*
	 * Let's allow the user to override the output of uname via the shell environment.
	 * This is a useful feature for cross-compiling (eg. during an OS bringup).
	 * Otherwise, you have to hack your kernel with the desired strings.
	 */
	{
		char *s;
		s = getenv ("UNAME_SYSNAME");  if (s) strncpy (u.sysname,  s, sizeof (u.sysname));
		s = getenv ("UNAME_NODENAME"); if (s) strncpy (u.nodename, s, sizeof (u.nodename));
		s = getenv ("UNAME_RELEASE");  if (s) strncpy (u.release,  s, sizeof (u.release));
		s = getenv ("UNAME_VERSION");  if (s) strncpy (u.version,  s, sizeof (u.version));
		s = getenv ("UNAME_MACHINE");  if (s) strncpy (u.machine,  s, sizeof (u.machine));
	}
#endif /* __APPLE__ */

	if (print_mask & PRINT_SYSNAME) {
		space++;
		fputs(u.sysname, stdout);
	}
	if (print_mask & PRINT_NODENAME) {
		if (space++) putchar(' ');
		fputs(u.nodename, stdout);
	}
	if (print_mask & PRINT_RELEASE) {
		if (space++) putchar(' ');
		fputs(u.release, stdout);
	}
	if (print_mask & PRINT_VERSION) {
		if (space++) putchar(' ');
		fputs(u.version, stdout);
	}
	if (print_mask & PRINT_MACHINE) {
		if (space++) putchar(' ');
		fputs(u.machine, stdout);
	}
	if (print_mask & PRINT_MACHINE_ARCH) {
		if (space++) putchar(' ');
#ifndef __APPLE__
		fputs(machine_arch, stdout);
#else
#if defined(__ppc__) || defined(__ppc64__)
		fputs("powerpc", stdout);
#elif defined(__i386__) || defined(__x86_64__)
		fputs("i386", stdout);
#elif defined(__arm__) || defined(__arm64__)
		fputs("arm", stdout);
#else
		fputs("unknown", stdout);
#endif
#endif /* __APPLE__ */
	}
	putchar('\n');

	exit(EXIT_SUCCESS);
	/* NOTREACHED */
}

static void
usage()
{
	fprintf(stderr, "usage: uname [-amnprsv]\n");
	exit(EXIT_FAILURE);
}
