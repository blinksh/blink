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

/*	BSDI inet.c,v 2.3 1995/10/24 02:19:29 prb Exp	*/
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
 *
 * $FreeBSD: src/usr.bin/netstat/inet6.c,v 1.3.2.9 2001/08/10 09:07:09 ru Exp $
 */

#ifdef INET6
#include <sys/param.h>
#include <sys/socket.h>
#include <sys/socketvar.h>
#include <sys/ioctl.h>
#include <sys/sysctl.h>

#include <net/route.h>
#include <net/if.h>
#include <net/if_var.h>
#include <net/net_perf.h>
#include <netinet/in.h>
#include <netinet/ip6.h>
#include <netinet/icmp6.h>
#include <netinet/in_systm.h>
#include <netinet6/in6_pcb.h>
#include <netinet6/in6_var.h>
#include <netinet6/ip6_var.h>
#include <netinet6/raw_ip6.h>

#include <arpa/inet.h>
#include <netdb.h>

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "netstat.h"

#if defined(__APPLE__) && !defined(__unused)
#define __unused
#endif

char	*inet6name (struct in6_addr *);
void	inet6print (struct in6_addr *, int, char *, int);

static	char *ip6nh[] = {
	"hop by hop",
	"ICMP",
	"IGMP",
	"#3",
	"IP",
	"#5",
	"TCP",
	"#7",
	"#8",
	"#9",
	"#10",
	"#11",
	"#12",
	"#13",
	"#14",
	"#15",
	"#16",
	"UDP",
	"#18",
	"#19",	
	"#20",
	"#21",
	"IDP",
	"#23",
	"#24",
	"#25",
	"#26",
	"#27",
	"#28",
	"TP",	
	"#30",
	"#31",
	"#32",
	"#33",
	"#34",
	"#35",
	"#36",
	"#37",
	"#38",
	"#39",	
	"#40",
	"IP6",
	"#42",
	"routing",
	"fragment",
	"#45",
	"#46",
	"#47",
	"#48",
	"#49",	
	"ESP",
	"AH",
	"#52",
	"#53",
	"#54",
	"#55",
	"#56",
	"#57",
	"ICMP6",
	"no next header",	
	"destination option",
	"#61",
	"mobility",
	"#63",
	"#64",
	"#65",
	"#66",
	"#67",
	"#68",
	"#69",	
	"#70",
	"#71",
	"#72",
	"#73",
	"#74",
	"#75",
	"#76",
	"#77",
	"#78",
	"#79",	
	"ISOIP",
	"#81",
	"#82",
	"#83",
	"#84",
	"#85",
	"#86",
	"#87",
	"#88",
	"OSPF",	
	"#80",
	"#91",
	"#92",
	"#93",
	"#94",
	"#95",
	"#96",
	"Ethernet",
	"#98",
	"#99",	
	"#100",
	"#101",
	"#102",
	"PIM",
	"#104",
	"#105",
	"#106",
	"#107",
	"#108",
	"#109",	
	"#110",
	"#111",
	"#112",
	"#113",
	"#114",
	"#115",
	"#116",
	"#117",
	"#118",
	"#119",	
	"#120",
	"#121",
	"#122",
	"#123",
	"#124",
	"#125",
	"#126",
	"#127",
	"#128",
	"#129",	
	"#130",
	"#131",
	"#132",
	"#133",
	"#134",
	"#135",
	"#136",
	"#137",
	"#138",
	"#139",	
	"#140",
	"#141",
	"#142",
	"#143",
	"#144",
	"#145",
	"#146",
	"#147",
	"#148",
	"#149",	
	"#150",
	"#151",
	"#152",
	"#153",
	"#154",
	"#155",
	"#156",
	"#157",
	"#158",
	"#159",	
	"#160",
	"#161",
	"#162",
	"#163",
	"#164",
	"#165",
	"#166",
	"#167",
	"#168",
	"#169",	
	"#170",
	"#171",
	"#172",
	"#173",
	"#174",
	"#175",
	"#176",
	"#177",
	"#178",
	"#179",	
	"#180",
	"#181",
	"#182",
	"#183",
	"#184",
	"#185",
	"#186",
	"#187",
	"#188",
	"#189",	
	"#180",
	"#191",
	"#192",
	"#193",
	"#194",
	"#195",
	"#196",
	"#197",
	"#198",
	"#199",	
	"#200",
	"#201",
	"#202",
	"#203",
	"#204",
	"#205",
	"#206",
	"#207",
	"#208",
	"#209",	
	"#210",
	"#211",
	"#212",
	"#213",
	"#214",
	"#215",
	"#216",
	"#217",
	"#218",
	"#219",	
	"#220",
	"#221",
	"#222",
	"#223",
	"#224",
	"#225",
	"#226",
	"#227",
	"#228",
	"#229",	
	"#230",
	"#231",
	"#232",
	"#233",
	"#234",
	"#235",
	"#236",
	"#237",
	"#238",
	"#239",	
	"#240",
	"#241",
	"#242",
	"#243",
	"#244",
	"#245",
	"#246",
	"#247",
	"#248",
	"#249",	
	"#250",
	"#251",
	"#252",
	"#253",
	"#254",
	"#255",
};


static const char *srcrulenames[IP6S_SRCRULE_COUNT] = {
	"default",			// IP6S_SRCRULE_0
	"prefer same address",		// IP6S_SRCRULE_1
	"prefer appropriate scope",	// IP6S_SRCRULE_2
	"avoid deprecated addresses",	// IP6S_SRCRULE_3
	"prefer home addresses",	// IP6S_SRCRULE_4
	"prefer outgoing interface",	// IP6S_SRCRULE_5
	"prefer matching label",	// IP6S_SRCRULE_6
	"prefer temporary addresses",	// IP6S_SRCRULE_7
	"prefer addresses on alive interfaces",	// IP6S_SRCRULE_7x
	"use longest matching prefix",	// IP6S_SRCRULE_8
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL
};

/*
 * Dump IP6 statistics structure.
 */
void
ip6_stats(uint32_t off __unused, char *name, int af __unused)
{
	static struct ip6stat pip6stat;
	struct ip6stat ip6stat;
	int first, i;
	int mib[4];
	size_t len;
	static net_perf_t pout_net_perf, pin_net_perf;
	net_perf_t out_net_perf, in_net_perf;
	size_t out_net_perf_len = sizeof (out_net_perf);
	size_t in_net_perf_len = sizeof (in_net_perf);

	if (sysctlbyname("net.inet6.ip6.output_perf_data", &out_net_perf, &out_net_perf_len, 0, 0) < 0) {
		perror("sysctl: net.inet6.ip6.output_perf_data");
		return;
	}

	if (sysctlbyname("net.inet6.ip6.input_perf_data", &in_net_perf, &in_net_perf_len, 0, 0) < 0) {
		perror("sysctl: net.inet6.ip6.input_perf_data");
		return;
	}

	mib[0] = CTL_NET;
	mib[1] = PF_INET6;
	mib[2] = IPPROTO_IPV6;
	mib[3] = IPV6CTL_STATS;

	len = sizeof ip6stat;
	memset(&ip6stat, 0, len);
	if (sysctl(mib, 4, &ip6stat, &len, (void *)0, 0) < 0)
		return;
    if (interval && vflag > 0)
        print_time();
	printf("%s:\n", name);

#define	IP6DIFF(f) (ip6stat.f - pip6stat.f)
#define	p(f, m) if (IP6DIFF(f) || sflag <= 1) \
    printf(m, (unsigned long long)IP6DIFF(f), plural(IP6DIFF(f)))
#define	p1a(f, m) if (IP6DIFF(f) || sflag <= 1) \
    printf(m, (unsigned long long)IP6DIFF(f))

	p(ip6s_total, "\t%llu total packet%s received\n");
	p1a(ip6s_toosmall, "\t\t%llu with size smaller than minimum\n");
	p1a(ip6s_tooshort, "\t\t%llu with data size < data length\n");
	p1a(ip6s_adj, "\t\t%llu with data size > data length\n");
	p(ip6s_adj_hwcsum_clr,
	    "\t\t\t%llu packet%s forced to software checksum\n");
	p1a(ip6s_badoptions, "\t\t%llu with bad options\n");
	p1a(ip6s_badvers, "\t\t%llu with incorrect version number\n");
	p(ip6s_fragments, "\t\t%llu fragment%s received\n");
	p1a(ip6s_fragdropped,
	    "\t\t\t%llu dropped (dup or out of space)\n");
	p1a(ip6s_fragtimeout, "\t\t\t%llu dropped after timeout\n");
	p1a(ip6s_fragoverflow, "\t\t\t%llu exceeded limit\n");
	p1a(ip6s_reassembled, "\t\t\t%llu reassembled ok\n");
	p1a(ip6s_atmfrag_rcvd, "\t\t\t%llu atomic fragments received\n");
	p(ip6s_delivered, "\t\t%llu packet%s for this host\n");
	p(ip6s_forward, "\t\t%llu packet%s forwarded\n");
	p(ip6s_cantforward, "\t\t%llu packet%s not forwardable\n");
	p(ip6s_redirectsent, "\t\t%llu redirect%s sent\n");
	p(ip6s_notmember, "\t\t%llu multicast packet%s which we don't join\n");
	p(ip6s_exthdrtoolong,
	    "\t\t%llu packet%s whose headers are not continuous\n");
	p(ip6s_nogif, "\t\t%llu tunneling packet%s that can't find gif\n");
	p(ip6s_toomanyhdr,
	    "\t\t%llu packet%s discarded due to too may headers\n");
	p1a(ip6s_forward_cachehit, "\t\t%llu forward cache hit\n");
	p1a(ip6s_forward_cachemiss, "\t\t%llu forward cache miss\n");
	p(ip6s_pktdropcntrl,
	    "\t\t%llu packet%s dropped due to no bufs for control data\n");

#define INPERFDIFF(f) (in_net_perf.f - pin_net_perf.f)
	if (INPERFDIFF(np_total_pkts) > 0 && in_net_perf.np_total_usecs > 0) {
		printf("\tInput Performance Stats:\n");
		printf("\t\t%llu total packets measured\n", INPERFDIFF(np_total_pkts));
		printf("\t\t%llu total usec elapsed\n", INPERFDIFF(np_total_usecs));
		printf("\t\t%f usec per packet\n",
		    (double)in_net_perf.np_total_usecs/(double)in_net_perf.np_total_pkts);
		printf("\t\tPerformance Histogram:\n");
		printf("\t\t\t x <= %u: %llu\n", in_net_perf.np_hist_bars[0],
		    INPERFDIFF(np_hist1));
		printf("\t\t\t %u < x <= %u: %llu\n",
		    in_net_perf.np_hist_bars[0], in_net_perf.np_hist_bars[1],
		    INPERFDIFF(np_hist2));
		printf("\t\t\t %u < x <= %u: %llu\n",
		    in_net_perf.np_hist_bars[1], in_net_perf.np_hist_bars[2],
		    INPERFDIFF(np_hist3));
		printf("\t\t\t %u < x <= %u: %llu\n",
		    in_net_perf.np_hist_bars[2], in_net_perf.np_hist_bars[3],
		    INPERFDIFF(np_hist4));
		printf("\t\t\t %u < x: %llu\n",
		    in_net_perf.np_hist_bars[3], INPERFDIFF(np_hist5));
	}
#undef INPERFDIFF

	p(ip6s_localout, "\t%llu packet%s sent from this host\n");
	p(ip6s_rawout, "\t\t%llu packet%s sent with fabricated ip header\n");
	p(ip6s_odropped,
	    "\t\t%llu output packet%s dropped due to no bufs, etc.\n");
	p(ip6s_noroute, "\t\t%llu output packet%s discarded due to no route\n");
	p(ip6s_fragmented, "\t\t%llu output datagram%s fragmented\n");
	p(ip6s_ofragments, "\t\t%llu fragment%s created\n");
	p(ip6s_cantfrag, "\t\t%llu datagram%s that can't be fragmented\n");
	p(ip6s_badscope, "\t\t%llu packet%s that violated scope rules\n");
	p(ip6s_necp_policy_drop, "\t\t%llu packet%s dropped due to NECP policy\n");

#define OUTPERFDIFF(f) (out_net_perf.f - pout_net_perf.f)
	if (OUTPERFDIFF(np_total_pkts) > 0 && out_net_perf.np_total_usecs > 0) {
		printf("\tOutput Performance Stats:\n");
		printf("\t\t%llu total packets measured\n", OUTPERFDIFF(np_total_pkts));
		printf("\t\t%llu total usec elapsed\n", OUTPERFDIFF(np_total_usecs));
		printf("\t\t%f usec per packet\n",
		    (double)out_net_perf.np_total_usecs/(double)out_net_perf.np_total_pkts);
		printf("\t\tHistogram:\n");
		printf("\t\t\t x <= %u: %llu\n", out_net_perf.np_hist_bars[0],
		    OUTPERFDIFF(np_hist1));
		printf("\t\t\t %u < x <= %u: %llu\n",
		    out_net_perf.np_hist_bars[0], out_net_perf.np_hist_bars[1],
		    OUTPERFDIFF(np_hist2));
		printf("\t\t\t %u < x <= %u: %llu\n",
		    out_net_perf.np_hist_bars[1], out_net_perf.np_hist_bars[2],
		    OUTPERFDIFF(np_hist3));
		printf("\t\t\t %u < x <= %u: %llu\n",
		    out_net_perf.np_hist_bars[2], out_net_perf.np_hist_bars[3],
		    OUTPERFDIFF(np_hist4));
		printf("\t\t\t %u < x: %llu\n",
		    out_net_perf.np_hist_bars[3], OUTPERFDIFF(np_hist5));
	}
#undef OUTPERFDIFF

	for (first = 1, i = 0; i < 256; i++)
		if (IP6DIFF(ip6s_nxthist[i]) != 0) {
			if (first) {
				printf("\tInput histogram:\n");
				first = 0;
			}
			printf("\t\t%s: %llu\n", ip6nh[i],
			    (unsigned long long)IP6DIFF(ip6s_nxthist[i]));
		}
	printf("\tMbuf statistics:\n");
	printf("\t\t%llu one mbuf\n", (unsigned long long)IP6DIFF(ip6s_m1));
	for (first = 1, i = 0; i < 32; i++) {
		char ifbuf[IFNAMSIZ];
		if (IP6DIFF(ip6s_m2m[i]) != 0) {
			if (first) {
				printf("\t\ttwo or more mbuf:\n");
				first = 0;
			}
			printf("\t\t\t%s= %llu\n",
			    if_indextoname(i, ifbuf),
			    (unsigned long long)IP6DIFF(ip6s_m2m[i]));
		}
	}
	printf("\t\t%llu one ext mbuf\n",
	    (unsigned long long)IP6DIFF(ip6s_mext1));
	printf("\t\t%llu two or more ext mbuf\n",
	    (unsigned long long)IP6DIFF(ip6s_mext2m));

	/* for debugging source address selection */
#define PRINT_SCOPESTAT(s,i) do {\
		switch(i) { /* XXX hardcoding in each case */\
		case 1:\
			p(s, "\t\t\t%llu node-local%s\n");\
			break;\
		case 2:\
			p(s,"\t\t\t%llu link-local%s\n");\
			break;\
		case 5:\
			p(s,"\t\t\t%llu site-local%s\n");\
			break;\
		case 14:\
			p(s,"\t\t\t%llu global%s\n");\
			break;\
		default:\
			printf("\t\t\t%llu addresses scope=%x\n",\
			    (unsigned long long)IP6DIFF(s), i);\
		}\
	} while (0);

	p(ip6s_sources_none,
	  "\t\t%llu failure%s of source address selection\n");
	for (first = 1, i = 0; i < SCOPE6_ID_MAX; i++) {
		if (IP6DIFF(ip6s_sources_sameif[i]) || 1) {
			if (first) {
				printf("\t\tsource addresses on an outgoing I/F\n");
				first = 0;
			}
			PRINT_SCOPESTAT(ip6s_sources_sameif[i], i);
		}
	}
	for (first = 1, i = 0; i < SCOPE6_ID_MAX; i++) {
		if (IP6DIFF(ip6s_sources_otherif[i]) || 1) {
			if (first) {
				printf("\t\tsource addresses on a non-outgoing I/F\n");
				first = 0;
			}
			PRINT_SCOPESTAT(ip6s_sources_otherif[i], i);
		}
	}
	for (first = 1, i = 0; i < SCOPE6_ID_MAX; i++) {
		if (IP6DIFF(ip6s_sources_samescope[i]) || 1) {
			if (first) {
				printf("\t\tsource addresses of same scope\n");
				first = 0;
			}
			PRINT_SCOPESTAT(ip6s_sources_samescope[i], i);
		}
	}
	for (first = 1, i = 0; i < SCOPE6_ID_MAX; i++) {
		if (IP6DIFF(ip6s_sources_otherscope[i]) || 1) {
			if (first) {
				printf("\t\tsource addresses of a different scope\n");
				first = 0;
			}
			PRINT_SCOPESTAT(ip6s_sources_otherscope[i], i);
		}
	}
	for (first = 1, i = 0; i < SCOPE6_ID_MAX; i++) {
		if (IP6DIFF(ip6s_sources_deprecated[i]) || 1) {
			if (first) {
				printf("\t\tdeprecated source addresses\n");
				first = 0;
			}
			PRINT_SCOPESTAT(ip6s_sources_deprecated[i], i);
		}
	}
#define PRINT_SRCRULESTAT(s,i) do {\
	if (srcrulenames[i] != NULL) \
		printf("\t\t\t%llu rule%s %s\n", \
			(unsigned long long)IP6DIFF(s), \
			plural(IP6DIFF(s)), \
			srcrulenames[i]); \
} while (0);

	for (first = 1, i = 0; i < IP6S_SRCRULE_COUNT; i++) {
		if (IP6DIFF(ip6s_sources_rule[i]) || 1) {
			if (first) {
				printf("\t\tsource address selection\n");
				first = 0;
			}
			PRINT_SRCRULESTAT(ip6s_sources_rule[i], i);
		}
	}
	
	p(ip6s_dad_collide, "\t\t%llu duplicate address detection collision%s\n");
	
	p(ip6s_dad_loopcount, "\t\t%llu duplicate address detection NS loop%s\n");

	p(ip6s_sources_skip_expensive_secondary_if, "\t\t%llu time%s ignored source on secondary expensive I/F\n");

	if (interval > 0) {
		bcopy(&ip6stat, &pip6stat, len);
		bcopy(&in_net_perf, &pin_net_perf, in_net_perf_len);
		bcopy(&out_net_perf, &pout_net_perf, out_net_perf_len);
	}
#undef IP6DIFF
#undef p
#undef p1a
}

/*
 * Dump IPv6 per-interface statistics based on RFC 2465.
 */
void
ip6_ifstats(char *ifname)
{
	struct in6_ifreq ifr;
	int s;
#define	p(f, m) if (ifr.ifr_ifru.ifru_stat.f || sflag <= 1) \
    printf(m, (unsigned long long)ifr.ifr_ifru.ifru_stat.f, plural(ifr.ifr_ifru.ifru_stat.f))
#define	p_5(f, m) if (ifr.ifr_ifru.ifru_stat.f || sflag <= 1) \
    printf(m, (unsigned long long)ip6stat.f)

	if ((s = socket(AF_INET6, SOCK_DGRAM, 0)) < 0) {
		perror("Warning: socket(AF_INET6)");
		return;
	}

    if (interval && vflag > 0)
        print_time();
	strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
	printf("ip6 on %s:\n", ifr.ifr_name);

	if (ioctl(s, SIOCGIFSTAT_IN6, (char *)&ifr) < 0) {
		perror("Warning: ioctl(SIOCGIFSTAT_IN6)");
		goto end;
	}

	p(ifs6_in_receive, "\t%llu total input datagram%s\n");
	p(ifs6_in_hdrerr, "\t%llu datagram%s with invalid header received\n");
	p(ifs6_in_toobig, "\t%llu datagram%s exceeded MTU received\n");
	p(ifs6_in_noroute, "\t%llu datagram%s with no route received\n");
	p(ifs6_in_addrerr, "\t%llu datagram%s with invalid dst received\n");
	p(ifs6_in_protounknown, "\t%llu datagram%s with unknown proto received\n");
	p(ifs6_in_truncated, "\t%llu truncated datagram%s received\n");
	p(ifs6_in_discard, "\t%llu input datagram%s discarded\n");
	p(ifs6_in_deliver,
	  "\t%llu datagram%s delivered to an upper layer protocol\n");
	p(ifs6_out_forward, "\t%llu datagram%s forwarded to this interface\n");
	p(ifs6_out_request,
	  "\t%llu datagram%s sent from an upper layer protocol\n");
	p(ifs6_out_discard, "\t%llu total discarded output datagram%s\n");
	p(ifs6_out_fragok, "\t%llu output datagram%s fragmented\n");
	p(ifs6_out_fragfail, "\t%llu output datagram%s failed on fragment\n");
	p(ifs6_out_fragcreat, "\t%llu output datagram%s succeeded on fragment\n");
	p(ifs6_reass_reqd, "\t%llu incoming datagram%s fragmented\n");
	p(ifs6_reass_ok, "\t%llu datagram%s reassembled\n");
	p(ifs6_atmfrag_rcvd, "\t%llu atomic fragments%s received\n");
	p(ifs6_reass_fail, "\t%llu datagram%s failed on reassembling\n");
	p(ifs6_in_mcast, "\t%llu multicast datagram%s received\n");
	p(ifs6_out_mcast, "\t%llu multicast datagram%s sent\n");

	p(ifs6_cantfoward_icmp6, "\t%llu ICMPv6 packet%s received for unreachable destination\n");
	p(ifs6_addr_expiry_cnt, "\t%llu address expiry event%s reported\n");
	p(ifs6_pfx_expiry_cnt, "\t%llu prefix expiry event%s reported\n");
	p(ifs6_defrtr_expiry_cnt, "\t%llu default router expiry event%s reported\n");
  end:
	close(s);

#undef p
#undef p_5
}

static	char *icmp6names[] = {
	"#0",
	"unreach",
	"packet too big",
	"time exceed",
	"parameter problem",
	"#5",
	"#6",
	"#7",
	"#8",
	"#9",
	"#10",
	"#11",
	"#12",
	"#13",
	"#14",
	"#15",
	"#16",
	"#17",
	"#18",
	"#19",	
	"#20",
	"#21",
	"#22",
	"#23",
	"#24",
	"#25",
	"#26",
	"#27",
	"#28",
	"#29",	
	"#30",
	"#31",
	"#32",
	"#33",
	"#34",
	"#35",
	"#36",
	"#37",
	"#38",
	"#39",	
	"#40",
	"#41",
	"#42",
	"#43",
	"#44",
	"#45",
	"#46",
	"#47",
	"#48",
	"#49",	
	"#50",
	"#51",
	"#52",
	"#53",
	"#54",
	"#55",
	"#56",
	"#57",
	"#58",
	"#59",	
	"#60",
	"#61",
	"#62",
	"#63",
	"#64",
	"#65",
	"#66",
	"#67",
	"#68",
	"#69",	
	"#70",
	"#71",
	"#72",
	"#73",
	"#74",
	"#75",
	"#76",
	"#77",
	"#78",
	"#79",	
	"#80",
	"#81",
	"#82",
	"#83",
	"#84",
	"#85",
	"#86",
	"#87",
	"#88",
	"#89",	
	"#80",
	"#91",
	"#92",
	"#93",
	"#94",
	"#95",
	"#96",
	"#97",
	"#98",
	"#99",	
	"#100",
	"#101",
	"#102",
	"#103",
	"#104",
	"#105",
	"#106",
	"#107",
	"#108",
	"#109",	
	"#110",
	"#111",
	"#112",
	"#113",
	"#114",
	"#115",
	"#116",
	"#117",
	"#118",
	"#119",	
	"#120",
	"#121",
	"#122",
	"#123",
	"#124",
	"#125",
	"#126",
	"#127",
	"echo",
	"echo reply",	
	"multicast listener query",
	"MLDv1 listener report",
	"MLDv1 listener done",
	"router solicitation",
	"router advertisement",
	"neighbor solicitation",
	"neighbor advertisement",
	"redirect",
	"router renumbering",
	"node information request",
	"node information reply",
	"inverse neighbor solicitation",
	"inverse neighbor advertisement",
	"MLDv2 listener report",
	"#144",
	"#145",
	"#146",
	"#147",
	"#148",
	"#149",	
	"#150",
	"#151",
	"#152",
	"#153",
	"#154",
	"#155",
	"#156",
	"#157",
	"#158",
	"#159",	
	"#160",
	"#161",
	"#162",
	"#163",
	"#164",
	"#165",
	"#166",
	"#167",
	"#168",
	"#169",	
	"#170",
	"#171",
	"#172",
	"#173",
	"#174",
	"#175",
	"#176",
	"#177",
	"#178",
	"#179",	
	"#180",
	"#181",
	"#182",
	"#183",
	"#184",
	"#185",
	"#186",
	"#187",
	"#188",
	"#189",	
	"#180",
	"#191",
	"#192",
	"#193",
	"#194",
	"#195",
	"#196",
	"#197",
	"#198",
	"#199",	
	"#200",
	"#201",
	"#202",
	"#203",
	"#204",
	"#205",
	"#206",
	"#207",
	"#208",
	"#209",	
	"#210",
	"#211",
	"#212",
	"#213",
	"#214",
	"#215",
	"#216",
	"#217",
	"#218",
	"#219",	
	"#220",
	"#221",
	"#222",
	"#223",
	"#224",
	"#225",
	"#226",
	"#227",
	"#228",
	"#229",	
	"#230",
	"#231",
	"#232",
	"#233",
	"#234",
	"#235",
	"#236",
	"#237",
	"#238",
	"#239",	
	"#240",
	"#241",
	"#242",
	"#243",
	"#244",
	"#245",
	"#246",
	"#247",
	"#248",
	"#249",	
	"#250",
	"#251",
	"#252",
	"#253",
	"#254",
	"#255",
};

/*
 * Dump ICMP6 statistics.
 */
void
icmp6_stats(uint32_t off __unused, char *name, int af __unused)
{
	static struct icmp6stat picmp6stat;
	struct icmp6stat icmp6stat;
	register int i, first;
	int mib[4];
	size_t len;

	mib[0] = CTL_NET;
	mib[1] = PF_INET6;
	mib[2] = IPPROTO_ICMPV6;
	mib[3] = ICMPV6CTL_STATS;

	len = sizeof icmp6stat;
	memset(&icmp6stat, 0, len);
	if (sysctl(mib, 4, &icmp6stat, &len, (void *)0, 0) < 0)
		return;
    if (interval && vflag > 0)
        print_time();
	printf("%s:\n", name);

#define	ICMP6DIFF(f) (icmp6stat.f - picmp6stat.f)
#define	p(f, m) if (ICMP6DIFF(f) || sflag <= 1) \
    printf(m, (unsigned long long)ICMP6DIFF(f), plural(ICMP6DIFF(f)))
#define p_5(f, m) printf(m, (unsigned long long)ICMP6DIFF(f))

	p(icp6s_error, "\t%llu call%s to icmp_error\n");
	p(icp6s_canterror,
	    "\t%llu error%s not generated because old message was icmp error or so\n");
	p(icp6s_toofreq,
	  "\t%llu error%s not generated because rate limitation\n");
#define NELEM (sizeof(icmp6stat.icp6s_outhist)/sizeof(icmp6stat.icp6s_outhist[0]))
	for (first = 1, i = 0; i < NELEM; i++)
		if (ICMP6DIFF(icp6s_outhist[i]) != 0) {
			if (first) {
				printf("\tOutput histogram:\n");
				first = 0;
			}
			printf("\t\t%s: %llu\n", icmp6names[i],
			    (unsigned long long)ICMP6DIFF(icp6s_outhist[i]));
		}
#undef NELEM
	p(icp6s_badcode, "\t%llu message%s with bad code fields\n");
	p(icp6s_tooshort, "\t%llu message%s < minimum length\n");
	p(icp6s_checksum, "\t%llu bad checksum%s\n");
	p(icp6s_badlen, "\t%llu message%s with bad length\n");
#define NELEM (sizeof(icmp6stat.icp6s_inhist)/sizeof(icmp6stat.icp6s_inhist[0]))
	for (first = 1, i = 0; i < NELEM; i++)
		if (ICMP6DIFF(icp6s_inhist[i]) != 0) {
			if (first) {
				printf("\tInput histogram:\n");
				first = 0;
			}
			printf("\t\t%s: %llu\n", icmp6names[i],
			    (unsigned long long)ICMP6DIFF(icp6s_inhist[i]));
		}
#undef NELEM
	printf("\tHistogram of error messages to be generated:\n");
	p_5(icp6s_odst_unreach_noroute, "\t\t%llu no route\n");
	p_5(icp6s_odst_unreach_admin, "\t\t%llu administratively prohibited\n");
	p_5(icp6s_odst_unreach_beyondscope, "\t\t%llu beyond scope\n");
	p_5(icp6s_odst_unreach_addr, "\t\t%llu address unreachable\n");
	p_5(icp6s_odst_unreach_noport, "\t\t%llu port unreachable\n");
	p_5(icp6s_opacket_too_big, "\t\t%llu packet too big\n");
	p_5(icp6s_otime_exceed_transit, "\t\t%llu time exceed transit\n");
	p_5(icp6s_otime_exceed_reassembly, "\t\t%llu time exceed reassembly\n");
	p_5(icp6s_oparamprob_header, "\t\t%llu erroneous header field\n");
	p_5(icp6s_oparamprob_nextheader, "\t\t%llu unrecognized next header\n");
	p_5(icp6s_oparamprob_option, "\t\t%llu unrecognized option\n");
	p_5(icp6s_oredirect, "\t\t%llu redirect\n");
	p_5(icp6s_ounknown, "\t\t%llu unknown\n");

	p(icp6s_reflect, "\t%llu message response%s generated\n");
	p(icp6s_nd_toomanyopt, "\t%llu message%s with too many ND options\n");
	p(icp6s_nd_badopt, "\t%qu message%s with bad ND options\n");
	p(icp6s_badns, "\t%qu bad neighbor solicitation message%s\n");
	p(icp6s_badna, "\t%qu bad neighbor advertisement message%s\n");
	p(icp6s_badrs, "\t%qu bad router solicitation message%s\n");
	p(icp6s_badra, "\t%qu bad router advertisement message%s\n");
	p(icp6s_badredirect, "\t%qu bad redirect message%s\n");
	p(icp6s_pmtuchg, "\t%llu path MTU change%s\n");
	p(icp6s_rfc6980_drop, "\t%qu dropped fragmented NDP message%s\n");

	if (interval > 0)
		bcopy(&icmp6stat, &picmp6stat, len);

#undef ICMP6DIFF
#undef p
#undef p_5
}

/*
 * Dump ICMPv6 per-interface statistics based on RFC 2466.
 */
void
icmp6_ifstats(char *ifname)
{
	struct in6_ifreq ifr;
	int s;
#define	p(f, m) if (ifr.ifr_ifru.ifru_icmp6stat.f || sflag <= 1) \
    printf(m, (unsigned long long)ifr.ifr_ifru.ifru_icmp6stat.f, plural(ifr.ifr_ifru.ifru_icmp6stat.f))

	if ((s = socket(AF_INET6, SOCK_DGRAM, 0)) < 0) {
		perror("Warning: socket(AF_INET6)");
		return;
	}

    if (interval && vflag > 0)
        print_time();
	strlcpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name));
	printf("icmp6 on %s:\n", ifr.ifr_name);

	if (ioctl(s, SIOCGIFSTAT_ICMP6, (char *)&ifr) < 0) {
		perror("Warning: ioctl(SIOCGIFSTAT_ICMP6)");
		goto end;
	}

	p(ifs6_in_msg, "\t%llu total input message%s\n");
	p(ifs6_in_error, "\t%llu total input error message%s\n"); 
	p(ifs6_in_dstunreach, "\t%llu input destination unreachable error%s\n");
	p(ifs6_in_adminprohib, "\t%llu input administratively prohibited error%s\n");
	p(ifs6_in_timeexceed, "\t%llu input time exceeded error%s\n");
	p(ifs6_in_paramprob, "\t%llu input parameter problem error%s\n");
	p(ifs6_in_pkttoobig, "\t%llu input packet too big error%s\n");
	p(ifs6_in_echo, "\t%llu input echo request%s\n");
	p(ifs6_in_echoreply, "\t%llu input echo reply%s\n");
	p(ifs6_in_routersolicit, "\t%llu input router solicitation%s\n");
	p(ifs6_in_routeradvert, "\t%llu input router advertisement%s\n");
	p(ifs6_in_neighborsolicit, "\t%llu input neighbor solicitation%s\n");
	p(ifs6_in_neighboradvert, "\t%llu input neighbor advertisement%s\n");
	p(ifs6_in_redirect, "\t%llu input redirect%s\n");
	p(ifs6_in_mldquery, "\t%llu input MLD query%s\n");
	p(ifs6_in_mldreport, "\t%llu input MLD report%s\n");
	p(ifs6_in_mlddone, "\t%llu input MLD done%s\n");

	p(ifs6_out_msg, "\t%llu total output message%s\n");
	p(ifs6_out_error, "\t%llu total output error message%s\n");
	p(ifs6_out_dstunreach, "\t%llu output destination unreachable error%s\n");
	p(ifs6_out_adminprohib, "\t%llu output administratively prohibited error%s\n");
	p(ifs6_out_timeexceed, "\t%llu output time exceeded error%s\n");
	p(ifs6_out_paramprob, "\t%llu output parameter problem error%s\n");
	p(ifs6_out_pkttoobig, "\t%llu output packet too big error%s\n");
	p(ifs6_out_echo, "\t%llu output echo request%s\n");
	p(ifs6_out_echoreply, "\t%llu output echo reply%s\n");
	p(ifs6_out_routersolicit, "\t%llu output router solicitation%s\n");
	p(ifs6_out_routeradvert, "\t%llu output router advertisement%s\n");
	p(ifs6_out_neighborsolicit, "\t%llu output neighbor solicitation%s\n");
	p(ifs6_out_neighboradvert, "\t%llu output neighbor advertisement%s\n");
	p(ifs6_out_redirect, "\t%llu output redirect%s\n");
	p(ifs6_out_mldquery, "\t%llu output MLD query%s\n");
	p(ifs6_out_mldreport, "\t%llu output MLD report%s\n");
	p(ifs6_out_mlddone, "\t%llu output MLD done%s\n");

  end:
	close(s);
#undef p
}

/*
 * Dump raw ip6 statistics structure.
 */
void
rip6_stats(uint32_t off __unused, char *name, int af __unused)
{
	static struct rip6stat prip6stat;
	struct rip6stat rip6stat;
	u_quad_t delivered;
	int mib[4];
	size_t l;

	mib[0] = CTL_NET;
	mib[1] = PF_INET6;
	mib[2] = IPPROTO_IPV6;
	mib[3] = IPV6CTL_RIP6STATS;
	l = sizeof(rip6stat);
	if (sysctl(mib, 4, &rip6stat, &l, NULL, 0) < 0) {
		perror("Warning: sysctl(net.inet6.ip6.rip6stats)");
		return;
	}

    if (interval && vflag > 0)
        print_time();
	printf("%s:\n", name);

#define	RIP6DIFF(f) (rip6stat.f - prip6stat.f)
#define	p(f, m) if (RIP6DIFF(f) || sflag <= 1) \
    printf(m, (unsigned long long)RIP6DIFF(f), plural(RIP6DIFF(f)))
	p(rip6s_ipackets, "\t%llu message%s received\n");
	p(rip6s_isum, "\t%llu checksum calculation%s on inbound\n");
	p(rip6s_badsum, "\t%llu message%s with bad checksum\n");
	p(rip6s_nosock, "\t%llu message%s dropped due to no socket\n");
	p(rip6s_nosockmcast,
	    "\t%llu multicast message%s dropped due to no socket\n");
	p(rip6s_fullsock,
	    "\t%llu message%s dropped due to full socket buffers\n");
	delivered = RIP6DIFF(rip6s_ipackets) -
		    RIP6DIFF(rip6s_badsum) -
		    RIP6DIFF(rip6s_nosock) -
		    RIP6DIFF(rip6s_nosockmcast) -
		    RIP6DIFF(rip6s_fullsock);
	if (delivered || sflag <= 1)
		printf("\t%llu delivered\n", (unsigned long long)delivered);
	p(rip6s_opackets, "\t%llu datagram%s output\n");

	if (interval > 0)
		bcopy(&rip6stat, &prip6stat, l);

#undef RIP6DIFF
#undef p
}

/*
 * Pretty print an Internet address (net address + port).
 * If the nflag was specified, use numbers instead of names.
 */
#ifdef SRVCACHE
extern struct servent * _serv_cache_getservbyport(int port, char *proto);

#define GETSERVBYPORT6(port, proto, ret)\
{\
	if (strcmp((proto), "tcp6") == 0)\
		(ret) = _serv_cache_getservbyport((int)(port), "tcp");\
	else if (strcmp((proto), "udp6") == 0)\
		(ret) = _serv_cache_getservbyport((int)(port), "udp");\
	else\
		(ret) = _serv_cache_getservbyport((int)(port), (proto));\
};
#else
#define GETSERVBYPORT6(port, proto, ret)\
{\
	if (strcmp((proto), "tcp6") == 0)\
		(ret) = getservbyport((int)(port), "tcp");\
	else if (strcmp((proto), "udp6") == 0)\
		(ret) = getservbyport((int)(port), "udp");\
	else\
		(ret) = getservbyport((int)(port), (proto));\
};
#endif
void
inet6print(struct in6_addr *in6, int port, char *proto, int numeric)
{
	struct servent *sp = 0;
	char line[80], *cp;
	int width;

	snprintf(line, sizeof(line), "%.*s.", lflag ? 39 :
		(Aflag && !numeric) ? 12 : 16, inet6name(in6));
	cp = index(line, '\0');
	if (!numeric && port)
		GETSERVBYPORT6(port, proto, sp);
	if (sp || port == 0)
		snprintf(cp, sizeof(line) - (cp - line), "%.15s", sp ? sp->s_name : "*");
	else
		snprintf(cp, sizeof(line) - (cp - line), "%d", ntohs((u_short)port));
	width = lflag ? 45 : Aflag ? 18 : 22;
	printf("%-*.*s ", width, width, line);
}

/*
 * Construct an Internet address representation.
 * If the nflag has been supplied, give
 * numeric value, otherwise try for symbolic name.
 */

char *
inet6name(struct in6_addr *in6p)
{
	register char *cp;
	static char line[50];
	struct hostent *hp;
	static char domain[MAXHOSTNAMELEN];
	static int first = 1;
	char hbuf[NI_MAXHOST];
	struct sockaddr_in6 sin6;
	const int niflag = NI_NUMERICHOST;

	if (first && !nflag) {
		first = 0;
		if (gethostname(domain, MAXHOSTNAMELEN) == 0 &&
		    (cp = index(domain, '.')))
			(void) memmove(domain, cp + 1, strlen(cp + 1) + 1);
		else
			domain[0] = 0;
	}
	cp = 0;
	if (!nflag && !IN6_IS_ADDR_UNSPECIFIED(in6p)) {
		hp = gethostbyaddr((char *)in6p, sizeof(*in6p), AF_INET6);
		if (hp) {
			if ((cp = index(hp->h_name, '.')) &&
			    !strcmp(cp + 1, domain))
				*cp = 0;
			cp = hp->h_name;
		}
	}
	if (IN6_IS_ADDR_UNSPECIFIED(in6p))
		strlcpy(line, "*", sizeof(line));
	else if (cp)
		strlcpy(line, cp, sizeof(line));
	else {
		memset(&sin6, 0, sizeof(sin6));
		sin6.sin6_len = sizeof(sin6);
		sin6.sin6_family = AF_INET6;
		sin6.sin6_addr = *in6p;

		if (IN6_IS_ADDR_LINKLOCAL(in6p) ||
		    IN6_IS_ADDR_MC_NODELOCAL(in6p) ||
		    IN6_IS_ADDR_MC_LINKLOCAL(in6p)) {
			sin6.sin6_scope_id =
			    ntohs(*(u_int16_t *)&in6p->s6_addr[2]);
			sin6.sin6_addr.s6_addr[2] = 0;
			sin6.sin6_addr.s6_addr[3] = 0;
		}

		if (getnameinfo((struct sockaddr *)&sin6, sin6.sin6_len,
				hbuf, sizeof(hbuf), NULL, 0, niflag) != 0)
			strlcpy(hbuf, "?", sizeof(hbuf));
		strlcpy(line, hbuf, sizeof(line));
	}
	return (line);
}
#endif /*INET6*/
