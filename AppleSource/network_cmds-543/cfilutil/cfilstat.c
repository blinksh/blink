/*
 * Copyright (c) 2013-2014 Apple Inc. All rights reserved.
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

#include <sys/errno.h>
#include <sys/sysctl.h>
#include <net/content_filter.h>
#include <stdio.h>
#include <stdlib.h>
#include <err.h>
#include <unistd.h>
#include <string.h>

void
print_filter_list()
{
	size_t total_len, curr_len;
	void *buffer = NULL;
	void *ptr;
	uint32_t line = 0;
	
	if (sysctlbyname("net.cfil.filter_list", NULL, &total_len, NULL, 0) == -1)
		err(1, "sysctlbyname(net.cfil.filter_list)");
	
	buffer = malloc(total_len);
	if (buffer == NULL)
		err(1, "malloc()");
	if (sysctlbyname("net.cfil.filter_list", buffer, &total_len, NULL, 0) == -1)
		err(1, "sysctlbyname(net.cfil.filter_list)");
	
	ptr = buffer;
	curr_len = 0;
	do {
		struct cfil_filter_stat *filter_stat;
		
		filter_stat = (struct cfil_filter_stat *)ptr;
		
		if (curr_len + filter_stat->cfs_len > total_len ||
		    filter_stat->cfs_len < sizeof(struct cfil_filter_stat))
			break;
		
		if (line % 16 == 0)
			printf("%10s %10s %10s %10s\n",
			       "filter", "flags", "count", "necpunit");
		
		printf("%10u 0x%08x %10u %10u\n",
		       filter_stat->cfs_filter_id,
		       filter_stat->cfs_flags,
		       filter_stat->cfs_sock_count,
		       filter_stat->cfs_necp_control_unit);
		
		ptr += filter_stat->cfs_len;
		curr_len += filter_stat->cfs_len;
	} while (1);
	
	free(buffer);
}

void
sprint_offset(char *str, size_t len, const char *fmt, uint64_t offset)
{
	if (offset == CFM_MAX_OFFSET)
		snprintf(str, len, "%s", "MAX");
	else
		snprintf(str, len, fmt, offset);
}

void
print_socket_list()
{
	size_t total_len, curr_len;
	void *buffer = NULL;
	void *ptr;
	int i;
	
	if (sysctlbyname("net.cfil.sock_list", NULL, &total_len, NULL, 0) == -1)
		err(1, "sysctlbyname(net.cfil.sock_list)");
	
	buffer = malloc(total_len);
	if (buffer == NULL)
		err(1, "malloc()");
	if (sysctlbyname("net.cfil.sock_list", buffer, &total_len, NULL, 0) == -1)
		err(1, "sysctlbyname(net.cfil.sock_list)");
	
	ptr = buffer;
	curr_len = 0;
	do {
		struct cfil_sock_stat *sock_stat;
		char opass[32];
		char ipass[32];
		
		sock_stat = (struct cfil_sock_stat *)ptr;
		
		if (curr_len + sock_stat->cfs_len > total_len ||
		    sock_stat->cfs_len < sizeof(struct cfil_sock_stat))
			break;

		sprint_offset(opass, 32, "%8llu", sock_stat->cfs_snd.cbs_pass_offset);
		sprint_offset(ipass, 32, "%8llu", sock_stat->cfs_rcv.cbs_pass_offset);

		printf("%18s %10s "
		       "%8s %8s %8s %8s %8s %8s %8s "
		       "%8s %8s %8s %8s %8s %8s %8s "
		       "%8s %8s\n",
		       "sockid", "flags",
		       "ofirst", "olast", "oqlen", " ", "opass", " ", " ",
		       "ifirst", "ilast", "iqlen", " ", "ipass", " ", " ",
		       "pid", "epid");

		printf("0x%016llx 0x%08llx "
		       "%8llu %8llu %8llu %8s %8s %8s %8s "
		       "%8llu %8llu %8llu %8s %8s %8s %8s "
		       "%8u %8u\n",
		       
		       sock_stat->cfs_sock_id,
		       sock_stat->cfs_flags,
		       
		       sock_stat->cfs_snd.cbs_pending_first,
		       sock_stat->cfs_snd.cbs_pending_last,
		       sock_stat->cfs_snd.cbs_inject_q_len,
		       " ",
		       opass,
		       " ",
		       " ",
		       
		       sock_stat->cfs_rcv.cbs_pending_first,
		       sock_stat->cfs_rcv.cbs_pending_last,
		       sock_stat->cfs_rcv.cbs_inject_q_len,
		       " ",
		       ipass,
		       " ",
		       " ",
		       sock_stat->cfs_pid,
		       sock_stat->cfs_e_pid);
		
		printf("%7s %10s %10s "
		       "%8s %8s %8s %8s %8s %8s %8s "
		       "%8s %8s %8s %8s %8s %8s %8s\n",
		       " ",
		       "filter", "flags",
		       "octlfrst", "octllast", "opndfrst", "opndlast", "opass", "opked", "opeek",
		       "ictlfrst", "ictllast", "ipndfrst", "ipndlast", "ipass", "ipked", "ipeek");
		for (i = 0; i < CFIL_MAX_FILTER_COUNT; i++) {
			struct cfil_entry_stat *estat;
			char spass[32];
			char speek[32];
			char spked[32];
			char rpass[32];
			char rpeek[32];
			char rpked[32];

			estat = &sock_stat->ces_entries[i];

			sprint_offset(spass, 32, "%8llu", estat->ces_snd.cbs_pass_offset);
			sprint_offset(speek, 32, "%8llu", estat->ces_snd.cbs_peek_offset);
			sprint_offset(spked, 32, "%8llu", estat->ces_snd.cbs_peeked);
			
			sprint_offset(rpass, 32, "%8llu", estat->ces_rcv.cbs_pass_offset);
			sprint_offset(rpeek, 32, "%8llu", estat->ces_rcv.cbs_peek_offset);
			sprint_offset(rpked, 32, "%8llu", estat->ces_rcv.cbs_peeked);
			
			printf("%7s %10u 0x%08x "
			       "%8llu %8llu %8llu %8llu %8s %8s %8s "
			       "%8llu %8llu %8llu %8llu %8s %8s %8s\n",
			       
			       " ",
			       estat->ces_filter_id,
			       estat->ces_flags,
			       
			       estat->ces_snd.cbs_ctl_first,
			       estat->ces_snd.cbs_ctl_last,
			       estat->ces_snd.cbs_pending_first,
			       estat->ces_snd.cbs_pending_last,
			       spass,
			       spked,
			       speek,
			       
			       estat->ces_rcv.cbs_ctl_first,
			       estat->ces_rcv.cbs_ctl_last,
			       estat->ces_rcv.cbs_pending_first,
			       estat->ces_rcv.cbs_pending_last,
			       rpass,
			       rpked,
			       rpeek);
		}
		
		
		ptr += sock_stat->cfs_len;
		curr_len += sock_stat->cfs_len;
	} while (1);
	
	free(buffer);
}


#define PR32(x) printf(#x " %u\n", stats-> x)
#define PR64(x) printf(#x " %llu\n", stats-> x)
void
print_cfil_stats()
{
	size_t len, alloc_len;
	void *buffer = NULL;
	struct cfil_stats *stats;

	if (sysctlbyname("net.cfil.stats", NULL, &len, NULL, 0) == -1)
		err(1, "sysctlbyname(net.cfil.stats)");
	
	if (len < sizeof(struct cfil_stats))
		alloc_len = sizeof(struct cfil_stats);
	else
		alloc_len = len;
	
	buffer = malloc(alloc_len);
	if (buffer == NULL)
		err(1, "malloc()");
	if (sysctlbyname("net.cfil.stats", buffer, &len, NULL, 0) == -1)
		err(1, "sysctlbyname(net.cfil.stats)");
	stats = (struct cfil_stats *)buffer;

	PR32(cfs_ctl_connect_ok);
	PR32(cfs_ctl_connect_fail);
	PR32(cfs_ctl_connect_ok);
	PR32(cfs_ctl_connect_fail);
	PR32(cfs_ctl_disconnect_ok);
	PR32(cfs_ctl_disconnect_fail);
	PR32(cfs_ctl_send_ok);
	PR32(cfs_ctl_send_bad);
	PR32(cfs_ctl_rcvd_ok);
	PR32(cfs_ctl_rcvd_bad);
	PR32(cfs_ctl_rcvd_flow_lift);
	PR32(cfs_ctl_action_data_update);
	PR32(cfs_ctl_action_drop);
	PR32(cfs_ctl_action_bad_op);
	PR32(cfs_ctl_action_bad_len);

	PR32(cfs_sock_id_not_found);

	PR32(cfs_cfi_alloc_ok);
	PR32(cfs_cfi_alloc_fail);

	PR32(cfs_sock_userspace_only);
	PR32(cfs_sock_attach_in_vain);
	PR32(cfs_sock_attach_already);
	PR32(cfs_sock_attach_no_mem);
	PR32(cfs_sock_attach_failed);
	PR32(cfs_sock_attached);
	PR32(cfs_sock_detached);

	PR32(cfs_attach_event_ok);
	PR32(cfs_attach_event_flow_control);
	PR32(cfs_attach_event_fail);

	PR32(cfs_closed_event_ok);
	PR32(cfs_closed_event_flow_control);
	PR32(cfs_closed_event_fail);

	PR32(cfs_data_event_ok);
	PR32(cfs_data_event_flow_control);
	PR32(cfs_data_event_fail);

	PR32(cfs_disconnect_in_event_ok);
	PR32(cfs_disconnect_out_event_ok);
	PR32(cfs_disconnect_event_flow_control);
	PR32(cfs_disconnect_event_fail);

	PR32(cfs_ctl_q_not_started);

	PR32(cfs_close_wait);
	PR32(cfs_close_wait_timeout);

	PR32(cfs_flush_in_drop);
	PR32(cfs_flush_out_drop);
	PR32(cfs_flush_in_close);
	PR32(cfs_flush_out_close);
	PR32(cfs_flush_in_free);
	PR32(cfs_flush_out_free);

	PR32(cfs_inject_q_nomem);
	PR32(cfs_inject_q_nobufs);
	PR32(cfs_inject_q_detached);
	PR32(cfs_inject_q_in_fail);
	PR32(cfs_inject_q_out_fail);

	PR32(cfs_inject_q_in_retry);
	PR32(cfs_inject_q_out_retry);

	PR32(cfs_data_in_control);
	PR32(cfs_data_in_oob);
	PR32(cfs_data_out_control);
	PR32(cfs_data_out_oob);

	PR64(cfs_ctl_q_in_enqueued);
	PR64(cfs_ctl_q_out_enqueued);
	PR64(cfs_ctl_q_in_peeked);
	PR64(cfs_ctl_q_out_peeked);

	PR64(cfs_pending_q_in_enqueued);
	PR64(cfs_pending_q_out_enqueued);

	PR64(cfs_inject_q_in_enqueued);
	PR64(cfs_inject_q_out_enqueued);
	PR64(cfs_inject_q_in_passed);
	PR64(cfs_inject_q_out_passed);
}
