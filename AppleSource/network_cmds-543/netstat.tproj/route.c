/*
 * Copyright (c) 2008-2017 Apple Inc. All rights reserved.
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
 *	The Regents of the University of California.  All rights reserved.
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

#include <stdint.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <sys/time.h>

#include <net/if.h>
#include <net/if_var.h>
#include <net/if_dl.h>
#include <net/if_types.h>
#include <net/route.h>
#include <net/radix.h>

#include <netinet/in.h>

#include <sys/sysctl.h>

#include <arpa/inet.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <err.h>
#include <time.h>
#include "netstat.h"

/* alignment constraint for routing socket */
#define ROUNDUP(a) \
       ((a) > 0 ? (1 + (((a) - 1) | (sizeof(uint32_t) - 1))) : sizeof(uint32_t))
#define ADVANCE(x, n) (x += ROUNDUP((n)->sa_len))

/*
 * Definitions for showing gateway flags.
 */
struct bits {
	uint32_t	b_mask;
	char	b_val;
} bits[] = {
	{ RTF_UP,	'U' },
	{ RTF_GATEWAY,	'G' },
	{ RTF_HOST,	'H' },
	{ RTF_REJECT,	'R' },
	{ RTF_DYNAMIC,	'D' },
	{ RTF_MODIFIED,	'M' },
	{ RTF_MULTICAST,'m' },
	{ RTF_DONE,	'd' }, /* Completed -- for routing messages only */
	{ RTF_CLONING,	'C' },
	{ RTF_XRESOLVE,	'X' },
	{ RTF_LLINFO,	'L' },
	{ RTF_STATIC,	'S' },
	{ RTF_PROTO1,	'1' },
	{ RTF_PROTO2,	'2' },
	{ RTF_WASCLONED,'W' },
	{ RTF_PRCLONING,'c' },
	{ RTF_PROTO3,	'3' },
	{ RTF_BLACKHOLE,'B' },
	{ RTF_BROADCAST,'b' },
	{ RTF_IFSCOPE,	'I' },
	{ RTF_IFREF,	'i' },
	{ RTF_PROXY,	'Y' },
	{ RTF_ROUTER,	'r' },
	{ 0 }
};

typedef union {
	uint32_t dummy;		/* Helps align structure. */
	struct	sockaddr u_sa;
	u_short	u_data[128];
} sa_u;

static void np_rtentry __P((struct rt_msghdr2 *));
static void p_sockaddr __P((struct sockaddr *, struct sockaddr *, int, int));
static void p_flags __P((int, char *));
static uint32_t forgemask __P((uint32_t));
static void domask __P((char *, uint32_t, uint32_t));

/*
 * Print address family header before a section of the routing table.
 */
void
pr_family(int af)
{
	char *afname;

	switch (af) {
	case AF_INET:
		afname = "Internet";
		break;
#ifdef INET6
	case AF_INET6:
		afname = "Internet6";
		break;
#endif /*INET6*/
	case AF_IPX:
		afname = "IPX";
		break;
	default:
		afname = NULL;
		break;
	}
	if (afname)
		printf("\n%s:\n", afname);
	else
		printf("\nProtocol Family %d:\n", af);
}

/* column widths; each followed by one space */
#ifndef INET6
#define	WID_DST(af) 	18	/* width of destination column */
#define	WID_GW(af)	18	/* width of gateway column */
#define	WID_IF(af)	7	/* width of netif column */
#else
#define	WID_DST(af) \
	((af) == AF_INET6 ? (lflag ? 39 : (nflag ? 39: 18)) : 18)
#define	WID_GW(af) \
	((af) == AF_INET6 ? (lflag ? 31 : (nflag ? 31 : 18)) : 18)
#define	WID_IF(af)	((af) == AF_INET6 ? 8 : 7)
#endif /*INET6*/

/*
 * Print header for routing table columns.
 */
void
pr_rthdr(int af)
{

	if (Aflag)
		printf("%-8.8s ","Address");
	if (af == AF_INET || lflag)
		if (lflag)
			printf("%-*.*s %-*.*s %-10.10s %6.6s %8.8s %6.6s %*.*s %6s\n",
				WID_DST(af), WID_DST(af), "Destination",
				WID_GW(af), WID_GW(af), "Gateway",
				"Flags", "Refs", "Use", "Mtu",
				WID_IF(af), WID_IF(af), "Netif", "Expire");
		else
			printf("%-*.*s %-*.*s %-10.10s %6.6s %8.8s %*.*s %6s\n",
				WID_DST(af), WID_DST(af), "Destination",
				WID_GW(af), WID_GW(af), "Gateway",
				"Flags", "Refs", "Use",
				WID_IF(af), WID_IF(af), "Netif", "Expire");
	else
		printf("%-*.*s %-*.*s %-10.10s %8.8s %6s\n",
			WID_DST(af), WID_DST(af), "Destination",
			WID_GW(af), WID_GW(af), "Gateway",
			"Flags", "Netif", "Expire");
}

/*
 * Print routing tables.
 */
void
routepr(void)
{
	size_t needed;
	int mib[6];
	char *buf, *next, *lim;
	struct rt_msghdr2 *rtm;

	printf("Routing tables\n");

	mib[0] = CTL_NET;
	mib[1] = PF_ROUTE;
	mib[2] = 0;
	mib[3] = 0;
	mib[4] = NET_RT_DUMP2;
	mib[5] = 0;
	if (sysctl(mib, 6, NULL, &needed, NULL, 0) < 0) {
		err(1, "sysctl: net.route.0.0.dump estimate");
	}

	if ((buf = malloc(needed)) == 0) {
		err(2, "malloc(%lu)", (unsigned long)needed);
	}
	if (sysctl(mib, 6, buf, &needed, NULL, 0) < 0) {
		err(1, "sysctl: net.route.0.0.dump");
	}
	lim  = buf + needed;
	for (next = buf; next < lim; next += rtm->rtm_msglen) {
		rtm = (struct rt_msghdr2 *)next;
		np_rtentry(rtm);
	}
}

static void
get_rtaddrs(int addrs, struct sockaddr *sa, struct sockaddr **rti_info)
{
        int i;
        
        for (i = 0; i < RTAX_MAX; i++) {
                if (addrs & (1 << i)) {
                        rti_info[i] = sa;
						sa = (struct sockaddr *)(ROUNDUP(sa->sa_len) + (char *)sa);
		} else {
                        rti_info[i] = NULL;
        }
}
}

static void
np_rtentry(struct rt_msghdr2 *rtm)
{
	struct sockaddr *sa = (struct sockaddr *)(rtm + 1);
	struct sockaddr *rti_info[RTAX_MAX];
	static int old_fam;
	int fam = 0;
	u_short lastindex = 0xffff;
	static char ifname[IFNAMSIZ + 1];
	sa_u addr, mask;

	/*
	 * Don't print protocol-cloned routes unless -a.
	 */
	if ((rtm->rtm_flags & RTF_WASCLONED) &&
	    (rtm->rtm_parentflags & RTF_PRCLONING) &&
	    !aflag) {
			return;
	}

	fam = sa->sa_family;
	if (af != AF_UNSPEC && af != fam)
		return;
	if (fam != old_fam) {
		pr_family(fam);
		pr_rthdr(fam);
		old_fam = fam;
	}
	get_rtaddrs(rtm->rtm_addrs, sa, rti_info);
	bzero(&addr, sizeof(addr));
	if ((rtm->rtm_addrs & RTA_DST))
		bcopy(rti_info[RTAX_DST], &addr, rti_info[RTAX_DST]->sa_len);
	bzero(&mask, sizeof(mask));
	if ((rtm->rtm_addrs & RTA_NETMASK))
		bcopy(rti_info[RTAX_NETMASK], &mask, rti_info[RTAX_NETMASK]->sa_len);
	p_sockaddr(&addr.u_sa, &mask.u_sa, rtm->rtm_flags,
	    WID_DST(addr.u_sa.sa_family));

	p_sockaddr(rti_info[RTAX_GATEWAY], NULL, RTF_HOST,
	    WID_GW(addr.u_sa.sa_family));
	
	p_flags(rtm->rtm_flags, "%-10.10s ");

	if (addr.u_sa.sa_family == AF_INET || lflag) {
		printf("%6u %8u ", rtm->rtm_refcnt, (unsigned int)rtm->rtm_use);
		if (lflag) {
			if (rtm->rtm_rmx.rmx_mtu != 0)
				printf("%6u ", rtm->rtm_rmx.rmx_mtu);
			else
				printf("%6s ", "");
		}
	}
	if (rtm->rtm_index != lastindex) {
		if_indextoname(rtm->rtm_index, ifname);
		lastindex = rtm->rtm_index;
	}
	printf("%*.*s", WID_IF(addr.u_sa.sa_family),
		WID_IF(addr.u_sa.sa_family), ifname);

	if (rtm->rtm_rmx.rmx_expire) {
		time_t expire_time;

		if ((expire_time =
			rtm->rtm_rmx.rmx_expire - time((time_t *)0)) > 0)
			printf(" %6d", (int)expire_time);
	}
	putchar('\n');
}

static void
p_sockaddr(struct sockaddr *sa, struct sockaddr *mask, int flags, int width)
{
	char workbuf[128], *cplim;
	char *cp = workbuf;

	switch(sa->sa_family) {
	case AF_INET: {
		struct sockaddr_in *sin = (struct sockaddr_in *)sa;

		if ((sin->sin_addr.s_addr == INADDR_ANY) &&
			mask &&
		    (ntohl(((struct sockaddr_in *)mask)->sin_addr.s_addr) == 0L || mask->sa_len == 0))
				cp = "default" ;
		else if (flags & RTF_HOST)
			cp = routename(sin->sin_addr.s_addr);
		else if (mask)
			cp = netname(sin->sin_addr.s_addr,
			    ntohl(((struct sockaddr_in *)mask)->
			    sin_addr.s_addr));
		else
			cp = netname(sin->sin_addr.s_addr, 0L);
		break;
	    }

#ifdef INET6
	case AF_INET6: {
		struct sockaddr_in6 *sa6 = (struct sockaddr_in6 *)sa;
		struct in6_addr *in6 = &sa6->sin6_addr;

		/*
		 * XXX: This is a special workaround for KAME kernels.
		 * sin6_scope_id field of SA should be set in the future.
		 */
		if (IN6_IS_ADDR_LINKLOCAL(in6) ||
		    IN6_IS_ADDR_MC_NODELOCAL(in6) ||
		    IN6_IS_ADDR_MC_LINKLOCAL(in6)) {
		    /* XXX: override is ok? */
		    sa6->sin6_scope_id = (u_int32_t)ntohs(*(u_short *)&in6->s6_addr[2]);
		    *(u_short *)&in6->s6_addr[2] = 0;
		}

		if (flags & RTF_HOST)
		    cp = routename6(sa6);
		else if (mask)
		    cp = netname6(sa6, mask);
		else
		    cp = netname6(sa6, NULL);
		break;
	    }
#endif /*INET6*/

	case AF_LINK: {
		struct sockaddr_dl *sdl = (struct sockaddr_dl *)sa;

		if (sdl->sdl_nlen == 0 && sdl->sdl_alen == 0 &&
		    sdl->sdl_slen == 0) {
			(void) snprintf(workbuf, sizeof(workbuf), "link#%d", sdl->sdl_index);
		} else {
			switch (sdl->sdl_type) {

			case IFT_ETHER: {
				int i;
				u_char *lla = (u_char *)sdl->sdl_data +
				    sdl->sdl_nlen;

				cplim = "";
				for (i = 0; i < sdl->sdl_alen; i++, lla++) {
					cp += snprintf(cp, sizeof(workbuf) - (cp - workbuf), "%s%x", cplim, *lla);
					cplim = ":";
				}
				cp = workbuf;
				break;
			    }

			default:
				cp = link_ntoa(sdl);
				break;
			}
		}
		break;
	    }

	default: {
		u_char *s = (u_char *)sa->sa_data, *slim;

		slim =  sa->sa_len + (u_char *) sa;
		cplim = cp + sizeof(workbuf) - 6;
		cp += snprintf(cp, sizeof(workbuf) - (cp - workbuf), "(%d)", sa->sa_family);
		while (s < slim && cp < cplim) {
			cp += snprintf(cp, sizeof(workbuf) - (cp - workbuf), " %02x", *s++);
			if (s < slim)
			    cp += snprintf(cp, sizeof(workbuf) - (cp - workbuf), "%02x", *s++);
		}
		cp = workbuf;
	    }
	}
	if (width < 0 ) {
		printf("%s ", cp);
	} else {
		if (nflag)
			printf("%-*s ", width, cp);
		else
			printf("%-*.*s ", width, width, cp);
	}
}

static void
p_flags(int f, char *format)
{
	char name[33], *flags;
	struct bits *p = bits;

	for (flags = name; p->b_mask; p++)
		if (p->b_mask & f)
			*flags++ = p->b_val;
	*flags = '\0';
	printf(format, name);
}

char *
routename(uint32_t in)
{
	char *cp;
	static char line[MAXHOSTNAMELEN];
	struct hostent *hp;

	cp = 0;
	if (!nflag) {
		hp = gethostbyaddr((char *)&in, sizeof (struct in_addr),
			AF_INET);
		if (hp) {
			cp = hp->h_name;
			 //### trimdomain(cp, strlen(cp));
		}
	}
	if (cp) {
		strncpy(line, cp, sizeof(line) - 1);
		line[sizeof(line) - 1] = '\0';
	} else {
#define C(x)	((x) & 0xff)
		in = ntohl(in);
		snprintf(line, sizeof(line), "%u.%u.%u.%u",
		    C(in >> 24), C(in >> 16), C(in >> 8), C(in));
	}
	return (line);
}

static uint32_t
forgemask(uint32_t a)
{
	uint32_t m;

	if (IN_CLASSA(a))
		m = IN_CLASSA_NET;
	else if (IN_CLASSB(a))
		m = IN_CLASSB_NET;
	else
		m = IN_CLASSC_NET;
	return (m);
}

static void
domask(char *dst, uint32_t addr, uint32_t mask)
{
	int b, i;

	if (!mask || (forgemask(addr) == mask)) {
		*dst = '\0';
		return;
	}
	i = 0;
	for (b = 0; b < 32; b++)
		if (mask & (1 << b)) {
			int bb;

			i = b;
			for (bb = b+1; bb < 32; bb++)
				if (!(mask & (1 << bb))) {
					i = -1;	/* noncontig */
					break;
				}
			break;
		}
	if (i == -1)
		snprintf(dst, sizeof(dst), "&0x%x", mask);
	else
		snprintf(dst, sizeof(dst), "/%d", 32-i);
}

/*
 * Return the name of the network whose address is given.
 * The address is assumed to be that of a net or subnet, not a host.
 */
char *
netname(uint32_t in, uint32_t mask)
{
	char *cp = 0;
	static char line[MAXHOSTNAMELEN];
	struct netent *np = 0;
	uint32_t net, omask, dmask;
	uint32_t i;

	i = ntohl(in);
	dmask = forgemask(i);
	omask = mask;
	if (!nflag && i) {
		net = i & dmask;
		if (!(np = getnetbyaddr(i, AF_INET)) && net != i)
			np = getnetbyaddr(net, AF_INET);
		if (np) {
			cp = np->n_name;
			 //### trimdomain(cp, strlen(cp));
		}
	}
	if (cp)
		strncpy(line, cp, sizeof(line) - 1);
	else {
		switch (dmask) {
		case IN_CLASSA_NET:
			if ((i & IN_CLASSA_HOST) == 0) {
				snprintf(line, sizeof(line), "%u", C(i >> 24));
				break;
			}
			/* FALLTHROUGH */
		case IN_CLASSB_NET:
			if ((i & IN_CLASSB_HOST) == 0) {
				snprintf(line, sizeof(line), "%u.%u",
					C(i >> 24), C(i >> 16));
				break;
			}
			/* FALLTHROUGH */
		case IN_CLASSC_NET:
			if ((i & IN_CLASSC_HOST) == 0) {
				snprintf(line, sizeof(line), "%u.%u.%u",
					C(i >> 24), C(i >> 16), C(i >> 8));
				break;
			}
			/* FALLTHROUGH */
		default:
			snprintf(line, sizeof(line), "%u.%u.%u.%u",
				C(i >> 24), C(i >> 16), C(i >> 8), C(i));
			break;
		}
	}
	domask(line+strlen(line), i, omask);
	return (line);
}

#ifdef INET6
char *
netname6(struct sockaddr_in6 *sa6, struct sockaddr *sam)
{
	static char line[MAXHOSTNAMELEN];
	u_char *lim;
	int masklen, illegal = 0, flag = NI_WITHSCOPEID;
	struct in6_addr *mask = sam ? &((struct sockaddr_in6 *)sam)->sin6_addr : 0;

	if (sam && sam->sa_len == 0) {
		masklen = 0;
	} else if (mask) {
		u_char *p = (u_char *)mask;
		for (masklen = 0, lim = p + 16; p < lim; p++) {
			switch (*p) {
			 case 0xff:
				 masklen += 8;
				 break;
			 case 0xfe:
				 masklen += 7;
				 break;
			 case 0xfc:
				 masklen += 6;
				 break;
			 case 0xf8:
				 masklen += 5;
				 break;
			 case 0xf0:
				 masklen += 4;
				 break;
			 case 0xe0:
				 masklen += 3;
				 break;
			 case 0xc0:
				 masklen += 2;
				 break;
			 case 0x80:
				 masklen += 1;
				 break;
			 case 0x00:
				 break;
			 default:
				 illegal ++;
				 break;
			}
		}
		if (illegal)
			fprintf(stderr, "illegal prefixlen\n");
	} else {
		masklen = 128;
	}
	if (masklen == 0 && IN6_IS_ADDR_UNSPECIFIED(&sa6->sin6_addr))
		return("default");

	if (nflag)
		flag |= NI_NUMERICHOST;
	getnameinfo((struct sockaddr *)sa6, sa6->sin6_len, line, sizeof(line),
		    NULL, 0, flag);

	if (nflag)
		snprintf(&line[strlen(line)], sizeof(line) - strlen(line), "/%d", masklen);

	return line;
}

char *
routename6(struct sockaddr_in6 *sa6)
{
	static char line[MAXHOSTNAMELEN];
	int flag = NI_WITHSCOPEID;
	/* use local variable for safety */
	struct sockaddr_in6 sa6_local = {sizeof(sa6_local), AF_INET6, };

	sa6_local.sin6_addr = sa6->sin6_addr;
	sa6_local.sin6_scope_id = sa6->sin6_scope_id;

	if (nflag)
		flag |= NI_NUMERICHOST;

	getnameinfo((struct sockaddr *)&sa6_local, sa6_local.sin6_len,
		    line, sizeof(line), NULL, 0, flag);

	return line;
}
#endif /*INET6*/

/*
 * Print routing statistics
 */
void
rt_stats(void)
{
	struct rtstat rtstat;
	int rttrash;
	int mib[6];
	size_t len;

	mib[0] = CTL_NET;
	mib[1] = AF_ROUTE;
	mib[2] = 0;
	mib[3] = 0;
	mib[4] = NET_RT_STAT;
	mib[5] = 0;
	len = sizeof(struct rtstat);
	if (sysctl(mib, 6, &rtstat, &len, 0, 0) == -1)
		return;
		
	mib[0] = CTL_NET;
	mib[1] = AF_ROUTE;
	mib[2] = 0;
	mib[3] = 0;
	mib[4] = NET_RT_TRASH;
	mib[5] = 0;
	len = sizeof(rttrash);
	if (sysctl(mib, 6, &rttrash, &len, 0, 0) == -1)
		return;

	printf("routing:\n");

#define	p(f, m) if (rtstat.f || sflag <= 1) \
	printf(m, rtstat.f, plural(rtstat.f))

	p(rts_badredirect, "\t%u bad routing redirect%s\n");
	p(rts_dynamic, "\t%u dynamically created route%s\n");
	p(rts_newgateway, "\t%u new gateway%s due to redirects\n");
	p(rts_unreach, "\t%u destination%s found unreachable\n");
	p(rts_wildcard, "\t%u use%s of a wildcard route\n");
	p(rts_badrtgwroute, "\t%u lookup%s returned indirect "
	    "routes pointing to indirect gateway route\n");
#undef p

	if (rttrash || sflag <= 1)
		printf("\t%u route%s not in table but not freed\n",
		    rttrash, plural(rttrash));
}

void
upHex(char *p0)
{
	char *p = p0;

	for (; *p; p++)
		switch (*p) {

		case 'a':
		case 'b':
		case 'c':
		case 'd':
		case 'e':
		case 'f':
			*p += ('A' - 'a');
			break;
		}
}
