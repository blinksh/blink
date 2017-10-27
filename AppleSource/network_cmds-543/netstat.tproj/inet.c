/*
 * Copyright (c) 2008-2016 Apple Inc. All rights reserved.
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
 ** @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
/*
 * Copyright (c) 1983, 1988, 1993, 1995
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

#include <sys/param.h>
#include <sys/queue.h>
#include <sys/socket.h>
#include <sys/socketvar.h>
#include <sys/sysctl.h>

#include <net/route.h>
#include <net/if_arp.h>
#include <net/net_perf.h>
#include <netinet/in.h>
#include <netinet/in_systm.h>
#include <netinet/ip.h>
#ifdef INET6
#include <netinet/ip6.h>
#endif /* INET6 */
#include <netinet/in_pcb.h>
#include <netinet/ip_icmp.h>
#include <netinet/icmp_var.h>
#include <netinet/igmp_var.h>
#include <netinet/ip_var.h>
#include <netinet/tcp.h>
#include <netinet/tcpip.h>
#include <netinet/tcp_seq.h>
#define TCPSTATES
#include <netinet/tcp_fsm.h>
#include <netinet/tcp_var.h>
#include <netinet/udp.h>
#include <netinet/udp_var.h>

#include <arpa/inet.h>
#include <err.h>
#include <errno.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include "netstat.h"

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

#define ROUNDUP64(a) \
	((a) > 0 ? (1 + (((a) - 1) | (sizeof(uint64_t) - 1))) : sizeof(uint64_t))
#define ADVANCE64(x, n) (((char *)x) += ROUNDUP64(n))

char	*inetname (struct in_addr *);
void	inetprint (struct in_addr *, int, char *, int);
#ifdef INET6
extern void	inet6print (struct in6_addr *, int, char *, int);
static int udp_done, tcp_done;
extern int mptcp_done;
#endif /* INET6 */

#ifdef SRVCACHE
typedef struct __table_private table_t;

extern table_t *_nc_table_new(uint32_t n);
extern void _nc_table_free(table_t *tin);

extern void _nc_table_insert(table_t *t, const char *key, void *datum);
extern void *_nc_table_find(table_t *t, const char *key);
extern void _nc_table_delete(table_t *t, const char *key);

static table_t *_serv_cache = NULL;

/*
 * Read and cache all known services
 */
static void
_serv_cache_open()
{
	struct servent *s;
	char *key, *name, *test;

	if (_serv_cache != NULL) return;

	_serv_cache = _nc_table_new(8192);
	setservent(0);

	while (NULL != (s = getservent()))
	{
		if (s->s_name == NULL) continue;
		key = NULL;
		asprintf(&key, "%hu/%s", (unsigned short)ntohs(s->s_port), s->s_proto);
		name = strdup(s->s_name);
		test = _nc_table_find(_serv_cache, key);
		if (test == NULL) _nc_table_insert(_serv_cache, key, name);
		free(key);
	}

	endservent();
}

void
_serv_cache_close()
{
	_nc_table_free(_serv_cache);
	_serv_cache = NULL;
}

struct servent *
_serv_cache_getservbyport(int port, char *proto)
{
	static struct servent s;
	char *key;
	unsigned short p;

	_serv_cache_open();

	memset(&s, 0, sizeof(struct servent));
	asprintf(&key, "%u/%s", port, (proto == NULL) ? "udp" : proto);

	s.s_name = _nc_table_find(_serv_cache, key);
	free(key);
	if (s.s_name == NULL) return NULL;

	p = port;
	s.s_port = htons(p);
	s.s_proto = proto;
	return &s;
}

#endif /* SRVCACHE */
	
/*
 * Print a summary of connections related to an Internet
 * protocol.  For TCP, also give state of connection.
 * Listening processes (aflag) are suppressed unless the
 * -a (all) flag is specified.
 */

struct xgen_n {
	u_int32_t	xgn_len;			/* length of this structure */
	u_int32_t	xgn_kind;		/* number of PCBs at this time */
};

#define ALL_XGN_KIND_INP (XSO_SOCKET | XSO_RCVBUF | XSO_SNDBUF | XSO_STATS | XSO_INPCB)
#define ALL_XGN_KIND_TCP (ALL_XGN_KIND_INP | XSO_TCPCB)

void
protopr(uint32_t proto,		/* for sysctl version we pass proto # */
		char *name, int af)
{
	int istcp;
	static int first = 1;
	char *buf, *next;
	const char *mibvar;
	struct xinpgen *xig, *oxig;
	struct xgen_n *xgn;
	size_t len;
	struct xtcpcb_n *tp = NULL;
	struct xinpcb_n *inp = NULL;
	struct xsocket_n *so = NULL;
	struct xsockbuf_n *so_rcv = NULL;
	struct xsockbuf_n *so_snd = NULL;
	struct xsockstat_n *so_stat = NULL;
	int which = 0;

	istcp = 0;
	switch (proto) {
		case IPPROTO_TCP:
#ifdef INET6
			if (tcp_done != 0)
				return;
			else
				tcp_done = 1;
#endif
			istcp = 1;
			mibvar = "net.inet.tcp.pcblist_n";
			break;
		case IPPROTO_UDP:
#ifdef INET6
			if (udp_done != 0)
				return;
			else
				udp_done = 1;
#endif
			mibvar = "net.inet.udp.pcblist_n";
			break;
		case IPPROTO_DIVERT:
			mibvar = "net.inet.divert.pcblist_n";
			break;
		default:
			mibvar = "net.inet.raw.pcblist_n";
			break;
	}
	len = 0;
	if (sysctlbyname(mibvar, 0, &len, 0, 0) < 0) {
		if (errno != ENOENT)
			warn("sysctl: %s", mibvar);
		return;
	}        
	if ((buf = malloc(len)) == 0) {
		warn("malloc %lu bytes", (u_long)len);
		return;
	}
	if (sysctlbyname(mibvar, buf, &len, 0, 0) < 0) {
		warn("sysctl: %s", mibvar);
		free(buf);
		return;
	}
	
	/*
	 * Bail-out to avoid logic error in the loop below when
	 * there is in fact no more control block to process
	 */
	if (len <= sizeof(struct xinpgen)) {
		free(buf);
		return;
	}
	
	oxig = xig = (struct xinpgen *)buf;
	for (next = buf + ROUNDUP64(xig->xig_len); next < buf + len; next += ROUNDUP64(xgn->xgn_len)) {
		
		xgn = (struct xgen_n*)next;
		if (xgn->xgn_len <= sizeof(struct xinpgen))
			break;
		
		if ((which & xgn->xgn_kind) == 0) {
			which |= xgn->xgn_kind;
			switch (xgn->xgn_kind) {
				case XSO_SOCKET:
					so = (struct xsocket_n *)xgn;
					break;
				case XSO_RCVBUF:
					so_rcv = (struct xsockbuf_n *)xgn;
					break;
				case XSO_SNDBUF:
					so_snd = (struct xsockbuf_n *)xgn;
					break;
				case XSO_STATS:
					so_stat = (struct xsockstat_n *)xgn;
					break;
				case XSO_INPCB:
					inp = (struct xinpcb_n *)xgn;
					break;
				case XSO_TCPCB:
					tp = (struct xtcpcb_n *)xgn;
					break;
				default:
					printf("unexpected kind %d\n", xgn->xgn_kind);
					break;
			} 		
		} else {
			if (vflag)
        	        	printf("got %d twice\n", xgn->xgn_kind);
		}
		
		if ((istcp && which != ALL_XGN_KIND_TCP) || (!istcp && which != ALL_XGN_KIND_INP))
			continue;
		which = 0;
		
		/* Ignore sockets for protocols other than the desired one. */
		if (so->xso_protocol != (int)proto)
			continue;
		
		/* Ignore PCBs which were freed during copyout. */
		if (inp->inp_gencnt > oxig->xig_gen)
			continue;
		
		if ((af == AF_INET && (inp->inp_vflag & INP_IPV4) == 0)
#ifdef INET6
		    || (af == AF_INET6 && (inp->inp_vflag & INP_IPV6) == 0)
#endif /* INET6 */
		    || (af == AF_UNSPEC && ((inp->inp_vflag & INP_IPV4) == 0
#ifdef INET6
									&& (inp->inp_vflag &
										INP_IPV6) == 0
#endif /* INET6 */
									))
		    )
			continue;
		
		/*
		 * Local address is not an indication of listening socket or
		 * server sockey but just rather the socket has been bound.
		 * That why many UDP sockets were not displayed in the original code.
		 */
		if (!aflag && istcp && tp->t_state <= TCPS_LISTEN)
			continue;
		
		if (Lflag && !so->so_qlimit)
			continue;
		
		if (first) {
			if (!Lflag) {
				printf("Active Internet connections");
				if (aflag)
					printf(" (including servers)");
			} else
				printf(
					   "Current listen queue sizes (qlen/incqlen/maxqlen)");
			putchar('\n');
			if (Aflag) {
#if !TARGET_OS_EMBEDDED
				printf("%-16.16s ", "Socket");
#else
				printf("%-8.8s ", "Socket");
#endif
				printf("%-9.9s", "Flowhash");
			}
			if (Lflag)
				printf("%-14.14s %-22.22s\n",
					   "Listen", "Local Address");
			else {
				printf((Aflag && !Wflag) ?
					   "%-5.5s %-6.6s %-6.6s  %-18.18s %-18.18s %-11.11s" :
					   "%-5.5s %-6.6s %-6.6s  %-22.22s %-22.22s %-11.11s",
					   "Proto", "Recv-Q", "Send-Q",
					   "Local Address", "Foreign Address",
					   "(state)");
				if (bflag > 0)
					printf(" %10.10s %10.10s", "rxbytes", "txbytes");
				if (prioflag >= 0)
					printf(" %7.7s[%1d] %7.7s[%1d]", "rxbytes", prioflag, "txbytes", prioflag);
				if (vflag > 0)
					printf(" %6.6s %6.6s %6.6s %6.6s",
					    "rhiwat", "shiwat", "pid", "epid");
				printf("\n");
			}
			first = 0;
		}
		if (Aflag) {
			if (istcp)
#if !TARGET_OS_EMBEDDED
				printf("%16lx ", (u_long)inp->inp_ppcb);
#else
			printf("%8lx ", (u_long)inp->inp_ppcb);
			
#endif
			else
#if !TARGET_OS_EMBEDDED
				printf("%16lx ", (u_long)so->so_pcb);
#else
			printf("%8lx ", (u_long)so->so_pcb);
#endif
			printf("%8x ", inp->inp_flowhash);
		}
		if (Lflag) {
			char buf[15];
			
			snprintf(buf, 15, "%d/%d/%d", so->so_qlen,
					 so->so_incqlen, so->so_qlimit);
			printf("%-14.14s ", buf);
		}
		else {
			const char *vchar;
			
#ifdef INET6
			if ((inp->inp_vflag & INP_IPV6) != 0)
				vchar = ((inp->inp_vflag & INP_IPV4) != 0)
				? "46" : "6 ";
			else
#endif
				vchar = ((inp->inp_vflag & INP_IPV4) != 0)
				? "4 " : "  ";
			
			printf("%-3.3s%-2.2s %6u %6u  ", name, vchar,
			       so_rcv->sb_cc,
			       so_snd->sb_cc);
		}
		if (nflag) {
			if (inp->inp_vflag & INP_IPV4) {
				inetprint(&inp->inp_laddr, (int)inp->inp_lport,
						  name, 1);
				if (!Lflag)
					inetprint(&inp->inp_faddr,
							  (int)inp->inp_fport, name, 1);
			}
#ifdef INET6
			else if (inp->inp_vflag & INP_IPV6) {
				inet6print(&inp->in6p_laddr,
						   (int)inp->inp_lport, name, 1);
				if (!Lflag)
					inet6print(&inp->in6p_faddr,
							   (int)inp->inp_fport, name, 1);
			} /* else nothing printed now */
#endif /* INET6 */
		} else if (inp->inp_flags & INP_ANONPORT) {
			if (inp->inp_vflag & INP_IPV4) {
				inetprint(&inp->inp_laddr, (int)inp->inp_lport,
						  name, 1);
				if (!Lflag)
					inetprint(&inp->inp_faddr,
							  (int)inp->inp_fport, name, 0);
			}
#ifdef INET6
			else if (inp->inp_vflag & INP_IPV6) {
				inet6print(&inp->in6p_laddr,
						   (int)inp->inp_lport, name, 1);
				if (!Lflag)
					inet6print(&inp->in6p_faddr,
							   (int)inp->inp_fport, name, 0);
			} /* else nothing printed now */
#endif /* INET6 */
		} else {
			if (inp->inp_vflag & INP_IPV4) {
				inetprint(&inp->inp_laddr, (int)inp->inp_lport,
						  name, 0);
				if (!Lflag)
					inetprint(&inp->inp_faddr,
							  (int)inp->inp_fport, name,
							  inp->inp_lport !=
							  inp->inp_fport);
			}
#ifdef INET6
			else if (inp->inp_vflag & INP_IPV6) {
				inet6print(&inp->in6p_laddr,
						   (int)inp->inp_lport, name, 0);
				if (!Lflag)
					inet6print(&inp->in6p_faddr,
							   (int)inp->inp_fport, name,
							   inp->inp_lport !=
							   inp->inp_fport);
			} /* else nothing printed now */
#endif /* INET6 */
		}
		if (istcp && !Lflag) {
			if (tp->t_state < 0 || tp->t_state >= TCP_NSTATES)
				printf("%-11d", tp->t_state);
			else {
				printf("%-11s", tcpstates[tp->t_state]);
#if defined(TF_NEEDSYN) && defined(TF_NEEDFIN)
				/* Show T/TCP `hidden state' */
				if (tp->t_flags & (TF_NEEDSYN|TF_NEEDFIN))
					putchar('*');
#endif /* defined(TF_NEEDSYN) && defined(TF_NEEDFIN) */
			}
		}
		if (!istcp)
			printf("%-11s", "           ");
		if (bflag > 0) {
			int i;
			u_int64_t rxbytes = 0;
			u_int64_t txbytes = 0;
			
			for (i = 0; i < SO_TC_STATS_MAX; i++) {
				rxbytes += so_stat->xst_tc_stats[i].rxbytes;
				txbytes += so_stat->xst_tc_stats[i].txbytes;
			}
			
			printf(" %10llu %10llu", rxbytes, txbytes);
		}
		if (prioflag >= 0) {
			printf(" %10llu %10llu", 
				   prioflag < SO_TC_STATS_MAX ? so_stat->xst_tc_stats[prioflag].rxbytes : 0, 
				   prioflag < SO_TC_STATS_MAX ? so_stat->xst_tc_stats[prioflag].txbytes : 0);
		}
		if (vflag > 0) {
			printf(" %6u %6u %6u %6u",
			       so_rcv->sb_hiwat,
			       so_snd->sb_hiwat,
			       so->so_last_pid,
			       so->so_e_pid);
		}
		putchar('\n');
	}
	if (xig != oxig && xig->xig_gen != oxig->xig_gen) {
		if (oxig->xig_count > xig->xig_count) {
			printf("Some %s sockets may have been deleted.\n",
			       name);
		} else if (oxig->xig_count < xig->xig_count) {
			printf("Some %s sockets may have been created.\n",
			       name);
		} else {
			printf("Some %s sockets may have been created or deleted",
			       name);
		}
	}
	free(buf);
}

/*
 * Dump TCP statistics structure.
 */
void
tcp_stats(uint32_t off , char *name, int af)
{
	static struct tcpstat ptcpstat;
	struct tcpstat tcpstat;
	size_t len = sizeof tcpstat;
	static uint32_t r_swcsum, pr_swcsum;
	static uint32_t t_swcsum, pt_swcsum;

	if (sysctlbyname("net.inet.tcp.stats", &tcpstat, &len, 0, 0) < 0) {
		warn("sysctl: net.inet.tcp.stats");
		return;
	}

#ifdef INET6
	if (tcp_done != 0 && interval == 0)
		return;
	else
		tcp_done = 1;
#endif

	if (interval && vflag > 0)
		print_time();
	printf ("%s:\n", name);

#define	TCPDIFF(f) (tcpstat.f - ptcpstat.f)
#define	p(f, m) if (TCPDIFF(f) || sflag <= 1) \
    printf(m, TCPDIFF(f), plural(TCPDIFF(f)))
#define	p1a(f, m) if (TCPDIFF(f) || sflag <= 1) \
    printf(m, TCPDIFF(f))
#define	p2(f1, f2, m) if (TCPDIFF(f1) || TCPDIFF(f2) || sflag <= 1) \
    printf(m, TCPDIFF(f1), plural(TCPDIFF(f1)), TCPDIFF(f2), plural(TCPDIFF(f2)))
#define	p2a(f1, f2, m) if (TCPDIFF(f1) || TCPDIFF(f2) || sflag <= 1) \
    printf(m, TCPDIFF(f1), plural(TCPDIFF(f1)), TCPDIFF(f2))
#define	p3(f, m) if (TCPDIFF(f) || sflag <= 1) \
    printf(m, TCPDIFF(f), plurales(TCPDIFF(f)))

	p(tcps_sndtotal, "\t%u packet%s sent\n");
	p2(tcps_sndpack,tcps_sndbyte,
		"\t\t%u data packet%s (%u byte%s)\n");
	p2(tcps_sndrexmitpack, tcps_sndrexmitbyte,
		"\t\t%u data packet%s (%u byte%s) retransmitted\n");
	p(tcps_mturesent, "\t\t%u resend%s initiated by MTU discovery\n");
	p2a(tcps_sndacks, tcps_delack,
		"\t\t%u ack-only packet%s (%u delayed)\n");
	p(tcps_sndurg, "\t\t%u URG only packet%s\n");
	p(tcps_sndprobe, "\t\t%u window probe packet%s\n");
	p(tcps_sndwinup, "\t\t%u window update packet%s\n");
	p(tcps_sndctrl, "\t\t%u control packet%s\n");
	p(tcps_fcholdpacket, "\t\t%u data packet%s sent after flow control\n");
	t_swcsum = tcpstat.tcps_snd_swcsum + tcpstat.tcps_snd6_swcsum;
	if ((t_swcsum - pt_swcsum) || sflag <= 1)
        printf("\t\t%u checksummed in software\n", (t_swcsum - pt_swcsum));
	p2(tcps_snd_swcsum, tcps_snd_swcsum_bytes,
	    "\t\t\t%u segment%s (%u byte%s) over IPv4\n");
#if INET6
	p2(tcps_snd6_swcsum, tcps_snd6_swcsum_bytes,
	    "\t\t\t%u segment%s (%u byte%s) over IPv6\n");
#endif /* INET6 */
	p(tcps_rcvtotal, "\t%u packet%s received\n");
	p2(tcps_rcvackpack, tcps_rcvackbyte, "\t\t%u ack%s (for %u byte%s)\n");
	p(tcps_rcvdupack, "\t\t%u duplicate ack%s\n");
	p(tcps_rcvacktoomuch, "\t\t%u ack%s for unsent data\n");
	p2(tcps_rcvpack, tcps_rcvbyte,
		"\t\t%u packet%s (%u byte%s) received in-sequence\n");
	p2(tcps_rcvduppack, tcps_rcvdupbyte,
		"\t\t%u completely duplicate packet%s (%u byte%s)\n");
	p(tcps_pawsdrop, "\t\t%u old duplicate packet%s\n");
	p(tcps_rcvmemdrop, "\t\t%u received packet%s dropped due to low memory\n");
	p2(tcps_rcvpartduppack, tcps_rcvpartdupbyte,
		"\t\t%u packet%s with some dup. data (%u byte%s duped)\n");
	p2(tcps_rcvoopack, tcps_rcvoobyte,
		"\t\t%u out-of-order packet%s (%u byte%s)\n");
	p2(tcps_rcvpackafterwin, tcps_rcvbyteafterwin,
		"\t\t%u packet%s (%u byte%s) of data after window\n");
	p(tcps_rcvwinprobe, "\t\t%u window probe%s\n");
	p(tcps_rcvwinupd, "\t\t%u window update packet%s\n");
	p(tcps_rcvafterclose, "\t\t%u packet%s received after close\n");
	p(tcps_badrst, "\t\t%u bad reset%s\n");
	p(tcps_rcvbadsum, "\t\t%u discarded for bad checksum%s\n");
	r_swcsum = tcpstat.tcps_rcv_swcsum + tcpstat.tcps_rcv6_swcsum;
	if ((r_swcsum - pr_swcsum) || sflag <= 1)
        printf("\t\t%u checksummed in software\n",
               (r_swcsum - pr_swcsum));
	p2(tcps_rcv_swcsum, tcps_rcv_swcsum_bytes,
	    "\t\t\t%u segment%s (%u byte%s) over IPv4\n");
#if INET6
	p2(tcps_rcv6_swcsum, tcps_rcv6_swcsum_bytes,
	    "\t\t\t%u segment%s (%u byte%s) over IPv6\n");
#endif /* INET6 */
	p(tcps_rcvbadoff, "\t\t%u discarded for bad header offset field%s\n");
	p1a(tcps_rcvshort, "\t\t%u discarded because packet too short\n");
	p(tcps_connattempt, "\t%u connection request%s\n");
	p(tcps_accepts, "\t%u connection accept%s\n");
	p(tcps_badsyn, "\t%u bad connection attempt%s\n");
	p(tcps_listendrop, "\t%u listen queue overflow%s\n");
	p(tcps_connects, "\t%u connection%s established (including accepts)\n");
	p2(tcps_closed, tcps_drops,
		"\t%u connection%s closed (including %u drop%s)\n");
	p(tcps_cachedrtt, "\t\t%u connection%s updated cached RTT on close\n");
	p(tcps_cachedrttvar, 
	  "\t\t%u connection%s updated cached RTT variance on close\n");
	p(tcps_cachedssthresh,
	  "\t\t%u connection%s updated cached ssthresh on close\n");
	p(tcps_conndrops, "\t%u embryonic connection%s dropped\n");
	p2(tcps_rttupdated, tcps_segstimed,
		"\t%u segment%s updated rtt (of %u attempt%s)\n");
	p(tcps_rexmttimeo, "\t%u retransmit timeout%s\n");
	p(tcps_timeoutdrop, "\t\t%u connection%s dropped by rexmit timeout\n");
	p(tcps_rxtfindrop, "\t\t%u connection%s dropped after retransmitting FIN\n");
	p(tcps_persisttimeo, "\t%u persist timeout%s\n");
	p(tcps_persistdrop, "\t\t%u connection%s dropped by persist timeout\n");
	p(tcps_keeptimeo, "\t%u keepalive timeout%s\n");
	p(tcps_keepprobe, "\t\t%u keepalive probe%s sent\n");
	p(tcps_keepdrops, "\t\t%u connection%s dropped by keepalive\n");
	p(tcps_predack, "\t%u correct ACK header prediction%s\n");
	p(tcps_preddat, "\t%u correct data packet header prediction%s\n");
#ifdef TCP_MAX_SACK
	/* TCP_MAX_SACK indicates the header has the SACK structures */
	p(tcps_sack_recovery_episode, "\t%u SACK recovery episode%s\n"); 
	p(tcps_sack_rexmits,
		"\t%u segment rexmit%s in SACK recovery episodes\n");
	p(tcps_sack_rexmit_bytes,
		"\t%u byte rexmit%s in SACK recovery episodes\n"); 
	p(tcps_sack_rcv_blocks,
		"\t%u SACK option%s (SACK blocks) received\n"); 
	p(tcps_sack_send_blocks, "\t%u SACK option%s (SACK blocks) sent\n"); 
	p1a(tcps_sack_sboverflow, "\t%u SACK scoreboard overflow\n"); 
#endif /* TCP_MAX_SACK */

	p(tcps_coalesced_pack, "\t%u LRO coalesced packet%s\n");
	p(tcps_flowtbl_full, "\t\t%u time%s LRO flow table was full\n");
	p(tcps_flowtbl_collision, "\t\t%u collision%s in LRO flow table\n");
	p(tcps_lro_twopack, "\t\t%u time%s LRO coalesced 2 packets\n");
	p(tcps_lro_multpack, "\t\t%u time%s LRO coalesced 3 or 4 packets\n");
	p(tcps_lro_largepack, "\t\t%u time%s LRO coalesced 5 or more packets\n");

	p(tcps_limited_txt, "\t%u limited transmit%s done\n");
	p(tcps_early_rexmt, "\t%u early retransmit%s done\n");
	p(tcps_sack_ackadv, "\t%u time%s cumulative ack advanced along with SACK\n");
	p(tcps_pto, "\t%u probe timeout%s\n");
	p(tcps_rto_after_pto, "\t\t%u time%s retransmit timeout triggered after probe\n");
	p(tcps_probe_if, "\t\t%u time%s probe packets were sent for an interface\n");
	p(tcps_probe_if_conflict, "\t\t%u time%s couldn't send probe packets for an interface\n");
	p(tcps_tlp_recovery, "\t\t%u time%s fast recovery after tail loss\n");
	p(tcps_tlp_recoverlastpkt, "\t\t%u time%s recovered last packet \n");
	p(tcps_pto_in_recovery, "\t\t%u SACK based rescue retransmit%s\n");
	p(tcps_ecn_client_setup, "\t%u client connection%s attempted to negotiate ECN\n");
	p(tcps_ecn_client_success, "\t\t%u client connection%s successfully negotiated ECN\n");
	p(tcps_ecn_not_supported, "\t\t%u time%s graceful fallback to Non-ECN connection\n");
	p(tcps_ecn_lost_syn, "\t\t%u time%s lost ECN negotiating SYN, followed by retransmission\n");
	p(tcps_ecn_server_setup, "\t\t%u server connection%s attempted to negotiate ECN\n");
	p(tcps_ecn_server_success, "\t\t%u server connection%s successfully negotiated ECN\n");
	p(tcps_ecn_lost_synack, "\t\t%u time%s lost ECN negotiating SYN-ACK, followed by retransmission\n");
	p(tcps_ecn_recv_ce, "\t\t%u time%s received congestion experienced (CE) notification\n");
	p(tcps_ecn_recv_ece, "\t\t%u time%s CWR was sent in response to ECE\n");
	p(tcps_ecn_sent_ece, "\t\t%u time%s sent ECE notification\n");
	p(tcps_ecn_conn_recv_ce, "\t\t%u connection%s received CE atleast once\n");
	p(tcps_ecn_conn_recv_ece, "\t\t%u connection%s received ECE atleast once\n");
	p(tcps_ecn_conn_plnoce, "\t\t%u connection%s using ECN have seen packet loss but no CE\n");
	p(tcps_ecn_conn_pl_ce, "\t\t%u connection%s using ECN have seen packet loss and CE\n");
	p(tcps_ecn_conn_nopl_ce, "\t\t%u connection%s using ECN received CE but no packet loss\n");
	p(tcps_ecn_fallback_synloss, "\t\t%u connection%s fell back to non-ECN due to SYN-loss\n");
	p(tcps_ecn_fallback_reorder, "\t\t%u connection%s fell back to non-ECN due to reordering\n");
	p(tcps_ecn_fallback_ce, "\t\t%u connection%s fell back to non-ECN due to excessive CE-markings\n");
	p(tcps_detect_reordering, "\t%u time%s packet reordering was detected on a connection\n");
	p(tcps_reordered_pkts, "\t\t%u time%s transmitted packets were reordered\n");
	p(tcps_delay_recovery, "\t\t%u time%s fast recovery was delayed to handle reordering\n");
	p(tcps_avoid_rxmt, "\t\t%u time%s retransmission was avoided by delaying recovery\n");
	p(tcps_unnecessary_rxmt, "\t\t%u retransmission%s not needed \n");
	p(tcps_dsack_sent, "\t%u time%s DSACK option was sent\n");
	p(tcps_dsack_recvd, "\t\t%u time%s DSACK option was received\n");
	p(tcps_dsack_disable, "\t\t%u time%s DSACK was disabled on a connection\n");
	p(tcps_dsack_badrexmt, "\t\t%u time%s recovered from bad retransmission using DSACK\n");
	p(tcps_dsack_ackloss,"\t\t%u time%s ignored DSACK due to ack loss\n");
	p(tcps_dsack_recvd_old,"\t\t%u time%s ignored old DSACK options\n");
	p(tcps_pmtudbh_reverted, "\t%u time%s PMTU Blackhole detection, size reverted\n");
	p(tcps_drop_after_sleep, "\t%u connection%s were dropped after long sleep\n");

	p(tcps_tfo_cookie_sent,"\t%u time%s a TFO-cookie has been announced\n");
	p(tcps_tfo_syn_data_rcv,"\t%u SYN%s with data and a valid TFO-cookie have been received\n");
	p(tcps_tfo_cookie_req_rcv,"\t%u SYN%s with TFO-cookie-request received\n");
	p(tcps_tfo_cookie_invalid,"\t%u time%s an invalid TFO-cookie has been received\n");
	p(tcps_tfo_cookie_req,"\t%u time%s we requested a TFO-cookie\n");
	p(tcps_tfo_cookie_rcv,"\t\t%u time%s the peer announced a TFO-cookie\n");
	p(tcps_tfo_syn_data_sent,"\t%u time%s we combined SYN with data and a TFO-cookie\n");
	p(tcps_tfo_syn_data_acked,"\t\t%u time%s our SYN with data has been acknowledged\n");
	p(tcps_tfo_syn_loss,"\t%u time%s a connection-attempt with TFO fell back to regular TCP\n");
	p(tcps_tfo_blackhole,"\t%u time%s a TFO-connection blackhole'd\n");
	p(tcps_mss_to_default,"\t%u time%s maximum segment size was changed to default\n");
	p(tcps_mss_to_medium,"\t%u time%s maximum segment size was changed to medium\n");
	p(tcps_mss_to_low,"\t%u time%s maximum segment size was changed to low\n");

	p(tcps_timer_drift_le_1_ms,"\t%u timer drift%s less or equal to 1 ms\n");
	p(tcps_timer_drift_le_10_ms,"\t%u timer drift%s less or equal to 10 ms\n");
	p(tcps_timer_drift_le_20_ms,"\t%u timer drift%s less or equal to 20 ms\n");
	p(tcps_timer_drift_le_50_ms,"\t%u timer drift%s less or equal to 50 ms\n");
	p(tcps_timer_drift_le_100_ms,"\t%u timer drift%s less or equal to 100 ms\n");
	p(tcps_timer_drift_le_200_ms,"\t%u timer drift%s less or equal to 200 ms\n");
	p(tcps_timer_drift_le_500_ms,"\t%u timer drift%s less or equal to 500 ms\n");
	p(tcps_timer_drift_le_1000_ms,"\t%u timer drift%s less or equal to 1000 ms\n");
	p(tcps_timer_drift_gt_1000_ms,"\t%u timer drift%s greater than to 1000 ms\n");

	if (interval > 0) {
		bcopy(&tcpstat, &ptcpstat, len);
		pr_swcsum = r_swcsum;
		pt_swcsum = t_swcsum;
	}

#undef TCPDIFF
#undef p
#undef p1a
#undef p2
#undef p2a
#undef p3
}

/*
 * Dump MPTCP statistics
 */
void
mptcp_stats(uint32_t off , char *name, int af)
{
	static struct tcpstat ptcpstat;
	struct tcpstat tcpstat;
	size_t len = sizeof tcpstat;

	if (sysctlbyname("net.inet.tcp.stats", &tcpstat, &len, 0, 0) < 0) {
		warn("sysctl: net.inet.tcp.stats");
		return;
	}

#ifdef INET6
	if (mptcp_done != 0 && interval == 0)
		return;
	else
		mptcp_done = 1;
#endif

	if (interval && vflag > 0)
		print_time();
	printf ("%s:\n", name);

#define	MPTCPDIFF(f) (tcpstat.f - ptcpstat.f)
#define	p(f, m) if (MPTCPDIFF(f) || sflag <= 1) \
    printf(m, MPTCPDIFF(f), plural(MPTCPDIFF(f)))
#define	p1a(f, m) if (MPTCPDIFF(f) || sflag <= 1) \
    printf(m, MPTCPDIFF(f))
#define	p2(f1, f2, m) if (MPTCPDIFF(f1) || MPTCPDIFF(f2) || sflag <= 1) \
    printf(m, MPTCPDIFF(f1), plural(MPTCPDIFF(f1)), \
        MPTCPDIFF(f2), plural(MPTCPDIFF(f2)))
#define	p2a(f1, f2, m) if (MPTCPDIFF(f1) || MPTCPDIFF(f2) || sflag <= 1) \
    printf(m, MPTCPDIFF(f1), plural(MPTCPDIFF(f1)), MPTCPDIFF(f2))
#define	p3(f, m) if (MPTCPDIFF(f) || sflag <= 1) \
    printf(m, MPTCPDIFF(f), plurales(MPTCPDIFF(f)))

	p(tcps_mp_sndpacks, "\t%u data packet%s sent\n");
	p(tcps_mp_sndbytes, "\t%u data byte%s sent\n");
	p(tcps_mp_rcvtotal, "\t%u data packet%s received\n");
	p(tcps_mp_rcvbytes, "\t%u data byte%s received\n");
	p(tcps_invalid_mpcap, "\t%u packet%s with an invalid MPCAP option\n");
	p(tcps_invalid_joins, "\t%u packet%s with an invalid MPJOIN option\n");
	p(tcps_mpcap_fallback, "\t%u time%s primary subflow fell back to "
	    "TCP\n");
	p(tcps_join_fallback, "\t%u time%s secondary subflow fell back to "
	    "TCP\n");
	p(tcps_estab_fallback, "\t%u DSS option drop%s\n");
	p(tcps_invalid_opt, "\t%u other invalid MPTCP option%s\n");
	p(tcps_mp_reducedwin, "\t%u time%s the MPTCP subflow window was reduced\n");
	p(tcps_mp_badcsum, "\t%u bad DSS checksum%s\n");
	p(tcps_mp_oodata, "\t%u time%s received out of order data \n");
	p3(tcps_mp_switches, "\t%u subflow switch%s\n");
	p3(tcps_mp_sel_symtomsd, "\t%u subflow switch%s due to advisory\n");
	p3(tcps_mp_sel_rtt, "\t%u subflow switch%s due to rtt\n");
	p3(tcps_mp_sel_rto, "\t%u subflow switch%s due to rto\n");
	p3(tcps_mp_sel_peer, "\t%u subflow switch%s due to peer\n");
	p3(tcps_mp_num_probes, "\t%u number of subflow probe%s\n");

	if (interval > 0) {
		bcopy(&tcpstat, &ptcpstat, len);
	}

#undef MPTCPDIFF
#undef p
#undef p1a
#undef p2
#undef p2a
#undef p3
}

/*
 * Dump UDP statistics structure.
 */
void
udp_stats(uint32_t off , char *name, int af )
{
	static struct udpstat pudpstat;
	struct udpstat udpstat;
	size_t len = sizeof udpstat;
	uint32_t delivered;
	static uint32_t r_swcsum, pr_swcsum;
	static uint32_t t_swcsum, pt_swcsum;

	if (sysctlbyname("net.inet.udp.stats", &udpstat, &len, 0, 0) < 0) {
		warn("sysctl: net.inet.udp.stats");
		return;
	}

#ifdef INET6
	if (udp_done != 0 && interval == 0)
		return;
	else
		udp_done = 1;
#endif

	if (interval && vflag > 0)
		print_time();
	printf("%s:\n", name);

#define	UDPDIFF(f) (udpstat.f - pudpstat.f)
#define	p(f, m) if (UDPDIFF(f) || sflag <= 1) \
    printf(m, UDPDIFF(f), plural(UDPDIFF(f)))
#define	p1a(f, m) if (UDPDIFF(f) || sflag <= 1) \
    printf(m, UDPDIFF(f))
#define	p2(f1, f2, m) if (UDPDIFF(f1) || UDPDIFF(f2) || sflag <= 1) \
    printf(m, UDPDIFF(f1), plural(UDPDIFF(f1)), UDPDIFF(f2), plural(UDPDIFF(f2)))
	p(udps_ipackets, "\t%u datagram%s received\n");
	p1a(udps_hdrops, "\t\t%u with incomplete header\n");
	p1a(udps_badlen, "\t\t%u with bad data length field\n");
	p1a(udps_badsum, "\t\t%u with bad checksum\n");
	p1a(udps_nosum, "\t\t%u with no checksum\n");
	r_swcsum = udpstat.udps_rcv_swcsum + udpstat.udps_rcv6_swcsum;
	if ((r_swcsum - pr_swcsum) || sflag <= 1)
        printf("\t\t%u checksummed in software\n", (r_swcsum - pr_swcsum));
	p2(udps_rcv_swcsum, udps_rcv_swcsum_bytes,
	    "\t\t\t%u datagram%s (%u byte%s) over IPv4\n");
#if INET6
	p2(udps_rcv6_swcsum, udps_rcv6_swcsum_bytes,
	    "\t\t\t%u datagram%s (%u byte%s) over IPv6\n");
#endif /* INET6 */
	p1a(udps_noport, "\t\t%u dropped due to no socket\n");
	p(udps_noportbcast,
	    "\t\t%u broadcast/multicast datagram%s undelivered\n");
	/* the next statistic is cumulative in udps_noportbcast */
	p(udps_filtermcast,
	    "\t\t%u time%s multicast source filter matched\n");
	p1a(udps_fullsock, "\t\t%u dropped due to full socket buffers\n");
	p1a(udpps_pcbhashmiss, "\t\t%u not for hashed pcb\n");
	delivered = UDPDIFF(udps_ipackets) -
		    UDPDIFF(udps_hdrops) -
		    UDPDIFF(udps_badlen) -
		    UDPDIFF(udps_badsum) -
		    UDPDIFF(udps_noport) -
		    UDPDIFF(udps_noportbcast) -
		    UDPDIFF(udps_fullsock);
	if (delivered || sflag <= 1)
		printf("\t\t%u delivered\n", delivered);
	p(udps_opackets, "\t%u datagram%s output\n");
	t_swcsum = udpstat.udps_snd_swcsum + udpstat.udps_snd6_swcsum;
	if ((t_swcsum - pt_swcsum) || sflag <= 1)
        printf("\t\t%u checksummed in software\n", (t_swcsum - pt_swcsum));
	p2(udps_snd_swcsum, udps_snd_swcsum_bytes,
	    "\t\t\t%u datagram%s (%u byte%s) over IPv4\n");
#if INET6
	p2(udps_snd6_swcsum, udps_snd6_swcsum_bytes,
	    "\t\t\t%u datagram%s (%u byte%s) over IPv6\n");
#endif /* INET6 */

	if (interval > 0) {
		bcopy(&udpstat, &pudpstat, len);
		pr_swcsum = r_swcsum;
		pt_swcsum = t_swcsum;
	}

#undef UDPDIFF
#undef p
#undef p1a
#undef p2
}

/*
 * Dump IP statistics structure.
 */
void
ip_stats(uint32_t off , char *name, int af )
{
	static struct ipstat pipstat;
	struct ipstat ipstat;
	size_t ipstat_len = sizeof ipstat;

	static net_perf_t pout_net_perf, pin_net_perf;
	net_perf_t out_net_perf, in_net_perf;
	size_t out_net_perf_len = sizeof (out_net_perf);
	size_t in_net_perf_len = sizeof (in_net_perf);

	if (sysctlbyname("net.inet.ip.stats", &ipstat, &ipstat_len, 0, 0) < 0) {
		warn("sysctl: net.inet.ip.stats");
		return;
	}

	if (sysctlbyname("net.inet.ip.output_perf_data", &out_net_perf, &out_net_perf_len, 0, 0) < 0) {
		warn("sysctl: net.inet.ip.output_perf_data");
		return;
	}

	if (sysctlbyname("net.inet.ip.input_perf_data", &in_net_perf, &in_net_perf_len, 0, 0) < 0) {
		warn("sysctl: net.inet.ip.input_perf_data");
		return;
	}

	if (interval && vflag > 0)
		print_time();
	printf("%s:\n", name);

#define	IPDIFF(f) (ipstat.f - pipstat.f)
#define	p(f, m) if (IPDIFF(f) || sflag <= 1) \
    printf(m, IPDIFF(f), plural(IPDIFF(f)))
#define	p1a(f, m) if (IPDIFF(f) || sflag <= 1) \
    printf(m, IPDIFF(f))
#define	p2(f1, f2, m) if (IPDIFF(f1) || IPDIFF(f2) || sflag <= 1) \
    printf(m, IPDIFF(f1), plural(IPDIFF(f1)), IPDIFF(f2), plural(IPDIFF(f2)))

	p(ips_total, "\t%u total packet%s received\n");
	p(ips_badsum, "\t\t%u bad header checksum%s\n");
	p2(ips_rcv_swcsum, ips_rcv_swcsum_bytes,
	    "\t\t%u header%s (%u byte%s) checksummed in software\n");
	p1a(ips_toosmall, "\t\t%u with size smaller than minimum\n");
	p1a(ips_tooshort, "\t\t%u with data size < data length\n");
	p1a(ips_adj, "\t\t%u with data size > data length\n");
	p(ips_adj_hwcsum_clr,
	    "\t\t\t%u packet%s forced to software checksum\n");
	p1a(ips_toolong, "\t\t%u with ip length > max ip packet size\n");
	p1a(ips_badhlen, "\t\t%u with header length < data size\n");
	p1a(ips_badlen, "\t\t%u with data length < header length\n");
	p1a(ips_badoptions, "\t\t%u with bad options\n");
	p1a(ips_badvers, "\t\t%u with incorrect version number\n");
	p(ips_fragments, "\t\t%u fragment%s received\n");
	p1a(ips_fragdropped, "\t\t\t%u dropped (dup or out of space)\n");
	p1a(ips_fragtimeout, "\t\t\t%u dropped after timeout\n");
	p1a(ips_reassembled, "\t\t\t%u reassembled ok\n");
	p(ips_delivered, "\t\t%u packet%s for this host\n");
	p(ips_noproto, "\t\t%u packet%s for unknown/unsupported protocol\n");
	p(ips_forward, "\t\t%u packet%s forwarded");
	p(ips_fastforward, " (%u packet%s fast forwarded)");
	if (IPDIFF(ips_forward) || sflag <= 1)
		putchar('\n');
	p(ips_cantforward, "\t\t%u packet%s not forwardable\n");
	p(ips_notmember,
	  "\t\t%u packet%s received for unknown multicast group\n");
	p(ips_redirectsent, "\t\t%u redirect%s sent\n");
	p(ips_rxc_collisions, "\t\t%u input packet%s not chained due to collision\n");
	p(ips_rxc_chained, "\t\t%u input packet%s processed in a chain\n");
	p(ips_rxc_notchain, "\t\t%u input packet%s unable to chain\n");
	p(ips_rxc_chainsz_gt2,
	  "\t\t%u input packet chain%s processed with length greater than 2\n");
	p(ips_rxc_chainsz_gt4,
	  "\t\t%u input packet chain%s processed with length greater than 4\n");
	p(ips_rxc_notlist,
	  "\t\t%u input packet%s did not go through list processing path\n");

#define INPERFDIFF(f) (in_net_perf.f - pin_net_perf.f)
	if (INPERFDIFF(np_total_pkts) > 0 && in_net_perf.np_total_usecs > 0) {
		printf("\tInput Performance Stats:\n");
		printf("\t\t%llu total packets measured\n", INPERFDIFF(np_total_pkts));
		printf("\t\t%llu total usec elapsed\n", INPERFDIFF(np_total_usecs));
		printf("\t\t%f usec per packet\n",
		    (double)in_net_perf.np_total_usecs/(double)in_net_perf.np_total_pkts);
		printf("\t\tHistogram:\n");
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

	p(ips_localout, "\t%u packet%s sent from this host\n");
	p(ips_rawout, "\t\t%u packet%s sent with fabricated ip header\n");
	p(ips_odropped,
	  "\t\t%u output packet%s dropped due to no bufs, etc.\n");
	p(ips_noroute, "\t\t%u output packet%s discarded due to no route\n");
	p(ips_fragmented, "\t\t%u output datagram%s fragmented\n");
	p(ips_ofragments, "\t\t%u fragment%s created\n");
	p(ips_cantfrag, "\t\t%u datagram%s that can't be fragmented\n");
	p(ips_nogif, "\t\t%u tunneling packet%s that can't find gif\n");
	p(ips_badaddr, "\t\t%u datagram%s with bad address in header\n");
	p(ips_pktdropcntrl,
	    "\t\t%u packet%s dropped due to no bufs for control data\n");
	p(ips_necp_policy_drop, "\t\t%u packet%s dropped due to NECP policy\n");
	p2(ips_snd_swcsum, ips_snd_swcsum_bytes,
	    "\t\t%u header%s (%u byte%s) checksummed in software\n");

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

	if (interval > 0) {
		bcopy(&ipstat, &pipstat, ipstat_len);
		bcopy(&in_net_perf, &pin_net_perf, in_net_perf_len);
		bcopy(&out_net_perf, &pout_net_perf, out_net_perf_len);
	}

#undef IPDIFF
#undef p
#undef p1a
#undef p2
}

/*
 * Dump ARP statistics structure.
 */
void
arp_stats(uint32_t off, char *name, int af)
{
	static struct arpstat parpstat;
	struct arpstat arpstat;
	size_t len = sizeof (arpstat);

	if (sysctlbyname("net.link.ether.inet.stats", &arpstat,
	    &len, 0, 0) < 0) {
		warn("sysctl: net.link.ether.inet.stats");
		return;
	}

	if (interval && vflag > 0)
		print_time();
	printf("%s:\n", name);

#define	ARPDIFF(f) (arpstat.f - parpstat.f)
#define	p(f, m) if (ARPDIFF(f) || sflag <= 1) \
    printf(m, ARPDIFF(f), plural(ARPDIFF(f)))
#define	p2(f, m) if (ARPDIFF(f) || sflag <= 1) \
    printf(m, ARPDIFF(f), pluralies(ARPDIFF(f)))
#define	p3(f, m) if (ARPDIFF(f) || sflag <= 1) \
    printf(m, ARPDIFF(f), plural(ARPDIFF(f)), pluralies(ARPDIFF(f)))

	p(txrequests, "\t%u broadast ARP request%s sent\n");
	p(txurequests, "\t%u unicast ARP request%s sent\n");
	p2(txreplies, "\t%u ARP repl%s sent\n");
	p(txannounces, "\t%u ARP announcement%s sent\n");
	p(rxrequests, "\t%u ARP request%s received\n");
	p2(rxreplies, "\t%u ARP repl%s received\n");
	p(received, "\t%u total ARP packet%s received\n");
	p(txconflicts, "\t%u ARP conflict probe%s sent\n");
	p(invalidreqs, "\t%u invalid ARP resolve request%s\n");
	p(reqnobufs, "\t%u total packet%s dropped due to lack of memory\n");
	p3(held, "\t%u total packet%s held awaiting ARP repl%s\n");
	p(dropped, "\t%u total packet%s dropped due to no ARP entry\n");
	p(purged, "\t%u total packet%s dropped during ARP entry removal\n");
	p2(timeouts, "\t%u ARP entr%s timed out\n");
	p(dupips, "\t%u Duplicate IP%s seen\n");

	if (interval > 0)
		bcopy(&arpstat, &parpstat, len);

#undef ARPDIFF
#undef p
#undef p2
}

static	char *icmpnames[] = {
	"echo reply",
	"#1",
	"#2",
	"destination unreachable",
	"source quench",
	"routing redirect",
	"#6",
	"#7",
	"echo",
	"router advertisement",
	"router solicitation",
	"time exceeded",
	"parameter problem",
	"time stamp",
	"time stamp reply",
	"information request",
	"information request reply",
	"address mask request",
	"address mask reply",
};

/*
 * Dump ICMP statistics.
 */
void
icmp_stats(uint32_t off , char *name, int af )
{
	static struct icmpstat picmpstat;
	struct icmpstat icmpstat;
	int i, first;
	int mib[4];		/* CTL_NET + PF_INET + IPPROTO_ICMP + req */
	size_t len;

	mib[0] = CTL_NET;
	mib[1] = PF_INET;
	mib[2] = IPPROTO_ICMP;
	mib[3] = ICMPCTL_STATS;

	len = sizeof icmpstat;
	memset(&icmpstat, 0, len);
	if (sysctl(mib, 4, &icmpstat, &len, (void *)0, 0) < 0)
		return;		/* XXX should complain, but not traditional */

	if (interval && vflag > 0)
		print_time();
	printf("%s:\n", name);

#define	ICMPDIFF(f) (icmpstat.f - picmpstat.f)
#define	p(f, m) if (ICMPDIFF(f) || sflag <= 1) \
    printf(m, ICMPDIFF(f), plural(ICMPDIFF(f)))
#define	p1a(f, m) if (ICMPDIFF(f) || sflag <= 1) \
    printf(m, ICMPDIFF(f))

	p(icps_error, "\t%u call%s to icmp_error\n");
	p(icps_oldicmp,
	    "\t%u error%s not generated 'cuz old message was icmp\n");
	for (first = 1, i = 0; i < ICMP_MAXTYPE + 1; i++)
		if (ICMPDIFF(icps_outhist[i]) != 0) {
			if (first) {
				printf("\tOutput histogram:\n");
				first = 0;
			}
			printf("\t\t%s: %u\n", icmpnames[i],
				ICMPDIFF(icps_outhist[i]));
		}
	p(icps_badcode, "\t%u message%s with bad code fields\n");
	p(icps_tooshort, "\t%u message%s < minimum length\n");
	p(icps_checksum, "\t%u bad checksum%s\n");
	p(icps_badlen, "\t%u message%s with bad length\n");
	p1a(icps_bmcastecho, "\t%u multicast echo requests ignored\n");
	p1a(icps_bmcasttstamp, "\t%u multicast timestamp requests ignored\n");
	for (first = 1, i = 0; i < ICMP_MAXTYPE + 1; i++)
		if (ICMPDIFF(icps_inhist[i]) != 0) {
			if (first) {
				printf("\tInput histogram:\n");
				first = 0;
			}
			printf("\t\t%s: %u\n", icmpnames[i],
				ICMPDIFF(icps_inhist[i]));
		}
	p(icps_reflect, "\t%u message response%s generated\n");

#undef ICMPDIFF
#undef p
#undef p1a
	mib[3] = ICMPCTL_MASKREPL;
	len = sizeof i;
	if (sysctl(mib, 4, &i, &len, (void *)0, 0) < 0)
		return;
	printf("\tICMP address mask responses are %sabled\n", 
	       i ? "en" : "dis");

	if (interval > 0)
		bcopy(&icmpstat, &picmpstat, sizeof (icmpstat));
}

/*
 * Dump IGMP statistics structure.
 */
void
igmp_stats(uint32_t off , char *name, int af )
{
	static struct igmpstat_v3 pigmpstat;
	struct igmpstat_v3 igmpstat;
	size_t len = sizeof igmpstat;

	if (sysctlbyname("net.inet.igmp.v3stats", &igmpstat, &len, 0, 0) < 0) {
		warn("sysctl: net.inet.igmp.v3stats");
		return;
	}

	if (igmpstat.igps_version != IGPS_VERSION_3) {
		warnx("%s: version mismatch (%d != %d)", __func__,
		    igmpstat.igps_version, IGPS_VERSION_3);
	}
	if (igmpstat.igps_len != IGPS_VERSION3_LEN) {
		warnx("%s: size mismatch (%d != %d)", __func__,
		    igmpstat.igps_len, IGPS_VERSION3_LEN);
	}

	if (interval && vflag > 0)
		print_time();
	printf("%s:\n", name);

#define	IGMPDIFF(f) ((uintmax_t)(igmpstat.f - pigmpstat.f))
#define	p64(f, m) if (IGMPDIFF(f) || sflag <= 1) \
    printf(m, IGMPDIFF(f), plural(IGMPDIFF(f)))
#define	py64(f, m) if (IGMPDIFF(f) || sflag <= 1) \
    printf(m, IGMPDIFF(f), IGMPDIFF(f) != 1 ? "ies" : "y")

	p64(igps_rcv_total, "\t%ju message%s received\n");
	p64(igps_rcv_tooshort, "\t%ju message%s received with too few bytes\n");
	p64(igps_rcv_badttl, "\t%ju message%s received with wrong TTL\n");
	p64(igps_rcv_badsum, "\t%ju message%s received with bad checksum\n");
	py64(igps_rcv_v1v2_queries, "\t%ju V1/V2 membership quer%s received\n");
	py64(igps_rcv_v3_queries, "\t%ju V3 membership quer%s received\n");
	py64(igps_rcv_badqueries,
	    "\t%ju membership quer%s received with invalid field(s)\n");
	py64(igps_rcv_gen_queries, "\t%ju general quer%s received\n");
	py64(igps_rcv_group_queries, "\t%ju group quer%s received\n");
	py64(igps_rcv_gsr_queries, "\t%ju group-source quer%s received\n");
	py64(igps_drop_gsr_queries, "\t%ju group-source quer%s dropped\n");
	p64(igps_rcv_reports, "\t%ju membership report%s received\n");
	p64(igps_rcv_badreports,
	    "\t%ju membership report%s received with invalid field(s)\n");
	p64(igps_rcv_ourreports,
"\t%ju membership report%s received for groups to which we belong\n");
        p64(igps_rcv_nora, "\t%ju V3 report%s received without Router Alert\n");
        p64(igps_snd_reports, "\t%ju membership report%s sent\n");

	if (interval > 0)
		bcopy(&igmpstat, &pigmpstat, len);

#undef IGMPDIFF
#undef p64
#undef py64
}

/*
 * Pretty print an Internet address (net address + port).
 */
void
inetprint(struct in_addr *in, int port, char *proto, int numeric_port)
{
	struct servent *sp = 0;
	char line[80], *cp;
	int width;

	if (Wflag)
	    snprintf(line, sizeof(line), "%s.", inetname(in));
	else
	    snprintf(line, sizeof(line), "%.*s.", (Aflag && !numeric_port) ? 12 : 16, inetname(in));
	cp = index(line, '\0');
	if (!numeric_port && port)
#ifdef _SERVICE_CACHE_
		sp = _serv_cache_getservbyport(port, proto);
#else
		sp = getservbyport((int)port, proto);
#endif
	if (sp || port == 0)
		snprintf(cp, sizeof(line) - (cp - line), "%.15s ", sp ? sp->s_name : "*");
	else
		snprintf(cp, sizeof(line) - (cp - line), "%d ", ntohs((u_short)port));
	width = (Aflag && !Wflag) ? 18 : 22;
	if (Wflag)
	    printf("%-*s ", width, line);
	else
	    printf("%-*.*s ", width, width, line);
}

/*
 * Construct an Internet address representation.
 * If the nflag has been supplied, give
 * numeric value, otherwise try for symbolic name.
 */
char *
inetname(struct in_addr *inp)
{
	register char *cp;
	static char line[MAXHOSTNAMELEN];
	struct hostent *hp;
	struct netent *np;

	cp = 0;
	if (!nflag && inp->s_addr != INADDR_ANY) {
		int net = inet_netof(*inp);
		int lna = inet_lnaof(*inp);

		if (lna == INADDR_ANY) {
			np = getnetbyaddr(net, AF_INET);
			if (np)
				cp = np->n_name;
		}
		if (cp == 0) {
			hp = gethostbyaddr((char *)inp, sizeof (*inp), AF_INET);
			if (hp) {
				cp = hp->h_name;
				 //### trimdomain(cp, strlen(cp));
			}
		}
	}
	if (inp->s_addr == INADDR_ANY)
		strlcpy(line, "*", sizeof(line));
	else if (cp) {
		strncpy(line, cp, sizeof(line) - 1);
		line[sizeof(line) - 1] = '\0';
	} else {
		inp->s_addr = ntohl(inp->s_addr);
#define C(x)	((u_int)((x) & 0xff))
		snprintf(line, sizeof(line), "%u.%u.%u.%u", C(inp->s_addr >> 24),
		    C(inp->s_addr >> 16), C(inp->s_addr >> 8), C(inp->s_addr));
	}
	return (line);
}
