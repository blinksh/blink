/*
 * Copyright (c) 2013 Apple Inc. All rights reserved.
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

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

#include <stdio.h>
#include <err.h>
#include <stdlib.h>
#include <strings.h>
#include <inttypes.h>

#include <sys/errno.h>
#include <sys/types.h>
#include <sys/sysctl.h>

#include <netinet/in.h>
#include <netinet/tcp.h>
#include <netinet/mptcp_var.h>

#include <arpa/inet.h>

#include "netstat.h"

/* XXX we can't include tcp_fsm.h because inet.c already includes it. */
static const char *tcpstates[] = {
        "CLOSED",       "LISTEN",       "SYN_SENT",     "SYN_RCVD",
        "ESTABLISHED",  "CLOSE_WAIT",   "FIN_WAIT_1",   "CLOSING",
        "LAST_ACK",     "FIN_WAIT_2",   "TIME_WAIT"
};

static const char *mptcpstates[] = {
	"CLOSED", "LISTEN", "ESTABLISHED", "CLOSE_WAIT", "FIN_WAIT_1",
	"CLOSING", "LAST_ACK", "FIN_WAIT_2", "TIME_WAIT", "TERMINATE"
};

int mptcp_done = 0;
extern void inetprint (struct in_addr *, int, char *, int);
extern void inet6print (struct in6_addr *, int, char *, int);

static void
printmptcp(int id, conninfo_mptcp_t *mptcp)
{
	int i;
	conninfo_tcp_t *tcpci;
	struct sockaddr_storage *src, *dst;
	mptcp_flow_t *flow;
	int af;

	printf("mptcp/%-2.2d  %-8.8x/%-8.8x %50s \n"
	    "      [tok(%#"PRIx32") snd(%#"PRIx64") rcv(%#"PRIx64") "
	    "aid(%d)]\n", id,
	    mptcp->mptcpci_mpte_flags, mptcp->mptcpci_flags,
	    mptcpstates[mptcp->mptcpci_state], mptcp->mptcpci_rtoken,
	    mptcp->mptcpci_sndnxt, mptcp->mptcpci_rcvnxt,
	    mptcp->mptcpci_mpte_addrid);

	flow = (mptcp_flow_t*)((caddr_t)mptcp + mptcp->mptcpci_flow_offset);

	for (i = 0; i < mptcp->mptcpci_nflows; i++) {
		src = &flow->flow_src;
		dst = &flow->flow_dst;
		af = src->ss_family;
		printf(" tcp%d/%-2.2d  ", af == AF_INET ? 4 : 6,
		    flow->flow_cid);
		printf("%-8.8x   ", flow->flow_flags);
#define SIN(x) ((struct sockaddr_in *)(x))
#define SIN6(x) ((struct sockaddr_in6 *)(x))
		switch (af) {
		case AF_INET:
			inetprint(&SIN(src)->sin_addr, SIN(src)->sin_port,
			    "tcp", nflag);
			inetprint(&SIN(dst)->sin_addr, SIN(dst)->sin_port,
			    "tcp", nflag);
			break;
#ifdef INET6
		case AF_INET6:
			inet6print(&SIN6(src)->sin6_addr, SIN6(src)->sin6_port,
			    "tcp", nflag);
			inet6print(&SIN6(dst)->sin6_addr, SIN6(dst)->sin6_port,
			    "tcp", nflag);
			break;
		}
#endif
#undef SIN
#undef SIN6
		tcpci = (conninfo_tcp_t*)((caddr_t)flow +
		    flow->flow_tcpci_offset);
		printf("%s \n"
		    "      [relseq(%-4.4d), err(%d)]\n",
		    tcpstates[tcpci->tcpci_tcp_info.tcpi_state],
		    flow->flow_relseq,
		    flow->flow_soerror);

		flow = (mptcp_flow_t*)((caddr_t)flow + flow->flow_len);
	}
}

void
mptcppr(uint32_t off, char *name, int af)
{
#pragma unused(off, name, af)
	const char *mibvar = "net.inet.mptcp.pcblist";
	size_t len = 0;
	conninfo_mptcp_t *mptcp;
	char *buf, *bufp;
	int id = 0;

	if (Lflag || Aflag || mptcp_done)
		return;
	mptcp_done = 1;

	if (sysctlbyname(mibvar, 0, &len, NULL, 0) < 0) {
		if (errno != ENOENT)
			warn("sysctl: %s", mibvar);
		return;
	}
	if ((buf = malloc(len)) == NULL) {
		warn("malloc");
		return;
	}
	if (sysctlbyname(mibvar, buf, &len, NULL, 0) < 0) {
		warn("sysctl: %s", mibvar);
		free(buf);
		return;
	}

	printf("Active Multipath Internet connections\n");
	printf("%-8.8s  %-9.9s  %-22.22s %-22.22s %-11.11s\n",
		"Proto/ID", "Flags",
		"Local Address", "Foreign Address",
		"(state)");

	bufp = buf;
	while (bufp < buf + len) {
		/* Sanity check */
		if (buf + len - bufp < sizeof(conninfo_mptcp_t))
			break;
		mptcp = (conninfo_mptcp_t *)bufp;
		printmptcp(id++, mptcp);
		bufp += mptcp->mptcpci_len;
	}
	free(buf);
}
