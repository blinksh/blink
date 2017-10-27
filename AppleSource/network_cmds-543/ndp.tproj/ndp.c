/*
 * Copyright (c) 2009-2013 Apple Inc. All rights reserved.
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
 * Copyright (C) 1995, 1996, 1997, 1998, and 1999 WIDE Project.
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
 * 3. Neither the name of the project nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
/*
 * Copyright (c) 1984, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Sun Microsystems, Inc.
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

/*
 * Based on:
 * "@(#) Copyright (c) 1984, 1993\n\
 *	The Regents of the University of California.  All rights reserved.\n";
 *
 * "@(#)arp.c	8.2 (Berkeley) 1/2/94";
 */

/*
 * ndp - display, set, delete and flush neighbor cache
 */

#include <stdint.h>
#include <sys/param.h>
#include <sys/file.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <sys/queue.h>

#include <net/if.h>
#include <net/if_var.h>
#include <net/if_dl.h>
#include <net/if_types.h>
#include <net/route.h>

#include <netinet/in.h>
#include <netinet/if_ether.h>

#include <netinet/icmp6.h>
#include <netinet6/in6_var.h>
#include <netinet6/nd6.h>

#include <arpa/inet.h>

#include <netdb.h>
#include <errno.h>
#include <nlist.h>
#include <stdio.h>
#include <string.h>
#include <paths.h>
#include <err.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>

/* packing rule for routing socket */
#define	ROUNDUP(a) \
	((a) > 0 ? (1 + (((a) - 1) | (sizeof (uint32_t) - 1))) : \
	sizeof (uint32_t))
#define	ADVANCE(x, n) (x += ROUNDUP((n)->sa_len))

static int pid;
static int cflag;
static int nflag;
static int tflag;
static int32_t thiszone = 0;	/* time difference with gmt */
static int s = -1;
static int repeat = 0;

static char host_buf[NI_MAXHOST];		/* getnameinfo() */
static char ifix_buf[IFNAMSIZ];		/* if_indextoname() */

static int file(char *);
static void getsocket(void);
static int set(int, char **);
static void get(char *);
static int delete(char *);
static void dump(struct in6_addr *);
static void dump_ext(struct in6_addr *, int);
static struct in6_nbrinfo *getnbrinfo(struct in6_addr *, int, int);
static char *ether_str(struct sockaddr_dl *);
static int ndp_ether_aton(char *, u_char *);
static void usage(void);
static int rtmsg(int);
static void ifinfo(int, char **);
static void rtrlist(void);
static void plist(void);
static void pfx_flush(void);
static void rtrlist(void);
static void rtr_flush(void);
static void harmonize_rtr(void);
static void getdefif(void);
static void setdefif(char *);
static char *sec2str(time_t);
static char *ether_str(struct sockaddr_dl *);
static void ts_print(const struct timeval *);
static void read_cga_parameters(void);
static void write_cga_parameters(const char[]);

static char *rtpref_str[] = {
	"medium",		/* 00 */
	"high",			/* 01 */
	"rsv",			/* 10 */
	"low"			/* 11 */
};

int
main(int argc, char **argv)
{
	int ch;
	int aflag = 0, dflag = 0, sflag = 0, Hflag = 0, pflag = 0, rflag = 0,
	    Pflag = 0, Rflag = 0, lflag = 0, xflag = 0, wflag = 0;

	pid = getpid();
	while ((ch = getopt(argc, argv, "acndfIilprstA:HPRxwW")) != -1)
		switch ((char) ch) {
		case 'a':
			aflag = 1;
			break;
		case 'c':
			cflag = 1;
			break;
		case 'd':
			dflag = 1;
			break;
		case 'I':
			if (argc > 2)
				setdefif(argv[2]);
			getdefif(); /* always call it to print the result */
			exit(0);
		case 'i' :
			argc -= optind;
			argv += optind;
			if (argc < 1)
				usage();
			ifinfo(argc, argv);
			exit(0);
		case 'n':
			nflag = 1;
			continue;
		case 'p':
			pflag = 1;
			break;
		case 'f' :
			if (argc != 3)
				usage();
			file(argv[2]);
			exit(0);
		case 'l' :
			lflag = 1;
			break;
		case 'r' :
			rflag = 1;
			break;
		case 's':
			sflag = 1;
			break;
		case 't':
			tflag = 1;
			break;
		case 'A':
			aflag = 1;
			repeat = atoi(optarg);
			if (repeat < 0)
				usage();
			break;
		case 'H' :
			Hflag = 1;
			break;
		case 'P':
			Pflag = 1;
			break;
		case 'R':
			Rflag = 1;
			break;
		case 'x':
			xflag = 1;
			lflag = 1;
			break;
		case 'w':
			wflag = 1;
			break;
		case 'W':
			if (argc != 3)
				usage();
			write_cga_parameters(argv[2]);
			exit(0);
		default:
			usage();
		}

	argc -= optind;
	argv += optind;

	if (aflag || cflag) {
		if (lflag)
			dump_ext(0, xflag);
		else
			dump(0);
		exit(0);
	}
	if (dflag) {
		if (argc != 1)
			usage();
		delete(argv[0]);
		exit(0);
	}
	if (pflag) {
		plist();
		exit(0);
	}
	if (rflag) {
		rtrlist();
		exit(0);
	}
	if (sflag) {
		if (argc < 2 || argc > 4)
			usage();
		exit(set(argc, argv) ? 1 : 0);
	}
	if (Hflag) {
		harmonize_rtr();
		exit(0);
	}
	if (Pflag) {
		pfx_flush();
		exit(0);
	}
	if (Rflag) {
		rtr_flush();
		exit(0);
	}
	if (wflag) {
		read_cga_parameters();
		exit(0);
	}

	if (argc != 1)
		usage();
	get(argv[0]);
	exit(0);
}

/*
 * Process a file to set standard ndp entries
 */
static int
file(char *name)
{
	FILE *fp;
	int i, retval;
	char line[100], arg[5][50], *args[5];

	if ((fp = fopen(name, "r")) == NULL) {
		fprintf(stderr, "ndp: cannot open %s\n", name);
		exit(1);
	}
	args[0] = &arg[0][0];
	args[1] = &arg[1][0];
	args[2] = &arg[2][0];
	args[3] = &arg[3][0];
	args[4] = &arg[4][0];
	retval = 0;
	while (fgets(line, 100, fp) != NULL) {
		i = sscanf(line, "%s %s %s %s %s", arg[0], arg[1], arg[2],
		    arg[3], arg[4]);
		if (i < 2) {
			fprintf(stderr, "ndp: bad line: %s\n", line);
			retval = 1;
			continue;
		}
		if (set(i, args))
			retval = 1;
	}
	fclose(fp);
	return (retval);
}

static void
getsocket(void)
{
	if (s < 0) {
		s = socket(PF_ROUTE, SOCK_RAW, 0);
		if (s < 0) {
			perror("ndp: socket");
			exit(1);
		}
	}
}

struct sockaddr_in6 so_mask = {sizeof (so_mask), AF_INET6 };
struct sockaddr_in6 blank_sin = {sizeof (blank_sin), AF_INET6 }, sin_m;
struct sockaddr_dl blank_sdl = {sizeof (blank_sdl), AF_LINK }, sdl_m;
int expire_time, flags, found_entry;
struct {
	struct	rt_msghdr m_rtm;
	char	m_space[512];
} m_rtmsg;

/*
 * Set an individual neighbor cache entry
 */
static int
set(int argc, char **argv)
{
	register struct sockaddr_in6 *sin = &sin_m;
	register struct sockaddr_dl *sdl;
	register struct rt_msghdr *rtm = &(m_rtmsg.m_rtm);
	struct addrinfo hints, *res;
	int gai_error;
	u_char *ea;
	char *host = argv[0], *eaddr = argv[1];

	getsocket();
	argc -= 2;
	argv += 2;
	sdl_m = blank_sdl;
	sin_m = blank_sin;

	bzero(&hints, sizeof (hints));
	hints.ai_family = AF_INET6;
	gai_error = getaddrinfo(host, NULL, &hints, &res);
	if (gai_error) {
		fprintf(stderr, "ndp: %s: %s\n", host,
			gai_strerror(gai_error));
		return (1);
	}
	sin->sin6_addr = ((struct sockaddr_in6 *)res->ai_addr)->sin6_addr;
#ifdef __KAME__
	if (IN6_IS_ADDR_LINKLOCAL(&sin->sin6_addr)) {
		*(u_int16_t *)&sin->sin6_addr.s6_addr[2] =
		    htons(((struct sockaddr_in6 *)res->ai_addr)->sin6_scope_id);
	}
#endif
	ea = (u_char *)LLADDR(&sdl_m);
	if (ndp_ether_aton(eaddr, ea) == 0)
		sdl_m.sdl_alen = 6;
	flags = expire_time = 0;
	while (argc-- > 0) {
		if (strncmp(argv[0], "temp", 4) == 0) {
			struct timeval time;
			gettimeofday(&time, 0);
			expire_time = time.tv_sec + 20 * 60;
		} else if (strncmp(argv[0], "proxy", 5) == 0)
			flags |= RTF_ANNOUNCE;
		argv++;
	}
	if (rtmsg(RTM_GET) < 0) {
		perror(host);
		return (1);
	}
	sin = (struct sockaddr_in6 *)(rtm + 1);
	sdl = (struct sockaddr_dl *)(ROUNDUP(sin->sin6_len) + (char *)sin);
	if (IN6_ARE_ADDR_EQUAL(&sin->sin6_addr, &sin_m.sin6_addr)) {
		if (sdl->sdl_family == AF_LINK &&
		    (rtm->rtm_flags & RTF_LLINFO) &&
		    !(rtm->rtm_flags & RTF_GATEWAY)) switch (sdl->sdl_type) {
		case IFT_ETHER: case IFT_FDDI: case IFT_ISO88023:
		case IFT_ISO88024: case IFT_ISO88025:
			goto overwrite;
		}
		/*
		 * IPv4 arp command retries with sin_other = SIN_PROXY here.
		 */
		fprintf(stderr, "set: cannot configure a new entry\n");
		return (1);
	}

overwrite:
	if (sdl->sdl_family != AF_LINK) {
		printf("cannot intuit interface index and type for %s\n", host);
		return (1);
	}
	sdl_m.sdl_type = sdl->sdl_type;
	sdl_m.sdl_index = sdl->sdl_index;
	return (rtmsg(RTM_ADD));
}

/*
 * Display an individual neighbor cache entry
 */
static void
get(char *host)
{
	struct sockaddr_in6 *sin = &sin_m;
	struct addrinfo hints, *res;
	int gai_error;

	sin_m = blank_sin;
	bzero(&hints, sizeof (hints));
	hints.ai_family = AF_INET6;
	gai_error = getaddrinfo(host, NULL, &hints, &res);
	if (gai_error) {
		fprintf(stderr, "ndp: %s: %s\n", host,
			gai_strerror(gai_error));
		return;
	}
	sin->sin6_addr = ((struct sockaddr_in6 *)res->ai_addr)->sin6_addr;
#ifdef __KAME__
	if (IN6_IS_ADDR_LINKLOCAL(&sin->sin6_addr)) {
		*(u_int16_t *)&sin->sin6_addr.s6_addr[2] =
		    htons(((struct sockaddr_in6 *)res->ai_addr)->sin6_scope_id);
	}
#endif
	dump(&sin->sin6_addr);
	if (found_entry == 0) {
		getnameinfo((struct sockaddr *)sin, sin->sin6_len, host_buf,
		    sizeof (host_buf), NULL, 0, NI_WITHSCOPEID | (nflag ?
		    NI_NUMERICHOST : 0));
		printf("%s (%s) -- no entry\n", host, host_buf);
		exit(1);
	}
}

/*
 * Delete a neighbor cache entry
 */
static int
delete(char *host)
{
	struct sockaddr_in6 *sin = &sin_m;
	register struct rt_msghdr *rtm = &m_rtmsg.m_rtm;
	struct sockaddr_dl *sdl;
	struct addrinfo hints, *res;
	int gai_error;

	getsocket();
	sin_m = blank_sin;

	bzero(&hints, sizeof (hints));
	hints.ai_family = AF_INET6;
	gai_error = getaddrinfo(host, NULL, &hints, &res);
	if (gai_error) {
		fprintf(stderr, "ndp: %s: %s\n", host,
			gai_strerror(gai_error));
		return (1);
	}
	sin->sin6_addr = ((struct sockaddr_in6 *)res->ai_addr)->sin6_addr;
#ifdef __KAME__
	if (IN6_IS_ADDR_LINKLOCAL(&sin->sin6_addr)) {
		*(u_int16_t *)&sin->sin6_addr.s6_addr[2] =
		    htons(((struct sockaddr_in6 *)res->ai_addr)->sin6_scope_id);
	}
#endif
	if (rtmsg(RTM_GET) < 0) {
		perror(host);
		return (1);
	}
	sin = (struct sockaddr_in6 *)(rtm + 1);
	sdl = (struct sockaddr_dl *)(ROUNDUP(sin->sin6_len) + (char *)sin);
	if (IN6_ARE_ADDR_EQUAL(&sin->sin6_addr, &sin_m.sin6_addr)) {
		if (sdl->sdl_family == AF_LINK &&
		    (rtm->rtm_flags & RTF_LLINFO) &&
		    !(rtm->rtm_flags & RTF_GATEWAY)) {
			goto delete;
		}
		/*
		 * IPv4 arp command retries with sin_other = SIN_PROXY here.
		 */
		fprintf(stderr, "delete: cannot delete non-NDP entry\n");
		return (1);
	}

delete:
	if (sdl->sdl_family != AF_LINK) {
		printf("cannot locate %s\n", host);
		return (1);
	}
	if (rtmsg(RTM_DELETE) == 0) {
		struct sockaddr_in6 s6 = *sin;

#ifdef __KAME__
		if (IN6_IS_ADDR_LINKLOCAL(&s6.sin6_addr)) {
			s6.sin6_scope_id =
			    ntohs(*(u_int16_t *)&s6.sin6_addr.s6_addr[2]);
			*(u_int16_t *)&s6.sin6_addr.s6_addr[2] = 0;
		}
#endif
		getnameinfo((struct sockaddr *)&s6,
			    s6.sin6_len, host_buf,
			    sizeof (host_buf), NULL, 0,
			    NI_WITHSCOPEID | (nflag ? NI_NUMERICHOST : 0));
		printf("%s (%s) deleted\n", host, host_buf);
	}

	return (0);
}

#define	W_ADDR	31
#define	W_LL	17
#define	W_IF	6

/*
 * Dump the entire neighbor cache
 */
static void
dump(struct in6_addr *addr)
{
	int mib[6];
	size_t needed;
	char *lim, *buf, *next;
	struct rt_msghdr *rtm;
	struct sockaddr_in6 *sin;
	struct sockaddr_dl *sdl;
	struct in6_nbrinfo *nbi;
	struct timeval time;
	int addrwidth;
	int llwidth;
	int ifwidth;
	char flgbuf[8];
	char *ifname;

	/* Print header */
	if (!tflag && !cflag)
		printf("%-*.*s %-*.*s %*.*s %-9.9s %2s %4s %4s\n",
		    W_ADDR, W_ADDR, "Neighbor", W_LL, W_LL, "Linklayer Address",
		    W_IF, W_IF, "Netif", "Expire", "St", "Flgs", "Prbs");

again:;
	mib[0] = CTL_NET;
	mib[1] = PF_ROUTE;
	mib[2] = 0;
	mib[3] = AF_INET6;
	mib[4] = NET_RT_FLAGS;
	mib[5] = RTF_LLINFO;
	if (sysctl(mib, 6, NULL, &needed, NULL, 0) < 0)
		err(1, "sysctl(PF_ROUTE estimate)");
	if (needed > 0) {
		if ((buf = malloc(needed)) == NULL)
			errx(1, "malloc");
		if (sysctl(mib, 6, buf, &needed, NULL, 0) < 0)
			err(1, "sysctl(PF_ROUTE, NET_RT_FLAGS)");
		lim = buf + needed;
	} else
		buf = lim = NULL;

	for (next = buf; next && next < lim; next += rtm->rtm_msglen) {
		int isrouter = 0, prbs = 0;

		rtm = (struct rt_msghdr *)next;
		sin = (struct sockaddr_in6 *)(rtm + 1);
		sdl = (struct sockaddr_dl *)((char *)sin +
		    ROUNDUP(sin->sin6_len));

		/*
		 * Some OSes can produce a route that has the LINK flag but
		 * has a non-AF_LINK gateway (e.g. fe80::xx%lo0 on FreeBSD
		 * and BSD/OS, where xx is not the interface identifier on
		 * lo0).  Such routes entry would annoy getnbrinfo() below,
		 * so we skip them.
		 * XXX: such routes should have the GATEWAY flag, not the
		 * LINK flag.  However, there are rotten routing software
		 * that advertises all routes that have the GATEWAY flag.
		 * Thus, KAME kernel intentionally does not set the LINK flag.
		 * What is to be fixed is not ndp, but such routing software
		 * (and the kernel workaround)...
		 */
		if (sdl->sdl_family != AF_LINK)
			continue;

		if (addr) {
			if (!IN6_ARE_ADDR_EQUAL(addr, &sin->sin6_addr))
				continue;
			found_entry = 1;
		} else if (IN6_IS_ADDR_MULTICAST(&sin->sin6_addr))
			continue;
		if (IN6_IS_ADDR_LINKLOCAL(&sin->sin6_addr) ||
		    IN6_IS_ADDR_MC_NODELOCAL(&sin->sin6_addr) ||
		    IN6_IS_ADDR_MC_LINKLOCAL(&sin->sin6_addr)) {
			/* should scope id be filled in the kernel? */
			if (sin->sin6_scope_id == 0)
				sin->sin6_scope_id = sdl->sdl_index;
#ifdef __KAME__
			/* KAME specific hack; removed the embedded id */
			*(u_int16_t *)&sin->sin6_addr.s6_addr[2] = 0;
#endif
		}
		getnameinfo((struct sockaddr *)sin, sin->sin6_len, host_buf,
			    sizeof (host_buf), NULL, 0,
			    NI_WITHSCOPEID | (nflag ? NI_NUMERICHOST : 0));
		if (cflag == 1) {
			if (rtm->rtm_flags & RTF_WASCLONED)
				delete(host_buf);
			continue;
		}
		gettimeofday(&time, 0);
		if (tflag)
			ts_print(&time);

		addrwidth = strlen(host_buf);
		if (addrwidth < W_ADDR)
			addrwidth = W_ADDR;
		llwidth = strlen(ether_str(sdl));
		if (W_ADDR + W_LL - addrwidth > llwidth)
			llwidth = W_ADDR + W_LL - addrwidth;
		ifname = if_indextoname(sdl->sdl_index, ifix_buf);
		if (!ifname)
			ifname = "?";
		ifwidth = strlen(ifname);
		if (W_ADDR + W_LL + W_IF - addrwidth - llwidth > ifwidth)
			ifwidth = W_ADDR + W_LL + W_IF - addrwidth - llwidth;

		printf("%-*.*s %-*.*s %*.*s", addrwidth, addrwidth, host_buf,
		    llwidth, llwidth, ether_str(sdl), ifwidth, ifwidth, ifname);

		/* Print neighbor discovery specific informations */
		nbi = getnbrinfo(&sin->sin6_addr, sdl->sdl_index, 1);
		if (nbi) {
			if (nbi->expire > time.tv_sec) {
				printf(" %-9.9s", sec2str(nbi->expire -
				    time.tv_sec));
			} else if (nbi->expire == 0)
				printf(" %-9.9s", "permanent");
			else
				printf(" %-9.9s", "expired");

			switch (nbi->state) {
			case ND6_LLINFO_NOSTATE:
				printf(" N");
				break;
			case ND6_LLINFO_INCOMPLETE:
				printf(" I");
				break;
			case ND6_LLINFO_REACHABLE:
				printf(" R");
				break;
			case ND6_LLINFO_STALE:
				printf(" S");
				break;
			case ND6_LLINFO_DELAY:
				printf(" D");
				break;
			case ND6_LLINFO_PROBE:
				printf(" P");
				break;
			default:
				printf(" ?");
				break;
			}

			isrouter = nbi->isrouter;
			prbs = nbi->asked;
		} else {
			warnx("failed to get neighbor information");
			printf("  ");
		}
		putchar(' ');

		/*
		 * other flags. R: router, P: proxy, W: ??
		 */
		if ((rtm->rtm_addrs & RTA_NETMASK) == 0) {
			snprintf(flgbuf, sizeof (flgbuf), "%s%s",
				isrouter ? "R" : "",
				(rtm->rtm_flags & RTF_ANNOUNCE) ? "p" : "");
		} else {
			sin = (struct sockaddr_in6 *)
				(sdl->sdl_len + (char *)sdl);
			snprintf(flgbuf, sizeof (flgbuf), "%s%s%s%s",
				isrouter ? "R" : "",
				!IN6_IS_ADDR_UNSPECIFIED(&sin->sin6_addr)
					? "P" : "",
				(sin->sin6_len != sizeof (struct sockaddr_in6))
					? "W" : "",
				(rtm->rtm_flags & RTF_ANNOUNCE) ? "p" : "");
		}
		printf(" %-4.4s", flgbuf);

		if (prbs)
			printf(" %4d", prbs);

		printf("\n");
	}
	if (buf != NULL)
		free(buf);

	if (repeat) {
		printf("\n");
		sleep(repeat);
		goto again;
	}
}

/*
 * Dump the entire neighbor cache (extended)
 */
void
dump_ext(addr, xflag)
	struct in6_addr *addr;
	int xflag;
{
	int mib[6];
	size_t needed;
	char *lim, *buf, *next;
	struct rt_msghdr_ext *ertm;
	struct sockaddr_in6 *sin;
	struct sockaddr_dl *sdl;
	struct in6_nbrinfo *nbi;
	struct timeval time;
	int addrwidth;
	int llwidth;
	int ifwidth;
	char flgbuf[8];
	char *ifname;

	/* Print header */
	if (!tflag && !cflag) {
		printf("%-*.*s %-*.*s %*.*s %-9.9s %-9.9s %2s %4s %4s",
		    W_ADDR, W_ADDR, "Neighbor", W_LL, W_LL, "Linklayer Address",
		    W_IF, W_IF, "Netif", "Expire(O)", "Expire(I)", "St",
		    "Flgs", "Prbs");
		if (xflag)
			printf(" %-7.7s %-7.7s %-7.7s", "RSSI", "LQM", "NPM");
		printf("\n");
	}

again:;
	mib[0] = CTL_NET;
	mib[1] = PF_ROUTE;
	mib[2] = 0;
	mib[3] = AF_INET6;
	mib[4] = NET_RT_DUMPX_FLAGS;
	mib[5] = RTF_LLINFO;
	if (sysctl(mib, 6, NULL, &needed, NULL, 0) < 0)
		err(1, "sysctl(PF_ROUTE estimate)");
	if (needed > 0) {
		if ((buf = malloc(needed)) == NULL)
			errx(1, "malloc");
		if (sysctl(mib, 6, buf, &needed, NULL, 0) < 0)
			err(1, "sysctl(PF_ROUTE, NET_RT_FLAGS)");
		lim = buf + needed;
	} else
		buf = lim = NULL;

	for (next = buf; next && next < lim; next += ertm->rtm_msglen) {
		int isrouter = 0, prbs = 0;

		ertm = (struct rt_msghdr_ext *)next;
		sin = (struct sockaddr_in6 *)(ertm + 1);
		sdl = (struct sockaddr_dl *)((char *)sin +
		    ROUNDUP(sin->sin6_len));

		/*
		 * Some OSes can produce a route that has the LINK flag but
		 * has a non-AF_LINK gateway (e.g. fe80::xx%lo0 on FreeBSD
		 * and BSD/OS, where xx is not the interface identifier on
		 * lo0).  Such routes entry would annoy getnbrinfo() below,
		 * so we skip them.
		 * XXX: such routes should have the GATEWAY flag, not the
		 * LINK flag.  However, there are rotten routing software
		 * that advertises all routes that have the GATEWAY flag.
		 * Thus, KAME kernel intentionally does not set the LINK flag.
		 * What is to be fixed is not ndp, but such routing software
		 * (and the kernel workaround)...
		 */
		if (sdl->sdl_family != AF_LINK)
			continue;

		if (addr) {
			if (!IN6_ARE_ADDR_EQUAL(addr, &sin->sin6_addr))
				continue;
			found_entry = 1;
		} else if (IN6_IS_ADDR_MULTICAST(&sin->sin6_addr))
			continue;
		if (IN6_IS_ADDR_LINKLOCAL(&sin->sin6_addr) ||
		    IN6_IS_ADDR_MC_NODELOCAL(&sin->sin6_addr) ||
		    IN6_IS_ADDR_MC_LINKLOCAL(&sin->sin6_addr)) {
			/* should scope id be filled in the kernel? */
			if (sin->sin6_scope_id == 0)
				sin->sin6_scope_id = sdl->sdl_index;
#ifdef __KAME__
			/* KAME specific hack; removed the embedded id */
			*(u_int16_t *)&sin->sin6_addr.s6_addr[2] = 0;
#endif
		}
		getnameinfo((struct sockaddr *)sin, sin->sin6_len, host_buf,
			    sizeof (host_buf), NULL, 0,
			    NI_WITHSCOPEID | (nflag ? NI_NUMERICHOST : 0));
		if (cflag == 1) {
			if (ertm->rtm_flags & RTF_WASCLONED)
				delete(host_buf);
			continue;
		}
		gettimeofday(&time, 0);
		if (tflag)
			ts_print(&time);

		addrwidth = strlen(host_buf);
		if (addrwidth < W_ADDR)
			addrwidth = W_ADDR;
		llwidth = strlen(ether_str(sdl));
		if (W_ADDR + W_LL - addrwidth > llwidth)
			llwidth = W_ADDR + W_LL - addrwidth;
		ifname = if_indextoname(sdl->sdl_index, ifix_buf);
		if (!ifname)
			ifname = "?";
		ifwidth = strlen(ifname);
		if (W_ADDR + W_LL + W_IF - addrwidth - llwidth > ifwidth)
			ifwidth = W_ADDR + W_LL + W_IF - addrwidth - llwidth;

		printf("%-*.*s %-*.*s %*.*s", addrwidth, addrwidth, host_buf,
		    llwidth, llwidth, ether_str(sdl), ifwidth, ifwidth, ifname);

		if (ertm->rtm_ri.ri_refcnt == 0 ||
		    ertm->rtm_ri.ri_snd_expire == 0)
			printf(" %-9.9s", "(none)");
		else if (ertm->rtm_ri.ri_snd_expire > time.tv_sec)
			printf(" %-9.9s",
			    sec2str(ertm->rtm_ri.ri_snd_expire - time.tv_sec));
		else
			printf(" %-9.9s", "expired");

		if (ertm->rtm_ri.ri_refcnt == 0 ||
		    ertm->rtm_ri.ri_rcv_expire == 0)
			printf(" %-9.9s", "(none)");
		else if (ertm->rtm_ri.ri_rcv_expire > time.tv_sec)
			printf(" %-9.9s",
			    sec2str(ertm->rtm_ri.ri_rcv_expire - time.tv_sec));
		else
			printf(" %-9.9s", "expired");

		/* Print neighbor discovery specific informations */
		nbi = getnbrinfo(&sin->sin6_addr, sdl->sdl_index, 1);
		if (nbi) {
			switch (nbi->state) {
			case ND6_LLINFO_NOSTATE:
				printf(" N");
				break;
			case ND6_LLINFO_INCOMPLETE:
				printf(" I");
				break;
			case ND6_LLINFO_REACHABLE:
				printf(" R");
				break;
			case ND6_LLINFO_STALE:
				printf(" S");
				break;
			case ND6_LLINFO_DELAY:
				printf(" D");
				break;
			case ND6_LLINFO_PROBE:
				printf(" P");
				break;
			default:
				printf(" ?");
				break;
			}

			isrouter = nbi->isrouter;
			prbs = nbi->asked;
		} else {
			warnx("failed to get neighbor information");
			printf("  ");
		}
		putchar(' ');

		/*
		 * other flags. R: router, P: proxy, W: ??
		 */
		if ((ertm->rtm_addrs & RTA_NETMASK) == 0) {
			snprintf(flgbuf, sizeof (flgbuf), "%s%s",
				isrouter ? "R" : "",
				(ertm->rtm_flags & RTF_ANNOUNCE) ? "p" : "");
		} else {
			sin = (struct sockaddr_in6 *)
				(sdl->sdl_len + (char *)sdl);
			snprintf(flgbuf, sizeof (flgbuf), "%s%s%s%s",
				isrouter ? "R" : "",
				!IN6_IS_ADDR_UNSPECIFIED(&sin->sin6_addr)
					? "P" : "",
				(sin->sin6_len != sizeof (struct sockaddr_in6))
					? "W" : "",
				(ertm->rtm_flags & RTF_ANNOUNCE) ? "p" : "");
		}
		printf(" %-4.4s", flgbuf);

		if (prbs)
			printf(" %4d", prbs);

		if (xflag) {
			if (!prbs)
				printf(" %-4.4s", "none");

			if (ertm->rtm_ri.ri_rssi != IFNET_RSSI_UNKNOWN)
				printf(" %7d", ertm->rtm_ri.ri_rssi);
			else
				printf(" %-7.7s", "unknown");

			switch (ertm->rtm_ri.ri_lqm)
			{
			case IFNET_LQM_THRESH_OFF:
				printf(" %-7.7s", "off");
				break;
			case IFNET_LQM_THRESH_UNKNOWN:
				printf(" %-7.7s", "unknown");
				break;
			case IFNET_LQM_THRESH_POOR:
				printf(" %-7.7s", "poor");
				break;
			case IFNET_LQM_THRESH_GOOD:
				printf(" %-7.7s", "good");
				break;
			default:
				printf(" %7d", ertm->rtm_ri.ri_lqm);
				break;
			}

			switch (ertm->rtm_ri.ri_npm)
			{
			case IFNET_NPM_THRESH_UNKNOWN:
				printf(" %-7.7s", "unknown");
				break;
			case IFNET_NPM_THRESH_NEAR:
				printf(" %-7.7s", "near");
				break;
			case IFNET_NPM_THRESH_GENERAL:
				printf(" %-7.7s", "general");
				break;
			case IFNET_NPM_THRESH_FAR:
				printf(" %-7.7s", "far");
				break;
			default:
				printf(" %7d", ertm->rtm_ri.ri_npm);
				break;
			}
		}

		printf("\n");
	}
	if (buf != NULL)
		free(buf);

	if (repeat) {
		printf("\n");
		sleep(repeat);
		goto again;
	}
}

static struct in6_nbrinfo *
getnbrinfo(addr, ifindex, warning)
	struct in6_addr *addr;
	int ifindex;
	int warning;
{
	static struct in6_nbrinfo nbi;
	int s;

	if ((s = socket(AF_INET6, SOCK_DGRAM, 0)) < 0)
		err(1, "socket");

	bzero(&nbi, sizeof (nbi));
	if_indextoname(ifindex, nbi.ifname);
	nbi.addr = *addr;
	if (ioctl(s, SIOCGNBRINFO_IN6, (caddr_t)&nbi) < 0) {
		if (warning)
			warn("ioctl(SIOCGNBRINFO_IN6)");
		close(s);
		return (NULL);
	}

	close(s);
	return (&nbi);
}

static char *
ether_str(struct sockaddr_dl *sdl)
{
	static char ebuf[32];
	u_char *cp;

	if (sdl->sdl_alen) {
		cp = (u_char *)LLADDR(sdl);
		snprintf(ebuf, sizeof (ebuf), "%x:%x:%x:%x:%x:%x",
			cp[0], cp[1], cp[2], cp[3], cp[4], cp[5]);
	} else {
		snprintf(ebuf, sizeof (ebuf), "(incomplete)");
	}

	return (ebuf);
}

static int
ndp_ether_aton(char *a, u_char *n)
{
	int i, o[6];

	i = sscanf(a, "%x:%x:%x:%x:%x:%x", &o[0], &o[1], &o[2], &o[3], &o[4],
	    &o[5]);
	if (i != 6) {
		fprintf(stderr, "ndp: invalid Ethernet address '%s'\n", a);
		return (1);
	}
	for (i = 0; i < 6; i++)
		n[i] = o[i];
	return (0);
}

static void
usage(void)
{
	printf("usage: ndp hostname\n");
	printf("       ndp -a[lnt]\n");
	printf("       ndp [-nt] -A wait\n");
	printf("       ndp -c[nt]\n");
	printf("       ndp -d[nt] hostname\n");
	printf("       ndp -f[nt] filename\n");
	printf("       ndp -i interface [flags...]\n");
	printf("       ndp -I [interface|delete]\n");
	printf("       ndp -p\n");
	printf("       ndp -r\n");
	printf("       ndp -s hostname ether_addr [temp] [proxy]\n");
	printf("       ndp -H\n");
	printf("       ndp -P\n");
	printf("       ndp -R\n");
	printf("       ndp -w\n");
	printf("       ndp -W cfgfile\n");
	exit(1);
}

static int
rtmsg(int cmd)
{
	static int seq;
	int rlen;
	register struct rt_msghdr *rtm = &m_rtmsg.m_rtm;
	register char *cp = m_rtmsg.m_space;
	register int l;

	errno = 0;
	if (cmd == RTM_DELETE)
		goto doit;
	bzero((char *)&m_rtmsg, sizeof (m_rtmsg));
	rtm->rtm_flags = flags;
	rtm->rtm_version = RTM_VERSION;

	switch (cmd) {
	default:
		fprintf(stderr, "ndp: internal wrong cmd\n");
		exit(1);
	case RTM_ADD:
		rtm->rtm_addrs |= RTA_GATEWAY;
		rtm->rtm_rmx.rmx_expire = expire_time;
		rtm->rtm_inits = RTV_EXPIRE;
		rtm->rtm_flags |= (RTF_HOST | RTF_STATIC);
		if (rtm->rtm_flags & RTF_ANNOUNCE) {
			rtm->rtm_flags &= ~RTF_HOST;
			rtm->rtm_flags |= RTA_NETMASK;
		}
		/* FALLTHROUGH */
	case RTM_GET:
		rtm->rtm_addrs |= RTA_DST;
	}
#define	NEXTADDR(w, s) \
	if (rtm->rtm_addrs & (w)) { \
		bcopy((char *)&s, cp, sizeof (s)); cp += sizeof (s); \
	}

	NEXTADDR(RTA_DST, sin_m);
	NEXTADDR(RTA_GATEWAY, sdl_m);
	memset(&so_mask.sin6_addr, 0xff, sizeof (so_mask.sin6_addr));
	NEXTADDR(RTA_NETMASK, so_mask);

	rtm->rtm_msglen = cp - (char *)&m_rtmsg;
doit:
	l = rtm->rtm_msglen;
	rtm->rtm_seq = ++seq;
	rtm->rtm_type = cmd;
	if ((rlen = write(s, (char *)&m_rtmsg, l)) < 0) {
		if (errno != ESRCH || cmd != RTM_DELETE) {
			perror("writing to routing socket");
			return (-1);
		}
	}
	do {
		l = read(s, (char *)&m_rtmsg, sizeof (m_rtmsg));
	} while (l > 0 && (rtm->rtm_seq != seq || rtm->rtm_pid != pid));
	if (l < 0)
		(void) fprintf(stderr, "ndp: read from routing socket: %s\n",
		    strerror(errno));
	return (0);
}

static void
ifinfo(int argc, char **argv)
{
	struct in6_ndireq nd;
	int i, s;
	char *ifname = argv[0];
	u_int32_t newflags;
	u_int8_t nullbuf[8];

	if ((s = socket(AF_INET6, SOCK_DGRAM, 0)) < 0) {
		perror("ndp: socket");
		exit(1);
	}
	bzero(&nd, sizeof (nd));
	strlcpy(nd.ifname, ifname, sizeof (nd.ifname));
	if (ioctl(s, SIOCGIFINFO_IN6, (caddr_t)&nd) < 0) {
		perror("ioctl (SIOCGIFINFO_IN6)");
		exit(1);
	}
#define	ND nd.ndi
	newflags = ND.flags;
	for (i = 1; i < argc; i++) {
		int clear = 0;
		char *cp = argv[i];

		if (*cp == '-') {
			clear = 1;
			cp++;
		}

#define	SETFLAG(s, f) \
	do {\
		if (strcmp(cp, (s)) == 0) {\
			if (clear)\
				newflags &= ~(f);\
			else\
				newflags |= (f);\
		}\
	} while (0)
		SETFLAG("nud", ND6_IFF_PERFORMNUD);
		SETFLAG("proxy_prefixes", ND6_IFF_PROXY_PREFIXES);
		SETFLAG("disabled", ND6_IFF_IFDISABLED);
		SETFLAG("insecure", ND6_IFF_INSECURE);
		SETFLAG("replicated", ND6_IFF_REPLICATED);

		ND.flags = newflags;
		if (ioctl(s, SIOCSIFINFO_FLAGS, (caddr_t)&nd) < 0) {
			perror("ioctl(SIOCSIFINFO_FLAGS)");
			exit(1);
		}
#undef SETFLAG
	}

	printf("linkmtu=%d", ND.linkmtu);
	printf(", curhlim=%d", ND.chlim);
	printf(", basereachable=%ds%dms", ND.basereachable / 1000,
	    ND.basereachable % 1000);
	printf(", reachable=%ds", ND.reachable);
	printf(", retrans=%ds%dms", ND.retrans / 1000, ND.retrans % 1000);
	memset(nullbuf, 0, sizeof (nullbuf));
	if (memcmp(nullbuf, ND.randomid, sizeof (nullbuf)) != 0) {
		int j;
		u_int8_t *rbuf = NULL;

		for (i = 0; i < 3; i++) {
			switch (i) {
			case 0:
				printf("\nRandom seed(0): ");
				rbuf = ND.randomseed0;
				break;
			case 1:
				printf("\nRandom seed(1): ");
				rbuf = ND.randomseed1;
				break;
			case 2:
				printf("\nRandom ID:      ");
				rbuf = ND.randomid;
				break;
			}
			for (j = 0; j < 8; j++)
				printf("%02x", rbuf[j]);
		}
	}
	if (ND.flags) {
		printf("\nFlags: 0x%x ", ND.flags);
		if ((ND.flags & ND6_IFF_IFDISABLED) != 0)
			printf("IFDISABLED ");
		if ((ND.flags & ND6_IFF_INSECURE) != 0)
			printf("INSECURE ");
		if ((ND.flags & ND6_IFF_PERFORMNUD) != 0)
			printf("PERFORMNUD ");
		if ((ND.flags & ND6_IFF_PROXY_PREFIXES) != 0)
			printf("PROXY_PREFIXES ");
		if ((ND.flags & ND6_IFF_REPLICATED) != 0)
			printf("REPLICATED ");
		if ((ND.flags & ND6_IFF_DAD) != 0)
			printf("DAD ");
	}
	putc('\n', stdout);
#undef ND

	close(s);
}

#ifndef ND_RA_FLAG_RTPREF_MASK	/* XXX: just for compilation on *BSD release */
#define	ND_RA_FLAG_RTPREF_MASK	0x18 /* 00011000 */
#endif

static void
rtrlist(void)
{
	int mib[] = { CTL_NET, PF_INET6, IPPROTO_ICMPV6, ICMPV6CTL_ND6_DRLIST };
	char *buf;
	struct in6_defrouter *p, *ep;
	size_t l;
	struct timeval time;

	if (sysctl(mib, sizeof (mib) / sizeof (mib[0]), NULL, &l, NULL, 0)
	    < 0) {
		err(1, "sysctl(ICMPV6CTL_ND6_DRLIST)");
		/*NOTREACHED*/
	}
	buf = malloc(l);
	if (!buf) {
		errx(1, "not enough core");
		/*NOTREACHED*/
	}
	if (sysctl(mib, sizeof (mib) / sizeof (mib[0]), buf, &l, NULL, 0) < 0) {
		err(1, "sysctl(ICMPV6CTL_ND6_DRLIST)");
		/*NOTREACHED*/
	}

	ep = (struct in6_defrouter *)(buf + l);
	for (p = (struct in6_defrouter *)buf; p < ep; p++) {
		int rtpref;

		if (getnameinfo((struct sockaddr *)&p->rtaddr,
		    p->rtaddr.sin6_len, host_buf, sizeof (host_buf), NULL, 0,
		    NI_WITHSCOPEID | (nflag ? NI_NUMERICHOST : 0)) != 0)
			strlcpy(host_buf, "?", sizeof (host_buf));

		printf("%s if=%s", host_buf, if_indextoname(p->if_index,
		    ifix_buf));
		printf(", flags=%s%s%s%s%s",
		    p->stateflags & NDDRF_IFSCOPE ? "I" : "",
		    p->flags & ND_RA_FLAG_MANAGED ? "M" : "",
		    p->flags & ND_RA_FLAG_OTHER   ? "O" : "",
		    p->stateflags & NDDRF_STATIC ? "S" : "",
		    p->stateflags & NDDRF_INSTALLED ? "T" : "");
		rtpref = ((p->flags & ND_RA_FLAG_RTPREF_MASK) >> 3) & 0xff;
		printf(", pref=%s", rtpref_str[rtpref]);

		gettimeofday(&time, 0);
		if (p->expire == 0)
			printf(", expire=Never\n");
		else
			printf(", expire=%s\n",
				sec2str(p->expire - time.tv_sec));
	}
	free(buf);
}

static void
plist(void)
{
	int mib[] = { CTL_NET, PF_INET6, IPPROTO_ICMPV6, ICMPV6CTL_ND6_PRLIST };
	char *buf;
	struct in6_prefix *p, *ep, *n;
	struct sockaddr_in6 *advrtr;
	size_t l;
	struct timeval time;
	const int niflags = NI_NUMERICHOST | NI_WITHSCOPEID;
	int ninflags = (nflag ? NI_NUMERICHOST : 0) | NI_WITHSCOPEID;
	char namebuf[NI_MAXHOST];

	if (sysctl(mib, sizeof (mib) / sizeof (mib[0]), NULL, &l, NULL, 0)
	    < 0) {
		err(1, "sysctl(ICMPV6CTL_ND6_PRLIST)");
		/*NOTREACHED*/
	}
	buf = malloc(l);
	if (!buf) {
		errx(1, "not enough core");
		/*NOTREACHED*/
	}
	if (sysctl(mib, sizeof (mib) / sizeof (mib[0]), buf, &l, NULL, 0)
	    < 0) {
		err(1, "sysctl(ICMPV6CTL_ND6_PRLIST)");
		/*NOTREACHED*/
	}

	ep = (struct in6_prefix *)(buf + l);
	for (p = (struct in6_prefix *)buf; p < ep; p = n) {
		advrtr = (struct sockaddr_in6 *)(p + 1);
		n = (struct in6_prefix *)&advrtr[p->advrtrs];

		if (getnameinfo((struct sockaddr *)&p->prefix,
		    p->prefix.sin6_len, namebuf, sizeof (namebuf),
		    NULL, 0, niflags) != 0)
			strlcpy(namebuf, "?", sizeof (namebuf));
		printf("%s/%d if=%s\n", namebuf, p->prefixlen,
		    if_indextoname(p->if_index, ifix_buf));

		gettimeofday(&time, 0);
		/*
		 * meaning of fields, especially flags, is very different
		 * by origin.  notify the difference to the users.
		 */
		printf("flags=%s%s%s%s%s%s%s",
		    p->raflags.autonomous ? "A" : "",
		    (p->flags & NDPRF_DETACHED) != 0 ? "D" : "",
		    (p->flags & NDPRF_IFSCOPE) != 0 ? "I" : "",
		    p->raflags.onlink ? "L" : "",
		    (p->flags & NDPRF_STATIC) != 0 ? "S" : "",
		    (p->flags & NDPRF_ONLINK) != 0 ? "O" : "",
		    (p->flags & NDPRF_PRPROXY) != 0 ? "Y" : "");
		if (p->vltime == ND6_INFINITE_LIFETIME)
			printf(" vltime=infinity");
		else
			printf(" vltime=%ld", (long)p->vltime);
		if (p->pltime == ND6_INFINITE_LIFETIME)
			printf(", pltime=infinity");
		else
			printf(", pltime=%ld", (long)p->pltime);
		if (p->expire == 0)
			printf(", expire=Never");
		else if (p->expire >= time.tv_sec)
			printf(", expire=%s",
				sec2str(p->expire - time.tv_sec));
		else
			printf(", expired");
		printf(", ref=%d", p->refcnt);
		printf("\n");
		/*
		 * "advertising router" list is meaningful only if the prefix
		 * information is from RA.
		 */
		if (p->advrtrs) {
			int j;
			struct sockaddr_in6 *sin6;

			sin6 = (struct sockaddr_in6 *)(p + 1);
			printf("  advertised by\n");
			for (j = 0; j < p->advrtrs; j++) {
				struct in6_nbrinfo *nbi;

				if (getnameinfo((struct sockaddr *)sin6,
				    sin6->sin6_len, namebuf, sizeof (namebuf),
				    NULL, 0, ninflags) != 0)
					strlcpy(namebuf, "?", sizeof (namebuf));
				printf("    %s", namebuf);

				nbi = getnbrinfo(&sin6->sin6_addr, p->if_index,
				    0);
				if (nbi) {
					switch (nbi->state) {
					case ND6_LLINFO_REACHABLE:
					case ND6_LLINFO_STALE:
					case ND6_LLINFO_DELAY:
					case ND6_LLINFO_PROBE:
						printf(" (reachable)\n");
						break;
					default:
						printf(" (unreachable)\n");
					}
				} else
					printf(" (no neighbor state)\n");
				sin6++;
			}
		} else
			printf("  No advertising router\n");
	}
	free(buf);
}

static void
pfx_flush(void)
{
	char dummyif[IFNAMSIZ+8];
	int s;

	if ((s = socket(AF_INET6, SOCK_DGRAM, 0)) < 0)
		err(1, "socket");
	strlcpy(dummyif, "lo0", sizeof (dummyif)); /* dummy */
	if (ioctl(s, SIOCSPFXFLUSH_IN6, (caddr_t)&dummyif) < 0)
		err(1, "ioctl(SIOCSPFXFLUSH_IN6)");
}

static void
rtr_flush(void)
{
	char dummyif[IFNAMSIZ+8];
	int s;

	if ((s = socket(AF_INET6, SOCK_DGRAM, 0)) < 0)
		err(1, "socket");
	strlcpy(dummyif, "lo0", sizeof (dummyif)); /* dummy */
	if (ioctl(s, SIOCSRTRFLUSH_IN6, (caddr_t)&dummyif) < 0)
		err(1, "ioctl(SIOCSRTRFLUSH_IN6)");

	close(s);
}

static void
harmonize_rtr(void)
{
	char dummyif[IFNAMSIZ+8];
	int s;

	if ((s = socket(AF_INET6, SOCK_DGRAM, 0)) < 0)
		err(1, "socket");
	strlcpy(dummyif, "lo0", sizeof (dummyif)); /* dummy */
	if (ioctl(s, SIOCSNDFLUSH_IN6, (caddr_t)&dummyif) < 0)
		err(1, "ioctl (SIOCSNDFLUSH_IN6)");

	close(s);
}

static void
setdefif(char *ifname)
{
	struct in6_ndifreq ndifreq;
	unsigned int ifindex;

	if (strcasecmp(ifname, "delete") == 0)
		ifindex = 0;
	else {
		if ((ifindex = if_nametoindex(ifname)) == 0)
			err(1, "failed to resolve i/f index for %s", ifname);
	}

	if ((s = socket(AF_INET6, SOCK_DGRAM, 0)) < 0)
		err(1, "socket");

	strlcpy(ndifreq.ifname, "lo0", sizeof (ndifreq.ifname)); /* dummy */
	ndifreq.ifindex = ifindex;

	if (ioctl(s, SIOCSDEFIFACE_IN6, (caddr_t)&ndifreq) < 0)
		err(1, "ioctl (SIOCSDEFIFACE_IN6)");

	close(s);
}

static void
getdefif(void)
{
	struct in6_ndifreq ndifreq;
	char ifname[IFNAMSIZ+8];

	if ((s = socket(AF_INET6, SOCK_DGRAM, 0)) < 0)
		err(1, "socket");

	memset(&ndifreq, 0, sizeof (ndifreq));
	strlcpy(ndifreq.ifname, "lo0", sizeof (ndifreq.ifname)); /* dummy */

	if (ioctl(s, SIOCGDEFIFACE_IN6, (caddr_t)&ndifreq) < 0)
		err(1, "ioctl (SIOCGDEFIFACE_IN6)");

	if (ndifreq.ifindex == 0)
		printf("No default interface.\n");
	else {
		if ((if_indextoname(ndifreq.ifindex, ifname)) == NULL)
			err(1, "failed to resolve ifname for index %lu",
			    ndifreq.ifindex);
		printf("ND default interface = %s\n", ifname);
	}

	close(s);
}

static char *
sec2str(time_t total)
{
	static char result[256];
	int days, hours, mins, secs;
	int first = 1;
	char *p = result;

	days = total / 3600 / 24;
	hours = (total / 3600) % 24;
	mins = (total / 60) % 60;
	secs = total % 60;

	if (days) {
		first = 0;
		p += snprintf(p, sizeof (result) - (p - result), "%dd", days);
	}
	if (!first || hours) {
		first = 0;
		p += snprintf(p, sizeof (result) - (p - result), "%dh", hours);
	}
	if (!first || mins)
		p += snprintf(p, sizeof (result) - (p - result), "%dm", mins);
	snprintf(p, sizeof (result) - (p - result), "%ds", secs);

	return (result);
}

/*
 * Print the timestamp
 * from tcpdump/util.c
 */
static void
ts_print(const struct timeval *tvp)
{
	int s;

	/* Default */
	s = (tvp->tv_sec + thiszone) % 86400;
	printf("%02d:%02d:%02d.%06u ", s / 3600, (s % 3600) / 60, s % 60,
	    (u_int32_t)tvp->tv_usec);
}

#define	SYSCTL_CGA_PARAMETERS_BUFFER_SIZE \
	2 * (sizeof (size_t) + IN6_CGA_KEY_MAXSIZE) + \
	sizeof (struct in6_cga_prepare)

static void
read_cga_parameters(void)
{
	static char oldb[SYSCTL_CGA_PARAMETERS_BUFFER_SIZE];

	int error;
	struct in6_cga_nodecfg cfg;
	struct iovec *iov;
	const char *oldp;
	const char *finp;
	size_t oldn;
	unsigned int column;
	uint16_t u16;

	oldn = sizeof oldb;
	error = sysctlbyname("net.inet6.send.cga_parameters", oldb, &oldn,
	    NULL, NULL);
	if (error != 0)
		err(1, "sysctlbyname");

	if (oldn == 0) {
		printf("No CGA parameters.\n");
		exit(0);
	}

	oldp = oldb;
	finp = &oldb[oldn];
	memset(&cfg, 0, sizeof (cfg));

	if (oldp + sizeof (cfg.cga_prepare) > finp)
		err(1, "format error[1]");

	memcpy(&cfg.cga_prepare, oldp, sizeof (cfg.cga_prepare));
	oldp += sizeof (cfg.cga_prepare);

	iov = &cfg.cga_pubkey;

	if (oldp + sizeof (u16) > finp)
		err(1, "format error[2]");

	memcpy(&u16, oldp, sizeof (u16));
	oldp += sizeof (u16);
	iov->iov_len = u16;

	if (oldp + iov->iov_len > finp)
		err(1, "format error[3]");

	iov->iov_base = (void *)oldp;
	oldp += iov->iov_len;

	if (oldp != finp)
		err(1, "format error[4]");

	puts("Public Key:");
	finp = &iov->iov_base[iov->iov_len];
	column = 0;
	oldp = iov->iov_base;
	while (oldp < finp) {
		if (column++ != 0)
			putchar(':');
		printf("%02x", (unsigned char) *oldp++);
		if (column >= 32) {
			column = 0;
			puts("");
		}
	}
	if (column < 32)
		puts("");
	puts("");
	puts("Modifier:");
	oldp = (const char*) cfg.cga_prepare.cga_modifier.octets;
	finp = &oldp[sizeof (cfg.cga_prepare.cga_modifier.octets)];
	column = 0;
	while (oldp < finp) {
		if (column++ != 0)
			putchar(':');
		printf("%02x", (unsigned char) *oldp++);
	}
	puts("\n");
	printf("Security Level: %u\n", cfg.cga_prepare.cga_security_level);
}

static void
write_cga_parameters(const char filename[])
{
	static char newb[SYSCTL_CGA_PARAMETERS_BUFFER_SIZE];

	int error;
	FILE* fp;
	size_t oldn, newn;

	fp = fopen(filename, "r");
	if (fp == NULL)
		err(1, "opening '%s' for reading.", filename);
	
	newn = fread(newb, 1, sizeof (newb), fp);
	if (feof(fp) == 0)
		err(1, "parameters too large");

	if (fclose(fp) != 0)
		err(1, "closing file.");

	oldn = 0;
	error = sysctlbyname("net.inet6.send.cga_parameters", NULL, NULL, newb,
	    newn);
	if (error != 0)
		err(1, "sysctlbyname");
}
