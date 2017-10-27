/*
 * Copyright (c) 2008-2009 Apple Inc. All rights reserved.
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
/*-
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

/*
 * Display protocol blocks in the unix domain.
 */
#include <sys/param.h>
#include <sys/queue.h>
#include <sys/socket.h>
#include <sys/socketvar.h>
#include <sys/mbuf.h>
#include <sys/sysctl.h>
#include <sys/un.h>
#include <sys/unpcb.h>

#include <netinet/in.h>

#include <errno.h>
#include <err.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include "netstat.h"

#if !TARGET_OS_EMBEDDED
static	void unixdomainpr __P((struct xunpcb64 *, struct xsocket64 *));
#else
static	void unixdomainpr __P((struct xunpcb *, struct xsocket *));
#endif

static	const char *const socktype[] =
    { "#0", "stream", "dgram", "raw" };

void
unixpr()
{
	char 	*buf;
	int	type;
	size_t	len;
	struct	xunpgen *xug, *oxug;
#if !TARGET_OS_EMBEDDED
	struct	xsocket64 *so;
	struct	xunpcb64 *xunp;
	char mibvar[sizeof "net.local.seqpacket.pcblist64"];
#else
	struct	xsocket *so;
	struct	xunpcb *xunp;
	char mibvar[sizeof "net.local.seqpacket.pcblist"];
#endif

	for (type = SOCK_STREAM; type <= SOCK_RAW; type++) {
#if !TARGET_OS_EMBEDDED
		snprintf(mibvar, sizeof(mibvar), "net.local.%s.pcblist64", socktype[type]);
#else
		snprintf(mibvar, sizeof(mibvar), "net.local.%s.pcblist", socktype[type]);
#endif
		len = 0;
		if (sysctlbyname(mibvar, 0, &len, 0, 0) < 0) {
			if (errno != ENOENT)
				warn("sysctl: %s", mibvar);
			continue;
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

		oxug = xug = (struct xunpgen *)buf;
		for (xug = (struct xunpgen *)((char *)xug + xug->xug_len);
		     xug->xug_len > sizeof(struct xunpgen);
		     xug = (struct xunpgen *)((char *)xug + xug->xug_len)) {
#if !TARGET_OS_EMBEDDED
			xunp = (struct xunpcb64 *)xug;
#else
			xunp = (struct xunpcb *)xug;
#endif
			so = &xunp->xu_socket;

			/* Ignore PCBs which were freed during copyout. */
#if !TARGET_OS_EMBEDDED
			if (xunp->xunp_gencnt > oxug->xug_gen)
#else
			if (xunp->xu_unp.unp_gencnt > oxug->xug_gen)
#endif
				continue;
			unixdomainpr(xunp, so);
		}
		if (xug != oxug && xug->xug_gen != oxug->xug_gen) {
			if (oxug->xug_count > xug->xug_count) {
				printf("Some %s sockets may have been deleted.\n",
				       socktype[type]);
			} else if (oxug->xug_count < xug->xug_count) {
				printf("Some %s sockets may have been created.\n",
			       socktype[type]);
			} else {
				printf("Some %s sockets may have been created or deleted\n",
			       socktype[type]);
			}
		}
		free(buf);
	}
}

static void
unixdomainpr(xunp, so)
#if !TARGET_OS_EMBEDDED
	struct xunpcb64 *xunp;
	struct xsocket64 *so;
#else
	struct xunpcb *xunp;
	struct xsocket *so;
#endif
{
#if TARGET_OS_EMBEDDED
	struct unpcb *unp;
#endif
	struct sockaddr_un *sa;
	static int first = 1;

#if !TARGET_OS_EMBEDDED
	sa = &xunp->xu_addr;
#else
	unp = &xunp->xu_unp;
	if (unp->unp_addr)
		sa = &xunp->xu_addr;
	else
		sa = (struct sockaddr_un *)0;
#endif

	if (first) {
		printf("Active LOCAL (UNIX) domain sockets\n");
		printf(
#if !TARGET_OS_EMBEDDED
"%-16.16s %-6.6s %-6.6s %-6.6s %16.16s %16.16s %16.16s %16.16s Addr\n",
#else
"%-8.8s %-6.6s %-6.6s %-6.6s %8.8s %8.8s %8.8s %8.8s Addr\n",
#endif
		    "Address", "Type", "Recv-Q", "Send-Q",
		    "Inode", "Conn", "Refs", "Nextref");
		first = 0;
	}
#if !TARGET_OS_EMBEDDED
	printf("%16lx %-6.6s %6u %6u %16lx %16lx %16lx %16lx",
	       (long)xunp->xu_unpp, socktype[so->so_type], so->so_rcv.sb_cc,
	       so->so_snd.sb_cc,
	       (long)xunp->xunp_vnode, (long)xunp->xunp_conn,
	       (long)xunp->xunp_refs, (long)xunp->xunp_reflink.le_next);
#else
	printf("%8lx %-6.6s %6u %6u %8lx %8lx %8lx %8lx",
	       (long)so->so_pcb, socktype[so->so_type], so->so_rcv.sb_cc,
	       so->so_snd.sb_cc,
	       (long)unp->unp_vnode, (long)unp->unp_conn,
	       (long)unp->unp_refs.lh_first, (long)unp->unp_reflink.le_next);
#endif

#if !TARGET_OS_EMBEDDED
	if (sa->sun_len)
#else
	if (sa)
#endif
		printf(" %.*s",
		    (int)(sa->sun_len - offsetof(struct sockaddr_un, sun_path)),
		    sa->sun_path);
	putchar('\n');
}
