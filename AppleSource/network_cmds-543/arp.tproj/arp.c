/*
 * Copyright (c) 2003-2012 Apple Inc. All rights reserved.
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

#if 0
#ifndef lint
static char const copyright[] =
"@(#) Copyright (c) 1984, 1993\n\
	The Regents of the University of California.  All rights reserved.\n";
#endif /* not lint */
#endif

/*
 * arp - display, set, and delete arp table entries
 */


#include <sys/param.h>
#include <sys/file.h>
#include <sys/socket.h>
#include <sys/sockio.h>
#include <sys/sysctl.h>
#include <sys/ioctl.h>
#include <sys/time.h>

#include <net/if.h>
#include <net/if_dl.h>
#include <net/if_types.h>
#include <net/route.h>
#if 0
#include <net/iso88025.h>
#endif

#include <netinet/in.h>
#include <netinet/if_ether.h>

#include <arpa/inet.h>

#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <netdb.h>
#include <nlist.h>
#include <paths.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

typedef void (action_fn)(struct sockaddr_dl *sdl,
	struct sockaddr_inarp *s_in, struct rt_msghdr *rtm);
typedef void (action_ext_fn)(struct sockaddr_dl *sdl,
	struct sockaddr_inarp *s_in, struct rt_msghdr_ext *rtm);

static int search(in_addr_t addr, action_fn *action);
static int search_ext(in_addr_t addr, action_ext_fn *action);
static action_fn print_entry;
static action_fn nuke_entry;
static action_ext_fn print_entry_ext;

static char *print_lladdr(struct sockaddr_dl *);
static int delete(char *host, int do_proxy);
static void usage(void);
static int set(int argc, char **argv);
static int get(char *host);
static int file(char *name);
static struct rt_msghdr *rtmsg(int cmd,
    struct sockaddr_inarp *dst, struct sockaddr_dl *sdl);
static int get_ether_addr(in_addr_t ipaddr, struct ether_addr *hwaddr);
static struct sockaddr_inarp *getaddr(char *host);
static int valid_type(int type);
static char *sec2str(time_t);

static int nflag;	/* no reverse dns lookups */
static int xflag;	/* extended link-layer reachability information */
static char *rifname;

static int	expire_time, flags, doing_proxy, proxy_only;

static char *boundif = NULL;
static unsigned int ifscope = 0;

/* which function we're supposed to do */
#define F_GET		1
#define F_SET		2
#define F_FILESET	3
#define F_REPLACE	4
#define F_DELETE	5

#ifndef SA_SIZE
#define SA_SIZE(sa)                                             \
    (  (!(sa) || ((struct sockaddr *)(sa))->sa_len == 0) ?      \
        sizeof(uint32_t)            :                               \
        1 + ( (((struct sockaddr *)(sa))->sa_len - 1) | (sizeof(uint32_t) - 1) ) )
#endif

#define SETFUNC(f)	{ if (func) usage(); func = (f); }


int
main(int argc, char *argv[])
{
	int ch, func = 0;
	int rtn = 0;
	int aflag = 0;	/* do it for all entries */
	int lflag = 0;
	uint32_t ifindex = 0;

	while ((ch = getopt(argc, argv, "andflsSi:x")) != -1)
		switch((char)ch) {
		case 'a':
			aflag = 1;
			break;
		case 'd':
			SETFUNC(F_DELETE);
			break;
		case 'n':
			nflag = 1;
			break;
		case 'l':
			lflag = 1;
			break;
		case 'S':
			SETFUNC(F_REPLACE);
			break;
		case 's':
			SETFUNC(F_SET);
			break;
		case 'f' :
			SETFUNC(F_FILESET);
			break;
		case 'i':
			rifname = optarg;
			break;
		case 'x':
			xflag = 1;
			lflag = 1;
			break;
		case '?':
		default:
			usage();
		}
	argc -= optind;
	argv += optind;

	if (!func)
		func = F_GET;
	if (rifname) {
		if (func != F_GET && !(func == F_DELETE && aflag))
			errx(1, "-i not applicable to this operation");
		if ((ifindex = if_nametoindex(rifname)) == 0) {
			if (errno == ENXIO)
				errx(1, "interface %s does not exist", rifname);
			else
				err(1, "if_nametoindex(%s)", rifname);
		}
	}
	switch (func) {
	case F_GET:
		if (aflag) {
			if (argc != 0)
				usage();
			if (lflag) {
				printf("%-23s %-17s %-9.9s %-9.9s %8.8s %4s "
				    "%4s", "Neighbor",
				    "Linklayer Address", "Expire(O)",
				    "Expire(I)", "Netif", "Refs", "Prbs");
				if (xflag)
					printf(" %-7.7s %-7.7s %-7.7s",
					    "RSSI", "LQM", "NPM");
				printf("\n");
				search_ext(0, print_entry_ext);
			} else {
				search(0, print_entry);
			}
		} else {
			if (argc != 1)
				usage();
			rtn = get(argv[0]);
		}
		break;
	case F_SET:
	case F_REPLACE:
		if (argc < 2 || argc > 6)
			usage();
		if (func == F_REPLACE)
			(void)delete(argv[0], 0);
		rtn = set(argc, argv) ? 1 : 0;
		break;
	case F_DELETE:
		if (aflag) {
			if (argc != 0)
				usage();
			search(0, nuke_entry);
		} else {
			int do_proxy = 0;
			int i;
			
			for (i = 1; i < argc; i++) {
				if (strncmp(argv[i], "pub", sizeof("pub")) == 0) {
					do_proxy = SIN_PROXY;
				} else if (strncmp(argv[i], "ifscope", sizeof("ifscope")) == 0) {
					if (i + 1 >= argc) {
						printf("ifscope needs an interface parameter\n");
						return (1);
					}
					boundif = argv[++i];
					if ((ifscope = if_nametoindex(boundif)) == 0)
						errx(1, "ifscope has bad interface name: %s", boundif);
				} else {
					usage();
				}
			}
			if (i > argc)
				usage();
			rtn = delete(argv[0], do_proxy);
		}
		break;
	case F_FILESET:
		if (argc != 1)
			usage();
		rtn = file(argv[0]);
		break;
	}

	return (rtn);
}

/*
 * Process a file to set standard arp entries
 */
static int
file(char *name)
{
	FILE *fp;
	int i, retval;
	char line[128], arg[7][50], *args[7], *p;

	if ((fp = fopen(name, "r")) == NULL)
		err(1, "cannot open %s", name);
	args[0] = &arg[0][0];
	args[1] = &arg[1][0];
	args[2] = &arg[2][0];
	args[3] = &arg[3][0];
	args[4] = &arg[4][0];
	args[5] = &arg[5][0];
	args[6] = &arg[6][0];
	retval = 0;
	while(fgets(line, sizeof(line), fp) != NULL) {
		if ((p = strchr(line, '#')) != NULL)
			*p = '\0';
		for (p = line; isblank(*p); p++);
		if (*p == '\n' || *p == '\0')
			continue;
		i = sscanf(p, "%49s %49s %49s %49s %49s %49s %49s", arg[0], arg[1],
		    arg[2], arg[3], arg[4], arg[5], arg[6]);
		if (i < 2) {
			warnx("bad line: %s", line);
			retval = 1;
			continue;
		}
		if (set(i, args))
			retval = 1;
	}
	fclose(fp);
	return (retval);
}

/*
 * Given a hostname, fills up a (static) struct sockaddr_inarp with
 * the address of the host and returns a pointer to the
 * structure.
 */
static struct sockaddr_inarp *
getaddr(char *host)
{
	struct hostent *hp;
	static struct sockaddr_inarp reply;

	bzero(&reply, sizeof(reply));
	reply.sin_len = sizeof(reply);
	reply.sin_family = AF_INET;
	reply.sin_addr.s_addr = inet_addr(host);
	if (reply.sin_addr.s_addr == INADDR_NONE) {
		if (!(hp = gethostbyname(host))) {
			warnx("%s: %s", host, hstrerror(h_errno));
			return (NULL);
		}
		bcopy((char *)hp->h_addr, (char *)&reply.sin_addr,
			sizeof reply.sin_addr);
	}
	return (&reply);
}

/*
 * Returns true if the type is a valid one for ARP.
 */
static int
valid_type(int type)
{

	switch (type) {
	case IFT_ETHER:
	case IFT_FDDI:
	case IFT_ISO88023:
	case IFT_ISO88024:
#if 0
	case IFT_ISO88025:
#endif
	case IFT_L2VLAN:
#ifdef IFT_BRIDGE
	case IFT_BRIDGE:
#endif
		return (1);
	default:
		return (0);
	}
}

/*
 * Set an individual arp entry
 */
static int
set(int argc, char **argv)
{
	struct sockaddr_inarp *addr;
	struct sockaddr_inarp *dst;	/* what are we looking for */
	struct sockaddr_dl *sdl;
	struct rt_msghdr *rtm;
	struct ether_addr *ea;
	char *host = argv[0], *eaddr = argv[1];
	struct sockaddr_dl sdl_m;

	argc -= 2;
	argv += 2;

	bzero(&sdl_m, sizeof(sdl_m));
	sdl_m.sdl_len = sizeof(sdl_m);
	sdl_m.sdl_family = AF_LINK;

	dst = getaddr(host);
	if (dst == NULL)
		return (1);
	doing_proxy = flags = proxy_only = expire_time = 0;
	boundif = NULL;
	ifscope = 0;
	while (argc-- > 0) {
		if (strncmp(argv[0], "temp", sizeof("temp")) == 0) {
			struct timeval tv;
			gettimeofday(&tv, 0);
			expire_time = tv.tv_sec + 20 * 60;
		} else if (strncmp(argv[0], "pub", sizeof("pub")) == 0) {
			flags |= RTF_ANNOUNCE;
			doing_proxy = 1;
			if (argc && strncmp(argv[1], "only", sizeof("only")) == 0) {
				proxy_only = 1;
				dst->sin_other = SIN_PROXY;
				argc--; argv++;
			}
		} else if (strncmp(argv[0], "blackhole", sizeof("blackhole")) == 0) {
			flags |= RTF_BLACKHOLE;
		} else if (strncmp(argv[0], "reject", sizeof("reject")) == 0) {
			flags |= RTF_REJECT;
		} else if (strncmp(argv[0], "trail", sizeof("trail")) == 0) {
			/* XXX deprecated and undocumented feature */
			printf("%s: Sending trailers is no longer supported\n",
				host);
		} else if (strncmp(argv[0], "ifscope", sizeof("ifscope")) == 0) {
			if (argc < 1) {
				printf("ifscope needs an interface parameter\n");
				return (1);
			}
			boundif = argv[1];
			if ((ifscope = if_nametoindex(boundif)) == 0)
				errx(1, "ifscope has bad interface name: %s", boundif);
			argc--; argv++;
		}
		argv++;
	}
	ea = (struct ether_addr *)LLADDR(&sdl_m);
	if (doing_proxy && !strcmp(eaddr, "auto")) {
		if (!get_ether_addr(dst->sin_addr.s_addr, ea)) {
			printf("no interface found for %s\n",
			       inet_ntoa(dst->sin_addr));
			return (1);
		}
		sdl_m.sdl_alen = ETHER_ADDR_LEN;
	} else {
		struct ether_addr *ea1 = ether_aton(eaddr);

		if (ea1 == NULL) {
			warnx("invalid Ethernet address '%s'", eaddr);
			return (1);
		} else {
			*ea = *ea1;
			sdl_m.sdl_alen = ETHER_ADDR_LEN;
		}
	}
	for (;;) {	/* try at most twice */
		rtm = rtmsg(RTM_GET, dst, &sdl_m);
		if (rtm == NULL) {
			warn("%s", host);
			return (1);
		}
		addr = (struct sockaddr_inarp *)(rtm + 1);
		sdl = (struct sockaddr_dl *)(SA_SIZE(addr) + (char *)addr);
		if (addr->sin_addr.s_addr != dst->sin_addr.s_addr)	
			break;
		if (sdl->sdl_family == AF_LINK &&
		    (rtm->rtm_flags & RTF_LLINFO) &&
		    !(rtm->rtm_flags & RTF_GATEWAY) &&
		    valid_type(sdl->sdl_type) )
			break;
		/*
		 * If we asked for a scope entry and did not get one or 
		 * did not asked for a scope entry and got one, we can 
		 * proceed.
		 */
		if ((ifscope != 0) != (rtm->rtm_flags & RTF_IFSCOPE))
			break;
		if (doing_proxy == 0) {
			printf("set: can only proxy for %s\n", host);
			return (1);
		}
		if (dst->sin_other & SIN_PROXY) {
			printf("set: proxy entry exists for non 802 device\n");
			return (1);
		}
		dst->sin_other = SIN_PROXY;
		proxy_only = 1;
	}

	if (sdl->sdl_family != AF_LINK) {
		printf("cannot intuit interface index and type for %s\n", host);
		return (1);
	}
	sdl_m.sdl_type = sdl->sdl_type;
	sdl_m.sdl_index = sdl->sdl_index;
	return (rtmsg(RTM_ADD, dst, &sdl_m) == NULL);
}

/*
 * Display an individual arp entry
 */
static int
get(char *host)
{
	struct sockaddr_inarp *addr;

	addr = getaddr(host);
	if (addr == NULL)
		return (1);
	if (0 == search(addr->sin_addr.s_addr, print_entry)) {
		printf("%s (%s) -- no entry",
		    host, inet_ntoa(addr->sin_addr));
		if (rifname)
			printf(" on %s", rifname);
		printf("\n");
		return (1);
	}
	return (0);
}

/*
 * Delete an arp entry
 */
static int
delete(char *host, int do_proxy)
{
	struct sockaddr_inarp *addr, *dst;
	struct rt_msghdr *rtm;
	struct sockaddr_dl *sdl;

	dst = getaddr(host);
	if (dst == NULL)
		return (1);
	dst->sin_other = do_proxy;
	for (;;) {	/* try twice */
		rtm = rtmsg(RTM_GET, dst, NULL);
		if (rtm == NULL) {
			warn("%s", host);
			return (1);
		}
		addr = (struct sockaddr_inarp *)(rtm + 1);
		sdl = (struct sockaddr_dl *)(SA_SIZE(addr) + (char *)addr);
		if (addr->sin_addr.s_addr == dst->sin_addr.s_addr &&
		    sdl->sdl_family == AF_LINK &&
		    (rtm->rtm_flags & RTF_LLINFO) &&
		    !(rtm->rtm_flags & RTF_GATEWAY) &&
		    valid_type(sdl->sdl_type) )
			break;	/* found it */
		if (dst->sin_other & SIN_PROXY) {
			fprintf(stderr, "delete: cannot locate %s\n",host);
			return (1);
		}
		dst->sin_other = SIN_PROXY;
	}
	if (rtmsg(RTM_DELETE, dst, NULL) != NULL) {
		printf("%s (%s) deleted\n", host, inet_ntoa(addr->sin_addr));
		return (0);
	}
	return (1);
}

/*
 * Search the arp table and do some action on matching entries
 */
static int
search(in_addr_t addr, action_fn *action)
{
	int mib[6];
	size_t needed;
	char *lim, *buf, *newbuf, *next;
	struct rt_msghdr *rtm;
	struct sockaddr_inarp *sin2;
	struct sockaddr_dl *sdl;
	char ifname[IF_NAMESIZE];
	int st, found_entry = 0;

	mib[0] = CTL_NET;
	mib[1] = PF_ROUTE;
	mib[2] = 0;
	mib[3] = AF_INET;
	mib[4] = NET_RT_FLAGS;
	mib[5] = RTF_LLINFO;
	if (sysctl(mib, 6, NULL, &needed, NULL, 0) < 0)
		err(1, "route-sysctl-estimate");
	if (needed == 0)	/* empty table */
		return 0;
	buf = NULL;
	for (;;) {
		newbuf = realloc(buf, needed);
		if (newbuf == NULL) {
			if (buf != NULL)
				free(buf);
			errx(1, "could not reallocate memory");
		}
		buf = newbuf;
		st = sysctl(mib, 6, buf, &needed, NULL, 0);
		if (st == 0 || errno != ENOMEM)
			break;
		needed += needed / 8;
	}
	if (st == -1)
		err(1, "actual retrieval of routing table");
	lim = buf + needed;
	for (next = buf; next < lim; next += rtm->rtm_msglen) {
		rtm = (struct rt_msghdr *)next;
		sin2 = (struct sockaddr_inarp *)(rtm + 1);
		sdl = (struct sockaddr_dl *)((char *)sin2 + SA_SIZE(sin2));
		if (rifname && if_indextoname(sdl->sdl_index, ifname) &&
		    strcmp(ifname, rifname))
			continue;
		if (addr) {
			if (addr != sin2->sin_addr.s_addr)
				continue;
			found_entry = 1;
		}
		(*action)(sdl, sin2, rtm);
	}
	free(buf);
	return (found_entry);
}

/*
 * Stolen and adapted from ifconfig
 */
static char *
print_lladdr(struct sockaddr_dl *sdl)
{
	static char buf[256];
        char *cp;
        int n, bufsize = sizeof (buf), p = 0;

	bzero(buf, sizeof (buf));
        cp = (char *)LLADDR(sdl);
        if ((n = sdl->sdl_alen) > 0) {
                while (--n >= 0)
                        p += snprintf(buf + p, bufsize - p, "%x%s",
			    *cp++ & 0xff, n > 0 ? ":" : "");
        }
	return (buf);
}

/*
 * Display an arp entry
 */
static void
print_entry(struct sockaddr_dl *sdl,
	struct sockaddr_inarp *addr, struct rt_msghdr *rtm)
{
	const char *host;
	struct hostent *hp;
	char ifname[IF_NAMESIZE];
#if 0
	struct iso88025_sockaddr_dl_data *trld;
	int seg;
#endif

	if (nflag == 0)
		hp = gethostbyaddr((caddr_t)&(addr->sin_addr),
		    sizeof addr->sin_addr, AF_INET);
	else
		hp = 0;
	if (hp)
		host = hp->h_name;
	else {
		host = "?";
		if (h_errno == TRY_AGAIN)
			nflag = 1;
	}
	printf("%s (%s) at ", host, inet_ntoa(addr->sin_addr));
	if (sdl->sdl_alen) {
#if 1
		printf("%s", print_lladdr(sdl));
#else
		if ((sdl->sdl_type == IFT_ETHER ||
		    sdl->sdl_type == IFT_L2VLAN ||
		    sdl->sdl_type == IFT_BRIDGE) &&
		    sdl->sdl_alen == ETHER_ADDR_LEN)
			printf("%s", ether_ntoa((struct ether_addr *)LLADDR(sdl)));
		else {
			int n = sdl->sdl_nlen > 0 ? sdl->sdl_nlen + 1 : 0;

			printf("%s", link_ntoa(sdl) + n);
		}
#endif
	} else
		printf("(incomplete)");
	if (if_indextoname(sdl->sdl_index, ifname) != NULL)
		printf(" on %s", ifname);
	if ((rtm->rtm_flags & RTF_IFSCOPE))
		printf(" ifscope");
	if (rtm->rtm_rmx.rmx_expire == 0)
		printf(" permanent");
	if (addr->sin_other & SIN_PROXY)
		printf(" published (proxy only)");
	if (rtm->rtm_addrs & RTA_NETMASK) {
		addr = (struct sockaddr_inarp *)
			(SA_SIZE(sdl) + (char *)sdl);
		if (addr->sin_addr.s_addr == 0xffffffff)
			printf(" published");
		if (addr->sin_len != 8)
			printf("(weird)");
	}
        switch(sdl->sdl_type) {
	case IFT_ETHER:
                printf(" [ethernet]");
                break;
#if 0
	case IFT_ISO88025:
                printf(" [token-ring]");
		trld = SDL_ISO88025(sdl);
		if (trld->trld_rcf != 0) {
			printf(" rt=%x", ntohs(trld->trld_rcf));
			for (seg = 0;
			     seg < ((TR_RCF_RIFLEN(trld->trld_rcf) - 2 ) / 2);
			     seg++) 
				printf(":%x", ntohs(*(trld->trld_route[seg])));
		}
                break;
#endif
	case IFT_FDDI:
                printf(" [fddi]");
                break;
	case IFT_ATM:
                printf(" [atm]");
                break;
	case IFT_L2VLAN:
		printf(" [vlan]");
		break;
	case IFT_IEEE1394:
                printf(" [firewire]");
                break;
#ifdef IFT_BRIDGE
	case IFT_BRIDGE:
		printf(" [bridge]");
		break;
#endif
	default:
		break;
        }
		
	printf("\n");

}

/*
 * Nuke an arp entry
 */
static void
nuke_entry(struct sockaddr_dl *sdl __unused,
	struct sockaddr_inarp *addr, struct rt_msghdr *rtm)
{
	char ip[20];

	snprintf(ip, sizeof(ip), "%s", inet_ntoa(addr->sin_addr));
	/*
	 * When deleting all entries, specify the interface scope of each entry 
	 */
	if ((rtm->rtm_flags & RTF_IFSCOPE))
		ifscope = rtm->rtm_index;
	(void)delete(ip, 0);
	ifscope = 0;
}

static void
usage(void)
{
	fprintf(stderr, "%s\n%s\n%s\n%s\n%s\n%s\n%s\n",
		"usage: arp [-n] [-i interface] hostname",
		"       arp [-n] [-i interface] [-l] -a",
		"       arp -d hostname [pub] [ifscope interface]",
		"       arp -d [-i interface] -a",
		"       arp -s hostname ether_addr [temp] [reject] [blackhole] [pub [only]] [ifscope interface]",
		"       arp -S hostname ether_addr [temp] [reject] [blackhole] [pub [only]] [ifscope interface]",
		"       arp -f filename");
	exit(1);
}

static struct rt_msghdr *
rtmsg(int cmd, struct sockaddr_inarp *dst, struct sockaddr_dl *sdl)
{
	static int seq;
	int rlen;
	int l;
	struct sockaddr_in so_mask, *so_mask_ptr = &so_mask;
	static int s = -1;
	static pid_t pid;

	static struct	{
		struct	rt_msghdr m_rtm;
		char	m_space[512];
	}	m_rtmsg;

	struct rt_msghdr *rtm = &m_rtmsg.m_rtm;
	char *cp = m_rtmsg.m_space;

	if (s < 0) {	/* first time: open socket, get pid */
		s = socket(PF_ROUTE, SOCK_RAW, 0);
		if (s < 0)
			err(1, "socket");
		pid = getpid();
	}
	bzero(&so_mask, sizeof(so_mask));
	so_mask.sin_len = 8;
	so_mask.sin_addr.s_addr = 0xffffffff;

	errno = 0;
	/*
	 * XXX RTM_DELETE relies on a previous RTM_GET to fill the buffer
	 * appropriately (except for the mask set just above).
	 */
	if (cmd == RTM_DELETE)
		goto doit;
	bzero((char *)&m_rtmsg, sizeof(m_rtmsg));
	rtm->rtm_flags = flags;
	rtm->rtm_version = RTM_VERSION;

	/*
	 * Note: On RTM_GET the kernel will return a scoped route when both a scoped route and 
	 * a unscoped route exist. That means we cannot delete a unscoped route if there is 
	 * also a matching scope route
	 */
	if (ifscope) {
		rtm->rtm_index = ifscope;
		rtm->rtm_flags |= RTF_IFSCOPE;
	}
	
	switch (cmd) {
	default:
		errx(1, "internal wrong cmd");
	case RTM_ADD:
		rtm->rtm_addrs |= RTA_GATEWAY;
		rtm->rtm_rmx.rmx_expire = expire_time;
		rtm->rtm_inits = RTV_EXPIRE;
		rtm->rtm_flags |= (RTF_HOST | RTF_STATIC);
		dst->sin_other = 0;
		if (doing_proxy) {
			if (proxy_only)
				dst->sin_other = SIN_PROXY;
			else {
				rtm->rtm_addrs |= RTA_NETMASK;
				rtm->rtm_flags &= ~RTF_HOST;
			}
		}
		/* FALLTHROUGH */
	case RTM_GET:
		rtm->rtm_addrs |= RTA_DST;
	}
#define NEXTADDR(w, s) \
	if ((s) != NULL && rtm->rtm_addrs & (w)) { \
		bcopy((s), cp, sizeof(*(s))); cp += SA_SIZE(s);}

	NEXTADDR(RTA_DST, dst);
	NEXTADDR(RTA_GATEWAY, sdl);
	NEXTADDR(RTA_NETMASK, so_mask_ptr);

	rtm->rtm_msglen = cp - (char *)&m_rtmsg;
doit:
	l = rtm->rtm_msglen;
	rtm->rtm_seq = ++seq;
	rtm->rtm_type = cmd;
	if ((rlen = write(s, (char *)&m_rtmsg, l)) < 0) {
		if (errno != ESRCH || cmd != RTM_DELETE) {
			warn("writing to routing socket");
			return (NULL);
		}
	}
	do {
		l = read(s, (char *)&m_rtmsg, sizeof(m_rtmsg));
	} while (l > 0 && (rtm->rtm_seq != seq || rtm->rtm_pid != pid));
	if (l < 0)
		warn("read from routing socket");
	return (rtm);
}

/*
 * get_ether_addr - get the hardware address of an interface on the
 * the same subnet as ipaddr.
 */
#define MAX_IFS		32

static int
get_ether_addr(in_addr_t ipaddr, struct ether_addr *hwaddr)
{
	struct ifreq *ifr, *ifend, *ifp;
	in_addr_t ina, mask;
	struct sockaddr_dl *dla;
	struct ifreq ifreq;
	struct ifconf ifc;
	struct ifreq ifs[MAX_IFS];
	int sock;
	int retval = 0;

	sock = socket(AF_INET, SOCK_DGRAM, 0);
	if (sock < 0)
		err(1, "socket");

	ifc.ifc_len = sizeof(ifs);
	ifc.ifc_req = ifs;
	if (ioctl(sock, SIOCGIFCONF, &ifc) < 0) {
		warnx("ioctl(SIOCGIFCONF)");
		goto done;
	}

#define NEXTIFR(i)						\
    ((struct ifreq *)((char *)&(i)->ifr_addr			\
	+ MAX((i)->ifr_addr.sa_len, sizeof((i)->ifr_addr))) )

	/*
	 * Scan through looking for an interface with an Internet
	 * address on the same subnet as `ipaddr'.
	 */
	ifend = (struct ifreq *)(ifc.ifc_buf + ifc.ifc_len);
	for (ifr = ifc.ifc_req; ifr < ifend; ifr = NEXTIFR(ifr) ) {
		if (ifr->ifr_addr.sa_family != AF_INET)
			continue;
		strncpy(ifreq.ifr_name, ifr->ifr_name,
			sizeof(ifreq.ifr_name));
		ifreq.ifr_addr = ifr->ifr_addr;
		/*
		 * Check that the interface is up,
		 * and not point-to-point or loopback.
		 */
		if (ioctl(sock, SIOCGIFFLAGS, &ifreq) < 0)
			continue;
		if ((ifreq.ifr_flags &
		     (IFF_UP|IFF_BROADCAST|IFF_POINTOPOINT|
				IFF_LOOPBACK|IFF_NOARP))
		     != (IFF_UP|IFF_BROADCAST))
			continue;
		/*
		 * Get its netmask and check that it's on 
		 * the right subnet.
		 */
		if (ioctl(sock, SIOCGIFNETMASK, &ifreq) < 0)
			continue;
		mask = ((struct sockaddr_in *)
			&ifreq.ifr_addr)->sin_addr.s_addr;
		ina = ((struct sockaddr_in *)
			&ifr->ifr_addr)->sin_addr.s_addr;
		if ((ipaddr & mask) == (ina & mask))
			break; /* ok, we got it! */
	}

	if (ifr >= ifend)
		goto done;

	/*
	 * Now scan through again looking for a link-level address
	 * for this interface.
	 */
	ifp = ifr;
	for (ifr = ifc.ifc_req; ifr < ifend; ifr = NEXTIFR(ifr))
		if (strcmp(ifp->ifr_name, ifr->ifr_name) == 0 &&
		    ifr->ifr_addr.sa_family == AF_LINK)
			break;
	if (ifr >= ifend)
		goto done;
	/*
	 * Found the link-level address - copy it out
	 */
	dla = (struct sockaddr_dl *) &ifr->ifr_addr;
	memcpy(hwaddr,  LLADDR(dla), dla->sdl_alen);
	printf("using interface %s for proxy with address ",
		ifp->ifr_name);
	printf("%s\n", ether_ntoa(hwaddr));
	retval = dla->sdl_alen;
done:
	close(sock);
	return (retval);
}

static char *
sec2str(total)
	time_t total;
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
		p += snprintf(p, sizeof(result) - (p - result), "%dd", days);
	}
	if (!first || hours) {
		first = 0;
		p += snprintf(p, sizeof(result) - (p - result), "%dh", hours);
	}
	if (!first || mins) {
		first = 0;
		p += snprintf(p, sizeof(result) - (p - result), "%dm", mins);
	}
	snprintf(p, sizeof(result) - (p - result), "%ds", secs);

	return(result);
}

static int
search_ext(in_addr_t addr, action_ext_fn *action)
{
	int mib[6];
	size_t needed;
	char *lim, *buf, *newbuf, *next;
	struct rt_msghdr_ext *ertm;
	struct sockaddr_inarp *sin2;
	struct sockaddr_dl *sdl;
	char ifname[IF_NAMESIZE];
	int st, found_entry = 0;

	mib[0] = CTL_NET;
	mib[1] = PF_ROUTE;
	mib[2] = 0;
	mib[3] = AF_INET;
	mib[4] = NET_RT_DUMPX_FLAGS;
	mib[5] = RTF_LLINFO;
	if (sysctl(mib, 6, NULL, &needed, NULL, 0) < 0)
		err(1, "route-sysctl-estimate");
	if (needed == 0)	/* empty table */
		return 0;
	buf = NULL;
	for (;;) {
		newbuf = realloc(buf, needed);
		if (newbuf == NULL) {
			if (buf != NULL)
				free(buf);
			errx(1, "could not reallocate memory");
		}
		buf = newbuf;
		st = sysctl(mib, 6, buf, &needed, NULL, 0);
		if (st == 0 || errno != ENOMEM)
			break;
		needed += needed / 8;
	}
	if (st == -1)
		err(1, "actual retrieval of routing table");
	lim = buf + needed;
	for (next = buf; next < lim; next += ertm->rtm_msglen) {
		ertm = (struct rt_msghdr_ext *)next;
		sin2 = (struct sockaddr_inarp *)(ertm + 1);
		sdl = (struct sockaddr_dl *)((char *)sin2 + SA_SIZE(sin2));
		if (rifname && if_indextoname(sdl->sdl_index, ifname) &&
		    strcmp(ifname, rifname))
			continue;
		if (addr) {
			if (addr != sin2->sin_addr.s_addr)
				continue;
			found_entry = 1;
		}
		(*action)(sdl, sin2, ertm);
	}
	free(buf);
	return (found_entry);
}

static void
print_entry_ext(struct sockaddr_dl *sdl, struct sockaddr_inarp *addr,
    struct rt_msghdr_ext *ertm)
{
	const char *host;
	struct hostent *hp;
	char ifname[IF_NAMESIZE];
	struct timeval time;

	if (nflag == 0)
		hp = gethostbyaddr((caddr_t)&(addr->sin_addr),
		    sizeof (addr->sin_addr), AF_INET);
	else
		hp = 0;

	if (hp)
		host = hp->h_name;
	else
		host = inet_ntoa(addr->sin_addr);

	printf("%-23s ", host);

	if (sdl->sdl_alen)
		printf("%-17s ", print_lladdr(sdl));
	else
		printf("%-17s ", "(incomplete)");

	gettimeofday(&time, 0);

	if (ertm->rtm_ri.ri_refcnt == 0 || ertm->rtm_ri.ri_snd_expire == 0)
		printf("%-9.9s ", "(none)");
	else if (ertm->rtm_ri.ri_snd_expire > time.tv_sec)
		printf("%-9.9s ",
		    sec2str(ertm->rtm_ri.ri_snd_expire - time.tv_sec));
	else
		printf("%-9.9s ", "expired");

	if (ertm->rtm_ri.ri_refcnt == 0 || ertm->rtm_ri.ri_rcv_expire == 0)
		printf("%-9.9s", "(none)");
	else if (ertm->rtm_ri.ri_rcv_expire > time.tv_sec)
		printf("%-9.9s",
		    sec2str(ertm->rtm_ri.ri_rcv_expire - time.tv_sec));
	else
		printf("%-9.9s", "expired");

	if (if_indextoname(sdl->sdl_index, ifname) == NULL)
		snprintf(ifname, sizeof (ifname), "%s", "?");
	printf(" %8.8s", ifname);

	if (ertm->rtm_ri.ri_refcnt) {
		printf(" %4d", ertm->rtm_ri.ri_refcnt);
		if (ertm->rtm_ri.ri_probes)
			printf(" %4d", ertm->rtm_ri.ri_probes);

		if (xflag) {
			if (!ertm->rtm_ri.ri_probes)
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
	}
	printf("\n");
}
