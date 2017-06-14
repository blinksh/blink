/*-
 * Copyright (c) 2000 Peter Wemm <peter@FreeBSD.org>
 * Copyright (c) 2000 Paul Saab <ps@FreeBSD.org>
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
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sys/cdefs.h>
__FBSDID("$FreeBSD: src/usr.bin/killall/killall.c,v 1.31 2004/07/29 18:36:35 maxim Exp $");

#include <sys/param.h>
#ifndef __APPLE__
#include <sys/jail.h>
#endif /* !__APPLE__ */
#include <sys/stat.h>
#include <sys/user.h>
#include <sys/sysctl.h>
#include <fcntl.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pwd.h>
#include <signal.h>
#include <regex.h>
#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <unistd.h>
#include <locale.h>

#include <getopt.h>
#define OPTIONS ("c:dej:lmst:u:vz")

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

static void __dead2
usage(void)
{

#ifdef __APPLE__
	fprintf(stderr, "usage: killall [-delmsvz] [-help]\n");
#else /* !__APPLE__ */
	fprintf(stderr, "usage: killall [-delmsvz] [-help] [-j jid]\n");
#endif /* __APPLE__ */
	fprintf(stderr,
	    "               [-u user] [-t tty] [-c cmd] [-SIGNAL] [cmd]...\n");
	fprintf(stderr, "At least one option or argument to specify processes must be given.\n");
	exit(1);
}

static char *
upper(const char *str)
{
	static char buf[80];
	char *s;

	strncpy(buf, str, sizeof(buf));
	buf[sizeof(buf) - 1] = '\0';
	for (s = buf; *s; s++)
		*s = toupper((unsigned char)*s);
	return buf;
}


static void
printsig(FILE *fp)
{
	const char	*const * p;
	int		cnt;
	int		offset = 0;

	for (cnt = NSIG, p = sys_signame + 1; --cnt; ++p) {
		offset += fprintf(fp, "%s ", upper(*p));
		if (offset >= 75 && cnt > 1) {
			offset = 0;
			fprintf(fp, "\n");
		}
	}
	fprintf(fp, "\n");
}

static void
nosig(char *name)
{

	warnx("unknown signal %s; valid signals:", name);
	printsig(stderr);
	exit(1);
}

/*
 * kludge_signal_args - remove any signal option (-SIGXXX, -##) from the argv array.
 */
void
kludge_signal_args(int *argc, char **argv, int *sig)
{
	int i;
	int shift = 0;
	int kludge = 1;
	char *ptr;
	const char *const *p;
	char		*ep;

	/* i = 1, skip program name */
	for (i = 1; i < *argc; i++) {
		/* Stop kludging if we encounter -- */
		if (strcmp(argv[i], "--") == 0)
			kludge = 0;
		ptr = argv[i] + 1;
		/* Only process arguments that start with - and do not look like an existing option. */
		if (kludge && *argv[i] == '-' && *ptr && strchr(OPTIONS, *ptr) == NULL) {
			if (isalpha(*ptr)) {
				if (strcmp(ptr, "help") == 0)
					usage();
				if (strncasecmp(ptr, "sig", 3) == 0)
					ptr += 3;
				for (*sig = NSIG, p = sys_signame + 1; --*sig; ++p)
					if (strcasecmp(*p, ptr) == 0) {
						*sig = p - sys_signame;
						break;
					}
				if (!*sig)
					nosig(ptr);
			} else if (isdigit(*ptr)) {
				*sig = strtol(ptr, &ep, 10);
				if (*ep)
					errx(1, "illegal signal number: %s", ptr);
				if (*sig < 0 || *sig >= NSIG)
					nosig(ptr);
			} else
				nosig(ptr);

			shift++;
			continue;
		}

		argv[i - shift] = argv[i];
	}

	for (i = *argc - shift; i < *argc; i++) {
		argv[i] = NULL;
	}

	*argc -= shift;
}

int
main(int ac, char **av)
{
	struct kinfo_proc *procs = NULL, *newprocs;
	struct stat	sb;
	struct passwd	*pw;
	regex_t		rgx;
	regmatch_t	pmatch;
	int		i, j;
	char		buf[256];
	char		*user = NULL;
	char		*tty = NULL;
	char		*cmd = NULL;
	int		vflag = 0;
	int		sflag = 0;
	int		dflag = 0;
	int		eflag = 0;
#ifndef __APPLE__
	int		jflag = 0;
#endif /* !__APPLE__*/
	int		mflag = 0;
	int		zflag = 0;
	uid_t		uid = 0;
	dev_t		tdev = 0;
	pid_t		mypid;
#ifdef __APPLE__
	char		*thiscmd;
#else /* !__APPLE__ */
	char		thiscmd[MAXCOMLEN + 1];
#endif /* __APPLE__ */
	pid_t		thispid;
#ifndef __APPLE__
	uid_t		thisuid;
#endif /* !__APPLE__ */
	dev_t		thistdev;
	int		sig = SIGTERM;
	char		*ep;
	int		errors = 0;
#ifndef __APPLE__
	int		jid;
#endif /* !__APPLE__ */
	int		mib[4];
	size_t		miblen;
	int		st, nprocs;
	size_t		size;
	int		matched;
	int		killed = 0;
	int		ch;

	setlocale(LC_ALL, "");

	kludge_signal_args(&ac, av, &sig);

	while ((ch = getopt(ac, av, OPTIONS)) != -1) {
		switch (ch) {
		case 'c':
			cmd = optarg;
			break;
		case 'd':
			dflag++;
			break;
		case 'e':
			eflag++;
			break;
#ifndef __APPLE__
		case 'j':
			jflag++;
			jid = strtol(optarg, &ep, 10);
			if (*ep)
				errx(1, "illegal jid: %s", optarg);
			if (jail_attach(jid) == -1)
				err(1, "jail_attach(): %d", jid);
			break;
#endif /* __APPLE__ */
		case 'l':
			printsig(stdout);
			exit(0);
		case 'm':
			mflag++;
			break;
		case 's':
			sflag++;
			break;
		case 't':
			tty = optarg;
			break;
		case 'u':
			user = optarg;
			break;
		case 'v':
			vflag++;
			break;
		case 'z':
			zflag++;
			break;
		default:
			usage();
		}
	}

	ac -= optind;
	av += optind;

#ifdef __APPLE__
	if (user == NULL && tty == NULL && cmd == NULL && ac == 0)
#else /* !__APPLE__*/
	if (user == NULL && tty == NULL && cmd == NULL && !jflag && ac == 0)
#endif /* __APPLE__ */
		usage();

	if (tty) {
		if (strncmp(tty, "/dev/", 5) == 0)
			snprintf(buf, sizeof(buf), "%s", tty);
		else if (strncmp(tty, "tty", 3) == 0)
			snprintf(buf, sizeof(buf), "/dev/%s", tty);
		else
			snprintf(buf, sizeof(buf), "/dev/tty%s", tty);
		if (stat(buf, &sb) < 0)
			err(1, "stat(%s)", buf);
		if (!S_ISCHR(sb.st_mode))
			errx(1, "%s: not a character device", buf);
		tdev = sb.st_rdev;
		if (dflag)
			printf("ttydev:0x%x\n", tdev);
	}
	if (user) {
		uid = strtol(user, &ep, 10);
		if (*user == '\0' || *ep != '\0') { /* was it a number? */
			pw = getpwnam(user);
			if (pw == NULL)
				errx(1, "user %s does not exist", user);
			uid = pw->pw_uid;
			if (dflag)
				printf("uid:%d\n", uid);
		}
	} else {
		uid = getuid();
		if (uid != 0) {
			pw = getpwuid(uid);
			if (pw)
				user = pw->pw_name;
			if (dflag)
				printf("uid:%d\n", uid);
		}
	}
	size = 0;
	mib[0] = CTL_KERN;
	mib[1] = KERN_PROC;
#ifdef __APPLE__
	mib[2] = KERN_PROC_ALL;
#else /* !__APPLE__ */
	mib[2] = KERN_PROC_PROC;
#endif /* __APPLE__ */
	mib[3] = 0;
	miblen = 3;

	if (user) {
		mib[2] = eflag ? KERN_PROC_UID : KERN_PROC_RUID;
		mib[3] = uid;
		miblen = 4;
	} else if (tty) {
		mib[2] = KERN_PROC_TTY;
		mib[3] = tdev;
		miblen = 4;
	}

	st = sysctl(mib, miblen, NULL, &size, NULL, 0);
	do {
		size += size / 10;
		newprocs = realloc(procs, size);
		if (newprocs == 0) {
			if (procs)
				free(procs);
			errx(1, "could not reallocate memory");
		}
		procs = newprocs;
		st = sysctl(mib, miblen, procs, &size, NULL, 0);
	} while (st == -1 && errno == ENOMEM);
	if (st == -1)
		err(1, "could not sysctl(KERN_PROC)");
	if (size % sizeof(struct kinfo_proc) != 0) {
		fprintf(stderr, "proc size mismatch (%zu total, %zu chunks)\n",
			size, sizeof(struct kinfo_proc));
		fprintf(stderr, "userland out of sync with kernel, recompile libkvm etc\n");
		exit(1);
	}
	nprocs = size / sizeof(struct kinfo_proc);
	if (dflag)
		printf("nprocs %d\n", nprocs);
	mypid = getpid();

	for (i = 0; i < nprocs; i++) {
#ifdef __APPLE__
		if (procs[i].kp_proc.p_stat == SZOMB && !zflag)
			continue;
		thispid = procs[i].kp_proc.p_pid;

		int mib[3], argmax;
		size_t syssize;
		char *procargs, *cp;

		mib[0] = CTL_KERN;
		mib[1] = KERN_ARGMAX;

		syssize = sizeof(argmax);
		if (sysctl(mib, 2, &argmax, &syssize, NULL, 0) == -1)
			continue;

		procargs = malloc(argmax);
		if (procargs == NULL)
			continue;

		mib[0] = CTL_KERN;
#if defined(__APPLE__) && TARGET_OS_EMBEDDED
		mib[1] = KERN_PROCARGS2;
#else
		mib[1] = KERN_PROCARGS;
#endif
		mib[2] = thispid;

		syssize = (size_t)argmax;
		if (sysctl(mib, 3, procargs, &syssize, NULL, 0) == -1) {
			free(procargs);
			continue;
		}

		for (cp = procargs; cp < &procargs[syssize]; cp++) {
			if (*cp == '\0') {
				break;
			}
		}

		if (cp == &procargs[syssize]) {
			free(procargs);
			continue;
		}

		for (; cp < &procargs[syssize]; cp++) {
			if (*cp != '\0') {
				break;
			}
		}

		if (cp == &procargs[syssize]) {
			free(procargs);
			continue;
		}

		/* Strip off any path that was specified */
		for (thiscmd = cp; (cp < &procargs[syssize]) && (*cp != '\0'); cp++) {
			if (*cp == '/') {
				thiscmd = cp + 1;
			}
		}

		thistdev = procs[i].kp_eproc.e_tdev;
#else /* !__APPLE__ */
		if (procs[i].ki_stat == SZOMB && !zflag)
			continue;
		thispid = procs[i].ki_pid;
		strncpy(thiscmd, procs[i].ki_comm, MAXCOMLEN);
		thiscmd[MAXCOMLEN] = '\0';
		thistdev = procs[i].ki_tdev;
#endif /* __APPLE__ */
#ifndef __APPLE__
		if (eflag)
			thisuid = procs[i].ki_uid;	/* effective uid */
		else
			thisuid = procs[i].ki_ruid;	/* real uid */
#endif /* !__APPLE__ */

		if (thispid == mypid) {
#ifdef __APPLE__
			free(procargs);
#endif /* __APPLE__ */
			continue;
		}
		matched = 1;
#ifndef __APPLE__
		if (user) {
			if (thisuid != uid)
				matched = 0;
		}
#endif /* !__APPLE__ */
		if (tty) {
			if (thistdev != tdev)
				matched = 0;
		}
		if (cmd) {
			if (mflag) {
				if (regcomp(&rgx, cmd,
				    REG_EXTENDED|REG_NOSUB) != 0) {
					mflag = 0;
					warnx("%s: illegal regexp", cmd);
				}
			}
			if (mflag) {
				pmatch.rm_so = 0;
				pmatch.rm_eo = strlen(thiscmd);
				if (regexec(&rgx, thiscmd, 0, &pmatch,
				    REG_STARTEND) != 0)
					matched = 0;
				regfree(&rgx);
			} else {
				if (strncmp(thiscmd, cmd, MAXCOMLEN) != 0)
					matched = 0;
			}
		}
#ifndef __APPLE__
		if (jflag && thispid == getpid())
			matched = 0;
#endif /* !__APPLE__ */
		if (matched == 0) {
#ifdef __APPLE__
			free(procargs);
#endif /* !__APPLE__ */
			continue;
		}
		if (ac > 0)
			matched = 0;
		for (j = 0; j < ac; j++) {
			if (mflag) {
				if (regcomp(&rgx, av[j],
				    REG_EXTENDED|REG_NOSUB) != 0) {
					mflag = 0;
					warnx("%s: illegal regexp", av[j]);
				}
			}
			if (mflag) {
				pmatch.rm_so = 0;
				pmatch.rm_eo = strlen(thiscmd);
				if (regexec(&rgx, thiscmd, 0, &pmatch,
				    REG_STARTEND) == 0)
					matched = 1;
				regfree(&rgx);
			} else {
				if (strcmp(thiscmd, av[j]) == 0)
					matched = 1;
			}
			if (matched)
				break;
		}
		if (matched == 0) {
#ifdef __APPLE__
			free(procargs);
#endif /* __APPLE__ */
			continue;
		}
		if (dflag)
#ifdef __APPLE__
			printf("sig:%d, cmd:%s, pid:%d, dev:0x%x\n", sig,
			    thiscmd, thispid, thistdev);
#else /* !__APPLE__ */
			printf("sig:%d, cmd:%s, pid:%d, dev:0x%x uid:%d\n", sig,
			    thiscmd, thispid, thistdev, thisuid);
#endif /* __APPLE__ */

		if (vflag || sflag)
			printf("kill -%s %d\n", upper(sys_signame[sig]),
			    thispid);

		killed++;
		if (!dflag && !sflag) {
			if (kill(thispid, sig) < 0 /* && errno != ESRCH */ ) {
				warn("warning: kill -%s %d",
				    upper(sys_signame[sig]), thispid);
				errors = 1;
			}
		}
#ifdef __APPLE__
		free(procargs);
#endif /* __APPLE__ */
	}
	if (killed == 0) {
		fprintf(stderr, "No matching processes %swere found\n",
		    getuid() != 0 ? "belonging to you " : "");
		errors = 1;
	}
	exit(errors);
}
