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
#include <sys/socket.h>
#include <sys/mbuf.h>
#include <sys/sysctl.h>

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include "netstat.h"

#define	YES	1
typedef int bool;

struct	mbstat mbstat;

static struct mbtypes {
	int	mt_type;
	char	*mt_name;
} mbtypes[] = {
	{ MT_DATA,	"data" },
	{ MT_OOBDATA,	"oob data" },
	{ MT_CONTROL,	"ancillary data" },
	{ MT_HEADER,	"packet headers" },
	{ MT_SOCKET,	"socket structures" },			/* XXX */
	{ MT_PCB,	"protocol control blocks" },		/* XXX */
	{ MT_RTABLE,	"routing table entries" },		/* XXX */
	{ MT_HTABLE,	"IMP host table entries" },		/* XXX */
	{ MT_ATABLE,	"address resolution tables" },
	{ MT_FTABLE,	"fragment reassembly queue headers" },	/* XXX */
	{ MT_SONAME,	"socket names and addresses" },
	{ MT_SOOPTS,	"socket options" },
	{ MT_RIGHTS,	"access rights" },
	{ MT_IFADDR,	"interface addresses" },		/* XXX */
	{ MT_TAG,		"packet tags" },		/* XXX */
	{ 0, 0 }
};

int nmbtypes = sizeof(mbstat.m_mtypes) / sizeof(short);
bool seen[256];			/* "have we seen this type yet?" */

mb_stat_t *mb_stat;
unsigned int njcl, njclbytes;
mleak_stat_t *mleak_stat;
struct mleak_table table;

#define	KERN_IPC_MB_STAT	"kern.ipc.mb_stat"
#define	KERN_IPC_NJCL		"kern.ipc.njcl"
#define	KERN_IPC_NJCL_BYTES	"kern.ipc.njclbytes"
#define	KERN_IPC_MLEAK_TABLE	"kern.ipc.mleak_table"
#define	KERN_IPC_MLEAK_TOP_TRACE "kern.ipc.mleak_top_trace"

#define	MB_STAT_HDR1 "\
class        buf   active   ctotal    total cache   cached uncached    memory\n\
name        size     bufs     bufs     bufs state     bufs     bufs     usage\n\
---------- ----- -------- -------- -------- ----- -------- -------- ---------\n\
"

#define	MB_STAT_HDR2 "\n\
class        waiter   notify    purge   wretry  nwretry  failure\n\
name          count    count    count    count    count    count\n\
---------- -------- -------- -------- -------- -------- --------\n\
"

#define MB_LEAK_HDR "\n\
    calltrace [1]       calltrace [2]       calltrace [3]       calltrace [4]       calltrace [5]      \n\
    ------------------  ------------------  ------------------  ------------------  ------------------ \n\
"

#define MB_LEAK_SPACING "                    "
static const char *mbpr_state(int);
static const char *mbpr_mem(u_int32_t);
static int mbpr_getdata(void);

/*
 * Print mbuf statistics.
 */
void
mbpr(void)
{
	unsigned long totmem = 0, totfree = 0, totmbufs, totused, totreturned = 0;
	double totpct;
	u_int32_t m_msize, m_mbufs = 0, m_clfree = 0, m_bigclfree = 0;
	u_int32_t m_mbufclfree = 0, m_mbufbigclfree = 0;
	u_int32_t m_16kclusters = 0, m_16kclfree = 0, m_mbuf16kclfree = 0;
	int i;
	struct mbtypes *mp;
	mb_class_stat_t *cp;

	if (mbpr_getdata() != 0)
		return;

	m_msize = mbstat.m_msize;
	cp = &mb_stat->mbs_class[0];
	for (i = 0; i < mb_stat->mbs_cnt; i++, cp++) {
		if (cp->mbcl_size == m_msize) {
			m_mbufs = cp->mbcl_active;
		} else if (cp->mbcl_size == mbstat.m_mclbytes) {
			m_clfree = cp->mbcl_total - cp->mbcl_active;
		} else if (cp->mbcl_size == mbstat.m_bigmclbytes) {
			m_bigclfree = cp->mbcl_total - cp->mbcl_active;
		} else if (njcl > 0 && cp->mbcl_size == njclbytes) {
			m_16kclfree = cp->mbcl_total - cp->mbcl_active;
			m_16kclusters = cp->mbcl_total;
		} else if (cp->mbcl_size == (m_msize + mbstat.m_mclbytes)) {
			m_mbufclfree = cp->mbcl_total - cp->mbcl_active;
		} else if (cp->mbcl_size == (m_msize + mbstat.m_bigmclbytes)) {
			m_mbufbigclfree = cp->mbcl_total - cp->mbcl_active;
		} else if (njcl > 0 && cp->mbcl_size == (m_msize + njclbytes)) {
			m_mbuf16kclfree = cp->mbcl_total - cp->mbcl_active;
		}
	}

	/* adjust free counts to include composite caches */
	m_clfree += m_mbufclfree;
	m_bigclfree += m_mbufbigclfree;
	m_16kclfree += m_mbuf16kclfree;

	cp = &mb_stat->mbs_class[0];
	for (i = 0; i < mb_stat->mbs_cnt; i++, cp++) {
		u_int32_t mem;

		mem = cp->mbcl_ctotal * cp->mbcl_size;
		totmem += mem;
		totreturned += cp->mbcl_release_cnt;
		totfree += (cp->mbcl_mc_cached + cp->mbcl_infree) *
		    cp->mbcl_size;
		if (mflag > 1) {
			if (i == 0)
				printf(MB_STAT_HDR1);

			if (njcl == 0 &&
			    cp->mbcl_size > (m_msize + mbstat.m_bigmclbytes))
				continue;

			printf("%-10s %5u %8u %8u %8u %5s %8u %8u %9s\n",
			    cp->mbcl_cname, cp->mbcl_size, cp->mbcl_active,
			    cp->mbcl_ctotal, cp->mbcl_total,
			    mbpr_state(cp->mbcl_mc_state), cp->mbcl_mc_cached,
			    cp->mbcl_infree, mbpr_mem(mem));
		}
	}

	cp = &mb_stat->mbs_class[0];
	for (i = 0; i < mb_stat->mbs_cnt; i++, cp++) {
		if (mflag > 2) {
			if (i == 0)
				printf(MB_STAT_HDR2);

			if (njcl == 0 &&
			    cp->mbcl_size > (m_msize + mbstat.m_bigmclbytes))
				continue;

			printf("%-10s %8u %8llu %8llu %8u %8u %8llu\n",
			    cp->mbcl_cname, cp->mbcl_mc_waiter_cnt,
			    cp->mbcl_notified, cp->mbcl_purge_cnt,
			    cp->mbcl_mc_wretry_cnt, cp->mbcl_mc_nwretry_cnt,
			    cp->mbcl_fail_cnt);
		}
	}

	if (mflag > 1)
		printf("\n");

	totmbufs = 0;
	for (mp = mbtypes; mp->mt_name; mp++)
		totmbufs += mbstat.m_mtypes[mp->mt_type];
	/*
	 * These stats are not updated atomically in the kernel;
	 * adjust the total as neeeded.
	 */
	if (totmbufs > m_mbufs)
		totmbufs = m_mbufs;
	printf("%lu/%u mbufs in use:\n", totmbufs, m_mbufs);
	for (mp = mbtypes; mp->mt_name; mp++)
		if (mbstat.m_mtypes[mp->mt_type]) {
			seen[mp->mt_type] = YES;
			printf("\t%u mbufs allocated to %s\n",
			    mbstat.m_mtypes[mp->mt_type], mp->mt_name);
		}
	seen[MT_FREE] = YES;
	for (i = 0; i < nmbtypes; i++)
		if (!seen[i] && mbstat.m_mtypes[i]) {
			printf("\t%u mbufs allocated to <mbuf type %d>\n",
			    mbstat.m_mtypes[i], i);
		}
	if ((m_mbufs - totmbufs) > 0)
		printf("\t%lu mbufs allocated to caches\n",
		    m_mbufs - totmbufs);
	printf("%u/%u mbuf 2KB clusters in use\n",
	       (unsigned int)(mbstat.m_clusters - m_clfree),
	       (unsigned int)mbstat.m_clusters);
	printf("%u/%u mbuf 4KB clusters in use\n",
	       (unsigned int)(mbstat.m_bigclusters - m_bigclfree),
	       (unsigned int)mbstat.m_bigclusters);
	if (njcl > 0) {
		printf("%u/%u mbuf %uKB clusters in use\n",
		    m_16kclusters - m_16kclfree, m_16kclusters,
		    njclbytes/1024);
	}
	totused = totmem - totfree;
	if (totmem == 0)
		totpct = 0;
	else if (totused < (ULONG_MAX/100))
		totpct = (totused * 100)/(double)totmem;
	else {
		u_long totmem1 = totmem/100;
		u_long totused1 = totused/100;
		totpct = (totused1 * 100)/(double)totmem1;
	}
	printf("%lu KB allocated to network (%.1f%% in use)\n",
		totmem / 1024, totpct);
	printf("%lu KB returned to the system\n", totreturned / 1024);

	printf("%u requests for memory denied\n", (unsigned int)mbstat.m_drops);
	printf("%u requests for memory delayed\n", (unsigned int)mbstat.m_wait);
	printf("%u calls to drain routines\n", (unsigned int)mbstat.m_drain);

	free(mb_stat);
	mb_stat = NULL;

	if (mleak_stat != NULL) {
		mleak_trace_stat_t *mltr;

		printf("\nmbuf leak detection table:\n");
		printf("\ttotal captured: %u (one per %u)\n"
		    "\ttotal allocs outstanding: %llu\n"
		    "\tnew hash recorded: %llu allocs, %llu traces\n"
		    "\thash collisions: %llu allocs, %llu traces\n"
		    "\toverwrites: %llu allocs, %llu traces\n"
		    "\tlock conflicts: %llu\n\n",
		    table.mleak_capture / table.mleak_sample_factor,
		    table.mleak_sample_factor,
		    table.outstanding_allocs,
		    table.alloc_recorded, table.trace_recorded,
		    table.alloc_collisions, table.trace_collisions,
		    table.alloc_overwrites, table.trace_overwrites,
		    table.total_conflicts);

		printf("top %d outstanding traces:\n", mleak_stat->ml_cnt);
		for (i = 0; i < mleak_stat->ml_cnt; i++) {
			mltr = &mleak_stat->ml_trace[i];
			printf("[%d] %llu outstanding alloc(s), "
			    "%llu hit(s), %llu collision(s)\n", (i + 1),
			    mltr->mltr_allocs, mltr->mltr_hitcount,
			    mltr->mltr_collisions);
		}

		printf(MB_LEAK_HDR);
		for (i = 0; i < MLEAK_STACK_DEPTH; i++) {
			int j;

			printf("%2d: ", (i + 1));
			for (j = 0; j < mleak_stat->ml_cnt; j++) {
				mltr = &mleak_stat->ml_trace[j];
				if (i < mltr->mltr_depth) {
					if (mleak_stat->ml_isaddr64) {
						printf("0x%0llx  ",
						    mltr->mltr_addr[i]);
					} else {
						printf("0x%08x          ",
						    (u_int32_t)mltr->mltr_addr[i]);
					}
				} else {
					printf(MB_LEAK_SPACING);
				}
			}
			printf("\n");
		}
		free(mleak_stat);
		mleak_stat = NULL;
	}
}

static const char *
mbpr_state(int state)
{
	char *msg = "?";

	switch (state) {
	case MCS_DISABLED:
		msg = "dis";
		break;

	case MCS_ONLINE:
		msg = "on";
		break;

	case MCS_PURGING:
		msg = "purge";
		break;

	case MCS_OFFLINE:
		msg = "off";
		break;
	}
	return (msg);
}

static const char *
mbpr_mem(u_int32_t bytes)
{
	static char buf[33];
	double mem = bytes;

	if (mem < 1024) {
		(void) snprintf(buf, sizeof (buf), "%d", (int)mem);
	} else if ((mem /= 1024) < 1024) {
		(void) snprintf(buf, sizeof (buf), "%.1f KB", mem);
	} else {
		mem /= 1024;
		(void) snprintf(buf, sizeof (buf), "%.1f MB", mem);
	}
	return (buf);
}

static int
mbpr_getdata(void)
{
	size_t len;
	int error = -1;

	if (nmbtypes != 256) {
		(void) fprintf(stderr,
		    "netstat: unexpected change to mbstat; check source\n");
		goto done;
	}

	len = sizeof(mbstat);
	if (sysctlbyname("kern.ipc.mbstat", &mbstat, &len, 0, 0) == -1)
		goto done;

	if (sysctlbyname(KERN_IPC_MB_STAT, NULL, &len, 0, 0) == -1) {
		(void) fprintf(stderr,
		    "Error retrieving length for %s\n", KERN_IPC_MB_STAT);
		goto done;
	}

	mb_stat = calloc(1, len);
	if (mb_stat == NULL) {
		(void) fprintf(stderr,
		    "Error allocating %lu bytes for sysctl data\n", len);
		goto done;
	}

	if (sysctlbyname(KERN_IPC_MB_STAT, mb_stat, &len, 0, 0) == -1) {
		(void) fprintf(stderr,
		     "Error %d getting %s\n", errno, KERN_IPC_MB_STAT);
		goto done;
	}

	if (mb_stat->mbs_cnt == 0) {
		(void) fprintf(stderr,
		    "Invalid mbuf class count (%d)\n", mb_stat->mbs_cnt);
		goto done;
	}

	/* mbuf leak detection! */
	if (mflag > 3) {
		errno = 0;
		len = sizeof (table);
		if (sysctlbyname(KERN_IPC_MLEAK_TABLE, &table, &len, 0, 0) ==
		    -1 && errno != ENXIO) {
			(void) fprintf(stderr, "error %d getting %s\n", errno,
			    KERN_IPC_MLEAK_TABLE);
			goto done;
		} else if (errno == ENXIO) {
			(void) fprintf(stderr, "mbuf leak detection is not "
			    "enabled in the kernel.\n");
			goto skip;
		}

		if (sysctlbyname(KERN_IPC_MLEAK_TOP_TRACE, NULL, &len,
		    0, 0) == -1) {
			(void) fprintf(stderr, "Error retrieving length for "
			    "%s: %d\n", KERN_IPC_MB_STAT, errno);
			goto done;
		}

		mleak_stat = calloc(1, len);
		if (mleak_stat == NULL) {
			(void) fprintf(stderr, "Error allocating %lu bytes "
			    "for sysctl data\n", len);
			goto done;
		}

		if (sysctlbyname(KERN_IPC_MLEAK_TOP_TRACE, mleak_stat, &len,
		    0, 0) == -1) {
			(void) fprintf(stderr, "error %d getting %s\n", errno,
			     KERN_IPC_MLEAK_TOP_TRACE);
			goto done;
		}
	}

skip:
	len = sizeof (njcl);
	(void) sysctlbyname(KERN_IPC_NJCL, &njcl, &len, 0, 0);
	len = sizeof (njclbytes);
	(void) sysctlbyname(KERN_IPC_NJCL_BYTES, &njclbytes, &len, 0, 0);

	error = 0;

done:
	if (error != 0  && mb_stat != NULL) {
		free(mb_stat);
		mb_stat = NULL;
	}

	if (error != 0 && mleak_stat != NULL) {
		free(mleak_stat);
		mleak_stat = NULL;
	}

	return (error);
}
