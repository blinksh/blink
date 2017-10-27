/*
 * Copyright (c) 2008-2010 Apple Inc. All rights reserved.
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
 * Copyright (c) 2007 Bruce M. Simpson <bms@FreeBSD.org>
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
 *
 */

#include <sys/cdefs.h>

/*
 * Print the running system's current multicast group memberships.
 * As this relies on getifmaddrs(), it may not be used with a core file.
 */

#include <sys/types.h>
#include <sys/param.h>
#include <sys/sysctl.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/errno.h>

#include <net/if.h>
#include <net/if_var.h>
#include <net/if_mib.h>
#include <net/if_types.h>
#include <net/if_dl.h>
#include <net/route.h>
#include <netinet/in.h>
#include <netinet/if_ether.h>
#include <netinet/igmp_var.h>
#include <netinet6/mld6_var.h>
#include <arpa/inet.h>
#include <netdb.h>

#include <ctype.h>
#include <err.h>
#include <ifaddrs.h>
#include <sysexits.h>

#include <stddef.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <ifaddrs.h>


#include "netstat.h"

union sockunion {
	struct sockaddr_storage	ss;
	struct sockaddr		sa;
	struct sockaddr_dl	sdl;
	struct sockaddr_in	sin;
	struct sockaddr_in6	sin6;
};
typedef union sockunion sockunion_t;

/*
 * This may have been defined in <net/if.h>.  Note that if <net/if.h> is
 * to be included it must be included before this header file.
 */
#ifndef	ifa_broadaddr
#define	ifa_broadaddr	ifa_dstaddr	/* broadcast address interface */
#endif

//struct ifmaddrs {
//	struct ifmaddrs	*ifma_next;
//	struct sockaddr	*ifma_name;
//	struct sockaddr	*ifma_addr;
//	struct sockaddr	*ifma_lladdr;
//};

void ifmalist_dump_af(const struct ifmaddrs * const ifmap, int const af);
static int ifmalist_dump_mcstat(struct ifmaddrs *);
static void in_ifinfo(struct igmp_ifinfo *);
static const char *inm_mode(u_int);
static void inm_print_sources_sysctl(uint32_t, struct in_addr);
#ifdef INET6
static void in6_ifinfo(struct mld_ifinfo *);
static void in6m_print_sources_sysctl(uint32_t, struct in6_addr *);
static const char *inet6_n2a(struct in6_addr *);
#endif
static void printb(const char *, unsigned int, const char *);
static const char *sdl_addr_to_hex(const struct sockaddr_dl *, char *, int);

extern char *routename6(struct sockaddr_in6 *);

#define	sa_equal(a1, a2)	\
	(bcmp((a1), (a2), ((a1))->sa_len) == 0)

#define	sa_dl_equal(a1, a2)	\
	((((struct sockaddr_dl *)(a1))->sdl_len ==			\
	 ((struct sockaddr_dl *)(a2))->sdl_len) &&			\
	 (bcmp(LLADDR((struct sockaddr_dl *)(a1)),			\
	       LLADDR((struct sockaddr_dl *)(a2)),			\
	       ((struct sockaddr_dl *)(a1))->sdl_alen) == 0))

#define	SALIGN	(sizeof(uint32_t) - 1)
#define	SA_RLEN(sa)	(sa ? ((sa)->sa_len ? (((sa)->sa_len + SALIGN) & ~SALIGN) : \
			    (SALIGN + 1)) : 0)
#define	MAX_SYSCTL_TRY	5
#define	RTA_MASKS	(RTA_GATEWAY | RTA_IFP | RTA_IFA)

void
ifmalist_dump_af(const struct ifmaddrs * const ifmap, int const af)
{
	const struct ifmaddrs *ifma;
	sockunion_t *psa;
	char myifname[IFNAMSIZ];
	char *pcolon;
	char *pafname, *pifname, *plladdr = NULL, *pgroup = NULL;

	switch (af) {
	case AF_INET:
		pafname = "IPv4";
		break;
#ifdef INET6
	case AF_INET6:
		pafname = "IPv6";
		break;
#endif
	case AF_LINK:
		pafname = "Link-layer";
		break;
	default:
		return;		/* XXX */
	}

	fprintf(stdout, "%s Multicast Group Memberships\n", pafname);
	fprintf(stdout, "%-20s\t%-16s\t%s\n", "Group", "Link-layer Address",
	    "Netif");

	for (ifma = ifmap; ifma; ifma = ifma->ifma_next) {

		if (ifma->ifma_name == NULL || ifma->ifma_addr == NULL)
			continue;

		/* Group address */
		psa = (sockunion_t *)ifma->ifma_addr;
		if (psa->sa.sa_family != af)
			continue;

		switch (psa->sa.sa_family) {
		case AF_INET:
			pgroup = inet_ntoa(psa->sin.sin_addr);
			break;
#ifdef INET6
		case AF_INET6:
			pgroup = routename6(&(psa->sin6));
			break;
#endif
		case AF_LINK:
			if ((psa->sdl.sdl_alen == ETHER_ADDR_LEN) ||
			    (psa->sdl.sdl_type == IFT_ETHER)) {
				pgroup =
ether_ntoa((struct ether_addr *)&psa->sdl.sdl_data);
#ifdef notyet
			} else {
				pgroup = addr2ascii(AF_LINK,
				    &psa->sdl,
				    sizeof(struct sockaddr_dl),
				    addrbuf);
#endif
			}
			break;
		default:
			continue;	/* XXX */
		}

		/* Link-layer mapping, if any */
		psa = (sockunion_t *)ifma->ifma_lladdr;
		if (psa != NULL) {
			if (psa->sa.sa_family == AF_LINK) {
				if ((psa->sdl.sdl_alen == ETHER_ADDR_LEN) ||
				    (psa->sdl.sdl_type == IFT_ETHER)) {
					/* IEEE 802 */
					plladdr =
ether_ntoa((struct ether_addr *)&psa->sdl.sdl_data);
#ifdef notyet
				} else {
					/* something more exotic */
					plladdr = addr2ascii(AF_LINK,
					    &psa->sdl,
					    sizeof(struct sockaddr_dl),
					    addrbuf);
#endif
				}
			} else {
				int i;
				
				/* not a link-layer address */
				plladdr = "<invalid>";
				
				for (i = 0; psa->sa.sa_len > 2 && i < psa->sa.sa_len - 2; i++)
					printf("0x%x ", psa->sa.sa_data[i]);
				printf("\n");
			}
		} else {
			plladdr = "<none>";
		}

		/* Interface upon which the membership exists */
		psa = (sockunion_t *)ifma->ifma_name;
		if (psa != NULL && psa->sa.sa_family == AF_LINK) {
			strlcpy(myifname, link_ntoa(&psa->sdl), IFNAMSIZ);
			pcolon = strchr(myifname, ':');
			if (pcolon)
				*pcolon = '\0';
			pifname = myifname;
		} else {
			pifname = "";
		}

		fprintf(stdout, "%-20s\t%-16s\t%s\n", pgroup, plladdr, pifname);
	}
}

void
ifmalist_dump(void)
{
	struct ifmaddrs *ifmap;

	if (getifmaddrs(&ifmap))
		err(EX_OSERR, "getifmaddrs");

	ifmalist_dump_af(ifmap, AF_LINK);
	fputs("\n", stdout);
	ifmalist_dump_af(ifmap, AF_INET);
#ifdef INET6
	fputs("\n", stdout);
	ifmalist_dump_af(ifmap, AF_INET6);
#endif
	if (sflag) {
		fputs("\n", stdout);
		ifmalist_dump_mcstat(ifmap);
	}

	freeifmaddrs(ifmap);
}

static int
ifmalist_dump_mcstat(struct ifmaddrs *ifmap)
{
	char			 thisifname[IFNAMSIZ];
	char			 addrbuf[NI_MAXHOST];
	struct ifaddrs		*ifap, *ifa;
	struct ifmaddrs		*ifma;
	sockunion_t		 lastifasa;
	sockunion_t		*psa, *pgsa, *pllsa, *pifasa;
	char			*pcolon;
	char			*pafname;
	uint32_t		 lastifindex, thisifindex;
	int			 error;
	uint32_t		ifindex = 0;

	if (interface != NULL)
		ifindex = if_nametoindex(interface);

	error = 0;
	ifap = NULL;
	lastifindex = 0;
	thisifindex = 0;
	lastifasa.ss.ss_family = AF_UNSPEC;

	if (getifaddrs(&ifap) != 0) {
		warn("getifmaddrs");
		return (-1);
	}

	for (ifma = ifmap; ifma; ifma = ifma->ifma_next) {
		error = 0;
		if (ifma->ifma_name == NULL || ifma->ifma_addr == NULL)
			continue;

		psa = (sockunion_t *)ifma->ifma_name;
		if (psa->sa.sa_family != AF_LINK) {
			fprintf(stderr,
			    "WARNING: Kernel returned invalid data.\n");
			error = -1;
			break;
		}

		/* Filter on interface name. */
		thisifindex = psa->sdl.sdl_index;
		if (ifindex != 0 && thisifindex != ifindex)
			continue;

		/* Filter on address family. */
		pgsa = (sockunion_t *)ifma->ifma_addr;
		if (af != 0 && pgsa->sa.sa_family != af)
			continue;

		strlcpy(thisifname, link_ntoa(&psa->sdl), IFNAMSIZ);
		pcolon = strchr(thisifname, ':');
		if (pcolon)
			*pcolon = '\0';

		/* Only print the banner for the first ifmaddrs entry. */
		if (lastifindex == 0 || lastifindex != thisifindex) {
			lastifindex = thisifindex;
			fprintf(stdout, "%s:\n", thisifname);
		}

		/*
		 * Currently, multicast joins only take place on the
		 * primary IPv4 address, and only on the link-local IPv6
		 * address, as per IGMPv2/3 and MLDv1/2 semantics.
		 * Therefore, we only look up the primary address on
		 * the first pass.
		 */
		pifasa = NULL;
		for (ifa = ifap; ifa; ifa = ifa->ifa_next) {
			if ((strcmp(ifa->ifa_name, thisifname) != 0) ||
			    (ifa->ifa_addr == NULL) ||
			    (ifa->ifa_addr->sa_family != pgsa->sa.sa_family))
				continue;
			/*
			 * For AF_INET6 only the link-local address should
			 * be returned. If built without IPv6 support,
			 * skip this address entirely.
			 */
			pifasa = (sockunion_t *)ifa->ifa_addr;
			if (pifasa->sa.sa_family == AF_INET6
#ifdef INET6
			    && !IN6_IS_ADDR_LINKLOCAL(&pifasa->sin6.sin6_addr)
#endif
			) {
				pifasa = NULL;
				continue;
			}
			break;
		}
		if (pifasa == NULL)
			continue;	/* primary address not found */

		if (!vflag && pifasa->sa.sa_family == AF_LINK)
			continue;

		/* Parse and print primary address, if not already printed. */
		if (lastifasa.ss.ss_family == AF_UNSPEC ||
		    ((lastifasa.ss.ss_family == AF_LINK &&
		      !sa_dl_equal(&lastifasa.sa, &pifasa->sa)) ||
		     !sa_equal(&lastifasa.sa, &pifasa->sa))) {

			switch (pifasa->sa.sa_family) {
			case AF_INET:
				pafname = "inet";
				break;
			case AF_INET6:
				pafname = "inet6";
				break;
			case AF_LINK:
				pafname = "link";
				break;
			default:
				pafname = "unknown";
				break;
			}

			switch (pifasa->sa.sa_family) {
			case AF_INET6:
#ifdef INET6
			{
				const char *p =
				    inet6_n2a(&pifasa->sin6.sin6_addr);
				strlcpy(addrbuf, p, sizeof(addrbuf));
				break;
			}
#else
			/* FALLTHROUGH */
#endif
			case AF_INET:
				error = getnameinfo(&pifasa->sa,
				    pifasa->sa.sa_len,
				    addrbuf, sizeof(addrbuf), NULL, 0,
				    NI_NUMERICHOST);
				if (error)
					printf("getnameinfo: %s\n",
					    gai_strerror(error));
				break;
			case AF_LINK: {
				(void) sdl_addr_to_hex(&pifasa->sdl, addrbuf,
				    sizeof (addrbuf));
				break;
			}
			default:
				addrbuf[0] = '\0';
				break;
			}

			fprintf(stdout, "\t%s %s\n", pafname, addrbuf);
			/*
			 * Print per-link IGMP information, if available.
			 */
			if (pifasa->sa.sa_family == AF_INET) {
				struct igmp_ifinfo igi;
				size_t mibsize, len;
				int mib[5];

				mibsize = sizeof(mib) / sizeof(mib[0]);
				if (sysctlnametomib("net.inet.igmp.ifinfo",
				    mib, &mibsize) == -1) {
					perror("sysctlnametomib");
					goto next_ifnet;
				}
				mib[mibsize] = thisifindex;
				len = sizeof(struct igmp_ifinfo);
				if (sysctl(mib, mibsize + 1, &igi, &len, NULL,
				    0) == -1) {
					perror("sysctl net.inet.igmp.ifinfo");
					goto next_ifnet;
				}
				in_ifinfo(&igi);
			}
#ifdef INET6
			/*
			 * Print per-link MLD information, if available.
			 */
			if (pifasa->sa.sa_family == AF_INET6) {
				struct mld_ifinfo mli;
				size_t mibsize, len;
				int mib[5];

				mibsize = sizeof(mib) / sizeof(mib[0]);
				if (sysctlnametomib("net.inet6.mld.ifinfo",
				    mib, &mibsize) == -1) {
					perror("sysctlnametomib");
					goto next_ifnet;
				}
				mib[mibsize] = thisifindex;
				len = sizeof(struct mld_ifinfo);
				if (sysctl(mib, mibsize + 1, &mli, &len, NULL,
				    0) == -1) {
					perror("sysctl net.inet6.mld.ifinfo");
					goto next_ifnet;
				}
				in6_ifinfo(&mli);
			}
#endif /* INET6 */
#if defined(INET6)
next_ifnet:
#endif
			lastifasa = *pifasa;
		}

		/* Print this group address. */
#ifdef INET6
		if (pgsa->sa.sa_family == AF_INET6) {
			const char *p = inet6_n2a(&pgsa->sin6.sin6_addr);
			strlcpy(addrbuf, p, sizeof(addrbuf));
		} else
#endif
		if (pgsa->sa.sa_family == AF_INET) {
			error = getnameinfo(&pgsa->sa, pgsa->sa.sa_len,
			    addrbuf, sizeof(addrbuf), NULL, 0, NI_NUMERICHOST);
			if (error)
				printf("getnameinfo: %s\n",
				    gai_strerror(error));
		} else {
			(void) sdl_addr_to_hex(&pgsa->sdl, addrbuf,
			    sizeof (addrbuf));
		}

		fprintf(stdout, "\t\tgroup %s", addrbuf);
		if (pgsa->sa.sa_family == AF_INET) {
			inm_print_sources_sysctl(thisifindex,
			    pgsa->sin.sin_addr);
		}
#ifdef INET6
		if (pgsa->sa.sa_family == AF_INET6) {
			in6m_print_sources_sysctl(thisifindex,
			    &pgsa->sin6.sin6_addr);
		}
#endif
		fprintf(stdout, "\n");

		/* Link-layer mapping, if present. */
		pllsa = (sockunion_t *)ifma->ifma_lladdr;
		if (pllsa != NULL) {
			(void) sdl_addr_to_hex(&pllsa->sdl, addrbuf,
			    sizeof (addrbuf));
			fprintf(stdout, "\t\t\tmcast-macaddr %s\n", addrbuf);
		}
	}

	if (ifap != NULL)
		freeifaddrs(ifap);

	return (error);
}

static void
in_ifinfo(struct igmp_ifinfo *igi)
{

	printf("\t");
	switch (igi->igi_version) {
	case IGMP_VERSION_1:
	case IGMP_VERSION_2:
	case IGMP_VERSION_3:
		printf("igmpv%d", igi->igi_version);
		break;
	default:
		printf("igmpv?(%d)", igi->igi_version);
		break;
	}
	printb(" flags", igi->igi_flags, "\020\1SILENT\2LOOPBACK");
	if (igi->igi_version == IGMP_VERSION_3) {
		printf(" rv %u qi %u qri %u uri %u",
		    igi->igi_rv, igi->igi_qi, igi->igi_qri, igi->igi_uri);
	}
	if (vflag >= 2) {
		printf(" v1timer %u v2timer %u v3timer %u",
		    igi->igi_v1_timer, igi->igi_v2_timer, igi->igi_v3_timer);
	}
	printf("\n");
}

static const char *inm_modes[] = {
	"undefined",
	"include",
	"exclude",
};

static const char *
inm_mode(u_int mode)
{

	if (mode >= MCAST_UNDEFINED && mode <= MCAST_EXCLUDE)
		return (inm_modes[mode]);
	return (NULL);
}

/*
 * Retrieve per-group source filter mode and lists via sysctl.
 */
static void
inm_print_sources_sysctl(uint32_t ifindex, struct in_addr gina)
{
#define	MAX_SYSCTL_TRY	5
	int mib[7];
	int ntry = 0;
	size_t mibsize;
	size_t len;
	size_t needed;
	size_t cnt;
	int i;
	char *buf;
	struct in_addr *pina;
	uint32_t *p;
	uint32_t fmode;
	const char *modestr;

	mibsize = sizeof(mib) / sizeof(mib[0]);
	if (sysctlnametomib("net.inet.ip.mcast.filters", mib, &mibsize) == -1) {
		perror("sysctlnametomib");
		return;
	}

	needed = 0;
	mib[5] = ifindex;
	mib[6] = gina.s_addr;	/* 32 bits wide */
	mibsize = sizeof(mib) / sizeof(mib[0]);
	do {
		if (sysctl(mib, mibsize, NULL, &needed, NULL, 0) == -1) {
			perror("sysctl net.inet.ip.mcast.filters");
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
	if (len < sizeof(uint32_t)) {
		perror("sysctl");
		goto out_free;
	}

	p = (uint32_t *)buf;
	fmode = *p++;
	len -= sizeof(uint32_t);

	modestr = inm_mode(fmode);
	if (modestr)
		printf(" mode %s", modestr);
	else
		printf(" mode (%u)", fmode);

	if (vflag == 0)
		goto out_free;

	cnt = len / sizeof(struct in_addr);
	pina = (struct in_addr *)p;

	for (i = 0; i < cnt; i++) {
		if (i == 0)
			printf(" srcs ");
		fprintf(stdout, "%s%s", (i == 0 ? "" : ","),
		    inet_ntoa(*pina++));
		len -= sizeof(struct in_addr);
	}
	if (len > 0) {
		fprintf(stderr, "warning: %u trailing bytes from %s\n",
		    (unsigned int)len, "net.inet.ip.mcast.filters");
	}

out_free:
	free(buf);
#undef	MAX_SYSCTL_TRY
}

#ifdef INET6

static void
in6_ifinfo(struct mld_ifinfo *mli)
{

	printf("\t");
	switch (mli->mli_version) {
	case MLD_VERSION_1:
	case MLD_VERSION_2:
		printf("mldv%d", mli->mli_version);
		break;
	default:
		printf("mldv?(%d)", mli->mli_version);
		break;
	}
	printb(" flags", mli->mli_flags, "\020\1SILENT");
	if (mli->mli_version == MLD_VERSION_2) {
		printf(" rv %u qi %u qri %u uri %u",
		    mli->mli_rv, mli->mli_qi, mli->mli_qri, mli->mli_uri);
	}
	if (vflag >= 2) {
		printf(" v1timer %u v2timer %u", mli->mli_v1_timer,
		   mli->mli_v2_timer);
	}
	printf("\n");
}

/*
 * Retrieve MLD per-group source filter mode and lists via sysctl.
 *
 * Note: The 128-bit IPv6 group addres needs to be segmented into
 * 32-bit pieces for marshaling to sysctl. So the MIB name ends
 * up looking like this:
 *  a.b.c.d.e.ifindex.g[0].g[1].g[2].g[3]
 * Assumes that pgroup originated from the kernel, so its components
 * are already in network-byte order.
 */
static void
in6m_print_sources_sysctl(uint32_t ifindex, struct in6_addr *pgroup)
{
#define	MAX_SYSCTL_TRY	5
	char addrbuf[INET6_ADDRSTRLEN];
	int mib[10];
	int ntry = 0;
	int *pi;
	size_t mibsize;
	size_t len;
	size_t needed;
	size_t cnt;
	int i;
	char *buf;
	struct in6_addr *pina;
	uint32_t *p;
	uint32_t fmode;
	const char *modestr;

	mibsize = sizeof(mib) / sizeof(mib[0]);
	if (sysctlnametomib("net.inet6.ip6.mcast.filters", mib,
	    &mibsize) == -1) {
		perror("sysctlnametomib");
		return;
	}

	needed = 0;
	mib[5] = ifindex;
	pi = (int *)pgroup;
	for (i = 0; i < 4; i++)
		mib[6 + i] = *pi++;

	mibsize = sizeof(mib) / sizeof(mib[0]);
	do {
		if (sysctl(mib, mibsize, NULL, &needed, NULL, 0) == -1) {
			perror("sysctl net.inet6.ip6.mcast.filters");
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
	if (len < sizeof(uint32_t)) {
		perror("sysctl");
		goto out_free;
	}

	p = (uint32_t *)buf;
	fmode = *p++;
	len -= sizeof(uint32_t);

	modestr = inm_mode(fmode);
	if (modestr)
		printf(" mode %s", modestr);
	else
		printf(" mode (%u)", fmode);

	if (vflag == 0)
		goto out_free;

	cnt = len / sizeof(struct in6_addr);
	pina = (struct in6_addr *)p;

	for (i = 0; i < cnt; i++) {
		if (i == 0)
			printf(" srcs ");
		inet_ntop(AF_INET6, (const char *)pina++, addrbuf,
		    INET6_ADDRSTRLEN);
		fprintf(stdout, "%s%s", (i == 0 ? "" : ","), addrbuf);
		len -= sizeof(struct in6_addr);
	}
	if (len > 0) {
		fprintf(stderr, "warning: %u trailing bytes from %s\n",
		    (unsigned int)len, "net.inet6.ip6.mcast.filters");
	}

out_free:
	free(buf);
#undef	MAX_SYSCTL_TRY
}

static const char *
inet6_n2a(struct in6_addr *p)
{
	static char buf[NI_MAXHOST];
	struct sockaddr_in6 sin6;
	u_int32_t scopeid;
	const int niflags = NI_NUMERICHOST;

	memset(&sin6, 0, sizeof(sin6));
	sin6.sin6_family = AF_INET6;
	sin6.sin6_len = sizeof(struct sockaddr_in6);
	sin6.sin6_addr = *p;
	if (IN6_IS_ADDR_LINKLOCAL(p) || IN6_IS_ADDR_MC_LINKLOCAL(p) ||
	    IN6_IS_ADDR_MC_NODELOCAL(p)) {
		scopeid = ntohs(*(u_int16_t *)&sin6.sin6_addr.s6_addr[2]);
		if (scopeid) {
			sin6.sin6_scope_id = scopeid;
			sin6.sin6_addr.s6_addr[2] = 0;
			sin6.sin6_addr.s6_addr[3] = 0;
		}
	}
	if (getnameinfo((struct sockaddr *)&sin6, sin6.sin6_len,
	    buf, sizeof(buf), NULL, 0, niflags) == 0) {
		return (buf);
	} else {
		return ("(invalid)");
	}
}
#endif /* INET6 */

/*
 * Print a value a la the %b format of the kernel's printf
 */
void
printb(const char *s, unsigned int v, const char *bits)
{
	int i, any = 0;
	char c;

	if (bits && *bits == 8)
		printf("%s=%o", s, v);
	else
		printf("%s=%x", s, v);
	bits++;
	if (bits) {
		putchar('<');
		while ((i = *bits++) != '\0') {
			if (v & (1 << (i-1))) {
				if (any)
					putchar(',');
				any = 1;
				for (; (c = *bits) > 32; bits++)
					putchar(c);
			} else
				for (; *bits > 32; bits++)
					;
		}
		putchar('>');
	}
}

/*
 * convert hardware address to hex string for logging errors.
  */
static const char *
sdl_addr_to_hex(const struct sockaddr_dl *sdl, char *orig_buf, int buflen)
{
	char *buf = orig_buf;
	int i;
	const u_char *lladdr;
	int maxbytes = buflen / 3;

	lladdr = (u_char *)(size_t)sdl->sdl_data + sdl->sdl_nlen;

	if (maxbytes > sdl->sdl_alen) {
		maxbytes = sdl->sdl_alen;
	}
	*buf = '\0';
	for (i = 0; i < maxbytes; i++) {
		snprintf(buf, 3, "%02x", lladdr[i]);
		buf += 2;
		*buf = (i == maxbytes - 1) ? '\0' : ':';
		buf++;
	}
	return (orig_buf);
}

