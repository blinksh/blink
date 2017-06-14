/*
 * Copyright (c) 1994 SigmaSoft, Th. Lockert <tholo@sigmasoft.com>
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
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <sys/cdefs.h>

#include <assert.h>
#include <err.h>
#include <fcntl.h>
#include <grp.h>
#include <nlist.h>
#include <limits.h>
#include <paths.h>
#include <pwd.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sysexits.h>

#include "sys/types.h"
#include <sys/ucred.h>
#include <sys/time.h>
#include <sys/proc.h>
#include <sys/param.h>
#include <sys/sysctl.h>
#include <errno.h>
#include "sys/ipcs.h"
#define KERNEL 1		/* To get new ipc_perm and __(sem|shm|msg)ds_new */
#include "sys/ipc.h"
#include "sys/sem_internal.h"
#include "sys/shm_internal.h"
#include "sys/msg.h"


/* The following is a kludge, until the problem of multiple inclusions
   of ipc.h is taken care of. */
#ifndef IXSEQ_TO_IPCID
#define IXSEQ_TO_IPCID(ix,perm) (((perm._seq) << 16L) | (ix & 0xffff))
#endif

static char   *
fmt_perm(u_short mode, char write_char)
{
	static char buffer[100];

	buffer[0] = '-';
	buffer[1] = '-';
	buffer[2] = ((mode & 0400) ? 'r' : '-');
	buffer[3] = ((mode & 0200) ? write_char : '-');
	buffer[4] = '-';
	buffer[5] = ((mode & 0040) ? 'r' : '-');
	buffer[6] = ((mode & 0020) ? write_char : '-');
	buffer[7] = '-';
	buffer[8] = ((mode & 0004) ? 'r' : '-');
	buffer[9] = ((mode & 0002) ? write_char : '-');
	buffer[10] = '-';
	buffer[11] = '\0';
	return (&buffer[0]);
}

static void
cvt_time(time_t t, char *buf)
{
	struct tm *tm;

	if (t == 0) {
		strcpy(buf, "no-entry");
	} else {
		tm = localtime(&t);
		if (tm != NULL) {
			sprintf(buf, "%2d:%02d:%02d",
				tm->tm_hour, tm->tm_min, tm->tm_sec);
		}
	}
}
#define	SHMINFO		1
#define	SHMTOTAL	2
#define	MSGINFO		4
#define	MSGTOTAL	8
#define	SEMINFO		16
#define	SEMTOTAL	32

#define BIGGEST		1
#define CREATOR		2
#define OUTSTANDING	4
#define PID		8
#define TIME		16

static void
usage(void)
{
	errx(EX_USAGE, "%s","usage: ipcs [-abcmopqstMQST]\n");
}

int
main(argc, argv)
	int     argc;
	char   *argv[];
{
	int     display = 0;
	int     option = 0;
	int	exit_val = 0;
	time_t	now;
	char	datestring[100];
	int	i;

	while ((i = getopt(argc, argv, "MmQqSsabcoptT")) != -1)
		switch (i) {
		case 'M':
			display = SHMTOTAL;
			break;
		case 'm':
			display |= SHMINFO;
			break;
		case 'Q':
			display = MSGTOTAL;
			break;
		case 'q':
			display |= MSGINFO;
			break;
		case 'S':
			display = SEMTOTAL;
			break;
		case 's':
			display |= SEMINFO;
			break;
		case 'T':
			display = SHMTOTAL | MSGTOTAL | SEMTOTAL;
			break;
		case 'a':
			option |= BIGGEST | CREATOR | OUTSTANDING | PID | TIME;
			break;
		case 'b':
			option |= BIGGEST;
			break;
		case 'c':
			option |= CREATOR;
			break;
		case 'o':
			option |= OUTSTANDING;
			break;
		case 'p':
			option |= PID;
			break;
		case 't':
			option |= TIME;
			break;
		default:
			usage();
		}
	if (display == 0)
		display = SHMINFO | MSGINFO | SEMINFO;
	now = time(0);
	struct tm* tm = localtime(&now);
	if (tm == NULL) {
		now = 0;
		tm = localtime(&now);
	}
	if (0 == strftime(datestring, sizeof(datestring), "%a %b %e %H:%M:%S %Z %Y", tm))
	    errx(1, "strftime failed\n");
	printf("IPC status from <running system> as of %s\n", datestring);
	if ((display & (MSGINFO | MSGTOTAL))) {
		if (display & MSGTOTAL) {
			struct IPCS_command ic;
			struct msginfo msginfo;
			size_t ic_size = sizeof(ic);

			ic.ipcs_magic = IPCS_MAGIC;
			ic.ipcs_op = IPCS_MSG_CONF;
			ic.ipcs_cursor = 0;	/* 0 for fw. compat. */
			ic.ipcs_data = &msginfo;
			ic.ipcs_datalen = sizeof(msginfo);

			if (sysctlbyname(IPCS_MSG_SYSCTL, &ic, &ic_size, &ic, ic_size)) {
				if (errno != EPERM) {
					char buffer[1024];
					snprintf(buffer, 1024, "sysctlbyname(IPCS_MSG_SYSCTL, op=CONF, &ic, &%ld) datalen=%d",
						 sizeof(ic), ic.ipcs_datalen);
					perror(buffer);
				} else
					perror("sysctlbyname IPCS_MSG_SYSCTL");
			}

			printf("msginfo:\n");
			printf("\tmsgmax: %6d\t(max characters in a message)\n",
			    msginfo.msgmax);
			printf("\tmsgmni: %6d\t(# of message queues)\n",
			    msginfo.msgmni);
			printf("\tmsgmnb: %6d\t(max characters in a message queue)\n",
			    msginfo.msgmnb);
			printf("\tmsgtql: %6d\t(max # of messages in system)\n",
			    msginfo.msgtql);
			printf("\tmsgssz: %6d\t(size of a message segment)\n",
			    msginfo.msgssz);
			printf("\tmsgseg: %6d\t(# of message segments in system)\n\n",
			    msginfo.msgseg);
		}
		if (display & MSGINFO) {
			struct IPCS_command ic;
			struct __msqid_ds_new ds;
			struct __msqid_ds_new *msqptr = &ds;
			size_t ic_size = sizeof(ic);

			printf("T     ID     KEY        MODE       OWNER    GROUP");
			if (option & CREATOR)
				printf("  CREATOR   CGROUP");
			if (option & OUTSTANDING)
				printf(" CBYTES  QNUM");
			if (option & BIGGEST)
				printf(" QBYTES");
			if (option & PID)
				printf(" LSPID LRPID");
			if (option & TIME)
				printf("   STIME    RTIME    CTIME");
			printf("\nMessage Queues:\n");

			ic.ipcs_magic = IPCS_MAGIC;
			ic.ipcs_op = IPCS_MSG_ITER;
			ic.ipcs_cursor = 0;	/* start */
			ic.ipcs_datalen = sizeof(*msqptr);
			ic.ipcs_data = msqptr;

			memset(msqptr, 0, sizeof(*msqptr));

			while(!(sysctlbyname(IPCS_MSG_SYSCTL, &ic, &ic_size, &ic, ic_size))) {
				ic.ipcs_data = msqptr;

				if (msqptr->msg_qbytes != 0) {
					char    stime_buf[100], rtime_buf[100],
					        ctime_buf[100];

					cvt_time(msqptr->msg_stime, stime_buf);
					cvt_time(msqptr->msg_rtime, rtime_buf);
					cvt_time(msqptr->msg_ctime, ctime_buf);

					printf("q %6d 0x%08x %s %8s %8s",
					       IXSEQ_TO_IPCID((ic.ipcs_cursor-1), msqptr->msg_perm),
					    (int)msqptr->msg_perm._key,
					    fmt_perm(msqptr->msg_perm.mode, 'w'),
					    user_from_uid(msqptr->msg_perm.uid, 0),
					    group_from_gid(msqptr->msg_perm.gid, 0));

					if (option & CREATOR)
						printf(" %8s %8s",
						    user_from_uid(msqptr->msg_perm.cuid, 0),
						    group_from_gid(msqptr->msg_perm.cgid, 0));

					if (option & OUTSTANDING)
						printf(" %6lu %6lu",
						    msqptr->msg_cbytes,
						    msqptr->msg_qnum);

					if (option & BIGGEST)
						printf(" %6lu",
						    msqptr->msg_qbytes);

					if (option & PID)
						printf(" %6d %6d",
						    msqptr->msg_lspid,
						    msqptr->msg_lrpid);

					if (option & TIME)
						printf(" %s %s %s",
						    stime_buf,
						    rtime_buf,
						    ctime_buf);

					printf("\n");
				}
				memset(msqptr, 0, sizeof(*msqptr));
				errno = 0;
			}

			if (errno != ENOENT && errno != ERANGE) {
				if (errno != EPERM) {
					errx(1, "sysctlbyname(IPCS_MSG_SYSCTL, op=ITER, &ic, &%ld) datalen=%d failed:%s\n",
						 sizeof(ic), ic.ipcs_datalen, strerror(errno));
				} else
					errx(1, "sysctlbyname IPCS_MSG_SYSCTL: %s", strerror(errno));
			}
			printf("\n");
		}
	} else
		if (display & (MSGINFO | MSGTOTAL)) {
			errx(1, "%s", "SVID messages facility not configured in the system\n");
		}

	if ((display & (SHMINFO | SHMTOTAL))) {
		if (display & SHMTOTAL) {
			struct IPCS_command ic;
			struct shminfo shminfo;
			size_t ic_size = sizeof(ic);

			ic.ipcs_magic = IPCS_MAGIC;
			ic.ipcs_op = IPCS_SHM_CONF;
			ic.ipcs_cursor = 0;	/* 0 for fw. compat. */
			ic.ipcs_data = &shminfo;
			ic.ipcs_datalen = sizeof(shminfo);

			if (sysctlbyname(IPCS_SHM_SYSCTL, &ic, &ic_size, &ic, ic_size)) {
				if (errno != EPERM) {
					errx(1, "sysctlbyname(IPCS_SHM_SYSCTL, op=CONF, &ic, &%ld) datalen=%d failed: %s\n",
					     sizeof(ic), ic.ipcs_datalen, strerror(errno));
				} else
					errx(1, "sysctlbyname: %s", strerror(errno));
			}
			printf("shminfo:\n");
			printf("\tshmmax: %7lld\t(max shared memory segment size)\n",
			    shminfo.shmmax);
			printf("\tshmmin: %7lld\t(min shared memory segment size)\n",
			    shminfo.shmmin);
			printf("\tshmmni: %7lld\t(max number of shared memory identifiers)\n",
			    shminfo.shmmni);
			printf("\tshmseg: %7lld\t(max shared memory segments per process)\n",
			    shminfo.shmseg);
			printf("\tshmall: %7lld\t(max amount of shared memory in pages)\n\n",
			    shminfo.shmall);
		}
		if (display & SHMINFO) {
			struct IPCS_command ic;
			struct __shmid_ds_new ds;
			struct __shmid_ds_new *shmptr = &ds;
			size_t ic_size = sizeof(ic);

			printf("T     ID     KEY        MODE       OWNER    GROUP");
			if (option & CREATOR)
				printf("  CREATOR   CGROUP");
			if (option & OUTSTANDING)
				printf(" NATTCH");
			if (option & BIGGEST)
				printf("  SEGSZ");
			if (option & PID)
				printf("  CPID  LPID");
			if (option & TIME)
				printf("   ATIME    DTIME    CTIME");
			printf("\nShared Memory:\n");
		{	/* XXX */

			ic.ipcs_magic = IPCS_MAGIC;
			ic.ipcs_op = IPCS_SHM_ITER;
			ic.ipcs_cursor = 0;	/* start */
			ic.ipcs_datalen = sizeof(*shmptr);
			ic.ipcs_data = shmptr;
			memset(shmptr, 0, sizeof(*shmptr));

			while(!(sysctlbyname(IPCS_SHM_SYSCTL, &ic, &ic_size, &ic, ic_size))) {
				ic.ipcs_data = shmptr; /* xnu workaround */

				if (shmptr->shm_perm.mode & 0x0800) {
					char    atime_buf[100], dtime_buf[100],
					        ctime_buf[100];

					cvt_time(shmptr->shm_atime, atime_buf);
					cvt_time(shmptr->shm_dtime, dtime_buf);
					cvt_time(shmptr->shm_ctime, ctime_buf);

					printf("m %6d 0x%08x %s %8s %8s",
					       IXSEQ_TO_IPCID((ic.ipcs_cursor-1), shmptr->shm_perm),
					    (int)shmptr->shm_perm._key,
					    fmt_perm(shmptr->shm_perm.mode, 'w'),
					    user_from_uid(shmptr->shm_perm.uid, 0),
					    group_from_gid(shmptr->shm_perm.gid, 0));

					if (option & CREATOR)
						printf(" %8s %8s",
						    user_from_uid(shmptr->shm_perm.cuid, 0),
						    group_from_gid(shmptr->shm_perm.cgid, 0));

					if (option & OUTSTANDING)
						printf(" %6d",
						    shmptr->shm_nattch);

					if (option & BIGGEST)
						printf(" %6ld",
						    shmptr->shm_segsz);

					if (option & PID)
						printf(" %6d %6d",
						    shmptr->shm_cpid,
						    shmptr->shm_lpid);

					if (option & TIME)
						printf(" %s %s %s",
						    atime_buf,
						    dtime_buf,
						    ctime_buf);

					printf("\n");
				}
				memset(shmptr, 0, sizeof(*shmptr));
				errno = 0;
			}

			if (errno != ENOENT && errno != ERANGE) {
				if (errno != EPERM) {
					errx(1, "sysctlbyname(IPCS_SHM_SYSCTL, op=ITER, &ic, &%ld) datalen=%d failed:%s\n",
						 sizeof(ic), ic.ipcs_datalen, strerror(errno));
				} else
					errx(1, "sysctlbyname: %s", strerror(errno));
			}
		}	/* XXX */
			printf("\n");
		}
	}
else
		if (display & (SHMINFO | SHMTOTAL)) {
			errx(1, "%s", "SVID shared memory facility not configured in the system\n");
		}

	if ((display & (SEMINFO | SEMTOTAL))) {
		if (display & SEMTOTAL) {
			struct IPCS_command ic;
			struct seminfo seminfo;
			size_t ic_size = sizeof(ic);

			ic.ipcs_magic = IPCS_MAGIC;
			ic.ipcs_op = IPCS_SEM_CONF;
			ic.ipcs_cursor = 0;	/* 0 for fw. compat. */
			ic.ipcs_data = &seminfo;
			ic.ipcs_datalen = sizeof(seminfo);

			if (sysctlbyname(IPCS_SEM_SYSCTL, &ic, &ic_size, &ic, ic_size)) {
				if (errno != EPERM) {
					char buffer[1024];
					snprintf(buffer, 1024, "sysctlbyname(IPCS_SEM_SYSCTL, op=CONF, &ic, &%ld) datalen=%d",
						 sizeof(ic), ic.ipcs_datalen);
					perror(buffer);
				} else
					perror("sysctlbyname IPCS_SEM_SYSCTL/SEM_CONF");
			}

			printf("seminfo:\n");
			printf("\tsemmap: %6d\t(# of entries in semaphore map)\n",
			    seminfo.semmap);
			printf("\tsemmni: %6d\t(# of semaphore identifiers)\n",
			    seminfo.semmni);
			printf("\tsemmns: %6d\t(# of semaphores in system)\n",
			    seminfo.semmns);
			printf("\tsemmnu: %6d\t(# of undo structures in system)\n",
			    seminfo.semmnu);
			printf("\tsemmsl: %6d\t(max # of semaphores per id)\n",
			    seminfo.semmsl);
			printf("\tsemopm: %6d\t(max # of operations per semop call)\n",
			    seminfo.semopm);
			printf("\tsemume: %6d\t(max # of undo entries per process)\n",
			    seminfo.semume);
			printf("\tsemusz: %6d\t(size in bytes of undo structure)\n",
			    seminfo.semusz);
			printf("\tsemvmx: %6d\t(semaphore maximum value)\n",
			    seminfo.semvmx);
			printf("\tsemaem: %6d\t(adjust on exit max value)\n\n",
			    seminfo.semaem);
		}
		if (display & SEMINFO) {
			struct IPCS_command ic;
			struct __semid_ds_new ds;
			struct __semid_ds_new *semaptr = &ds;
			size_t ic_size = sizeof(ic);

			printf("T     ID     KEY        MODE       OWNER    GROUP");
			if (option & CREATOR)
				printf("  CREATOR   CGROUP");
			if (option & BIGGEST)
				printf(" NSEMS");
			if (option & TIME)
				printf("   OTIME    CTIME");
			printf("\nSemaphores:\n");

			ic.ipcs_magic = IPCS_MAGIC;
			ic.ipcs_op = IPCS_SEM_ITER;
			ic.ipcs_cursor = 0;	/* start */
			ic.ipcs_datalen = sizeof(*semaptr);
			ic.ipcs_data = semaptr;

			memset(semaptr, 0, sizeof(*semaptr));

			while(!(sysctlbyname(IPCS_SEM_SYSCTL, &ic, &ic_size, &ic, ic_size))) {
				ic.ipcs_data = semaptr;	/* xnu workaround */

				if ((semaptr->sem_perm.mode & SEM_ALLOC) != 0) {
					char    ctime_buf[100], otime_buf[100];

					cvt_time(semaptr->sem_otime, otime_buf);
					cvt_time(semaptr->sem_ctime, ctime_buf);

					printf("s %6d 0x%08x %s %8s %8s",
					       IXSEQ_TO_IPCID((ic.ipcs_cursor-1), semaptr->sem_perm),
					    (int)semaptr->sem_perm._key,
					    fmt_perm(semaptr->sem_perm.mode, 'a'),
					    user_from_uid(semaptr->sem_perm.uid, 0),
					    group_from_gid(semaptr->sem_perm.gid, 0));

					if (option & CREATOR)
						printf(" %8s %8s",
						    user_from_uid(semaptr->sem_perm.cuid, 0),
						    group_from_gid(semaptr->sem_perm.cgid, 0));

					if (option & BIGGEST)
						printf(" %6d",
						    semaptr->sem_nsems);

					if (option & TIME)
						printf(" %s %s",
						    otime_buf,
						    ctime_buf);

					printf("\n");
				}
				memset(semaptr, 0, sizeof(*semaptr));
				errno = 0;
			}

			if (errno != ENOENT && errno != ERANGE) {
				if (errno != EPERM) {
					errx(1, "sysctlbyname(IPCS_SEM_SYSCTL/ITER, op=ITER, &ic, &%ld) datalen=%d failed: %s\n",
						 sizeof(ic), ic.ipcs_datalen, strerror(errno));
				} else
					errx(1, "sysctlbyname: IPCS_SEM_SYSCTL %s", strerror(errno));
			}
			printf("\n");
		}
	} else
		if (display & (SEMINFO | SEMTOTAL)) {
			errx(1, "%s", "SVID semaphores facility not configured in the system\n");
		}

	exit(exit_val);
}
