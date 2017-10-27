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

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <sys/kern_control.h>

#include <net/if.h>
#include <net/if_var.h>
#include <net/if_dl.h>
#include <net/if_types.h>
#include <net/if_mib.h>
#include <net/if_llreach.h>
#include <net/ethernet.h>
#include <net/route.h>
#include <net/ntstat.h>

#include <net/pktsched/pktsched.h>
#include <net/classq/if_classq.h>

#include <netinet/in.h>
#include <netinet/in_var.h>

#include <arpa/inet.h>

#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stddef.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>

#include "netstat.h"

#define	YES	1
#define	NO	0

#define ROUNDUP(a, size) (((a) & ((size) - 1)) ? (1 + ((a)|(size - 1))) : (a))

#define NEXT_SA(p) (struct sockaddr *) \
    ((caddr_t)p + (p->sa_len ? ROUNDUP(p->sa_len, sizeof(uint32_t)) : \
    sizeof(uint32_t)))

static void sidewaysintpr ();
static void catchalarm (int);
static char *sec2str(time_t);
static void llreach_sysctl(uint32_t);
static char *nsec_to_str(unsigned long long);
static char *qtype2str(classq_type_t);
static char *sched2str(unsigned int);
static char *qid2str(unsigned int);
static char *qstate2str(unsigned int);
static char *tcqslot2str(unsigned int);
static char *rate2str(long double);
static char *pri2str(unsigned int i);

#define AVGN_MAX	8

struct queue_stats {
	int			 avgn;
	double			 avg_bytes;
	double			 avg_packets;
	u_int64_t		 prev_bytes;
	u_int64_t		 prev_packets;
	unsigned int		 printed;
	unsigned int		 handle;
};

static void print_tcqstats(int slot, struct tcq_classstats *,
    struct queue_stats *);
static void print_qfqstats(int slot, struct qfq_classstats *,
    struct queue_stats *);
static void print_sfbstats(struct sfb_stats *);
static void update_avg(struct if_ifclassq_stats *, struct queue_stats *);
static void print_fq_codel_stats(int slot, struct fq_codel_classstats *,
    struct queue_stats *);

struct queue_stats qstats[IFCQ_SC_MAX];

#ifdef INET6
char *netname6 (struct sockaddr_in6 *, struct sockaddr *);
static char ntop_buf[INET6_ADDRSTRLEN];		/* for inet_ntop() */
#endif

/*
 * Display a formatted value, or a '-' in the same space.
 */
static void
show_stat(const char *fmt, int width, u_int64_t value, short showvalue)
{
	char newfmt[32];

	/* Construct the format string */
	if (showvalue) {
		snprintf(newfmt, sizeof(newfmt), "%%%d%s", width, fmt);
		printf(newfmt, value);
	} else {
		snprintf(newfmt, sizeof(newfmt), "%%%ds", width);
		printf(newfmt, "-");
	}
}

size_t
get_rti_info(int addrs, struct sockaddr *sa, struct sockaddr **rti_info)
{
    int			i;
    size_t		len = 0;

    for (i = 0; i < RTAX_MAX; i++) {
        if (addrs & (1 << i)) {
            rti_info[i] = sa;
            if (sa->sa_len < sizeof(struct sockaddr))
                len += sizeof(struct sockaddr);
            else
                len += sa->sa_len;
            sa = NEXT_SA(sa);
        } else {
            rti_info[i] = NULL;
        }
    }
    return len;
}

static void
multipr(int family, char *buf, char *lim)
{
    char  *next;

    for (next = buf; next < lim; ) {
		struct ifma_msghdr2	*ifmam = (struct ifma_msghdr2 *)next;
		struct sockaddr *rti_info[RTAX_MAX];
		struct sockaddr *sa;
		const char *fmt = 0;
		
		next += ifmam->ifmam_msglen;
		if (ifmam->ifmam_type == RTM_IFINFO2)
			break;
		else if (ifmam->ifmam_type != RTM_NEWMADDR2)
			continue;
		get_rti_info(ifmam->ifmam_addrs, (struct sockaddr*)(ifmam + 1), rti_info);
		sa = rti_info[RTAX_IFA];
		
		if (sa->sa_family != family)
			continue;
		switch (sa->sa_family) {
			case AF_INET: {
				struct sockaddr_in *sin = (struct sockaddr_in *)sa;
				
				fmt = routename(sin->sin_addr.s_addr);
				break;
			}
	#ifdef INET6
			case AF_INET6: {
				struct sockaddr_in6 sin6;

				memcpy(&sin6, sa, sizeof(struct sockaddr_in6));

				if (IN6_IS_ADDR_LINKLOCAL(&sin6.sin6_addr) ||
					IN6_IS_ADDR_MC_NODELOCAL(&sin6.sin6_addr) ||
					IN6_IS_ADDR_MC_LINKLOCAL(&sin6.sin6_addr)) {
					sin6.sin6_scope_id = ntohs(*(u_int16_t *)&sin6.sin6_addr.s6_addr[2]);
					sin6.sin6_addr.s6_addr[2] = 0;
					sin6.sin6_addr.s6_addr[3] = 0;
				}

				printf("%23s %-19.19s(refs: %d)\n", "",
				    inet_ntop(AF_INET6, &sin6.sin6_addr,
				    ntop_buf, sizeof(ntop_buf)),
						ifmam->ifmam_refcount);
				break;
			}
	#endif /* INET6 */
			case AF_LINK: {
				struct sockaddr_dl *sdl = (struct sockaddr_dl *)sa;
				
				switch (sdl->sdl_type) {
				case IFT_ETHER:
				case IFT_FDDI:
					fmt = ether_ntoa((struct ether_addr *)
						LLADDR(sdl));
					break;
				}
				break;
			}
		}
		if (fmt)
			printf("%23s %s\n", "", fmt);
	}
}

/*
 * Print a description of the network interfaces.
 */
void
intpr(void (*pfunc)(char *))
{
	u_int64_t opackets = 0;
	u_int64_t ipackets = 0;
	u_int64_t obytes = 0;
	u_int64_t ibytes = 0;
	u_int64_t oerrors = 0;
	u_int64_t ierrors = 0;
	u_int64_t collisions = 0;
	u_int64_t fpackets = 0;
	u_int64_t fbytes = 0;
	uint32_t mtu = 0;
	int timer = 0;
	int drops = 0;
	struct sockaddr *sa = NULL;
	char name[32];
	short network_layer;
	short link_layer;
	int mib[6];
	char *buf = NULL, *lim, *next;
	size_t len;
	struct if_msghdr *ifm;
	struct sockaddr *rti_info[RTAX_MAX];
	unsigned int ifindex = 0;

	if (interval) {
		sidewaysintpr();
		return;
	}

	if (interface != 0)
		ifindex = if_nametoindex(interface);

	mib[0]	= CTL_NET;			// networking subsystem
	mib[1]	= PF_ROUTE;			// type of information
	mib[2]	= 0;				// protocol (IPPROTO_xxx)
	mib[3]	= 0;				// address family
	mib[4]	= NET_RT_IFLIST2;	// operation
	mib[5]	= 0;
	if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0)
		return;
	if ((buf = malloc(len)) == NULL) {
		printf("malloc failed\n");
		exit(1);
	}
	if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
		if (buf)
			free(buf);
		return;
	}

	if (!pfunc) {
		printf("%-5.5s %-5.5s %-13.13s %-15.15s %8.8s %5.5s",
		       "Name", "Mtu", "Network", "Address", "Ipkts", "Ierrs");
		if (prioflag >= 0)
			printf(" %8.8s %8.8s", "Itcpkts", "Ipvpkts");
		if (bflag) {
			printf(" %10.10s","Ibytes");
			if (prioflag >= 0)
				printf(" %8.8s %8.8s", "Itcbytes", "Ipvbytes");
		}
		printf(" %8.8s %5.5s", "Opkts", "Oerrs");
		if (prioflag >= 0)
			printf(" %8.8s %8.8s", "Otcpkts", "Opvpkts");
		if (bflag) {
			printf(" %10.10s","Obytes");
			if (prioflag >= 0)
				printf(" %8.8s %8.8s", "Otcbytes", "Opvbytes");
		}
		printf(" %5s", "Coll");
		if (tflag)
			printf(" %s", "Time");
		if (dflag)
			printf(" %s", "Drop");
		if (Fflag) {
			printf(" %8.8s", "Fpkts");
			if (bflag)
				printf(" %10.10s", "Fbytes");
		}
		putchar('\n');
	}
	lim = buf + len;
	for (next = buf; next < lim; ) {
		char *cp;
		int n, m;
		struct ifmibdata_supplemental ifmsupp;
		u_int64_t	ift_itcp = 0;	/* input tc packets */
		u_int64_t	ift_itcb = 0;	/* input tc bytes */
		u_int64_t	ift_otcp = 0;	/* output tc packets */
		u_int64_t	ift_otcb = 0;	/* output tc bytes */
		u_int64_t	ift_ipvp = 0;	/* input priv tc packets */
		u_int64_t	ift_ipvb = 0;	/* input priv tc bytes */
		u_int64_t	ift_opvp = 0;	/* output priv tc packets */
		u_int64_t	ift_opvb = 0;	/* output priv tc bytes */

		bzero(&ifmsupp, sizeof(struct ifmibdata_supplemental));

		network_layer = 0;
		link_layer = 0;
		ifm = (struct if_msghdr *)next;
		next += ifm->ifm_msglen;

		if (ifm->ifm_type == RTM_IFINFO2) {
			struct if_msghdr2 *if2m = (struct if_msghdr2 *)ifm;
			struct sockaddr_dl *sdl =
			    (struct sockaddr_dl *)(if2m + 1);
			int mibname[6];
			size_t miblen = sizeof(struct ifmibdata_supplemental);

			strncpy(name, sdl->sdl_data, sdl->sdl_nlen);
			name[sdl->sdl_nlen] = 0;
			if (interface != 0 && if2m->ifm_index != ifindex)
				continue;
			cp = index(name, '\0');

			if (pfunc) {
				(*pfunc)(name);
				continue;
			}

			if ((if2m->ifm_flags & IFF_UP) == 0)
				*cp++ = '*';
			*cp = '\0';

			/*
			 * Get the interface stats.  These may get
			 * overriden below on a per-interface basis.
			 */
			opackets = if2m->ifm_data.ifi_opackets;
			ipackets = if2m->ifm_data.ifi_ipackets;
			obytes = if2m->ifm_data.ifi_obytes;
			ibytes = if2m->ifm_data.ifi_ibytes;
			oerrors =if2m->ifm_data.ifi_oerrors;
			ierrors = if2m->ifm_data.ifi_ierrors;
			collisions = if2m->ifm_data.ifi_collisions;
			timer = if2m->ifm_timer;
			drops = if2m->ifm_snd_drops;
			mtu = if2m->ifm_data.ifi_mtu;

			/* Common OID prefix */
			mibname[0] = CTL_NET;
			mibname[1] = PF_LINK;
			mibname[2] = NETLINK_GENERIC;
			mibname[3] = IFMIB_IFDATA;
			mibname[4] = if2m->ifm_index;
			mibname[5] = IFDATA_SUPPLEMENTAL;
			if (sysctl(mibname, 6, &ifmsupp, &miblen, NULL, 0) == -1)
				err(1, "sysctl IFDATA_SUPPLEMENTAL");

			fpackets = ifmsupp.ifmd_data_extended.ifi_fpackets;
			fbytes = ifmsupp.ifmd_data_extended.ifi_fbytes;

			if (prioflag >= 0) {
				switch (prioflag) {
				case SO_TC_BE:
					ift_itcp = ifmsupp.ifmd_traffic_class.ifi_ibepackets;
					ift_itcb = ifmsupp.ifmd_traffic_class.ifi_ibebytes;
					ift_otcp = ifmsupp.ifmd_traffic_class.ifi_obepackets;
					ift_otcb = ifmsupp.ifmd_traffic_class.ifi_obebytes;
					break;
				case SO_TC_BK:
					ift_itcp = ifmsupp.ifmd_traffic_class.ifi_ibkpackets;
					ift_itcb = ifmsupp.ifmd_traffic_class.ifi_ibkbytes;
					ift_otcp = ifmsupp.ifmd_traffic_class.ifi_obkpackets;
					ift_otcb = ifmsupp.ifmd_traffic_class.ifi_obkbytes;
					break;
				case SO_TC_VI:
					ift_itcp = ifmsupp.ifmd_traffic_class.ifi_ivipackets;
					ift_itcb = ifmsupp.ifmd_traffic_class.ifi_ivibytes;
					ift_otcp = ifmsupp.ifmd_traffic_class.ifi_ovipackets;
					ift_otcb = ifmsupp.ifmd_traffic_class.ifi_ovibytes;
					break;
				case SO_TC_VO:
					ift_itcp = ifmsupp.ifmd_traffic_class.ifi_ivopackets;
					ift_itcb = ifmsupp.ifmd_traffic_class.ifi_ivobytes;
					ift_otcp = ifmsupp.ifmd_traffic_class.ifi_ovopackets;
					ift_otcb = ifmsupp.ifmd_traffic_class.ifi_ovobytes;
					break;
				default:
					ift_itcp = 0;
					ift_itcb = 0;
					ift_otcp = 0;
					ift_otcb = 0;
					ift_ipvp = 0;
					ift_ipvb = 0;
					ift_opvp = 0;
					ift_opvb = 0;
					break;
				}
				ift_ipvp = ifmsupp.ifmd_traffic_class.ifi_ipvpackets;
				ift_ipvb = ifmsupp.ifmd_traffic_class.ifi_ipvbytes;
				ift_opvp = ifmsupp.ifmd_traffic_class.ifi_opvpackets;
				ift_opvb = ifmsupp.ifmd_traffic_class.ifi_opvbytes;
			}

			get_rti_info(if2m->ifm_addrs,
			    (struct sockaddr*)(if2m + 1), rti_info);
			sa = rti_info[RTAX_IFP];
		} else if (ifm->ifm_type == RTM_NEWADDR) {
			struct ifa_msghdr *ifam = (struct ifa_msghdr *)ifm;

			if (interface != 0 && ifam->ifam_index != ifindex)
				continue;
			get_rti_info(ifam->ifam_addrs,
			    (struct sockaddr*)(ifam + 1), rti_info);
			sa = rti_info[RTAX_IFA];
		} else {
			continue;
		}
		printf("%-5.5s %-5u ", name, mtu);

		if (sa == 0) {
			printf("%-13.13s ", "none");
			printf("%-15.15s ", "none");
		} else {
			switch (sa->sa_family) {
			case AF_UNSPEC:
				printf("%-13.13s ", "none");
				printf("%-15.15s ", "none");
				break;

			case AF_INET: {
				struct sockaddr_in *sin =
				    (struct sockaddr_in *)sa;
				struct sockaddr_in mask;

				mask.sin_addr.s_addr = 0;
				memcpy(&mask, rti_info[RTAX_NETMASK],
				    ((struct sockaddr_in *)
				    rti_info[RTAX_NETMASK])->sin_len);

				printf("%-13.13s ",
				    netname(sin->sin_addr.s_addr &
				    mask.sin_addr.s_addr,
				    ntohl(mask.sin_addr.s_addr)));

				printf("%-15.15s ",
				    routename(sin->sin_addr.s_addr));

				network_layer = 1;
				break;
			}
#ifdef INET6
			case AF_INET6: {
				struct sockaddr_in6 *sin6 =
				    (struct sockaddr_in6 *)sa;
				struct sockaddr *mask =
				    (struct sockaddr *)rti_info[RTAX_NETMASK];

				printf("%-11.11s ", netname6(sin6, mask));
				printf("%-17.17s ", (char *)inet_ntop(AF_INET6,
				    &sin6->sin6_addr, ntop_buf,
				    sizeof(ntop_buf)));

				network_layer = 1;
				break;
			}
#endif /*INET6*/
			case AF_LINK: {
				struct sockaddr_dl *sdl =
				    (struct sockaddr_dl *)sa;
				char linknum[10];
				cp = (char *)LLADDR(sdl);
				n = sdl->sdl_alen;
				snprintf(linknum, sizeof(linknum),
				    "<Link#%d>", sdl->sdl_index);
				m = printf("%-11.11s ", linknum);
				goto hexprint;
			}

			default:
				m = printf("(%d)", sa->sa_family);
				for (cp = sa->sa_len + (char *)sa;
					--cp > sa->sa_data && (*cp == 0);) {}
				n = cp - sa->sa_data + 1;
				cp = sa->sa_data;
			hexprint:
				while (--n >= 0)
					m += printf("%02x%c", *cp++ & 0xff,
						    n > 0 ? ':' : ' ');
				m = 30 - m;
				while (m-- > 0)
					putchar(' ');

				link_layer = 1;
				break;
			}
		}

		show_stat("llu", 8, ipackets, link_layer|network_layer);
		printf(" ");
		show_stat("llu", 5, ierrors, link_layer);
		printf(" ");
		if (prioflag >= 0) {
			show_stat("llu", 8, ift_itcp, link_layer|network_layer);
			printf(" ");
			show_stat("llu", 8, ift_ipvp, link_layer|network_layer);
			printf(" ");
		}
		if (bflag) {
			show_stat("llu", 10, ibytes, link_layer|network_layer);
			printf(" ");
			if (prioflag >= 0) {
				show_stat("llu", 8, ift_itcb, link_layer|network_layer);
				printf(" ");
				show_stat("llu", 8, ift_ipvb, link_layer|network_layer);
				printf(" ");
			}
		}
		show_stat("llu", 8, opackets, link_layer|network_layer);
		printf(" ");
		show_stat("llu", 5, oerrors, link_layer);
		printf(" ");
		if (prioflag >= 0) {
			show_stat("llu", 8, ift_otcp, link_layer|network_layer);
			printf(" ");
			show_stat("llu", 8, ift_opvp, link_layer|network_layer);
			printf(" ");
		}
		if (bflag) {
			show_stat("llu", 10, obytes, link_layer|network_layer);
			printf(" ");
			if (prioflag >= 0) {
				show_stat("llu", 8, ift_otcb, link_layer|network_layer);
				printf(" ");
				show_stat("llu", 8, ift_opvb, link_layer|network_layer);
				printf(" ");
			}
		}
		show_stat("llu", 5, collisions, link_layer);
		if (tflag) {
			printf(" ");
			show_stat("d", 3, timer, link_layer);
		}
		if (dflag) {
			printf(" ");
			show_stat("d", 3, drops, link_layer);
		}
		if (Fflag) {
			printf(" ");
			show_stat("llu", 8, fpackets, link_layer|network_layer);
			if (bflag) {
				printf(" ");
				show_stat("llu", 10, fbytes,
				    link_layer|network_layer);
			}
		}
		putchar('\n');

		if (aflag)
			multipr(sa->sa_family, next, lim);
	}
	free(buf);
}

struct	iftot {
	SLIST_ENTRY(iftot) chain;
	char		ift_name[16];	/* interface name */
	u_int64_t	ift_ip;		/* input packets */
	u_int64_t	ift_ie;		/* input errors */
	u_int64_t	ift_op;		/* output packets */
	u_int64_t	ift_oe;		/* output errors */
	u_int64_t	ift_co;		/* collisions */
	u_int64_t	ift_dr;		/* drops */
	u_int64_t	ift_ib;		/* input bytes */
	u_int64_t	ift_ob;		/* output bytes */
	u_int64_t	ift_itcp;	/* input tc packets */
	u_int64_t	ift_itcb;	/* input tc bytes */
	u_int64_t	ift_otcp;	/* output tc packets */
	u_int64_t	ift_otcb;	/* output tc bytes */
	u_int64_t	ift_ipvp;	/* input priv tc packets */
	u_int64_t	ift_ipvb;	/* input priv tc bytes */
	u_int64_t	ift_opvp;	/* output priv tc packets */
	u_int64_t	ift_opvb;	/* output priv tc bytes */
	u_int64_t	ift_fp;		/* forwarded packets */
	u_int64_t	ift_fb;		/* forwarded bytes */
};

u_char	signalled;			/* set if alarm goes off "early" */

/*
 * Print a running summary of interface statistics.
 * Repeat display every interval seconds, showing statistics
 * collected over that interval.  Assumes that interval is non-zero.
 * First line printed at top of screen is always cumulative.
 * XXX - should be rewritten to use ifmib(4).
 */
static void
sidewaysintpr()
{
	struct iftot *total, *sum, *interesting;
	register int line;
	int first;
	int name[6];
	size_t len;
	unsigned int ifcount, i;
	struct ifmibdata *ifmdall = 0;
	int interesting_row;
	sigset_t sigset, oldsigset;
	struct itimerval timer_interval;

	/* Common OID prefix */
	name[0] = CTL_NET;
	name[1] = PF_LINK;
	name[2] = NETLINK_GENERIC;

	len = sizeof(int);
	name[3] = IFMIB_SYSTEM;
	name[4] = IFMIB_IFCOUNT;
	if (sysctl(name, 5, &ifcount, &len, 0, 0) == 1)
		err(1, "sysctl IFMIB_IFCOUNT");

	len = ifcount * sizeof(struct ifmibdata);
	ifmdall = malloc(len);
	if (ifmdall == 0)
		err(1, "malloc failed");
	name[3] = IFMIB_IFALLDATA;
	name[4] = 0;
	name[5] = IFDATA_GENERAL;
	if (sysctl(name, 6, ifmdall, &len, (void *)0, 0) == -1)
		err(1, "sysctl IFMIB_IFALLDATA");

	interesting = NULL;
	interesting_row = 0;
	for (i = 0; i < ifcount; i++) {
		struct ifmibdata *ifmd = ifmdall + i;

		if (interface && strcmp(ifmd->ifmd_name, interface) == 0) {
			if ((interesting = calloc(ifcount,
			    sizeof(struct iftot))) == NULL)
				err(1, "malloc failed");
			interesting_row = if_nametoindex(interface);
			snprintf(interesting->ift_name, 16, "(%s)",
			    ifmd->ifmd_name);;
		}
	}
	if ((total = calloc(1, sizeof(struct iftot))) == NULL)
		err(1, "malloc failed");

	if ((sum = calloc(1, sizeof(struct iftot))) == NULL)
		err(1, "malloc failed");

	/* create a timer that fires repeatedly every interval seconds */
	timer_interval.it_value.tv_sec = interval;
	timer_interval.it_value.tv_usec = 0;
	timer_interval.it_interval.tv_sec = interval;
	timer_interval.it_interval.tv_usec = 0;
	(void)signal(SIGALRM, catchalarm);
	signalled = NO;
	(void)setitimer(ITIMER_REAL, &timer_interval, NULL);
	first = 1;
banner:
	if (vflag > 0)
		printf("%9s", " ");

	if (prioflag >= 0)
		printf("%39s %39s %36s", "input",
		    interesting ? interesting->ift_name : "(Total)", "output");
	else
		printf("%17s %14s %16s", "input",
		    interesting ? interesting->ift_name : "(Total)", "output");
	putchar('\n');

	if (vflag > 0)
		printf("%9s", " ");

	printf("%10s %5s %10s ", "packets", "errs", "bytes");
	if (prioflag >= 0)
		printf(" %10s %10s %10s %10s",
		    "tcpkts", "tcbytes", "pvpkts", "pvbytes");
	printf("%10s %5s %10s %5s", "packets", "errs", "bytes", "colls");
	if (dflag)
		printf(" %5.5s", "drops");
	if (prioflag >= 0)
		printf(" %10s %10s %10s %10s",
		    "tcpkts", "tcbytes", "pvpkts", "pvbytes");
	if (Fflag)
		printf(" %10s %10s", "fpackets", "fbytes");
	putchar('\n');
	fflush(stdout);
	line = 0;
loop:
	if (vflag && !first)
		print_time();

	if (interesting != NULL) {
		struct ifmibdata ifmd;
		struct ifmibdata_supplemental ifmsupp;

		len = sizeof(struct ifmibdata);
		name[3] = IFMIB_IFDATA;
		name[4] = interesting_row;
		name[5] = IFDATA_GENERAL;
		if (sysctl(name, 6, &ifmd, &len, (void *)0, 0) == -1)
			err(1, "sysctl IFDATA_GENERAL %d", interesting_row);

		len = sizeof(struct ifmibdata_supplemental);
		name[3] = IFMIB_IFDATA;
		name[4] = interesting_row;
		name[5] = IFDATA_SUPPLEMENTAL;
		if (sysctl(name, 6, &ifmsupp, &len, (void *)0, 0) == -1)
			err(1, "sysctl IFDATA_SUPPLEMENTAL %d",
			    interesting_row);

		if (!first) {
			printf("%10llu %5llu %10llu ",
			    ifmd.ifmd_data.ifi_ipackets - interesting->ift_ip,
			    ifmd.ifmd_data.ifi_ierrors - interesting->ift_ie,
			    ifmd.ifmd_data.ifi_ibytes - interesting->ift_ib);
			switch (prioflag) {
			case SO_TC_BE:
				printf("%10llu %10llu ",
				    ifmsupp.ifmd_traffic_class.ifi_ibepackets -
				    interesting->ift_itcp,
				    ifmsupp.ifmd_traffic_class.ifi_ibebytes -
				    interesting->ift_itcb);
				break;
			case SO_TC_BK:
				printf("%10llu %10llu ",
				    ifmsupp.ifmd_traffic_class.ifi_ibkpackets -
				    interesting->ift_itcp,
				    ifmsupp.ifmd_traffic_class.ifi_ibkbytes -
				    interesting->ift_itcb);
				break;
			case SO_TC_VI:
				printf("%10llu %10llu ",
				    ifmsupp.ifmd_traffic_class.ifi_ivipackets -
				    interesting->ift_itcp,
				    ifmsupp.ifmd_traffic_class.ifi_ivibytes -
				    interesting->ift_itcb);
				break;
			case SO_TC_VO:
				printf("%10llu %10llu ",
				    ifmsupp.ifmd_traffic_class.ifi_ivopackets -
				    interesting->ift_itcp,
				    ifmsupp.ifmd_traffic_class.ifi_ivobytes -
				    interesting->ift_itcb);
				break;
			default:
				break;
			}
			if (prioflag >= 0) {
				printf("%10llu %10llu ",
				    ifmsupp.ifmd_traffic_class.ifi_ipvpackets -
				    interesting->ift_ipvp,
				    ifmsupp.ifmd_traffic_class.ifi_ipvbytes -
				    interesting->ift_ipvb);
			}
			printf("%10llu %5llu %10llu %5llu",
			    ifmd.ifmd_data.ifi_opackets - interesting->ift_op,
			    ifmd.ifmd_data.ifi_oerrors - interesting->ift_oe,
			    ifmd.ifmd_data.ifi_obytes - interesting->ift_ob,
			    ifmd.ifmd_data.ifi_collisions - interesting->ift_co);
			if (dflag)
				printf(" %5llu",
				    ifmd.ifmd_snd_drops - interesting->ift_dr);
			switch (prioflag) {
			case SO_TC_BE:
				printf(" %10llu %10llu",
				    ifmsupp.ifmd_traffic_class.ifi_obepackets -
				    interesting->ift_otcp,
				    ifmsupp.ifmd_traffic_class.ifi_obebytes -
				    interesting->ift_otcb);
				break;
			case SO_TC_BK:
				printf(" %10llu %10llu",
				    ifmsupp.ifmd_traffic_class.ifi_obkpackets -
				    interesting->ift_otcp,
				    ifmsupp.ifmd_traffic_class.ifi_obkbytes -
				    interesting->ift_otcb);
				break;
			case SO_TC_VI:
				printf(" %10llu %10llu",
				    ifmsupp.ifmd_traffic_class.ifi_ovipackets -
				    interesting->ift_otcp,
				    ifmsupp.ifmd_traffic_class.ifi_ovibytes -
				    interesting->ift_otcb);
				break;
			case SO_TC_VO:
				printf(" %10llu %10llu",
				    ifmsupp.ifmd_traffic_class.ifi_ovopackets -
				    interesting->ift_otcp,
				    ifmsupp.ifmd_traffic_class.ifi_ovobytes -
				    interesting->ift_otcb);
				break;
			default:
				break;
			}
			if (prioflag >= 0) {
				printf("%10llu %10llu ",
				    ifmsupp.ifmd_traffic_class.ifi_opvpackets -
				    interesting->ift_opvp,
				    ifmsupp.ifmd_traffic_class.ifi_opvbytes -
				    interesting->ift_opvb);
			}
			if (Fflag) {
				printf("%10llu %10llu",
				    ifmsupp.ifmd_data_extended.ifi_fpackets -
				    interesting->ift_fp,
				    ifmsupp.ifmd_data_extended.ifi_fbytes -
				    interesting->ift_fb);
			}
		}
		interesting->ift_ip = ifmd.ifmd_data.ifi_ipackets;
		interesting->ift_ie = ifmd.ifmd_data.ifi_ierrors;
		interesting->ift_ib = ifmd.ifmd_data.ifi_ibytes;
		interesting->ift_op = ifmd.ifmd_data.ifi_opackets;
		interesting->ift_oe = ifmd.ifmd_data.ifi_oerrors;
		interesting->ift_ob = ifmd.ifmd_data.ifi_obytes;
		interesting->ift_co = ifmd.ifmd_data.ifi_collisions;
		interesting->ift_dr = ifmd.ifmd_snd_drops;

		/* private counters */
		switch (prioflag) {
		case SO_TC_BE:
			interesting->ift_itcp =
			    ifmsupp.ifmd_traffic_class.ifi_ibepackets;
			interesting->ift_itcb =
			    ifmsupp.ifmd_traffic_class.ifi_ibebytes;
			interesting->ift_otcp =
			    ifmsupp.ifmd_traffic_class.ifi_obepackets;
			interesting->ift_otcb =
			    ifmsupp.ifmd_traffic_class.ifi_obebytes;
			break;
		case SO_TC_BK:
			interesting->ift_itcp =
			    ifmsupp.ifmd_traffic_class.ifi_ibkpackets;
			interesting->ift_itcb =
			    ifmsupp.ifmd_traffic_class.ifi_ibkbytes;
			interesting->ift_otcp =
			    ifmsupp.ifmd_traffic_class.ifi_obkpackets;
			interesting->ift_otcb =
			    ifmsupp.ifmd_traffic_class.ifi_obkbytes;
			break;
		case SO_TC_VI:
			interesting->ift_itcp =
			    ifmsupp.ifmd_traffic_class.ifi_ivipackets;
			interesting->ift_itcb =
			    ifmsupp.ifmd_traffic_class.ifi_ivibytes;
			interesting->ift_otcp =
			    ifmsupp.ifmd_traffic_class.ifi_ovipackets;
			interesting->ift_otcb =
			    ifmsupp.ifmd_traffic_class.ifi_ovibytes;
			break;
		case SO_TC_VO:
			interesting->ift_itcp =
			    ifmsupp.ifmd_traffic_class.ifi_ivopackets;
			interesting->ift_itcb =
			    ifmsupp.ifmd_traffic_class.ifi_ivobytes;
			interesting->ift_otcp =
			    ifmsupp.ifmd_traffic_class.ifi_ovopackets;
			interesting->ift_otcb =
			    ifmsupp.ifmd_traffic_class.ifi_ovobytes;
			break;
		default:
			break;
		}
		if (prioflag >= 0) {
			interesting->ift_ipvp =
			    ifmsupp.ifmd_traffic_class.ifi_ipvpackets;
			interesting->ift_ipvb =
			    ifmsupp.ifmd_traffic_class.ifi_ipvbytes;
			interesting->ift_opvp =
			    ifmsupp.ifmd_traffic_class.ifi_opvpackets;
			interesting->ift_opvb =
			    ifmsupp.ifmd_traffic_class.ifi_opvbytes;
		}
		interesting->ift_fp = ifmsupp.ifmd_data_extended.ifi_fpackets;
		interesting->ift_fb = ifmsupp.ifmd_data_extended.ifi_fbytes;
	} else {
		unsigned int latest_ifcount;
		struct ifmibdata_supplemental *ifmsuppall = NULL;

		len = sizeof(int);
		name[3] = IFMIB_SYSTEM;
		name[4] = IFMIB_IFCOUNT;
		if (sysctl(name, 5, &latest_ifcount, &len, 0, 0) == 1)
			err(1, "sysctl IFMIB_IFCOUNT");
		if (latest_ifcount > ifcount) {
			ifcount = latest_ifcount;
			len = ifcount * sizeof(struct ifmibdata);
			free(ifmdall);
			ifmdall = malloc(len);
			if (ifmdall == 0)
				err(1, "malloc ifmdall failed");
		} else if (latest_ifcount > ifcount) {
			ifcount = latest_ifcount;
			len = ifcount * sizeof(struct ifmibdata);
		}
		len = ifcount * sizeof(struct ifmibdata);
		name[3] = IFMIB_IFALLDATA;
		name[4] = 0;
		name[5] = IFDATA_GENERAL;
		if (sysctl(name, 6, ifmdall, &len, (void *)0, 0) == -1)
			err(1, "sysctl IFMIB_IFALLDATA");

		len = ifcount * sizeof(struct ifmibdata_supplemental);
		ifmsuppall = malloc(len);
		if (ifmsuppall == NULL)
			err(1, "malloc ifmsuppall failed");
		name[3] = IFMIB_IFALLDATA;
		name[4] = 0;
		name[5] = IFDATA_SUPPLEMENTAL;
		if (sysctl(name, 6, ifmsuppall, &len, (void *)0, 0) == -1)
			err(1, "sysctl IFMIB_IFALLDATA SUPPLEMENTAL");

		sum->ift_ip = 0;
		sum->ift_ie = 0;
		sum->ift_ib = 0;
		sum->ift_op = 0;
		sum->ift_oe = 0;
		sum->ift_ob = 0;
		sum->ift_co = 0;
		sum->ift_dr = 0;
		sum->ift_itcp = 0;
		sum->ift_itcb = 0;
		sum->ift_otcp = 0;
		sum->ift_otcb = 0;
		sum->ift_ipvp = 0;
		sum->ift_ipvb = 0;
		sum->ift_opvp = 0;
		sum->ift_opvb = 0;
		sum->ift_fp = 0;
		sum->ift_fb = 0;
		for (i = 0; i < ifcount; i++) {
			struct ifmibdata *ifmd = ifmdall + i;
			struct ifmibdata_supplemental *ifmsupp = ifmsuppall + i;

			sum->ift_ip += ifmd->ifmd_data.ifi_ipackets;
			sum->ift_ie += ifmd->ifmd_data.ifi_ierrors;
			sum->ift_ib += ifmd->ifmd_data.ifi_ibytes;
			sum->ift_op += ifmd->ifmd_data.ifi_opackets;
			sum->ift_oe += ifmd->ifmd_data.ifi_oerrors;
			sum->ift_ob += ifmd->ifmd_data.ifi_obytes;
			sum->ift_co += ifmd->ifmd_data.ifi_collisions;
			sum->ift_dr += ifmd->ifmd_snd_drops;
			/* private counters */
			if (prioflag >= 0) {
				switch (prioflag) {
				case SO_TC_BE:
					sum->ift_itcp += ifmsupp->ifmd_traffic_class.ifi_ibepackets;
					sum->ift_itcb += ifmsupp->ifmd_traffic_class.ifi_ibebytes;
					sum->ift_otcp += ifmsupp->ifmd_traffic_class.ifi_obepackets;
					sum->ift_otcb += ifmsupp->ifmd_traffic_class.ifi_obebytes;
					break;
				case SO_TC_BK:
					sum->ift_itcp += ifmsupp->ifmd_traffic_class.ifi_ibkpackets;
					sum->ift_itcb += ifmsupp->ifmd_traffic_class.ifi_ibkbytes;
					sum->ift_otcp += ifmsupp->ifmd_traffic_class.ifi_obkpackets;
					sum->ift_otcb += ifmsupp->ifmd_traffic_class.ifi_obkbytes;
					break;
				case SO_TC_VI:
					sum->ift_itcp += ifmsupp->ifmd_traffic_class.ifi_ivipackets;
					sum->ift_itcb += ifmsupp->ifmd_traffic_class.ifi_ivibytes;
					sum->ift_otcp += ifmsupp->ifmd_traffic_class.ifi_ovipackets;
					sum->ift_otcb += ifmsupp->ifmd_traffic_class.ifi_ovibytes;
					break;
				case SO_TC_VO:
					sum->ift_itcp += ifmsupp->ifmd_traffic_class.ifi_ivopackets;
					sum->ift_itcb += ifmsupp->ifmd_traffic_class.ifi_ivobytes;
					sum->ift_otcp += ifmsupp->ifmd_traffic_class.ifi_ovopackets;
					sum->ift_otcb += ifmsupp->ifmd_traffic_class.ifi_ovobytes;
					break;
				default:
					break;
				}
				sum->ift_ipvp += ifmsupp->ifmd_traffic_class.ifi_ipvpackets;
				sum->ift_ipvb += ifmsupp->ifmd_traffic_class.ifi_ipvbytes;
				sum->ift_opvp += ifmsupp->ifmd_traffic_class.ifi_opvpackets;
				sum->ift_opvb += ifmsupp->ifmd_traffic_class.ifi_opvbytes;
			}
			sum->ift_fp += ifmsupp->ifmd_data_extended.ifi_fpackets;
			sum->ift_fb += ifmsupp->ifmd_data_extended.ifi_fbytes;
		}
		if (!first) {
			printf("%10llu %5llu %10llu ",
				sum->ift_ip - total->ift_ip,
				sum->ift_ie - total->ift_ie,
				sum->ift_ib - total->ift_ib);
			if (prioflag >= 0)
				printf(" %10llu %10llu %10llu %10llu",
				    sum->ift_itcp - total->ift_itcp,
				    sum->ift_itcb - total->ift_itcb,
				    sum->ift_ipvp - total->ift_ipvp,
				    sum->ift_ipvb - total->ift_ipvb);
			printf("%10llu %5llu %10llu %5llu",
				sum->ift_op - total->ift_op,
				sum->ift_oe - total->ift_oe,
				sum->ift_ob - total->ift_ob,
				sum->ift_co - total->ift_co);
			if (dflag)
				printf(" %5llu", sum->ift_dr - total->ift_dr);
			if (prioflag >= 0)
				printf(" %10llu %10llu %10llu %10llu",
				    sum->ift_otcp - total->ift_otcp,
				    sum->ift_otcb - total->ift_otcb,
				    sum->ift_opvp - total->ift_opvp,
				    sum->ift_opvb - total->ift_opvb);
			if (Fflag)
				printf(" %10llu %10llu",
				    sum->ift_fp - total->ift_fp,
				    sum->ift_fb - total->ift_fb);
		}
		*total = *sum;
		
		free(ifmsuppall);
	}
	if (!first)
		putchar('\n');
	fflush(stdout);
	sigemptyset(&sigset);
	sigaddset(&sigset, SIGALRM);
	(void)sigprocmask(SIG_BLOCK, &sigset, &oldsigset);
	if (!signalled) {
	    sigemptyset(&sigset);
	    sigsuspend(&sigset);
	}
	(void)sigprocmask(SIG_SETMASK, &oldsigset, NULL);

	signalled = NO;
	line++;
	first = 0;
	if (line == 21)
		goto banner;
	else
		goto loop;
	/*NOTREACHED*/
}

void
intervalpr(void (*pr)(uint32_t, char *, int), uint32_t off, char *name , int af)
{
	struct itimerval timer_interval;
	sigset_t sigset, oldsigset;

	/* create a timer that fires repeatedly every interval seconds */
	timer_interval.it_value.tv_sec = interval;
	timer_interval.it_value.tv_usec = 0;
	timer_interval.it_interval.tv_sec = interval;
	timer_interval.it_interval.tv_usec = 0;
	(void) signal(SIGALRM, catchalarm);
	signalled = NO;
	(void) setitimer(ITIMER_REAL, &timer_interval, NULL);

	for (;;) {
		pr(off, name, af);

		fflush(stdout);
		sigemptyset(&sigset);
		sigaddset(&sigset, SIGALRM);
		(void) sigprocmask(SIG_BLOCK, &sigset, &oldsigset);
		if (!signalled) {
			sigemptyset(&sigset);
			sigsuspend(&sigset);
		}
		(void) sigprocmask(SIG_SETMASK, &oldsigset, NULL);
		signalled = NO;
	}
}

/*
 * Called if an interval expires before sidewaysintpr has completed a loop.
 * Sets a flag to not wait for the alarm.
 */
static void
catchalarm(int signo )
{
	signalled = YES;
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

void
intpr_ri(void (*pfunc)(char *))
{
	int mib[6];
	char *buf = NULL, *lim, *next;
	size_t len;
	unsigned int ifindex = 0;
	struct if_msghdr2 *if2m;

	if (interface != 0) {
		ifindex = if_nametoindex(interface);
		if (ifindex == 0) {
			printf("interface name is not valid: %s\n", interface);
			exit(1);
		}
	}

	mib[0]	= CTL_NET;		/* networking subsystem */
	mib[1]	= PF_ROUTE;		/* type of information */
	mib[2]	= 0;			/* protocol (IPPROTO_xxx) */
	mib[3]	= 0;			/* address family */
	mib[4]	= NET_RT_IFLIST2;	/* operation */
	mib[5]	= 0;
	if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0)
		return;
	if ((buf = malloc(len)) == NULL) {
		printf("malloc failed\n");
		exit(1);
	}
	if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
		free(buf);
		return;
	}

	printf("%-6s %-17s %8.8s %-9.9s %4s %4s",
	       "Proto", "Linklayer Address", "Netif", "Expire", "Refs",
	       "Prbs");
	if (xflag)
		printf(" %7s %7s %7s", "RSSI", "LQM", "NPM");
	printf("\n");

	lim = buf + len;
	if2m = (struct if_msghdr2 *)buf;

	for (next = buf; next < lim; ) {
		if2m = (struct if_msghdr2 *)next;
		next += if2m->ifm_msglen;

		if (if2m->ifm_type != RTM_IFINFO2)
			continue;
		else if (interface != 0 && if2m->ifm_index != ifindex)
			continue;

		llreach_sysctl(if2m->ifm_index);
	}
	free(buf);
}

static void
llreach_sysctl(uint32_t ifindex)
{
#define	MAX_SYSCTL_TRY	5
	int mib[6], i, ntry = 0;
	size_t mibsize, len, needed, cnt;
	struct if_llreach_info *lri;
	struct timeval time;
	char *buf;
	char ifname[IF_NAMESIZE];

	bzero(&mib, sizeof (mib));
	mibsize = sizeof (mib) / sizeof (mib[0]);
	if (sysctlnametomib("net.link.generic.system.llreach_info", mib,
	    &mibsize) == -1) {
		perror("sysctlnametomib");
		return;
	}

	needed = 0;
	mib[5] = ifindex;

	mibsize = sizeof (mib) / sizeof (mib[0]);
	do {
		if (sysctl(mib, mibsize, NULL, &needed, NULL, 0) == -1) {
			perror("sysctl net.link.generic.system.llreach_info");
			return;
		}
		if ((buf = malloc(needed)) == NULL) {
			perror("malloc");
			return;
		}
		if (sysctl(mib, mibsize, buf, &needed, NULL, 0) == -1) {
			if (errno != ENOMEM || ++ntry >= MAX_SYSCTL_TRY) {
				perror("sysctl");
				goto out_free;
			}
			free(buf);
			buf = NULL;
		}
	} while (buf == NULL);

	len = needed;
	cnt = len / sizeof (*lri);
	lri = (struct if_llreach_info *)buf;

	gettimeofday(&time, 0);
	if (if_indextoname(ifindex, ifname) == NULL)
		snprintf(ifname, sizeof (ifname), "%s", "?");

	for (i = 0; i < cnt; i++, lri++) {
		printf("0x%-4x %-17s %8.8s ", lri->lri_proto,
		    ether_ntoa((struct ether_addr *)lri->lri_addr), ifname);

		if (lri->lri_expire > time.tv_sec)
			printf("%-9.9s", sec2str(lri->lri_expire - time.tv_sec));
		else if (lri->lri_expire == 0)
			printf("%-9.9s", "permanent");
		else
			printf("%-9.9s", "expired");

		printf(" %4d", lri->lri_refcnt);
		if (lri->lri_probes)
			printf(" %4d", lri->lri_probes);

		if (xflag) {
			if (!lri->lri_probes)
				printf(" %-4.4s", "none");

			if (lri->lri_rssi != IFNET_RSSI_UNKNOWN)
				printf(" %7d", lri->lri_rssi);
			else
				printf(" %-7.7s", "unknown");

			switch (lri->lri_lqm)
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
				printf(" %7d", lri->lri_lqm);
				break;
			}

			switch (lri->lri_npm)
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
				printf(" %7d", lri->lri_npm);
				break;
			}
		}

		printf("\n");
		len -= sizeof (*lri);
	}

	if (len > 0) {
		fprintf(stderr, "warning: %u trailing bytes from %s\n",
		    (unsigned int)len, "net.link.generic.system.llreach_info");
	}

out_free:
	free(buf);
#undef	MAX_SYSCTL_TRY
}

void
aqstatpr(void)
{
	unsigned int ifindex;
	struct itimerval timer_interval;
	struct if_qstatsreq ifqr;
	struct if_ifclassq_stats *ifcqs;
	sigset_t sigset, oldsigset;
	u_int32_t scheduler;
	int s, n, tcq = 0;

	if (cq < -1 || cq >= IFCQ_SC_MAX) {
		fprintf(stderr, "Invalid classq index (range is 0-%d)\n",
		     IFCQ_SC_MAX-1);
		return;
	}
	ifindex = if_nametoindex(interface);
	if (ifindex == 0) {
		fprintf(stderr, "Invalid interface name\n");
		return;
	}

	ifcqs = malloc(sizeof (*ifcqs));
	if (ifcqs == NULL) {
		fprintf(stderr, "Unable to allocate memory\n");
		return;
	}

	if ((s = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
		perror("Warning: socket(AF_INET)");
		free(ifcqs);
		return;
	}

	bzero(&ifqr, sizeof (ifqr));
	strlcpy(ifqr.ifqr_name, interface, sizeof (ifqr.ifqr_name));
	ifqr.ifqr_buf = ifcqs;
	ifqr.ifqr_len = sizeof (*ifcqs);

loop:
	if (interval > 0) {
		/* create a timer that fires repeatedly every interval seconds */
		timer_interval.it_value.tv_sec = interval;
		timer_interval.it_value.tv_usec = 0;
		timer_interval.it_interval.tv_sec = interval;
		timer_interval.it_interval.tv_usec = 0;
		(void) signal(SIGALRM, catchalarm);
		signalled = NO;
		(void) setitimer(ITIMER_REAL, &timer_interval, NULL);
	}

	ifqr.ifqr_slot = 0;
	if (ioctl(s, SIOCGIFQUEUESTATS, (char *)&ifqr) < 0) {
		if (errno == ENXIO) {
			printf("Queue statistics are not available on %s\n",
			    interface);
		} else {
			perror("Warning: ioctl(SIOCGIFQUEUESTATS)");
		}
		goto done;
	}
	scheduler = ifcqs->ifqs_scheduler;
	tcq = (scheduler == PKTSCHEDT_TCQ);

	printf("%s:\n"
	    "%s     [ sched: %9s %sqlength:  %3d/%3d ]\n",
	    interface, tcq ? "  " : "", sched2str(ifcqs->ifqs_scheduler),
	    tcq ? "" : " ", ifcqs->ifqs_len, ifcqs->ifqs_maxlen);
	printf("%s     [ pkts: %10llu %sbytes: %10llu "
	    "%sdropped pkts: %6llu bytes: %6llu ]\n",
	    (scheduler != PKTSCHEDT_TCQ) ? "" : "  ",
	    ifcqs->ifqs_xmitcnt.packets, tcq ? "" : " ",
	    ifcqs->ifqs_xmitcnt.bytes, tcq ? "" : " ",
	    ifcqs->ifqs_dropcnt.packets, ifcqs->ifqs_dropcnt.bytes);

	for (n = 0; n < IFCQ_SC_MAX; n++) {
		qstats[n].printed = 0;
		if (!tcq)
			continue;
		ifqr.ifqr_slot = n;
		if (ioctl(s, SIOCGIFQUEUESTATS, (char *)&ifqr) < 0) {
			perror("Warning: ioctl(SIOCGIFQUEUESTATS)");
			goto done;
		}
		qstats[n].handle = ifcqs->ifqs_tcq_stats.class_handle;
	}

	for (n = 0; n < IFCQ_SC_MAX && scheduler != PKTSCHEDT_NONE; n++) {
		if (cq >= 0 && cq != n)
			continue;

		ifqr.ifqr_slot = n;
		if (ioctl(s, SIOCGIFQUEUESTATS, (char *)&ifqr) < 0) {
			perror("Warning: ioctl(SIOCGIFQUEUESTATS)");
			goto done;
		}

		update_avg(ifcqs, &qstats[n]);

		switch (scheduler) {
			case PKTSCHEDT_TCQ:
				print_tcqstats(n, &ifcqs->ifqs_tcq_stats,
				    &qstats[n]);
				break;
			case PKTSCHEDT_QFQ:
				print_qfqstats(n, &ifcqs->ifqs_qfq_stats,
				    &qstats[n]);
				break;
			case PKTSCHEDT_FQ_CODEL:
				print_fq_codel_stats(n,
				    &ifcqs->ifqs_fq_codel_stats,
				    &qstats[n]);
				break;
			case PKTSCHEDT_NONE:
			default:
				break;
		}
	}

	fflush(stdout);

	if (interval > 0) {
		sigemptyset(&sigset);
		sigaddset(&sigset, SIGALRM);
		(void) sigprocmask(SIG_BLOCK, &sigset, &oldsigset);
		if (!signalled) {
			sigemptyset(&sigset);
			sigsuspend(&sigset);
		}
		(void) sigprocmask(SIG_SETMASK, &oldsigset, NULL);

		signalled = NO;
		goto loop;
	}

done:
	free(ifcqs);
	close(s);
}

static void
print_tcqstats(int slot, struct tcq_classstats *cs, struct queue_stats *qs)
{
	int n;

	if (qs->printed)
		return;

	qs->handle = cs->class_handle;
	qs->printed++;

	for (n = 0; n < IFCQ_SC_MAX; n++) {
		if (&qstats[n] != qs && qstats[n].handle == qs->handle)
			qstats[n].printed++;
	}

	printf("%5s: [ pkts: %10llu bytes: %10llu "
	    "dropped pkts: %6llu bytes: %6llu ]\n", tcqslot2str(slot),
	    (unsigned long long)cs->xmitcnt.packets,
	    (unsigned long long)cs->xmitcnt.bytes,
	    (unsigned long long)cs->dropcnt.packets,
	    (unsigned long long)cs->dropcnt.bytes);
	printf("       [ qlength: %3d/%3d qalg: %11s "
	    "svc class: %9s %-13s ]\n", cs->qlength, cs->qlimit,
	    qtype2str(cs->qtype), qid2str(cs->class_handle),
	    qstate2str(cs->qstate));

	if (qs->avgn >= 2) {
		printf("       [ measured: %7.1f packets/s, %s/s ]\n",
		    qs->avg_packets / interval,
		    rate2str((8 * qs->avg_bytes) / interval));
	}

	if (qflag < 2)
		return;

	switch (cs->qtype) {
	case Q_SFB:
		print_sfbstats(&cs->sfb);
		break;
	default:
		break;
	}
}

static void
print_qfqstats(int slot, struct qfq_classstats *cs, struct queue_stats *qs)
{
	printf(" %2d: [ pkts: %10llu  bytes: %10llu  "
	    "dropped pkts: %6llu bytes: %6llu ]\n", slot,
	    (unsigned long long)cs->xmitcnt.packets,
	    (unsigned long long)cs->xmitcnt.bytes,
	    (unsigned long long)cs->dropcnt.packets,
	    (unsigned long long)cs->dropcnt.bytes);
	printf("     [ qlength: %3d/%3d  index: %10u  weight: %12u "
	    "lmax: %7u ]\n", cs->qlength, cs->qlimit, cs->index,
	    cs->weight, cs->lmax);
	printf("     [ qalg: %10s  svc class: %6s %-35s ]\n",
	    qtype2str(cs->qtype), qid2str(cs->class_handle),
	    qstate2str(cs->qstate));

	if (qs->avgn >= 2) {
		printf("     [ measured: %7.1f packets/s, %s/s ]\n",
		    qs->avg_packets / interval,
		    rate2str((8 * qs->avg_bytes) / interval));
	}

	if (qflag < 2)
		return;

	switch (cs->qtype) {
	case Q_SFB:
		print_sfbstats(&cs->sfb);
		break;
	default:
		break;
	}
}

static void
print_fq_codel_stats(int pri, struct fq_codel_classstats *fqst,
    struct queue_stats *qs)
{
	int i = 0;

	if (fqst->fcls_service_class == 0 && fqst->fcls_pri == 0)
		return;
	printf("=====================================================\n");
	printf("     [ pri: %s (%d)\tsrv_cl: 0x%x\tquantum: %d\tdrr_max: %d ]\n",
	    pri2str(fqst->fcls_pri), fqst->fcls_pri,
	    fqst->fcls_service_class, fqst->fcls_quantum,
	    fqst->fcls_drr_max);
	printf("     [ queued pkts: %llu\tbytes: %llu ]\n",
	    fqst->fcls_pkt_cnt, fqst->fcls_byte_cnt);
	printf("     [ dequeued pkts: %llu\tbytes: %llu ]\n",
	    fqst->fcls_dequeue, fqst->fcls_dequeue_bytes);
	printf("     [ budget: %lld\ttarget qdelay: %10s\t",
	    fqst->fcls_budget, nsec_to_str(fqst->fcls_target_qdelay));
	printf("update interval:%10s ]\n",
	    nsec_to_str(fqst->fcls_update_interval));
	printf("     [ flow control: %u\tfeedback: %u\tstalls: %u\tfailed: %u ]\n",
	    fqst->fcls_flow_control, fqst->fcls_flow_feedback,
	    fqst->fcls_dequeue_stall, fqst->fcls_flow_control_fail);
	printf("     [ drop overflow: %llu\tearly: %llu\tmemfail: %u\tduprexmt:%u ]\n",
	    fqst->fcls_drop_overflow, fqst->fcls_drop_early,
	    fqst->fcls_drop_memfailure, fqst->fcls_dup_rexmts);
	printf("     [ flows total: %u\tnew: %u\told: %u ]\n",
	    fqst->fcls_flows_cnt,
	    fqst->fcls_newflows_cnt, fqst->fcls_oldflows_cnt);
	printf("     [ throttle on: %u\toff: %u\tdrop: %u ]\n",
	    fqst->fcls_throttle_on, fqst->fcls_throttle_off,
	    fqst->fcls_throttle_drops);

	if (qflag < 2)
		return;

	if (fqst->fcls_flowstats_cnt > 0) {
		printf("Flowhash\tBytes\tMin qdelay\tFlags\t\n");
		for (i = 0; i < fqst->fcls_flowstats_cnt; i++) {
			printf("%u\t%u\t%14s\t",
			    fqst->fcls_flowstats[i].fqst_flowhash,
			    fqst->fcls_flowstats[i].fqst_bytes,
			    nsec_to_str(fqst->fcls_flowstats[i].fqst_min_qdelay));
			if (fqst->fcls_flowstats[i].fqst_flags &
			    FQ_FLOWSTATS_OLD_FLOW)
				printf("O");
			if (fqst->fcls_flowstats[i].fqst_flags &
			    FQ_FLOWSTATS_NEW_FLOW)
				printf("N");
			if (fqst->fcls_flowstats[i].fqst_flags &
			    FQ_FLOWSTATS_LARGE_FLOW)
				printf("L");
			if (fqst->fcls_flowstats[i].fqst_flags &
			    FQ_FLOWSTATS_DELAY_HIGH)
				printf("D");
			if (fqst->fcls_flowstats[i].fqst_flags &
			    FQ_FLOWSTATS_FLOWCTL_ON)
				printf("F");
			printf("\n");
		}
	}
}

static void
print_sfbstats(struct sfb_stats *sfb)
{
	struct sfbstats *sp = &sfb->sfbstats;
	int i, j, cur = sfb->current;

	printf("\n");
	printf("     [target delay: %14s   ",
	    nsec_to_str(sfb->target_qdelay));
	printf("update interval: %14s]\n",
	    nsec_to_str(sfb->update_interval));
	printf("     [ early drop: %12llu  rlimit drop: %11llu  "
	    "marked: %11llu ]\n",
	    sp->drop_early, sp->drop_pbox, sp->marked_packets);
	printf("     [ penalized: %13llu  rehash cnt: %12llu  "
	    "current: %10u ]\n", sp->pbox_packets, sp->num_rehash, cur);
	printf("     [ deque avg: %13s  ", nsec_to_str(sp->dequeue_avg));
	printf("rehash intvl: %11s]\n", nsec_to_str(sp->rehash_intval));
	printf("     [ holdtime: %14s  ", nsec_to_str(sp->hold_time));
	printf("pboxtime: %14s ]\n", nsec_to_str(sp->pbox_time));
	printf("     [ allocation: %12u  drop thresh: %11u ]\n",
	    sfb->allocation, sfb->dropthresh);
	printf("     [ flow controlled: %7llu  adv feedback: %10llu ]\n",
	    sp->flow_controlled, sp->flow_feedback);
	printf("     [ min queue delay: %10s   delay_fcthreshold: %12u]\n "
	    "     [stalls: %12llu]\n",
	    nsec_to_str(sfb->min_estdelay), sfb->delay_fcthreshold,
	    sp->dequeue_stall);

	printf("\n\t\t\t\tCurrent bins (set %d)", cur);
	for (i = 0; i < SFB_LEVELS; ++i) {
		unsigned int q;
		double p;

		printf("\n\tLevel: %d\n", i);
		for (j = 0; j < SFB_BINS; ++j) {
			if ((j % 4) == 0)
				printf("\t%6d:\t", j + 1);
			p = sfb->binstats[cur].stats[i][j].pmark;
			q = sfb->binstats[cur].stats[i][j].pkts;
			if (p > 0) {
				p /= (1 << SFB_FP_SHIFT);
				printf("[%1.4f %4u]", p, q);
			} else {
				printf("[           ]");
			}
			if (j > 0 && ((j + 1) % 4) == 0)
				printf("\n");
		}
	}

	cur ^= 1;
	printf("\n\t\t\t\tWarm up bins (set %d)", cur);
	for (i = 0; i < SFB_LEVELS; ++i) {
		unsigned int q;
		double p;

		printf("\n\tLevel: %d\n", i);
		for (j = 0; j < SFB_BINS; ++j) {
			if ((j % 4) == 0)
				printf("\t%6d:\t", j + 1);
			p = sfb->binstats[cur].stats[i][j].pmark;
			q = sfb->binstats[cur].stats[i][j].pkts;
			if (p > 0) {
				p /= (1 << SFB_FP_SHIFT);
				printf("[%1.4f %4u]", p, q);
			} else {
				printf("[           ]");
			}
			if (j > 0 && ((j + 1) % 4) == 0)
				printf("\n");
		}
	}
	printf("\n");
}

static void
update_avg(struct if_ifclassq_stats *ifcqs, struct queue_stats *qs)
{
	u_int64_t		 b, p;
	int			 n;

	n = qs->avgn;

	switch (ifcqs->ifqs_scheduler) {
	case PKTSCHEDT_TCQ:
		b = ifcqs->ifqs_tcq_stats.xmitcnt.bytes;
		p = ifcqs->ifqs_tcq_stats.xmitcnt.packets;
		break;
	case PKTSCHEDT_QFQ:
		b = ifcqs->ifqs_qfq_stats.xmitcnt.bytes;
		p = ifcqs->ifqs_qfq_stats.xmitcnt.packets;
		break;
	case PKTSCHEDT_FQ_CODEL:
		b = ifcqs->ifqs_fq_codel_stats.fcls_dequeue_bytes;
		p = ifcqs->ifqs_fq_codel_stats.fcls_dequeue;
		break;
	default:
		b = 0;
		p = 0;
		break;
	}

	if (n == 0) {
		qs->prev_bytes = b;
		qs->prev_packets = p;
		qs->avgn++;
		return;
	}

	if (b >= qs->prev_bytes)
		qs->avg_bytes = ((qs->avg_bytes * (n - 1)) +
		    (b - qs->prev_bytes)) / n;

	if (p >= qs->prev_packets)
		qs->avg_packets = ((qs->avg_packets * (n - 1)) +
		    (p - qs->prev_packets)) / n;

	qs->prev_bytes = b;
	qs->prev_packets = p;
	if (n < AVGN_MAX)
		qs->avgn++;
}

static char *
qtype2str(classq_type_t t)
{
	char *c;

	switch (t) {
        case Q_DROPHEAD:
		c = "DROPHEAD";
		break;
        case Q_DROPTAIL:
		c = "DROPTAIL";
		break;
        case Q_SFB:
		c = "SFB";
		break;
	default:
		c = "UNKNOWN";
		break;
	}

	return (c);
}

#define NSEC_PER_SEC    1000000000      /* nanoseconds per second */
#define USEC_PER_SEC    1000000		/* microseconds per second */
#define MSEC_PER_SEC    1000		/* milliseconds per second */

static char *
nsec_to_str(unsigned long long nsec)
{
	static char buf[32];
	const char *u;
	long double n = nsec, t;

	if (nsec >= NSEC_PER_SEC) {
		t = n / NSEC_PER_SEC;
		u = "sec ";
	} else if (n >= USEC_PER_SEC) {
		t = n / USEC_PER_SEC;
		u = "msec";
	} else if (n >= MSEC_PER_SEC) {
		t = n / MSEC_PER_SEC;
		u = "usec";
	} else {
		t = n;
		u = "nsec";
	}

	snprintf(buf, sizeof (buf), "%-4.2Lf %4s", t, u);
	return (buf);
}

static char *
sched2str(unsigned int s)
{
	char *c;

	switch (s) {
	case PKTSCHEDT_NONE:
		c = "NONE";
		break;
	case PKTSCHEDT_TCQ:
		c = "TCQ";
		break;
	case PKTSCHEDT_QFQ:
		c = "QFQ";
		break;
	case PKTSCHEDT_FQ_CODEL:
		c = "FQ_CODEL";
		break;
	default:
		c = "UNKNOWN";
		break;
	}

	return (c);
}

static char *
qid2str(unsigned int s)
{
	char *c;

	switch (s) {
	case 0:
		c = "BE";
		break;
	case 1:
		c = "BK_SYS";
		break;
	case 2:
		c = "BK";
		break;
	case 3:
		c = "RD";
		break;
	case 4:
		c = "OAM";
		break;
	case 5:
		c = "AV";
		break;
	case 6:
		c = "RV";
		break;
	case 7:
		c = "VI";
		break;
	case 8:
		c = "VO";
		break;
	case 9:
		c = "CTL";
		break;
	default:
		c = "UNKNOWN";
		break;
	}

	return (c);
}

static char *
tcqslot2str(unsigned int s)
{
	char *c;

	switch (s) {
	case 0:
	case 3:
	case 4:
		c = "0,3,4";
		break;
	case 1:
	case 2:
		c = "1,2";
		break;
	case 5:
	case 6:
	case 7:
		c = "5-7";
		break;
	case 8:
	case 9:
		c = "8,9";
		break;
	default:
		c = "?";
		break;
	}

	return (c);
}

static char *
pri2str(unsigned int i)
{
	char *c;
	switch (i) {
	case 9:
		c = "BK_SYS";
		break;
	case 8:
		c = "BK";
		break;
	case 7:
		c = "BE";
		break;
	case 6:
		c = "RD";
		break;
	case 5:
		c = "OAM";
		break;
	case 4:
		c = "AV";
		break;
	case 3:
		c = "RV";
		break;
	case 2:
		c = "VI";
		break;
	case 1:
		c = "VO";
		break;
	case 0:
		c = "CTL";
		break;
	default:
		c = "?";
		break;
	}
	return (c);
}

static char *
qstate2str(unsigned int s)
{
	char *c;

	switch (s) {
	case QS_RUNNING:
		c = "(RUNNING)";
		break;
	case QS_SUSPENDED:
		c = "(SUSPENDED)";
		break;
	default:
		c = "(UNKNOWN)";
		break;
	}

	return (c);
}

#define	R2S_BUFS	8
#define	RATESTR_MAX	16

static char *
rate2str(long double rate)
{
	char		*buf;
	static char	 r2sbuf[R2S_BUFS][RATESTR_MAX];  /* ring bufer */
	static int	 idx = 0;
	int		 i;
	static const char unit[] = " KMG";

	buf = r2sbuf[idx++];
	if (idx == R2S_BUFS)
		idx = 0;

	for (i = 0; rate >= 1000 && i <= 3; i++)
		rate /= 1000;

	if ((int)(rate * 100) % 100)
		snprintf(buf, RATESTR_MAX, "%.2Lf%cb", rate, unit[i]);
	else
		snprintf(buf, RATESTR_MAX, "%lld%cb", (int64_t)rate, unit[i]);

	return (buf);
}

void
rxpollstatpr(void)
{
	struct ifmibdata_supplemental ifmsupp;
	size_t miblen = sizeof (ifmsupp);
	struct itimerval timer_interval;
	struct if_rxpoll_stats *sp;
	sigset_t sigset, oldsigset;
	unsigned int ifindex;
	int name[6];

	ifindex = if_nametoindex(interface);
	if (ifindex == 0) {
		fprintf(stderr, "Invalid interface name\n");
		return;
	}

	bzero(&ifmsupp, sizeof (struct ifmibdata_supplemental));

loop:
	if (interval > 0) {
		/* create a timer that fires repeatedly every interval seconds */
		timer_interval.it_value.tv_sec = interval;
		timer_interval.it_value.tv_usec = 0;
		timer_interval.it_interval.tv_sec = interval;
		timer_interval.it_interval.tv_usec = 0;
		(void) signal(SIGALRM, catchalarm);
		signalled = NO;
		(void) setitimer(ITIMER_REAL, &timer_interval, NULL);
	}

	/* Common OID prefix */
	name[0] = CTL_NET;
	name[1] = PF_LINK;
	name[2] = NETLINK_GENERIC;
	name[3] = IFMIB_IFDATA;
	name[4] = ifindex;
	name[5] = IFDATA_SUPPLEMENTAL;
	if (sysctl(name, 6, &ifmsupp, &miblen, NULL, 0) == -1)
		err(1, "sysctl IFDATA_SUPPLEMENTAL");

	sp = &ifmsupp.ifmd_rxpoll_stats;

	printf("%-4s [ poll on requests:  %15u  errors: %27u ]\n",
	    interface, sp->ifi_poll_on_req, sp->ifi_poll_on_err);
	printf("     [ poll off requests: %15u  errors: %27u ]\n",
	    sp->ifi_poll_off_req, sp->ifi_poll_off_err);
	printf("     [ polled packets: %18llu  polled bytes: %21llu ]\n",
	    sp->ifi_poll_packets, sp->ifi_poll_bytes);
	printf("     [ sampled packets avg/min/max: %12u / %12u / %12u ]\n",
	    sp->ifi_poll_packets_avg, sp->ifi_poll_packets_min,
	    sp->ifi_poll_packets_max);
	printf("     [ sampled bytes avg/min/max:   %12u / %12u / %12u ]\n",
	    sp->ifi_poll_bytes_avg, sp->ifi_poll_bytes_min,
	    sp->ifi_poll_bytes_max);
	printf("     [ sampled wakeups avg:         %12u ]\n",
	    sp->ifi_poll_wakeups_avg);
	printf("     [ packets lowat/hiwat threshold: %10u / %10u ]\n",
	    sp->ifi_poll_packets_lowat, sp->ifi_poll_packets_hiwat);
	printf("     [ bytes lowat/hiwat threshold:   %10u / %10u ]\n",
	    sp->ifi_poll_bytes_lowat, sp->ifi_poll_bytes_hiwat);
	printf("     [ wakeups lowat/hiwat threshold: %10u / %10u ]\n",
	    sp->ifi_poll_wakeups_lowat, sp->ifi_poll_wakeups_hiwat);

	fflush(stdout);

	if (interval > 0) {
		sigemptyset(&sigset);
		sigaddset(&sigset, SIGALRM);
		(void) sigprocmask(SIG_BLOCK, &sigset, &oldsigset);
		if (!signalled) {
			sigemptyset(&sigset);
			sigsuspend(&sigset);
		}
		(void) sigprocmask(SIG_SETMASK, &oldsigset, NULL);

		signalled = NO;
		goto loop;
	}
}

static int
create_control_socket(const char *control_name)
{
	struct sockaddr_ctl sc;
	struct ctl_info	ctl;
	int fd;

	fd = socket(PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL);
	if (fd == -1) {
		perror("socket(PF_SYSTEM)");
		return fd;
	}

	/* Get the control ID for statistics */
	bzero(&ctl, sizeof(ctl));
	strlcpy(ctl.ctl_name, control_name, sizeof(ctl.ctl_name));
	if (ioctl(fd, CTLIOCGINFO, &ctl) == -1)
	{
		perror("ioctl(CTLIOCGINFO)");
		close(fd);
		return -1;
	}

	/* Connect to the statistics control */
	bzero(&sc, sizeof(sc));
	sc.sc_len = sizeof(sc);
	sc.sc_family = AF_SYSTEM;
	sc.ss_sysaddr = SYSPROTO_CONTROL;
	sc.sc_id = ctl.ctl_id;
	sc.sc_unit = 0;
	if (connect(fd, (struct sockaddr*)&sc, sc.sc_len) != 0)
	{
		perror("connect(SYSPROTO_CONTROL)");
		close(fd);
		return -1;
	}

	/* Set socket to non-blocking operation */
	if (fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK) == -1) {
		perror("fcnt(F_SETFL,O_NONBLOCK)");
		close(fd);
		return -1;
	}
	return fd;
}

static int
add_nstat_src(int fd, const nstat_ifnet_add_param *ifparam,
		nstat_src_ref_t *outsrc)
{
	nstat_msg_add_src_req *addreq;
	nstat_msg_src_added *addedmsg;
	nstat_ifnet_add_param *param;
	char buffer[sizeof(*addreq) + sizeof(*param)];
	ssize_t result;
	const u_int32_t	addreqsize =
		offsetof(struct nstat_msg_add_src, param) + sizeof(*param);

	/* Setup the add source request */
	addreq = (nstat_msg_add_src_req *)buffer;
	param = (nstat_ifnet_add_param*)addreq->param;
	bzero(addreq, addreqsize);
	addreq->hdr.context = (uintptr_t)&buffer;
	addreq->hdr.type = NSTAT_MSG_TYPE_ADD_SRC;
	addreq->provider = NSTAT_PROVIDER_IFNET;
	bzero(param, sizeof(*param));
	param->ifindex = ifparam->ifindex;
	param->threshold = ifparam->threshold;

	/* Send the add source request */
	result = send(fd, addreq, addreqsize, 0);
	if (result != addreqsize)
	{
		if (result == -1)
			perror("send(NSTAT_ADD_SRC_REQ)");
		else
			fprintf(stderr, "%s: could only sent %ld out of %d\n",
				__func__, result, addreqsize);
		return -1;
	}

	/* Receive the response */
	addedmsg = (nstat_msg_src_added *)buffer;
	result = recv(fd, addedmsg, sizeof(buffer), 0);
	if (result < sizeof(*addedmsg))
	{
		if (result == -1)
			perror("recv(NSTAT_ADD_SRC_RSP)");
		else
			fprintf(stderr, "%s: recv too small, received %ld, "
				"expected %lu\n", __func__, result,
				sizeof(*addedmsg));
		return -1;
	}

	if (addedmsg->hdr.type != NSTAT_MSG_TYPE_SRC_ADDED)
	{
		fprintf(stderr, "%s: received wrong message type, received %u "
			"expected %u\n", __func__, addedmsg->hdr.type,
			NSTAT_MSG_TYPE_SRC_ADDED);
		return -1;
	}

	if (addedmsg->hdr.context != (uintptr_t)&buffer)
	{
		fprintf(stderr, "%s: received wrong context, received %llu "
			"expected %lu\n", __func__, addedmsg->hdr.context,
			(uintptr_t)&buffer);
		return -1;
	}
	*outsrc = addedmsg->srcref;
	return 0;
}

static int
rem_nstat_src(int fd, nstat_src_ref_t sref)
{
	nstat_msg_rem_src_req *remreq;
	nstat_msg_src_removed *remrsp;
	char buffer[sizeof(*remreq)];
	ssize_t result;

	/* Setup the add source request */
	remreq = (nstat_msg_rem_src_req *)buffer;
	bzero(remreq, sizeof(*remreq));
	remreq->hdr.type = NSTAT_MSG_TYPE_REM_SRC;
	remreq->srcref = sref;

	/* Send the remove source request */
	result = send(fd, remreq, sizeof(*remreq), 0);
	if (result != sizeof(*remreq)) {
		if (result == -1)
			perror("send(NSTAT_REM_SRC_REQ)");
		else
			fprintf(stderr, "%s: could only sent %ld out of %lu\n",
				__func__, result, sizeof(*remreq));
		return -1;
	}

	/* Receive the response */
	remrsp = (nstat_msg_src_removed *)buffer;
	result = recv(fd, remrsp, sizeof(buffer), 0);
	if (result < sizeof(*remrsp)) {
		if (result == -1)
			perror("recv(NSTAT_REM_SRC_RSP)");
		else
			fprintf(stderr, "%s: recv too small, received %ld, "
				"expected %lu\n", __func__, result,
				sizeof(*remrsp));
		return -1;
	}

	if (remrsp->hdr.type != NSTAT_MSG_TYPE_SRC_REMOVED) {
		fprintf(stderr, "%s: received wrong message type, received %u "
			"expected %u\n", __func__, remrsp->hdr.type,
			NSTAT_MSG_TYPE_SRC_REMOVED);
		return -1;
	}

	if (remrsp->srcref != sref) {
		fprintf(stderr, "%s: received invalid srcref, received %llu "
			"expected %llu\n", __func__, remrsp->srcref, sref);
	}
	return 0;
}

static int
get_src_decsription(int fd, nstat_src_ref_t srcref,
			struct nstat_ifnet_descriptor *ifdesc)
{
	nstat_msg_get_src_description *dreq;
	nstat_msg_src_description *drsp;
	char buffer[sizeof(*drsp) + sizeof(*ifdesc)];
	ssize_t result;
	const u_int32_t	descsize =
		offsetof(struct nstat_msg_src_description, data) +
		sizeof(nstat_ifnet_descriptor);

	dreq = (nstat_msg_get_src_description *)buffer;
	bzero(dreq, sizeof(*dreq));
	dreq->hdr.type = NSTAT_MSG_TYPE_GET_SRC_DESC;
	dreq->srcref = srcref;
	result = send(fd, dreq, sizeof(*dreq), 0);
	if (result != sizeof(*dreq))
	{
		if (result == -1)
			perror("send(NSTAT_GET_SRC_DESC_REQ)");
		else
			fprintf(stderr, "%s: sent %ld out of %lu\n",
				__func__, result, sizeof(*dreq));
		return -1;
	}

	/* Receive the source description response */
	drsp = (nstat_msg_src_description *)buffer;
	result = recv(fd, drsp, sizeof(buffer), 0);
	if (result < descsize)
	{
		if (result == -1)
			perror("recv(NSTAT_GET_SRC_DESC_RSP");
		else
			fprintf(stderr, "%s: recv too small, received %ld, "
				"expected %u\n", __func__, result, descsize);
		return -1;
	}

	if (drsp->hdr.type != NSTAT_MSG_TYPE_SRC_DESC)
	{
		fprintf(stderr, "%s: received wrong message type, received %u "
			"expected %u\n", __func__, drsp->hdr.type,
			NSTAT_MSG_TYPE_SRC_DESC);
		return -1;
	}

	if (drsp->srcref != srcref)
	{
		fprintf(stderr, "%s: received message for wrong source, "
			"received 0x%llx expected 0x%llx\n",
			__func__, drsp->srcref, srcref);
		return -1;
	}

	bcopy(drsp->data, ifdesc, sizeof(*ifdesc));
	return 0;
}

static void
print_wifi_status(nstat_ifnet_desc_wifi_status *status)
{
	int tmp;
#define val(x, f)	\
	((status->valid_bitmask & NSTAT_IFNET_DESC_WIFI_ ## f ## _VALID) ?\
	 status->x : -1)
#define parg(n, un) #n, val(n, un)
#define pretxtl(n, un) \
	(((tmp = val(n, un)) == -1) ? "(not valid)" : \
	((tmp == NSTAT_IFNET_DESC_WIFI_UL_RETXT_LEVEL_NONE) ? "(none)" : \
	((tmp == NSTAT_IFNET_DESC_WIFI_UL_RETXT_LEVEL_LOW) ? "(low)" : \
	((tmp == NSTAT_IFNET_DESC_WIFI_UL_RETXT_LEVEL_MEDIUM) ? "(medium)" : \
	((tmp == NSTAT_IFNET_DESC_WIFI_UL_RETXT_LEVEL_HIGH) ? "(high)" : \
	"(?)")))))

	printf("\nwifi status:\n");
	printf(
	    "\t%s:\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t\t%d\n"
	    "\t%s:\t\t%d%s\n"
	    "\t%s:\t\t%d\n"
	    "\t%s:\t\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t\t%d\n"
	    "\t%s:\t\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t\t%d\n"
	    "\t%s:\t\t%d\n",
	    parg(link_quality_metric, LINK_QUALITY_METRIC),
	    parg(ul_effective_bandwidth, UL_EFFECTIVE_BANDWIDTH),
	    parg(ul_max_bandwidth, UL_MAX_BANDWIDTH),
	    parg(ul_min_latency, UL_MIN_LATENCY),
	    parg(ul_effective_latency, UL_EFFECTIVE_LATENCY),
	    parg(ul_max_latency, UL_MAX_LATENCY),
	    parg(ul_retxt_level, UL_RETXT_LEVEL),
	    pretxtl(ul_retxt_level, UL_RETXT_LEVEL),
	    parg(ul_bytes_lost, UL_BYTES_LOST),
	    parg(ul_error_rate, UL_ERROR_RATE),
	    parg(dl_effective_bandwidth, DL_EFFECTIVE_BANDWIDTH),
	    parg(dl_max_bandwidth, DL_MAX_BANDWIDTH),
	    parg(dl_min_latency, DL_MIN_LATENCY),
	    parg(dl_effective_latency, DL_EFFECTIVE_LATENCY),
	    parg(dl_max_latency, DL_MAX_LATENCY),
	    parg(dl_error_rate, DL_ERROR_RATE),
	    parg(config_frequency, CONFIG_FREQUENCY),
	    parg(config_multicast_rate, CONFIG_MULTICAST_RATE),
	    parg(scan_count, CONFIG_SCAN_COUNT),
	    parg(scan_duration, CONFIG_SCAN_DURATION)
	    );
#undef pretxtl
#undef parg
#undef val
}

static void
print_cellular_status(nstat_ifnet_desc_cellular_status *status)
{
	int tmp, tmp_mss;
#define val(x, f)	\
	((status->valid_bitmask & NSTAT_IFNET_DESC_CELL_ ## f ## _VALID) ?\
	 status->x : -1)
#define parg(n, un) #n, val(n, un)
#define pretxtl(n, un) \
	(((tmp = val(n, un)) == -1) ? "(not valid)" : \
	((tmp == NSTAT_IFNET_DESC_CELL_UL_RETXT_LEVEL_NONE) ? "(none)" : \
	((tmp == NSTAT_IFNET_DESC_CELL_UL_RETXT_LEVEL_LOW) ? "(low)" : \
	((tmp == NSTAT_IFNET_DESC_CELL_UL_RETXT_LEVEL_MEDIUM) ? "(medium)" : \
	((tmp == NSTAT_IFNET_DESC_CELL_UL_RETXT_LEVEL_HIGH) ? "(high)" : \
	"(?)")))))
#define pretxtm(n, un) \
	(((tmp_mss = val(n,un)) == -1) ? "(not valid)" : \
	((tmp_mss == NSTAT_IFNET_DESC_MSS_RECOMMENDED_NONE) ? "(none)" : \
	((tmp_mss == NSTAT_IFNET_DESC_MSS_RECOMMENDED_MEDIUM) ? "(medium)" : \
	((tmp_mss == NSTAT_IFNET_DESC_MSS_RECOMMENDED_LOW) ? "(low)" : \
	"(?)"))))

	printf("\ncellular status:\n");
	printf(
	    "\t%s:\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t\t%d\n"
	    "\t%s:\t\t%d%s\n"
	    "\t%s:\t\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t%d\n"
	    "\t%s:\t%d %s\n",
	    parg(link_quality_metric, LINK_QUALITY_METRIC),
	    parg(ul_effective_bandwidth, UL_EFFECTIVE_BANDWIDTH),
	    parg(ul_max_bandwidth, UL_MAX_BANDWIDTH),
	    parg(ul_min_latency, UL_MIN_LATENCY),
	    parg(ul_effective_latency, UL_EFFECTIVE_LATENCY),
	    parg(ul_max_latency, UL_MAX_LATENCY),
	    parg(ul_retxt_level, UL_RETXT_LEVEL),
	    pretxtl(ul_retxt_level, UL_RETXT_LEVEL),
	    parg(ul_bytes_lost, UL_BYTES_LOST),
	    parg(ul_min_queue_size, UL_MIN_QUEUE_SIZE),
	    parg(ul_avg_queue_size, UL_AVG_QUEUE_SIZE),
	    parg(ul_max_queue_size, UL_MAX_QUEUE_SIZE),
	    parg(dl_effective_bandwidth, DL_EFFECTIVE_BANDWIDTH),
	    parg(dl_max_bandwidth, DL_MAX_BANDWIDTH),
	    parg(config_inactivity_time, CONFIG_INACTIVITY_TIME),
	    parg(config_backoff_time, CONFIG_BACKOFF_TIME),
	    parg(mss_recommended, MSS_RECOMMENDED),
	    pretxtm(mss_recommended, MSS_RECOMMENDED)
	    );
#undef pretxtl
#undef parg
#undef val
}

static int
get_interface_state(int fd, const char *ifname, struct ifreq *ifr)
{
	bzero(ifr, sizeof(*ifr));
	snprintf(ifr->ifr_name, sizeof(ifr->ifr_name), "%s", ifname);

	if (ioctl(fd, SIOCGIFINTERFACESTATE, ifr) == -1) {
		perror("ioctl(CTLIOCGINFO)");
		return -1;
	}
	return 0;
}

static void
print_interface_state(struct ifreq *ifr)
{
	int lqm, rrc, avail;

	printf("\ninterface state:\n");

	if (ifr->ifr_interface_state.valid_bitmask &
	    IF_INTERFACE_STATE_LQM_STATE_VALID) {
		printf("\tlqm: ");
		lqm = ifr->ifr_interface_state.lqm_state;
		if (lqm == IFNET_LQM_THRESH_GOOD)
			printf("\"good\"");
		else if (lqm == IFNET_LQM_THRESH_POOR)
			printf("\"poor\"");
		else if (lqm == IFNET_LQM_THRESH_BAD)
			printf("\"bad\"");
		else if (lqm == IFNET_LQM_THRESH_UNKNOWN)
			printf("\"unknown\"");
		else if (lqm == IFNET_LQM_THRESH_OFF)
			printf("\"off\"");
		else
			printf("invalid(%d)", lqm);
	}

	if (ifr->ifr_interface_state.valid_bitmask &
	    IF_INTERFACE_STATE_RRC_STATE_VALID) {
		printf("\trrc: ");
		rrc = ifr->ifr_interface_state.rrc_state;
		if (rrc == IF_INTERFACE_STATE_RRC_STATE_CONNECTED)
			printf("\"connected\"");
		else if (rrc == IF_INTERFACE_STATE_RRC_STATE_IDLE)
			printf("\"idle\"");
		else
			printf("\"invalid(%d)\"", rrc);
	}

	if (ifr->ifr_interface_state.valid_bitmask &
	    IF_INTERFACE_STATE_INTERFACE_AVAILABILITY_VALID) {
		printf("\tavailability: ");
		avail = ifr->ifr_interface_state.interface_availability;
		if (avail == IF_INTERFACE_STATE_INTERFACE_AVAILABLE)
			printf("\"true\"");
		else if (rrc == IF_INTERFACE_STATE_INTERFACE_UNAVAILABLE)
			printf("\"false\"");
		else
			printf("\"invalid(%d)\"", avail);
	}
}

void
print_link_status(const char *ifname)
{
	unsigned int ifindex;
	struct itimerval timer_interval;
	sigset_t sigset, oldsigset;
	struct nstat_ifnet_descriptor ifdesc;
	nstat_ifnet_add_param ifparam;
	nstat_src_ref_t	sref = 0;
	struct ifreq ifr;
	int ctl_fd;

	ifindex = if_nametoindex(ifname);
	if (ifindex == 0) {
		fprintf(stderr, "Invalid interface name\n");
		return;
	}

	if ((ctl_fd = create_control_socket(NET_STAT_CONTROL_NAME)) < 0)
		return;

	ifparam.ifindex = ifindex;
	ifparam.threshold = UINT64_MAX;
	if (add_nstat_src(ctl_fd, &ifparam, &sref))
		goto done;
loop:
	if (interval > 0) {
		/* create a timer that fires repeatedly every interval
		 * seconds */
		timer_interval.it_value.tv_sec = interval;
		timer_interval.it_value.tv_usec = 0;
		timer_interval.it_interval.tv_sec = interval;
		timer_interval.it_interval.tv_usec = 0;
		(void) signal(SIGALRM, catchalarm);
		signalled = NO;
		(void) setitimer(ITIMER_REAL, &timer_interval, NULL);
	}

	/* get interface state */
	if (get_interface_state(ctl_fd, ifname, &ifr))
		goto done;

	/* get ntstat interface description */
	if (get_src_decsription(ctl_fd, sref, &ifdesc))
		goto done;

	/* print time */
	printf("\n%s: ", ifname);
	print_time();

	/* print interface state */
	print_interface_state(&ifr);

	/* print ntsat interface link status */
	if (ifdesc.link_status.link_status_type ==
	    NSTAT_IFNET_DESC_LINK_STATUS_TYPE_CELLULAR)
		print_cellular_status(&ifdesc.link_status.u.cellular);
	else if (ifdesc.link_status.link_status_type ==
		 NSTAT_IFNET_DESC_LINK_STATUS_TYPE_WIFI)
		print_wifi_status(&ifdesc.link_status.u.wifi);

	fflush(stdout);

	if (interval > 0) {
		sigemptyset(&sigset);
		sigaddset(&sigset, SIGALRM);
		(void) sigprocmask(SIG_BLOCK, &sigset, &oldsigset);
		if (!signalled) {
			sigemptyset(&sigset);
			sigsuspend(&sigset);
		}
		(void) sigprocmask(SIG_SETMASK, &oldsigset, NULL);

		signalled = NO;
		goto loop;
	}
done:
	if (sref)
		rem_nstat_src(ctl_fd, sref);
	close(ctl_fd);
}
