/*
 * Copyright (c) 2008-2015 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 * 
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/*
 * Copyright (c) 1983, 1988, 1993
 *	Regents of the University of California.  All rights reserved.
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
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef lint
char const copyright[] =
"@(#) Copyright (c) 1983, 1988, 1993\n\
	Regents of the University of California.  All rights reserved.\n";
#endif /* not lint */

#include <sys/param.h>
#include <sys/file.h>
#include <sys/socket.h>
#include <sys/sys_domain.h>

#include <netinet/in.h>
#include <net/pfkeyv2.h>

#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <limits.h>
#include <netdb.h>
#include <nlist.h>
#include <paths.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "netstat.h"
#include <sys/types.h>
#include <sys/sysctl.h>

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <phk@FreeBSD.org> wrote this file.  As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return.   Poul-Henning Kamp
 * ----------------------------------------------------------------------------
 *
 * $Id: main.c,v 1.8 2004/10/14 22:24:09 lindak Exp $
 *
 */

struct protox {
	void	(*pr_cblocks)(uint32_t, char *, int);
					/* control blocks printing routine */
	void	(*pr_stats)(uint32_t, char *, int);
					/* statistics printing routine */
	void	(*pr_istats)(char *);	/* per/if statistics printing routine */
	char	*pr_name;		/* well-known name */
	int	pr_protocol;
} protox[] = {
	{ protopr,	tcp_stats,	NULL,	"tcp",	IPPROTO_TCP },
	{ protopr,	udp_stats,	NULL,	"udp",	IPPROTO_UDP },
	{ protopr,	NULL,		NULL,	"divert", IPPROTO_DIVERT },
	{ protopr,	ip_stats,	NULL,	"ip",	IPPROTO_RAW },
	{ protopr,	icmp_stats,	NULL,	"icmp",	IPPROTO_ICMP },
	{ protopr,	igmp_stats,	NULL,	"igmp",	IPPROTO_IGMP },
#ifdef IPSEC
	{ NULL,		ipsec_stats,	NULL,	"ipsec", IPPROTO_ESP},
#endif
	{ NULL,		arp_stats,	NULL,	"arp",	0 },
	{ mptcppr,	mptcp_stats,	NULL,	"mptcp", IPPROTO_TCP },
	{ NULL,		NULL,		NULL,	NULL,	0 }
};

#ifdef INET6
struct protox ip6protox[] = {
	{ protopr,	tcp_stats,	NULL,	"tcp",	IPPROTO_TCP },
	{ protopr,	udp_stats,	NULL,	"udp",	IPPROTO_UDP },
	{ protopr,	ip6_stats,	ip6_ifstats,	"ip6",	IPPROTO_RAW },
	{ protopr,	icmp6_stats,	icmp6_ifstats,	"icmp6",IPPROTO_ICMPV6 },
#ifdef IPSEC
	{ NULL,		ipsec_stats,	NULL,	"ipsec6", IPPROTO_ESP },
#endif
	{ NULL,		rip6_stats,	NULL,	"rip6",	IPPROTO_RAW },
	{ mptcppr,	mptcp_stats,	NULL,	"mptcp", IPPROTO_TCP },
	{ NULL,		NULL,		NULL,	NULL,	0 }
};
#endif /*INET6*/

#ifdef IPSEC
struct protox pfkeyprotox[] = {
	{ NULL,		pfkey_stats,	NULL,	"pfkey", PF_KEY_V2 },
	{ NULL,		NULL,		NULL,	NULL,	0 }
};
#endif


struct protox systmprotox[] = {
	{ systmpr,	NULL,		NULL,	"reg", 0 },
	{ systmpr,	kevt_stats,		NULL,	"kevt", SYSPROTO_EVENT },
	{ systmpr,	kctl_stats,	NULL,	"kctl", SYSPROTO_CONTROL },
	{ NULL,		NULL,		NULL,	NULL,	0 }
};

struct protox nstatprotox[] = {
	{ NULL,		print_nstat_stats,	NULL,	"nstat", 0 },
	{ NULL,		NULL,		NULL,	NULL,	0 }
};

struct protox ipcprotox[] = {
	{ NULL,		print_extbkidle_stats,	NULL,	"xbkidle", 0 },
	{ NULL,		NULL,		NULL,	NULL,	0 }
};

struct protox kernprotox[] = {
	{ NULL,		print_net_api_stats,	NULL,	"net_api", 0 },
	{ NULL,		NULL,		NULL,	NULL,	0 }
};

struct protox *protoprotox[] = {
	protox,
#ifdef INET6
	ip6protox,
#endif
#ifdef IPSEC
	pfkeyprotox,
#endif
	systmprotox,
	nstatprotox,
	ipcprotox,
	kernprotox,
	NULL
};

static void printproto (struct protox *, char *);
static void usage (void);
static struct protox *name2protox (char *);
static struct protox *knownname (char *);
#ifdef SRVCACHE
extern void _serv_cache_close();
#endif

int	Aflag;		/* show addresses of protocol control block */
int	aflag;		/* show all sockets (including servers) */
int	bflag;		/* show i/f total bytes in/out */
int	cflag;		/* show specific classq */
int	dflag;		/* show i/f dropped packets */
int	Fflag;		/* show i/f forwarded packets */
#if defined(__APPLE__)
int	gflag;		/* show group (multicast) routing or stats */
#endif
int	iflag;		/* show interfaces */
int	lflag;		/* show routing table with use and ref */
int	Lflag;		/* show size of listen queues */
int	mflag;		/* show memory stats */
int	nflag;		/* show addresses numerically */
static int pflag;	/* show given protocol */
int	prioflag = -1;	/* show packet priority statistics */
int	Rflag;		/* show reachability information */
int	rflag;		/* show routing tables (or routing stats) */
int	sflag;		/* show protocol statistics */
int	Sflag;		/* show additional i/f link status */
int	tflag;		/* show i/f watchdog timers */
int	vflag;		/* more verbose */
int	Wflag;		/* wide display */
int	qflag;		/* classq stats display */
int	Qflag;		/* opportunistic polling stats display */
int	xflag;		/* show extended link-layer reachability information */

int	cq = -1;	/* send classq index (-1 for all) */
int	interval;	/* repeat interval for i/f stats */

char	*interface;	/* desired i/f for stats, or NULL for all i/fs */
int	unit;		/* unit number for above */

int	af;		/* address family */

int
main(argc, argv)
	int argc;
	char *argv[];
{
	register struct protox *tp = NULL;  /* for printing cblocks & stats */
	int ch;

	af = AF_UNSPEC;

	while ((ch = getopt(argc, argv, "Aabc:dFf:gI:ikLlmnP:p:qQrRsStuvWw:x")) != -1)
		switch(ch) {
		case 'A':
			Aflag = 1;
			break;
		case 'a':
			aflag = 1;
			break;
		case 'b':
			bflag = 1;
			break;
		case 'c':
			cflag = 1;
			cq = atoi(optarg);
			break;
		case 'd':
			dflag = 1;
			break;
		case 'F':
			Fflag = 1;
			break;
		case 'f':
			if (strcmp(optarg, "ipx") == 0)
				af = AF_IPX;
			else if (strcmp(optarg, "inet") == 0)
				af = AF_INET;
#ifdef INET6
			else if (strcmp(optarg, "inet6") == 0)
				af = AF_INET6;
#endif /*INET6*/
#ifdef INET6
			else if (strcmp(optarg, "pfkey") == 0)
				af = PF_KEY;
#endif /*INET6*/
			else if (strcmp(optarg, "unix") == 0)
				af = AF_UNIX;
			else if (strcmp(optarg, "systm") == 0)
				af = AF_SYSTEM;
			else {
				errx(1, "%s: unknown address family", optarg);
			}
			break;
#if defined(__APPLE__)
		case 'g':
			gflag = 1;
			break;
#endif
		case 'I': {
			char *cp;

			iflag = 1;
			for (cp = interface = optarg; isalpha(*cp); cp++)
				continue;
			unit = atoi(cp);
			break;
		}
		case 'i':
			iflag = 1;
			break;
		case 'l':
			lflag = 1;
			break;
		case 'L':
			Lflag = 1;
			break;
		case 'm':
			mflag++;
			break;
		case 'n':
			nflag = 1;
			break;
		case 'P':
			prioflag = atoi(optarg);
			break;
		case 'p':
			if ((tp = name2protox(optarg)) == NULL) {
				errx(1, 
				     "%s: unknown or uninstrumented protocol",
				     optarg);
			}
			pflag = 1;
			break;
		case 'q':
			qflag++;
			break;
		case 'Q':
			Qflag++;
			break;
		case 'R':
			Rflag = 1;
			break;
		case 'r':
			rflag = 1;
			break;
		case 's':
			++sflag;
			break;
		case 'S':
			Sflag = 1;
			break;
		case 't':
			tflag = 1;
			break;
		case 'u':
			af = AF_UNIX;
			break;
		case 'v':
			vflag++;
			break;
		case 'W':
			Wflag = 1;
			break;
		case 'w':
			interval = atoi(optarg);
			iflag = 1;
			break;
		case 'x':
			xflag = 1;
			Rflag = 1;
			break;
		case '?':
		default:
			usage();
		}
	argv += optind;
	argc -= optind;

#define	BACKWARD_COMPATIBILITY
#ifdef	BACKWARD_COMPATIBILITY
	if (*argv) {
		if (isdigit(**argv)) {
			interval = atoi(*argv);
			if (interval <= 0)
				usage();
			++argv;
			iflag = 1;
		}
	}
#endif

	if (mflag) {
		mbpr();
		exit(0);
	}
	if (iflag && !sflag && !Sflag && !gflag && !qflag && !Qflag) {
		if (Rflag)
			intpr_ri(NULL);
		else
			intpr(NULL);
		exit(0);
	}
	if (rflag) {
		if (sflag)
			rt_stats();
		else
			routepr();
		exit(0);
	}
	if (qflag || Qflag) {
		if (interface == NULL) {
			fprintf(stderr, "%s statistics option "
			    "requires interface name\n", qflag ? "Queue" :
			    "Polling");
		} else if (qflag) {
			aqstatpr();
		} else {
			rxpollstatpr();
		}
		exit(0);
	}
	if (Sflag) {
		if (interface == NULL) {
			fprintf(stderr, "additional link status option"
				" requires interface name\n");
		} else {
			print_link_status(interface);
		}
		exit(0);
	}

#if defined(__APPLE__)
	if (gflag) {
		ifmalist_dump();
		exit(0);
	}
#endif

	if (tp) {
		printproto(tp, tp->pr_name);
		exit(0);
	}
	if (af == AF_INET || af == AF_UNSPEC)
		for (tp = protox; tp->pr_name; tp++)
			printproto(tp, tp->pr_name);
#ifdef INET6
	if (af == AF_INET6 || af == AF_UNSPEC)
		for (tp = ip6protox; tp->pr_name; tp++)
			printproto(tp, tp->pr_name);
#endif /*INET6*/
#ifdef IPSEC
	if (af == PF_KEY || af == AF_UNSPEC)
		for (tp = pfkeyprotox; tp->pr_name; tp++)
			printproto(tp, tp->pr_name);
#endif /*IPSEC*/
	if ((af == AF_UNIX || af == AF_UNSPEC) && !Lflag && !sflag)
		unixpr();
		
	if ((af == AF_SYSTEM || af == AF_UNSPEC) && !Lflag)
		for (tp = systmprotox; tp->pr_name; tp++)
			printproto(tp, tp->pr_name);
#if TARGET_OS_IPHONE
	if (af == AF_UNSPEC && !Lflag)
		for (tp = nstatprotox; tp->pr_name; tp++)
			printproto(tp, tp->pr_name);
#endif /* TARGET_OS_IPHONE */

	if (af == AF_UNSPEC && !Lflag)
		for (tp = ipcprotox; tp->pr_name; tp++)
			printproto(tp, tp->pr_name);

	if (af == AF_UNSPEC && !Lflag)
		for (tp = kernprotox; tp->pr_name; tp++)
			printproto(tp, tp->pr_name);


#ifdef SRVCACHE
	_serv_cache_close();
#endif
	exit(0);
}

/*
 * Print out protocol statistics or control blocks (per sflag).
 * If the interface was not specifically requested, and the symbol
 * is not in the namelist, ignore this one.
 */
static void
printproto(tp, name)
	register struct protox *tp;
	char *name;
{
	void (*pr)(uint32_t, char *, int);
	uint32_t off;

	if (sflag) {
		if (iflag && !pflag) {
			if (tp->pr_istats)
				intpr(tp->pr_istats);
			else if (vflag)
				printf("%s: no per-interface stats routine\n",
				    tp->pr_name);
			return;
		}
		else {
			pr = tp->pr_stats;
			if (!pr) {
				if (pflag && vflag)
					printf("%s: no stats routine\n",
					    tp->pr_name);
				return;
			}
			off = tp->pr_protocol;
		}
	} else {
		pr = tp->pr_cblocks;
		if (!pr) {
			if (pflag && vflag)
				printf("%s: no PCB routine\n", tp->pr_name);
			return;
		}
		off = tp->pr_protocol;
	}
	if (pr != NULL) {
		if (sflag && iflag && pflag)
			intervalpr(pr, off, name, af);
		else
			(*pr)(off, name, af);
	} else {
		printf("### no stats for %s\n", name);
	}
}

char *
plural(int n)
{
	return (n > 1 ? "s" : "");
}

char *
plurales(int n)
{
	return (n > 1 ? "es" : "");
}

char *
pluralies(int n)
{
	return (n > 1 ? "ies" : "y");
}

/*
 * Find the protox for the given "well-known" name.
 */
static struct protox *
knownname(char *name)
{
	struct protox **tpp, *tp;

	for (tpp = protoprotox; *tpp; tpp++)
		for (tp = *tpp; tp->pr_name; tp++)
			if (strcmp(tp->pr_name, name) == 0)
				return (tp);
	return (NULL);
}

/*
 * Find the protox corresponding to name.
 */
static struct protox *
name2protox(char *name)
{
	struct protox *tp;
	char **alias;			/* alias from p->aliases */
	struct protoent *p;

	/*
	 * Try to find the name in the list of "well-known" names. If that
	 * fails, check if name is an alias for an Internet protocol.
	 */
	if ((tp = knownname(name)) != NULL)
		return (tp);

	setprotoent(1);			/* make protocol lookup cheaper */
	while ((p = getprotoent()) != NULL) {
		/* assert: name not same as p->name */
		for (alias = p->p_aliases; *alias; alias++)
			if (strcmp(name, *alias) == 0) {
				endprotoent();
				return (knownname(p->p_name));
			}
	}
	endprotoent();
	return (NULL);
}

#define	NETSTAT_USAGE "\
Usage:	netstat [-AaLlnW] [-f address_family | -p protocol]\n\
	netstat [-gilns] [-f address_family]\n\
	netstat -i | -I interface [-w wait] [-abdgRtS]\n\
	netstat -s [-s] [-f address_family | -p protocol] [-w wait]\n\
	netstat -i | -I interface -s [-f address_family | -p protocol]\n\
	netstat -m [-m]\n\
	netstat -r [-Aaln] [-f address_family]\n\
	netstat -rs [-s]\n\
"

static void
usage(void)
{
	(void) fprintf(stderr, "%s\n", NETSTAT_USAGE);
	exit(1);
}

int
print_time(void)
{
    time_t now;
    struct tm tm;
    int num_written = 0;
    
    (void) time(&now);
    (void) localtime_r(&now, &tm);
    
    num_written += printf("%02d:%02d:%02d ", tm.tm_hour, tm.tm_min, tm.tm_sec);
    
    return (num_written);
}

