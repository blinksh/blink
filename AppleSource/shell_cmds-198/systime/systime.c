/*
 * Copyright (c) 2012 Apple Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

#include <mach/mach.h>
#include <err.h>
#include <errno.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <libproc.h>
#include <mach/mach_time.h>

static void usage(void);
static void do_print(void);
static void do_difftime(bool usepercent, uint64_t *olduser, uint64_t *oldsystem, uint64_t *oldidle);
static void do_piddifftime(bool userpercent, int pid, uint64_t *old_pid_user, uint64_t *old_pid_system, uint64_t *old_pid_time);
static kern_return_t get_processor_time(uint64_t *user, uint64_t *sys, uint64_t *idle);
static kern_return_t get_processor_count(int *ncpu);
static mach_timebase_info_data_t timebase_info;

int
main(int argc, char *argv[])
{
	int ch;
	const char *optu = NULL;
	const char *opts = NULL;
	const char *opti = NULL;
	const char *tpid = NULL;
	const char *opt_sleep_time = NULL;
	int sleep_time = 1;
	int target_pid;
	bool systemwide_time = false;
	int pid;
	int status;
	uint64_t olduser, oldsystem, oldidle;
	uint64_t old_pid_time;
	uint64_t old_pid_user, old_pid_system;
	kern_return_t kret;
	bool usepercent = false;
	bool recurring = false;

	while ((ch = getopt(argc, argv, "PrT:t:pu:s:i:")) != -1) {
		switch (ch) {
		case 'P':
			usepercent = true;
			break;
		case 'r':
			recurring = true;
			break;
		case 't':
			opt_sleep_time = optarg;
			break;
		case 'T':
			tpid = optarg;
			break;
		case 'p':
			systemwide_time = true;
			break;
		case 'u':
			optu = optarg;
			break;
		case 's':
			opts = optarg;
			break;
		case 'i':
			opti = optarg;
			break;
		case '?':
		default:
			usage();
		}
	}

	mach_timebase_info(&timebase_info);

	if (opt_sleep_time) {
		char *endstr;
		sleep_time = (int)strtoul(opt_sleep_time, &endstr, 0);
		if (opt_sleep_time[0] == '\0' || endstr[0] != '\0')
			usage();
	}
	
	if (systemwide_time) {
		bool first_pass = true;
		olduser = oldsystem = oldidle = 0;

		if (recurring != true) {
			do_print();
			exit(0);
		}
		do {
			if (first_pass) {
				do_difftime(false, &olduser, &oldsystem, &oldidle);
				first_pass = false;
			} else {
				do_difftime(usepercent, &olduser, &oldsystem, &oldidle);
			}
			sleep(sleep_time);
		} while (recurring);

		exit(0);
	}


	if (tpid) {
		char *endstr;
		bool first_pass = true;

		target_pid = (int)strtoul(tpid, &endstr, 0);
		if (tpid[0] == '\0' || endstr[0] != '\0')
			usage();

		olduser = oldsystem = oldidle = 0;
		old_pid_user = old_pid_system = old_pid_time = 0;
		
		do {	
			if (first_pass) {
				do_difftime(false, &olduser, &oldsystem, &oldidle);
				do_piddifftime(false, target_pid, &old_pid_user, &old_pid_system, &old_pid_time);
				first_pass = false;
			} else {
				do_difftime(usepercent, &olduser, &oldsystem, &oldidle);
				do_piddifftime(usepercent, target_pid, &old_pid_user, &old_pid_system, &old_pid_time);
			}

			sleep(sleep_time);
		} while (recurring);
		exit(0);
	}

	if (optu || opts || opti) {
		char *endstr;

		if (!optu)
			usage();
		olduser = strtoull(optu, &endstr, 0);
		if (optu[0] == '\0' || endstr[0] != '\0')
			usage();

		if (!opts)
			usage();
		oldsystem = strtoull(opts, &endstr, 0);
		if (opts[0] == '\0' || endstr[0] != '\0')
			usage();

		if (!opti)
			usage();
		oldidle = strtoull(opti, &endstr, 0);
		if (opti[0] == '\0' || endstr[0] != '\0')
			usage();

		do_difftime(usepercent, &olduser, &oldsystem, &oldidle);
		exit(0);
	}

	argc -= optind;
	argv += optind;

	if (argc == 0)
		usage();

	do {
		kret = get_processor_time(&olduser, &oldsystem, &oldidle);
		if (kret)
			errx(1, "Error getting processor time: %s (%d)", mach_error_string(kret), kret);

		switch(pid = vfork()) {
			case -1:			/* error */
				perror("time");
				exit(1);
				/* NOTREACHED */
			case 0:				/* child */
				execvp(*argv, argv);
				perror(*argv);
				_exit((errno == ENOENT) ? 127 : 126);
				/* NOTREACHED */
		}

		/* parent */
		(void)signal(SIGINT, SIG_IGN);
		(void)signal(SIGQUIT, SIG_IGN);
		while (wait(&status) != pid);
		(void)signal(SIGINT, SIG_DFL);
		(void)signal(SIGQUIT, SIG_DFL);

		do_difftime(usepercent, &olduser, &oldsystem, &oldidle);

		sleep(sleep_time);
	} while (recurring);

	exit (WIFEXITED(status) ? WEXITSTATUS(status) : EXIT_FAILURE);

    return 0;
}

static void
usage(void)
{
	fprintf(stderr, "usage: systime [-P] [-r] [-t sleep_time] utility [argument ...]\n"
	                "       systime -p [-r] [-t sleep_time]\n"
	                "       systime [-P] -u user -s sys -i idle\n"
			"       systime [-P] [-r] [-t sleep_time] -T target_pid\n");
	exit(1);
}

static void
do_print(void)
{
	uint64_t user, system, idle;
	kern_return_t kret;

	kret = get_processor_time(&user, &system, &idle);
	if (kret)
		errx(1, "Error getting processor time: %s (%d)", mach_error_string(kret), kret);

	printf("systime_user=%llu\n",	user);
	printf("systime_sys=%llu\n",	system);
	printf("systime_idle=%llu\n",	idle);
}

static void
do_difftime(bool usepercent, uint64_t *olduser, uint64_t *oldsystem, uint64_t *oldidle)
{
	uint64_t user, system, idle;
	uint64_t userelapsed, systemelapsed, idleelapsed, totalelapsed;
	kern_return_t kret;

	kret = get_processor_time(&user, &system, &idle);
	if (kret)
		errx(1, "Error getting processor time: %s (%d)", mach_error_string(kret), kret);

	userelapsed = user - *olduser;
	systemelapsed = system - *oldsystem;
	idleelapsed = idle - *oldidle;
	totalelapsed = userelapsed + systemelapsed + idleelapsed;

	if (usepercent) {
		fprintf(stderr, "%1.02f%% user %1.02f%% sys %1.02f%% idle\n",
			   ((double)userelapsed * 100)/totalelapsed,
			   ((double)systemelapsed * 100)/totalelapsed,
			   ((double)idleelapsed * 100)/totalelapsed);
	} else {
		int ncpu;

		kret = get_processor_count(&ncpu);
		if (kret)
			errx(1, "Error getting processor count: %s (%d)", mach_error_string(kret), kret);

		fprintf(stderr, "%1.02f real %1.02f user %1.02f sys\n",
				((double)totalelapsed) / 1000 /* ms per sec */ / ncpu,
				((double)userelapsed) / 1000,
				((double)systemelapsed) / 1000);
	}
	*olduser = user;
	*oldsystem = system;
	*oldidle = idle;
}

static void
do_piddifftime(bool usepercent, int pid, uint64_t *old_pid_user, uint64_t *old_pid_system, uint64_t *old_pid_time)
{
	uint64_t pid_user, pid_system, pid_time;
	uint64_t userelapsed, systemelapsed, totalelapsed;
	struct proc_taskinfo info;
	int size;

	size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, sizeof(info));
	if (size == PROC_PIDTASKINFO_SIZE) {
		pid_user = info.pti_total_user;
		pid_system = info.pti_total_system;
	} else {
		fprintf(stderr, "Error in proc_pidinfo(): %s",
				strerror(errno));
		exit(1);
	}

	pid_time = mach_absolute_time();

	userelapsed = pid_user - *old_pid_user;
	systemelapsed = pid_system - *old_pid_system;
	totalelapsed = pid_time - *old_pid_time;

	if (usepercent) {
		fprintf(stderr, "Pid %d: %1.02f%% user %1.02f%% sys\n",
			   pid,
			   ((double)userelapsed * 100)/totalelapsed,
			   ((double)systemelapsed * 100)/totalelapsed);
	} else {
		fprintf(stderr, "Pid %d: %1.02f user %1.02f sys\n",
				pid,
				(((double)userelapsed) * timebase_info.numer / timebase_info.denom) / 1000000000,
				(((double)systemelapsed) * timebase_info.numer / timebase_info.denom) / 1000000000);
	}

	*old_pid_user = pid_user;
	*old_pid_system = pid_system;
	*old_pid_time = pid_time;

}

static kern_return_t
get_processor_time(uint64_t *user, uint64_t *sys, uint64_t *idle)
{
	host_name_port_t	host;
	kern_return_t		kret;
	host_cpu_load_info_data_t	host_load;
	mach_msg_type_number_t	count;

	host = mach_host_self();

	count = HOST_CPU_LOAD_INFO_COUNT;

	kret = host_statistics(host, HOST_CPU_LOAD_INFO, (host_info_t)&host_load, &count);
	if (kret)
		return kret;

	*user = ((uint64_t)host_load.cpu_ticks[CPU_STATE_USER]) * 10 /* ms per tick */;
	*sys = ((uint64_t)host_load.cpu_ticks[CPU_STATE_SYSTEM]) * 10;
	*idle = ((uint64_t)host_load.cpu_ticks[CPU_STATE_IDLE]) * 10;

	return KERN_SUCCESS;
}

static kern_return_t
get_processor_count(int *ncpu)
{
	host_name_port_t	host;
	kern_return_t		kret;
	host_basic_info_data_t	hi;
	mach_msg_type_number_t	count;

	host = mach_host_self();

	count = HOST_BASIC_INFO_COUNT;

	kret = host_info(host, HOST_BASIC_INFO, (host_info_t)&hi, &count);
	if (kret)
		return kret;

	*ncpu = hi.avail_cpus;

	return KERN_SUCCESS;
}
