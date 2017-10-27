/*
 * Copyright (c) 2014-2015 Apple Inc. All rights reserved.
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

#include <sys/param.h>
#include <sys/queue.h>
#include <sys/socket.h>
#include <sys/socketvar.h>
#include <sys/sysctl.h>
#include <sys/sys_domain.h>
#include <sys/kern_control.h>
#include <sys/kern_event.h>
#include <net/ntstat.h>

#include <errno.h>
#include <err.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>

#include "netstat.h"

#define ROUNDUP64(a) \
((a) > 0 ? (1 + (((a) - 1) | (sizeof(uint64_t) - 1))) : sizeof(uint64_t))
#define ADVANCE64(x, n) (((char *)x) += ROUNDUP64(n))

struct xgen_n {
	u_int32_t	xgn_len;			/* length of this structure */
	u_int32_t	xgn_kind;		/* number of PCBs at this time */
};

#define	ALL_XGN_KIND_KCREG (XSO_KCREG)
#define	ALL_XGN_KIND_EVT (XSO_SOCKET | XSO_RCVBUF | XSO_SNDBUF | XSO_STATS | XSO_EVT)
#define	ALL_XGN_KIND_KCB (XSO_SOCKET | XSO_RCVBUF | XSO_SNDBUF | XSO_STATS | XSO_KCB)

void
systmpr(uint32_t proto,
	char *name, int af)
{
	const char *mibvar;
	size_t len;
	char *buf, *next;
	struct xsystmgen *xig, *oxig;
	struct xgen_n *xgn;
	int which = 0;
	struct xsocket_n *so = NULL;
	struct xsockbuf_n *so_rcv = NULL;
	struct xsockbuf_n *so_snd = NULL;
	struct xsockstat_n *so_stat = NULL;
	struct xkctl_reg *kctl = NULL;
	struct xkctlpcb *kcb = NULL;
	struct xkevtpcb *kevb = NULL;
	int first = 1;
	
	switch (proto) {
		case SYSPROTO_EVENT:
                        mibvar = "net.systm.kevt.pcblist";
			break;
		case SYSPROTO_CONTROL:
			mibvar = "net.systm.kctl.pcblist";
			break;
		case 0:
			mibvar = "net.systm.kctl.reg_list";
			break;
		default:
			mibvar = NULL;
			break;
	}
	if (mibvar == NULL)
		return;
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
	if (len <= sizeof(struct xsystmgen)) {
		free(buf);
		return;
	}
	oxig = xig = (struct xsystmgen *)buf;
	for (next = buf + ROUNDUP64(xig->xg_len); next < buf + len;
	     next += ROUNDUP64(xgn->xgn_len)) {
		xgn = (struct xgen_n*)next;
		if (xgn->xgn_len <= sizeof(struct xsystmgen))
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
				case XSO_KCREG:
					kctl = (struct xkctl_reg *)xgn;
					break;
				case XSO_KCB:
					kcb = (struct xkctlpcb *)xgn;
					break;
				case XSO_EVT:
					kevb = (struct xkevtpcb *)xgn;
					break;
				default:
					printf("unexpected kind %d\n", xgn->xgn_kind);
					break;
			}
		} else {
			if (vflag)
				printf("got %d twice\n", xgn->xgn_kind);
		}
		
		if (which == ALL_XGN_KIND_KCREG) {
			which = 0;
			
			if (first) {
				printf("Registered kernel control modules\n");
				if (Aflag)
					printf("%-16.16s ", "kctlref");
				printf("%-8.8s ", "id");
				if (Aflag)
					printf("%-8.8s ", "unit");
				printf("%-8.8s ", "flags");
				printf("%-8.8s ", "pcbcount");
				printf("%-8.8s ", "rcvbuf");
				printf("%-8.8s ", "sndbuf");
				printf("%s ", "name");
				printf("\n");
				first = 0;
			}
			if (Aflag)
				printf("%16llx ", kctl->xkr_kctlref);
			printf("%8x ", kctl->xkr_id);
			if (Aflag)
				printf("%8d ", kctl->xkr_reg_unit);
			printf("%8x ", kctl->xkr_flags);
			printf("%8d ", kctl->xkr_pcbcount);
			printf("%8d ", kctl->xkr_recvbufsize);
			printf("%8d ", kctl->xkr_sendbufsize);
			printf("%s ", kctl->xkr_name);
			printf("\n");
		} else if (which == ALL_XGN_KIND_KCB) {
			which = 0;
			
			if (first) {
				printf("Active kernel control sockets\n");
				if (Aflag)
					printf("%16.16s ", "pcb");
				printf("%-5.5s %-6.6s %-6.6s ",
				        "Proto", "Recv-Q", "Send-Q");
				if (bflag > 0)
					printf("%10.10s %10.10s ",
					      "rxbytes", "txbytes");
				if (vflag > 0)
					printf("%6.6s %6.6s %6.6s %6.6s ",
					       "rhiwat", "shiwat", "pid", "epid");
				printf("%6.6s ", "unit");
				printf("%6.6s ", "id");
				printf("%s", "name");
				printf("\n");
				first = 0;
			}
			if (Aflag)
				printf("%16llx ", kcb->xkp_kctpcb);
			printf("%-5.5s %6u %6u ", name,
			       so_rcv->sb_cc,
			       so_snd->sb_cc);
			if (bflag > 0) {
				int i;
				u_int64_t rxbytes = 0;
				u_int64_t txbytes = 0;
				
				for (i = 0; i < SO_TC_STATS_MAX; i++) {
					rxbytes += so_stat->xst_tc_stats[i].rxbytes;
					txbytes += so_stat->xst_tc_stats[i].txbytes;
				}
				printf("%10llu %10llu ", rxbytes, txbytes);
			}
			if (vflag > 0) {
				printf("%6u %6u %6u %6u ",
				       so_rcv->sb_hiwat,
				       so_snd->sb_hiwat,
				       so->so_last_pid,
				       so->so_e_pid);
			}
			printf("%6d ", kcb->xkp_unit);
			printf("%6d ", kcb->xkp_kctlid);
			printf("%s", kcb->xkp_kctlname);
			printf("\n");
			
		} else if (which == ALL_XGN_KIND_EVT) {
			which = 0;
			if (first) {
				printf("Active kernel event sockets\n");
				if (Aflag)
					printf("%16.16s ", "pcb");
				printf("%-5.5s %-6.6s %-6.6s ",
				       "Proto", "Recv-Q", "Send-Q");
				printf("%6.6s ", "vendor");
				printf("%6.6s ", "class");
				printf("%6.6s", "subclass");
				if (bflag > 0)
					printf("%10.10s %10.10s ",
					       "rxbytes", "txbytes");
				if (vflag > 0)
					printf("%6.6s %6.6s %6.6s %6.6s",
					       "rhiwat", "shiwat", "pid", "epid");
				printf("\n");
				first = 0;
			}
			if (Aflag)
				printf("%16llx ", kevb->kep_evtpcb);
			printf("%-5.5s %6u %6u ", name,
			       so_rcv->sb_cc,
			       so_snd->sb_cc);
			printf("%6d ", kevb->kep_vendor_code_filter);
			printf("%6d ", kevb->kep_class_filter);
			printf("%6d", kevb->kep_subclass_filter);
			if (bflag > 0) {
				int i;
				u_int64_t rxbytes = 0;
				u_int64_t txbytes = 0;
				
				for (i = 0; i < SO_TC_STATS_MAX; i++) {
					rxbytes += so_stat->xst_tc_stats[i].rxbytes;
					txbytes += so_stat->xst_tc_stats[i].txbytes;
				}
				printf("%10llu %10llu ", rxbytes, txbytes);
			}
			if (vflag > 0) {
				printf("%6u %6u %6u %6u",
				       so_rcv->sb_hiwat,
				       so_snd->sb_hiwat,
				       so->so_last_pid,
				       so->so_e_pid);
			}
			printf("\n");
		}
			
	}
	if (xig != oxig && xig->xg_gen != oxig->xg_gen) {
		if (oxig->xg_count > xig->xg_count) {
			printf("Some %s sockets may have been deleted.\n",
			       name);
		} else if (oxig->xg_count < xig->xg_count) {
			printf("Some %s sockets may have been created.\n",
			       name);
		} else {
			printf("Some %s sockets may have been created or deleted",
			       name);
		}
	}
	free(buf);
}

void
kctl_stats(uint32_t off __unused, char *name, int af __unused)
{
	static struct kctlstat pkctlstat;
	struct kctlstat kctlstat;
	size_t len = sizeof(struct kctlstat);
	const char *mibvar = "net.systm.kctl.stats";
	
	if (sysctlbyname(mibvar, &kctlstat, &len, 0, 0) < 0) {
		warn("sysctl: %s", mibvar);
		return;
	}
	if (interval && vflag > 0)
		print_time();
	printf ("%s:\n", name);
	
#define	STATDIFF(f) (kctlstat.f - pkctlstat.f)
#define	p(f, m) if (STATDIFF(f) || sflag <= 1) \
	printf(m, STATDIFF(f), plural(STATDIFF(f)))
#define	p1a(f, m) if (STATDIFF(f) || sflag <= 1) \
	printf(m, STATDIFF(f))
	
	p(kcs_reg_total, "\t%llu total kernel control module%s registered\n");
	p(kcs_reg_count, "\t%llu current kernel control module%s registered\n");
	p(kcs_pcbcount, "\t%llu current kernel control socket%s\n");
	p1a(kcs_gencnt, "\t%llu kernel control generation count\n");
	p(kcs_connections, "\t%llu connection attempt%s\n");
	p(kcs_conn_fail, "\t%llu connection failure%s\n");
	p(kcs_send_fail, "\t%llu send failure%s\n");
	p(kcs_send_list_fail, "\t%llu send list failure%s\n");
	p(kcs_enqueue_fail, "\t%llu enqueue failure%s\n");
	p(kcs_enqueue_fullsock, "\t%llu packet%s dropped due to full socket buffers\n");
	
#undef STATDIFF
#undef p
#undef p1a
	
	if (interval > 0)
		bcopy(&kctlstat, &pkctlstat, len);
}

void
kevt_stats(uint32_t off __unused, char *name, int af __unused)
{
	static struct kevtstat pkevtstat;
	struct kevtstat kevtstat;
	size_t len = sizeof(struct kevtstat);
	const char *mibvar = "net.systm.kevt.stats";
	
	if (sysctlbyname(mibvar, &kevtstat, &len, 0, 0) < 0) {
		warn("sysctl: %s", mibvar);
		return;
	}
	if (interval && vflag > 0)
		print_time();
	printf ("%s:\n", name);
	
#define	STATDIFF(f) (kevtstat.f - pkevtstat.f)
#define	p(f, m) if (STATDIFF(f) || sflag <= 1) \
	printf(m, STATDIFF(f), plural(STATDIFF(f)))
#define	p1a(f, m) if (STATDIFF(f) || sflag <= 1) \
	printf(m, STATDIFF(f))
	
	p(kes_pcbcount, "\t%llu current kernel control socket%s\n");
	p1a(kes_gencnt, "\t%llu kernel control generation count\n");
	p(kes_badvendor, "\t%llu bad vendor failure%s\n");
	p(kes_toobig, "\t%llu message too big failure%s\n");
	p(kes_nomem, "\t%llu out of memory failure%s\n");
	p(kes_fullsock, "\t%llu message%s dropped due to full socket buffers\n");
	p(kes_posted, "\t%llu message%s posted\n");

#undef STATDIFF
#undef p
#undef p1a

	if (interval > 0)
		bcopy(&kevtstat, &pkevtstat, len);
}

void
print_extbkidle_stats(uint32_t off __unused, char *name, int af __unused)
{
	static struct soextbkidlestat psoextbkidlestat;
	struct soextbkidlestat soextbkidlestat;
	size_t len = sizeof(struct soextbkidlestat);
	const char *mibvar = "kern.ipc.extbkidlestat";
	
	if (sysctlbyname(mibvar, &soextbkidlestat, &len, 0, 0) < 0) {
		warn("sysctl: %s", mibvar);
		return;
	}

#define	STATDIFF(f) (soextbkidlestat.f - psoextbkidlestat.f)
#define	p(f, m) if (STATDIFF(f) || sflag <= 1) \
    printf(m, STATDIFF(f), plural(STATDIFF(f)))
#define	p1a(f, m) if (STATDIFF(f) || sflag <= 1) \
    printf(m, STATDIFF(f))
	
	if (interval && vflag > 0)
		print_time();
	printf ("%s:\n", name);
	
	p1a(so_xbkidle_maxperproc, "\t%u max per process\n");
	p1a(so_xbkidle_time, "\t%u maximum time (seconds)\n");
	p1a(so_xbkidle_rcvhiwat, "\t%u high water mark\n");
	p(so_xbkidle_notsupp, "\t%u socket option not supported failure%s\n");
	p(so_xbkidle_toomany, "\t%u too many sockets failure%s\n");
	p(so_xbkidle_wantok, "\t%u total socket%s requested OK\n");
	p(so_xbkidle_active, "\t%u extended bk idle socket%s\n");
	p(so_xbkidle_nocell, "\t%u no cellular failure%s\n");
	p(so_xbkidle_notime, "\t%u no time failures%s\n");
	p(so_xbkidle_forced, "\t%u forced defunct socket%s\n");
	p(so_xbkidle_resumed, "\t%u resumed socket%s\n");
	p(so_xbkidle_expired, "\t%u timeout expired failure%s\n");
	p1a(so_xbkidle_expired, "\t%u timer rescheduled\n");
	p(so_xbkidle_nodlgtd, "\t%u no delegated failure%s\n");

#undef STATDIFF
#undef p
#undef p1a
}

void
print_nstat_stats(uint32_t off __unused, char *name, int af __unused)
{
	static struct nstat_stats pnstat_stats;
	struct nstat_stats nstat_stats;
	size_t len = sizeof(struct nstat_stats);
	const char *mibvar = "net.stats.stats";
	
	if (sysctlbyname(mibvar, &nstat_stats, &len, 0, 0) < 0) {
		warn("sysctl: %s", mibvar);
		return;
	}
	
#define	STATDIFF(f) (nstat_stats.f - pnstat_stats.f)
#define	p(f, m) if (STATDIFF(f) || sflag <= 1) \
printf(m, STATDIFF(f), plural(STATDIFF(f)))
#define	p1a(f, m) if (STATDIFF(f) || sflag <= 1) \
printf(m, STATDIFF(f))
	
	if (interval && vflag > 0)
		print_time();
	printf ("%s:\n", name);
	
	p(nstat_successmsgfailures, "\t%u enqueue success message failure%s\n");
	p(nstat_sendcountfailures, "\t%u enqueue source counts message failure%s\n");
	p(nstat_sysinfofailures, "\t%u enqueue sysinfo message failure%s\n");
	p(nstat_srcupatefailures, "\t%u enqueue source udpate message failure%s\n");
	p(nstat_descriptionfailures, "\t%u enqueue description message failure%s\n");
	p(nstat_msgremovedfailures, "\t%u enqueue remove message failure%s\n");
	p(nstat_srcaddedfailures, "\t%u enqueue source added message failure%s\n");
	p(nstat_msgerrorfailures, "\t%u enqueue error message failure%s\n");
	p(nstat_copy_descriptor_failures, "\t%u copy descriptor failure%s\n");
	p(nstat_provider_counts_failures, "\t%u provider counts failure%s\n");
	p(nstat_control_send_description_failures, "\t%u control send description failure%s\n");
	p(nstat_control_send_goodbye_failures, "\t%u control send goodbye failure%s\n");
	p(nstat_flush_accumulated_msgs_failures, "\t%u flush accumulated messages failure%s\n");
	p(nstat_accumulate_msg_failures, "\t%u accumulated message failure%s\n");
	p(nstat_control_cleanup_source_failures, "\t%u control cleanup source failure%s\n");
	p(nstat_handle_msg_failures, "\t%u handle message failure%s\n");

#undef STATDIFF
#undef p
#undef p1a
}
