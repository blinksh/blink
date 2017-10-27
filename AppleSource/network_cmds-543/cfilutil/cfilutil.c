/*
 * Copyright (c) 2013-2016 Apple Inc. All rights reserved.
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

#include <sys/socket.h>
#include <sys/errno.h>
#include <sys/event.h>
#include <sys/time.h>
#include <sys/sys_domain.h>
#include <sys/ioctl.h>
#include <sys/kern_control.h>
#include <sys/queue.h>
#include <net/content_filter.h>
#include <netinet/in.h>
#include <stdio.h>
#include <err.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <ctype.h>
#include <sysexits.h>

extern void print_filter_list(void);
extern void print_socket_list(void);
extern void print_cfil_stats(void);

#define MAX_BUFFER (65536 + 1024)

#define MAXHEXDUMPCOL 16


enum {
	MODE_NONE = 0,
	MODE_INTERACTIVE = 0x01,
	MODE_PEEK = 0x02,
	MODE_PASS = 0x04,
	MODE_DELAY = 0x08
};
int mode = MODE_NONE;

unsigned long delay_ms = 0;
struct timeval delay_tv = { 0, 0 };
long verbosity = 0;
uint32_t necp_control_unit = 0;
unsigned long auto_start = 0;
uint64_t peek_inc = 0;
uint64_t pass_offset = 0;
struct timeval now, deadline;
int sf = -1;
int pass_loopback = 0;
uint32_t random_drop = 0;
uint32_t event_total = 0;
uint32_t event_dropped = 0;

uint64_t default_in_pass = 0;
uint64_t default_in_peek = 0;
uint64_t default_out_pass = 0;
uint64_t default_out_peek = 0;

unsigned long max_dump_len = 32;

TAILQ_HEAD(sock_info_head, sock_info) sock_info_head = TAILQ_HEAD_INITIALIZER(sock_info_head);


struct sock_info {
	TAILQ_ENTRY(sock_info)	si_link;
	cfil_sock_id_t		si_sock_id;
	struct timeval		si_deadline;
	uint64_t		si_in_pass;
	uint64_t		si_in_peek;
	uint64_t		si_out_pass;
	uint64_t		si_out_peek;
};

static void
HexDump(void *data, size_t len)
{
	size_t i, j, k;
	unsigned char *ptr = (unsigned char *)data;
	unsigned char buf[32 + 3 * MAXHEXDUMPCOL + 2 + MAXHEXDUMPCOL + 1];
	
	for (i = 0; i < len; i += MAXHEXDUMPCOL) {
		k = snprintf((char *)buf, sizeof(buf), "\t0x%04lx:  ", i);
		for (j = i; j < i + MAXHEXDUMPCOL; j++) {
			if (j < len) {
				unsigned char msnbl = ptr[j] >> 4;
				unsigned char lsnbl = ptr[j] & 0x0f;
				
				buf[k++] = msnbl < 10 ? msnbl + '0' : msnbl + 'a' - 10;
				buf[k++] = lsnbl < 10 ? lsnbl + '0' : lsnbl + 'a' - 10;
			} else {
				buf[k++] = ' ';
				buf[k++] = ' ';
			}
			if ((j % 2) == 1)
				buf[k++] = ' ';
			if ((j % MAXHEXDUMPCOL) == MAXHEXDUMPCOL - 1)
				buf[k++] = ' ';
		}
		
		buf[k++] = ' ';
		buf[k++] = ' ';
		
		for (j = i; j < i + MAXHEXDUMPCOL && j < len; j++) {
			if (isprint(ptr[j]))
				buf[k++] = ptr[j];
			else
				buf[k++] = '.';
		}
		buf[k] = 0;
		printf("%s\n", buf);
	}
}

void
print_hdr(struct cfil_msg_hdr *hdr)
{
	const char *typestr = "unknown";
	const char *opstr = "unknown";
	
	if (hdr->cfm_type == CFM_TYPE_EVENT) {
		typestr = "event";
		switch (hdr->cfm_op) {
			case CFM_OP_SOCKET_ATTACHED:
				opstr = "attached";
				break;
			case CFM_OP_SOCKET_CLOSED:
				opstr = "closed";
				break;
			case CFM_OP_DATA_OUT:
				opstr = "dataout";
				break;
			case CFM_OP_DATA_IN:
				opstr = "datain";
				break;
			case CFM_OP_DISCONNECT_OUT:
				opstr = "disconnectout";
				break;
			case CFM_OP_DISCONNECT_IN:
				opstr = "disconnectin";
				break;
				
			default:
				break;
		}
	} else if (hdr->cfm_type == CFM_TYPE_ACTION) {
		typestr = "action";
		switch (hdr->cfm_op) {
			case CFM_OP_DATA_UPDATE:
				opstr = "update";
				break;
			case CFM_OP_DROP:
				opstr = "drop";
				break;
				
			default:
				break;
		}
		
	}
	printf("%s %s len %u version %u type %u op %u sock_id 0x%llx\n",
	       typestr, opstr,
	       hdr->cfm_len, hdr->cfm_version, hdr->cfm_type,
	       hdr->cfm_op, hdr->cfm_sock_id);
}

void
print_data_req(struct cfil_msg_data_event *data_req)
{
	size_t datalen;
	void *databuf;
	
	if (verbosity <= 0)
		return;
	
	print_hdr(&data_req->cfd_msghdr);
	
	printf(" start %llu end %llu\n",
	       data_req->cfd_start_offset, data_req->cfd_end_offset);
	
	datalen = (size_t)(data_req->cfd_end_offset - data_req->cfd_start_offset);
	
	databuf = (void *)(data_req + 1);
	
	if (verbosity > 1)
		HexDump(databuf, MIN(datalen, max_dump_len));
}

void
print_action_msg(struct cfil_msg_action *action)
{
	if (verbosity <= 0)
		return;
	
	print_hdr(&action->cfa_msghdr);
	
	if (action->cfa_msghdr.cfm_op == CFM_OP_DATA_UPDATE)
		printf(" out pass %llu peek %llu in pass %llu peek %llu\n",
		       action->cfa_out_pass_offset, action->cfa_out_peek_offset,
		       action->cfa_in_pass_offset, action->cfa_in_peek_offset);
}

struct sock_info *
find_sock_info(cfil_sock_id_t sockid)
{
	struct sock_info *sock_info;
	
	TAILQ_FOREACH(sock_info, &sock_info_head, si_link) {
		if (sock_info->si_sock_id == sockid)
			return (sock_info);
	}
	return (NULL);
}

struct sock_info *
add_sock_info(cfil_sock_id_t sockid)
{
	struct sock_info *sock_info;
	
	if (find_sock_info(sockid) != NULL)
		return (NULL);
	
	sock_info = calloc(1, sizeof(struct sock_info));
	if (sock_info == NULL)
		err(EX_OSERR, "calloc()");
	sock_info->si_sock_id = sockid;
	TAILQ_INSERT_TAIL(&sock_info_head, sock_info, si_link);
	
	return (sock_info);
}

void
remove_sock_info(cfil_sock_id_t sockid)
{
	struct sock_info *sock_info = find_sock_info(sockid);
	
	if (sock_info != NULL) {
		TAILQ_REMOVE(&sock_info_head, sock_info, si_link);
		free(sock_info);
	}
}

/* return 0 if timer is already set */
int
set_sock_info_deadline(struct sock_info *sock_info)
{
	if (timerisset(&sock_info->si_deadline))
		return (0);
	
	timeradd(&now, &sock_info->si_deadline, &sock_info->si_deadline);
	
	if (!timerisset(&deadline)) {
		timeradd(&now, &delay_tv, &deadline);
	}
	
	return (1);
}

void
send_action_message(uint32_t op, struct sock_info *sock_info, int nodelay)
{
	struct cfil_msg_action action;

	if (!nodelay && delay_ms) {
		set_sock_info_deadline(sock_info);
		return;
	}
	bzero(&action, sizeof(struct cfil_msg_action));
	action.cfa_msghdr.cfm_len = sizeof(struct cfil_msg_action);
	action.cfa_msghdr.cfm_version = CFM_VERSION_CURRENT;
	action.cfa_msghdr.cfm_type = CFM_TYPE_ACTION;
	action.cfa_msghdr.cfm_op = op;
	action.cfa_msghdr.cfm_sock_id = sock_info->si_sock_id;
	switch (op) {
		case CFM_OP_DATA_UPDATE:
			action.cfa_out_pass_offset = sock_info->si_out_pass;
			action.cfa_out_peek_offset = sock_info->si_out_peek;
			action.cfa_in_pass_offset = sock_info->si_in_pass;
			action.cfa_in_peek_offset = sock_info->si_in_peek;
			break;
			
		default:
			break;
	}

	if (verbosity > -1)
		print_action_msg(&action);
	
	if (send(sf, &action, sizeof(struct cfil_msg_action), 0) == -1)
		warn("send()");
	
	timerclear(&sock_info->si_deadline);
}

void
process_delayed_actions()
{
	struct sock_info *sock_info;
	
	TAILQ_FOREACH(sock_info, &sock_info_head, si_link) {
		if (timerisset(&sock_info->si_deadline) &&
		    timercmp(&sock_info->si_deadline, &now, >=))
		    send_action_message(CFM_OP_DATA_UPDATE, sock_info, 1);
	}
}

int
set_non_blocking(int fd)
{
	int flags;
	
	flags = fcntl(fd, F_GETFL);
	if (flags == -1) {
		warn("fcntl(F_GETFL)");
		return (-1);
	}
	flags |= O_NONBLOCK;
	if (fcntl(fd, F_SETFL, flags) == -1) {
		warn("fcntl(F_SETFL)");
		return (-1);
	}
	return (0);
}

int
offset_from_str(const char *str, uint64_t *ret_val)
{
	char *endptr;
	uint64_t offset;
	int success = 1;
	
	if (strcasecmp(str, "max") == 0 || strcasecmp(str, "all") == 0)
		offset = CFM_MAX_OFFSET;
	else {
		offset = strtoull(str, &endptr, 0);
		if (*str == '\0' || *endptr != '\0')
			success = 0;
 	}
	if (success)
		*ret_val = offset;
	return (success);
}

#define IN6_IS_ADDR_V4MAPPED_LOOPBACK(a)               \
	((*(const __uint32_t *)(const void *)(&(a)->s6_addr[0]) == 0) && \
	(*(const __uint32_t *)(const void *)(&(a)->s6_addr[4]) == 0) && \
	(*(const __uint32_t *)(const void *)(&(a)->s6_addr[8]) == ntohl(0x0000ffff)) && \
	(*(const __uint32_t *)(const void *)(&(a)->s6_addr[12]) == ntohl(INADDR_LOOPBACK)))


int
is_loopback(struct cfil_msg_data_event *data_req)
{
	if (data_req->cfc_dst.sa.sa_family == AF_INET &&
	    ntohl(data_req->cfc_dst.sin.sin_addr.s_addr) == INADDR_LOOPBACK)
		return (1);
	if (data_req->cfc_dst.sa.sa_family == AF_INET6 &&
	    IN6_IS_ADDR_LOOPBACK(&data_req->cfc_dst.sin6.sin6_addr))
		return (1);
	if (data_req->cfc_dst.sa.sa_family == AF_INET6 &&
	    IN6_IS_ADDR_V4MAPPED_LOOPBACK(&data_req->cfc_dst.sin6.sin6_addr))
		return (1);

	if (data_req->cfc_src.sa.sa_family == AF_INET &&
	    ntohl(data_req->cfc_src.sin.sin_addr.s_addr) == INADDR_LOOPBACK)
		return (1);
	if (data_req->cfc_src.sa.sa_family == AF_INET6 &&
	    IN6_IS_ADDR_LOOPBACK(&data_req->cfc_src.sin6.sin6_addr))
		return (1);
	if (data_req->cfc_src.sa.sa_family == AF_INET6 &&
	    IN6_IS_ADDR_V4MAPPED_LOOPBACK(&data_req->cfc_src.sin6.sin6_addr))
		return (1);

	return (0);
}

int
drop(struct sock_info *sock_info)
{
	event_total++;
	if (random_drop > 0) {
		uint32_t r = arc4random();
		if (r <= random_drop) {
			event_dropped++;
			printf("dropping 0x%llx dropped %u total %u rate %f\n",
			       sock_info->si_sock_id,
			       event_dropped, event_total,
			       (double)event_dropped/(double)event_total * 100);
			send_action_message(CFM_OP_DROP, sock_info, 0);
			return (1);
		}
	}
	return (0);
}

int
doit()
{
	struct sockaddr_ctl sac;
	struct ctl_info ctl_info;
	void *buffer = NULL;
	struct cfil_msg_hdr *hdr;
	int kq = -1;
	struct kevent kv;
	int fdin = fileno(stdin);
	char *linep = NULL;
	size_t linecap = 0;
	char *cmdptr = NULL;
	char *argptr = NULL;
	size_t cmdlen = 0;
	struct cfil_msg_action action;
	cfil_sock_id_t last_sock_id = 0;
	struct sock_info *sock_info = NULL;
	struct timeval last_time, elapsed, delta;
	struct timespec interval, *timeout = NULL;
	
	kq = kqueue();
	if (kq == -1)
		err(1, "kqueue()");
	
	sf = socket(PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL);
	if (sf == -1)
		err(1, "socket()");
	
	bzero(&ctl_info, sizeof(struct ctl_info));
	strlcpy(ctl_info.ctl_name, CONTENT_FILTER_CONTROL_NAME, sizeof(ctl_info.ctl_name));
	if (ioctl(sf, CTLIOCGINFO, &ctl_info) == -1)
		err(1, "ioctl(CTLIOCGINFO)");
	
	if (fcntl(sf, F_SETNOSIGPIPE, 1) == -1)
		err(1, "fcntl(F_SETNOSIGPIPE)");
	
	bzero(&sac, sizeof(struct sockaddr_ctl));
	sac.sc_len = sizeof(struct sockaddr_ctl);
	sac.sc_family = AF_SYSTEM;
	sac.ss_sysaddr = AF_SYS_CONTROL;
	sac.sc_id = ctl_info.ctl_id;
	
	if (connect(sf, (struct sockaddr *)&sac, sizeof(struct sockaddr_ctl)) == -1)
		err(1, "connect()");
	
	if (set_non_blocking(sf) == -1)
		err(1, "set_non_blocking(sf)");
	
	if (setsockopt(sf, SYSPROTO_CONTROL, CFIL_OPT_NECP_CONTROL_UNIT,
		       &necp_control_unit, sizeof(uint32_t)) == -1)
		err(1, "setsockopt(CFIL_OPT_NECP_CONTROL_UNIT, %u)", necp_control_unit);
	
	bzero(&kv, sizeof(struct kevent));
	kv.ident = sf;
	kv.filter = EVFILT_READ;
	kv.flags = EV_ADD;
	if (kevent(kq, &kv, 1, NULL, 0, NULL) == -1)
		err(1, "kevent(sf %d)", sf);
	
	/*
	 * We can only read from an interactive terminal
	 */
	if (isatty(fdin)) {
		bzero(&kv, sizeof(struct kevent));
		kv.ident = fdin;
		kv.filter = EVFILT_READ;
		kv.flags = EV_ADD;
		if (kevent(kq, &kv, 1, NULL, 0, NULL) == -1)
			err(1, "kevent(fdin %d)", fdin);
	}
	
	buffer = malloc(MAX_BUFFER);
	if (buffer == NULL)
		err(1, "malloc()");

	gettimeofday(&now, NULL);
	
	while (1) {
		last_time = now;
		if (delay_ms && timerisset(&deadline)) {
			timersub(&deadline, &now, &delta);
			TIMEVAL_TO_TIMESPEC(&delta, &interval);
			timeout = &interval;
		} else {
			timeout = NULL;
		}
		
		if (kevent(kq, NULL, 0, &kv, 1, timeout) == -1) {
			if (errno == EINTR)
				continue;
			err(1, "kevent()");
		}
		gettimeofday(&now, NULL);
		timersub(&now, &last_time, &elapsed);
		if (delay_ms && timerisset(&deadline)) {
			if (timercmp(&now, &deadline, >=)) {
				process_delayed_actions();
				interval.tv_sec = 0;
				interval.tv_nsec = 0;
			}
		}
		
		if (kv.ident == sf && kv.filter == EVFILT_READ) {
			while (1) {
				ssize_t nread;
				
				nread = recv(sf, buffer, MAX_BUFFER, 0);
				if (nread == 0) {
					warnx("recv(sf) returned 0, connection closed");
					break;
				}
				if (nread == -1) {
					if (errno == EINTR)
						continue;
					if (errno == EWOULDBLOCK)
						break;
					err(1, "recv()");
					
				}
				if (nread < sizeof(struct cfil_msg_hdr))
					errx(1, "too small");
				hdr = (struct cfil_msg_hdr *)buffer;
				
				
				if (hdr->cfm_type != CFM_TYPE_EVENT) {
					warnx("not a content filter event type %u", hdr->cfm_type);
					continue;
				}
				switch (hdr->cfm_op) {
					case CFM_OP_SOCKET_ATTACHED: {
						struct cfil_msg_sock_attached *msg_attached = (struct cfil_msg_sock_attached *)hdr;
						
						if (verbosity > -2)
							print_hdr(hdr);
						if (verbosity > -1)
							printf(" fam %d type %d proto %d pid %u epid %u\n",
							       msg_attached->cfs_sock_family,
							       msg_attached->cfs_sock_type,
							       msg_attached->cfs_sock_protocol,
							       msg_attached->cfs_pid,
						       msg_attached->cfs_e_pid);
						break;
					}
					case CFM_OP_SOCKET_CLOSED:
					case CFM_OP_DISCONNECT_IN:
					case CFM_OP_DISCONNECT_OUT:
						if (verbosity > -2)
							print_hdr(hdr);
						break;
					case CFM_OP_DATA_OUT:
					case CFM_OP_DATA_IN:
						if (verbosity > -3)
							print_data_req((struct cfil_msg_data_event *)hdr);
						break;
					default:
						warnx("unknown content filter event op %u", hdr->cfm_op);
						continue;
				}
				switch (hdr->cfm_op) {
					case CFM_OP_SOCKET_ATTACHED:
						sock_info = add_sock_info(hdr->cfm_sock_id);
						if (sock_info == NULL) {
							warnx("sock_id %llx already exists", hdr->cfm_sock_id);
							continue;
						}
						break;
					case CFM_OP_DATA_OUT:
					case CFM_OP_DATA_IN:
					case CFM_OP_DISCONNECT_IN:
					case CFM_OP_DISCONNECT_OUT:
					case CFM_OP_SOCKET_CLOSED:
						sock_info = find_sock_info(hdr->cfm_sock_id);
						
						if (sock_info == NULL) {
							warnx("unexpected data message, sock_info is NULL");
							continue;
						}
						break;
					default:
						warnx("unknown content filter event op %u", hdr->cfm_op);
						continue;
				}
				

				switch (hdr->cfm_op) {
					case CFM_OP_SOCKET_ATTACHED: {
						if ((mode & MODE_PASS) || (mode & MODE_PEEK) || auto_start) {
							sock_info->si_out_pass = default_out_pass;
							sock_info->si_out_peek = (mode & MODE_PEEK) ? peek_inc : (mode & MODE_PASS) ? CFM_MAX_OFFSET : default_out_peek;
							sock_info->si_in_pass = default_in_pass;
							sock_info->si_in_peek = (mode & MODE_PEEK) ? peek_inc : (mode & MODE_PASS) ? CFM_MAX_OFFSET : default_in_peek;
							
							send_action_message(CFM_OP_DATA_UPDATE, sock_info, 0);
						}
						break;
					}
					case CFM_OP_SOCKET_CLOSED: {
						remove_sock_info(hdr->cfm_sock_id);
						sock_info = NULL;
						break;
					}
					case CFM_OP_DATA_OUT:
					case CFM_OP_DATA_IN: {
						struct cfil_msg_data_event *data_req = (struct cfil_msg_data_event *)hdr;
												
						if (pass_loopback && is_loopback(data_req)) {
							sock_info->si_out_pass = CFM_MAX_OFFSET;
							sock_info->si_in_pass = CFM_MAX_OFFSET;
						} else {
							if (drop(sock_info))
								continue;
							
							if ((mode & MODE_PASS)) {
								if (data_req->cfd_msghdr.cfm_op == CFM_OP_DATA_OUT) {
									if (pass_offset == 0 || pass_offset == CFM_MAX_OFFSET)
										sock_info->si_out_pass = data_req->cfd_end_offset;
									else if (data_req->cfd_end_offset > pass_offset) {
										sock_info->si_out_pass = CFM_MAX_OFFSET;
										sock_info->si_in_pass = CFM_MAX_OFFSET;
									}
									sock_info->si_out_peek = (mode & MODE_PEEK) ?
									data_req->cfd_end_offset + peek_inc : 0;
								} else {
									if (pass_offset == 0 || pass_offset == CFM_MAX_OFFSET)
										sock_info->si_in_pass = data_req->cfd_end_offset;
									else if (data_req->cfd_end_offset > pass_offset) {
										sock_info->si_out_pass = CFM_MAX_OFFSET;
										sock_info->si_in_pass = CFM_MAX_OFFSET;
									}
									sock_info->si_in_peek = (mode & MODE_PEEK) ?
									data_req->cfd_end_offset + peek_inc : 0;
								}
							} else {
								break;
							}
						}
						send_action_message(CFM_OP_DATA_UPDATE, sock_info, 0);
						
						break;
					}
					case CFM_OP_DISCONNECT_IN:
					case CFM_OP_DISCONNECT_OUT: {
						if (drop(sock_info))
							continue;
						
						if ((mode & MODE_PASS)) {
							sock_info->si_out_pass = CFM_MAX_OFFSET;
							sock_info->si_in_pass = CFM_MAX_OFFSET;
							
							send_action_message(CFM_OP_DATA_UPDATE, sock_info, 0);
						}
						break;
					}
					default:
						warnx("unkown message op %u", hdr->cfm_op);
						break;
				}
				if (sock_info)
					last_sock_id = sock_info->si_sock_id;
			}
		}
		if (kv.ident == fdin && kv.filter == EVFILT_READ) {
			ssize_t nread;
			uint64_t offset = 0;
			int nitems;
			int op = 0;
			
			nread = getline(&linep, &linecap, stdin);
			if (nread == -1)
				errx(1, "getline()");
			
			if (verbosity > 2)
				printf("linecap %lu nread %lu\n", linecap, nread);
			if (nread > 0)
				linep[nread - 1] = '\0';
			
			if (verbosity > 2)
				HexDump(linep, linecap);
			
			if (*linep == 0)
				continue;
			
			if (cmdptr == NULL || argptr == NULL || linecap > cmdlen) {
				cmdlen = linecap;
				cmdptr = realloc(cmdptr, cmdlen);
				argptr = realloc(argptr, cmdlen);
			}
			
			/* 
			 * Trick to support unisgned and hexadecimal arguments
			 * as I can't figure out sscanf() conversions
			 */
			nitems = sscanf(linep, "%s %s", cmdptr, argptr);
			if (nitems == 0) {
				warnx("I didn't get that...");
				continue;
			} else if (nitems > 1) {
				if (offset_from_str(argptr, &offset) == 0) {
					warnx("I didn't get that either...");
					continue;
				}
			}
			if (verbosity > 2)
				printf("nitems %d %s %s\n", nitems, cmdptr, argptr);

			bzero(&action, sizeof(struct cfil_msg_action));
			action.cfa_msghdr.cfm_len = sizeof(struct cfil_msg_action);
			action.cfa_msghdr.cfm_version = CFM_VERSION_CURRENT;
			action.cfa_msghdr.cfm_type = CFM_TYPE_ACTION;

			if (strcasecmp(cmdptr, "passout") == 0 && nitems > 1) {
				op = CFM_OP_DATA_UPDATE;
				action.cfa_out_pass_offset = offset;
			} else if (strcasecmp(cmdptr, "passin") == 0 && nitems > 1) {
				op = CFM_OP_DATA_UPDATE;
				action.cfa_in_pass_offset = offset;
			} else if (strcasecmp(cmdptr, "pass") == 0 && nitems > 1) {
				op = CFM_OP_DATA_UPDATE;
				action.cfa_out_pass_offset = offset;
				action.cfa_in_pass_offset = offset;
			} else if (strcasecmp(cmdptr, "peekout") == 0 && nitems > 1) {
				op = CFM_OP_DATA_UPDATE;
				action.cfa_out_peek_offset = offset;
			} else if (strcasecmp(cmdptr, "peekin") == 0 && nitems > 1) {
				op = CFM_OP_DATA_UPDATE;
				action.cfa_in_peek_offset = offset;
			} else if (strcasecmp(cmdptr, "peek") == 0 && nitems > 1) {
				op = CFM_OP_DATA_UPDATE;
				action.cfa_out_peek_offset = offset;
				action.cfa_in_peek_offset = offset;
			} else if (strcasecmp(cmdptr, "start") == 0) {
				op = CFM_OP_DATA_UPDATE;
				action.cfa_out_pass_offset = 0;
				action.cfa_out_peek_offset = CFM_MAX_OFFSET;
				action.cfa_in_pass_offset = 0;
				action.cfa_in_peek_offset = CFM_MAX_OFFSET;
			} else if (strcasecmp(cmdptr, "peekall") == 0) {
				op = CFM_OP_DATA_UPDATE;
				action.cfa_out_peek_offset = CFM_MAX_OFFSET;
				action.cfa_in_peek_offset = CFM_MAX_OFFSET;
			} else if (strcasecmp(cmdptr, "passall") == 0) {
				op = CFM_OP_DATA_UPDATE;
				action.cfa_out_pass_offset = CFM_MAX_OFFSET;
				action.cfa_out_peek_offset = CFM_MAX_OFFSET;
				action.cfa_in_pass_offset = CFM_MAX_OFFSET;
				action.cfa_in_peek_offset = CFM_MAX_OFFSET;
			} else if (strcasecmp(cmdptr, "drop") == 0)
				op = CFM_OP_DROP;
			else if (strcasecmp(cmdptr, "sock") == 0) {
				last_sock_id = offset;
				printf("last_sock_id 0x%llx\n", last_sock_id);
			} else
				warnx("syntax error");
			
			if (op == CFM_OP_DATA_UPDATE || op == CFM_OP_DROP) {
				action.cfa_msghdr.cfm_op = op;
				action.cfa_msghdr.cfm_sock_id = last_sock_id;
				print_action_msg(&action);
				
				if (send(sf, &action, sizeof(struct cfil_msg_action), 0) == -1)
					warn("send()");
			}
		}
	}
	
	return 0;
}

static const char *
basename(const char * str)
{
	const char *last_slash = strrchr(str, '/');
	
	if (last_slash == NULL)
		return (str);
	else
		return (last_slash + 1);
}

struct option_desc {
	const char *option;
	const char *description;
	int required;
};

struct option_desc option_desc_list[] = {
	{ "-a offset", "auto start with offset", 0 },
	{ "-d offset value", "default offset value for passin, peekin, passout, peekout, pass, peek", 0 },
	{ "-h", "dsiplay this help", 0 },
	{ "-i", "interactive mode", 0 },
	{ "-k increment", "peek mode with increment", 0 },
	{"-l", "pass loopback", 0 },
	{ "-m length", "max dump length", 0 },
	{ "-p offset", "pass mode (all or after given offset if > 0)", 0 },
	{ "-q", "decrease verbose level", 0 },
	{ "-r random", "random drop rate", 0 },
	{ "-s ", "display content filter statistics (all, sock, filt, cfil)", 0 },
	{ "-t delay", "pass delay in microseconds", 0 },
	{ "-u unit", "NECP filter control unit", 1 },
	{ "-v", "increase verbose level", 0 },
	{ NULL, NULL, 0 }  /* Mark end of list */
};

static void
usage(const char *cmd)
{
	struct option_desc *option_desc;
	char *usage_str = malloc(LINE_MAX);
	size_t usage_len;
	
	if (usage_str == NULL)
		err(1, "%s: malloc(%d)", __func__, LINE_MAX);
	
	usage_len = snprintf(usage_str, LINE_MAX, "# usage: %s ", basename(cmd));
	
	for (option_desc = option_desc_list; option_desc->option != NULL; option_desc++) {
		int len;
		
		if (option_desc->required)
			len = snprintf(usage_str + usage_len, LINE_MAX - usage_len, "%s ", option_desc->option);
		else
			len = snprintf(usage_str + usage_len, LINE_MAX - usage_len, "[%s] ", option_desc->option);
		if (len < 0)
			err(1, "%s: snprintf(", __func__);
		
		usage_len += len;
		if (usage_len > LINE_MAX)
			break;
	}
	printf("%s\n", usage_str);
	printf("options:\n");
	
	for (option_desc = option_desc_list; option_desc->option != NULL; option_desc++) {
		printf(" %-20s # %s\n", option_desc->option, option_desc->description);
	}
	
}

int
main(int argc, char * const argv[])
{
	int ch;
	double d;
	int stats_sock_list = 0;
	int stats_filt_list = 0;
	int stats_cfil_stats = 0;
	
	while ((ch = getopt(argc, argv, "a:d:hik:lm:p:qr:s:t:u:v")) != -1) {
		switch (ch) {
			case 'a':
				auto_start = strtoul(optarg, NULL, 0);
				break;
			case 'd': {
				if (optind >= argc)
					errx(1, "'-d' needs 2 parameters");
				if (strcasecmp(optarg, "passout") == 0) {
					if (offset_from_str(argv[optind], &default_out_pass) == 0)
						errx(1, "bad %s offset: %s", optarg, argv[optind + 1]);
				} else if (strcasecmp(optarg, "passin") == 0) {
					if (offset_from_str(argv[optind], &default_in_pass) == 0)
						errx(1, "bad %s offset: %s", optarg, argv[optind + 1]);
				} else if (strcasecmp(optarg, "pass") == 0) {
					if (offset_from_str(argv[optind], &default_out_pass) == 0)
						errx(1, "bad %s offset: %s", optarg, argv[optind + 1]);
					default_in_pass = default_out_pass;
				} else if (strcasecmp(optarg, "peekout") == 0) {
					if (offset_from_str(argv[optind], &default_out_peek) == 0)
						errx(1, "bad %s offset: %s", optarg, argv[optind + 1]);
				} else if (strcasecmp(optarg, "peekin") == 0) {
					if (offset_from_str(argv[optind], &default_in_peek) == 0)
						errx(1, "bad %s offset: %s", optarg, argv[optind + 1]);
				} else if (strcasecmp(optarg, "peek") == 0) {
					if (offset_from_str(argv[optind], &default_out_peek) == 0)
						errx(1, "bad %s offset: %s", optarg, argv[optind + 1]);
					default_in_peek = default_out_peek;
				} else
					errx(1, "syntax error");
				break;
			}
			case 'h':
				usage(argv[0]);
				exit(0);
			case 'i':
				mode |= MODE_INTERACTIVE;
				break;
			case 'k':
				mode |= MODE_PEEK;
				if (offset_from_str(optarg, &peek_inc) == 0)
					errx(1, "bad peek offset: %s", optarg);
				break;
			case 'l':
				pass_loopback = 1;
				break;
			case 'm':
				max_dump_len = strtoul(optarg, NULL, 0);
				break;
			case 'p':
				mode |= MODE_PASS;
				if (offset_from_str(optarg, &pass_offset) == 0)
					errx(1, "bad pass offset: %s", optarg);
				break;
			case 'q':
				verbosity--;
				break;
			case 'r':
				d = strtod(optarg, NULL);
				if (d < 0 || d > 1)
					errx(1, "bad drop rate: %s -- it must be between 0 and 1", optarg);
				random_drop = (uint32_t)(d * UINT32_MAX);
				break;
			case 's':
				if (strcasecmp(optarg, "all") == 0) {
					stats_sock_list = 1;
					stats_filt_list = 1;
					stats_cfil_stats = 1;
				} else if (strcasecmp(optarg, "sock") == 0) {
					stats_sock_list = 1;
				} else if (strcasecmp(optarg, "filt") == 0) {
					stats_filt_list = 1;
				} else if (strcasecmp(optarg, "cfil") == 0) {
					stats_cfil_stats = 1;
				} else {
					warnx("# Error: unknown type of statistic: %s", optarg);
					usage(argv[0]);
					exit(0);
				}
				break;
			case 't':
				mode |= MODE_DELAY;
				delay_ms = strtoul(optarg, NULL, 0);
				delay_tv.tv_sec = delay_ms / 1000;
				delay_tv.tv_usec = (delay_ms % 1000) * 1000;
				break;
			case 'u':
				necp_control_unit = (uint32_t)strtoul(optarg, NULL, 0);
				break;
			case 'v':
				verbosity++;
				break;
			default:
				errx(1, "# syntax error, unknow option '%d'", ch);
				usage(argv[0]);
				exit(0);
		}
	}
	
	if (stats_filt_list)
		print_filter_list();
	if (stats_sock_list)
		print_socket_list();
	if (stats_cfil_stats)
		print_cfil_stats();
	if (necp_control_unit == 0 && (stats_filt_list || stats_sock_list || stats_cfil_stats))
		return (0);
	
	if (necp_control_unit == 0) {
		warnx("necp filter control unit is 0");
		usage(argv[0]);
		exit(EX_USAGE);
	}
	doit();
	
	
	return (0);
}

