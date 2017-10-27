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
 * Copyright (c) 1992, 1993
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
 *
 *	@(#)netstat.h	8.2 (Berkeley) 1/4/94
 */

#include <sys/cdefs.h>
#include <sys/types.h>
#include <stdint.h>

#include <TargetConditionals.h>

extern int	Aflag;	/* show addresses of protocol control block */
extern int	aflag;	/* show all sockets (including servers) */
extern int	bflag;	/* show i/f total bytes in/out */
extern int	cflag;	/* show specific classq */
extern int	dflag;	/* show i/f dropped packets */
extern int	Fflag;	/* show i/f forwarded packets */
#if defined(__APPLE__) && !TARGET_OS_EMBEDDED
extern int	gflag;	/* show group (multicast) routing or stats */
#endif
extern int	iflag;	/* show interfaces */
extern int	lflag;	/* show routing table with use and ref */
extern int	Lflag;	/* show size of listen queues */
extern int	mflag;	/* show memory stats */
extern int	nflag;	/* show addresses numerically */
extern int	Rflag;	/* show reachability information */
extern int	rflag;	/* show routing tables (or routing stats) */
extern int	sflag;	/* show protocol statistics */
extern int	prioflag; /* show packet priority  statistics */
extern int	tflag;	/* show i/f watchdog timers */
extern int	vflag;	/* more verbose */
extern int	Wflag;	/* wide display */
extern int	qflag;	/* Display ifclassq stats */
extern int	Qflag;	/* Display opportunistic polling stats */
extern int	xflag;	/* show extended link-layer reachability information */

extern int	cq;	/* send classq index (-1 for all) */
extern int	interval; /* repeat interval for i/f stats */

extern char	*interface; /* desired i/f for stats, or NULL for all i/fs */
extern int	unit;	/* unit number for above */

extern int	af;	/* address family */

extern char	*plural(int);
extern char	*plurales(int);
extern char	*pluralies(int);

extern void	protopr(uint32_t, char *, int);
extern void	mptcppr(uint32_t, char *, int);
extern void	tcp_stats(uint32_t, char *, int);
extern void	mptcp_stats(uint32_t, char *, int);
extern void	udp_stats(uint32_t, char *, int);
extern void	ip_stats(uint32_t, char *, int);
extern void	icmp_stats(uint32_t, char *, int);
extern void	igmp_stats(uint32_t, char *, int);
extern void	arp_stats(uint32_t, char *, int);
#ifdef IPSEC
extern void	ipsec_stats(uint32_t, char *, int);
#endif

#ifdef INET6
extern void	ip6_stats(uint32_t, char *, int);
extern void	ip6_ifstats(char *);
extern void	icmp6_stats(uint32_t, char *, int);
extern void	icmp6_ifstats(char *);
extern void	rip6_stats(uint32_t, char *, int);

/* forward references */
struct sockaddr_in6;
struct in6_addr;
struct sockaddr;

extern char	*routename6(struct sockaddr_in6 *);
extern char	*netname6(struct sockaddr_in6 *, struct sockaddr *);
#endif /*INET6*/

#ifdef IPSEC
extern void	pfkey_stats(uint32_t, char *, int);
#endif

extern void	systmpr(uint32_t, char *, int);
extern void	kctl_stats(uint32_t, char *, int);
extern void	kevt_stats(uint32_t, char *, int);

extern void	mbpr(void);

extern void	intpr(void (*)(char *));
extern void	intpr_ri(void (*)(char *));
extern void	intervalpr(void (*)(uint32_t, char *, int), uint32_t,
		    char *, int);

extern void	pr_rthdr(int);
extern void	pr_family(int);
extern void	rt_stats(void);
extern void	upHex(char *);
extern char	*routename(uint32_t);
extern char	*netname(uint32_t, uint32_t);
extern void	routepr(void);

extern void	unixpr(void);
extern void	aqstatpr(void);
extern void	rxpollstatpr(void);

extern void	ifmalist_dump(void);

extern int print_time(void);
extern void	print_link_status(const char *);

extern void	print_extbkidle_stats(uint32_t, char *, int);
extern void	print_nstat_stats(uint32_t, char *, int);
extern void	print_net_api_stats(uint32_t, char *, int);

