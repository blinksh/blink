/*
 * Copyright (c) 2012-2014 Apple Inc. All rights reserved.
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
 * Copyright (c) 1997
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that: (1) source code distributions
 * retain the above copyright notice and this paragraph in its entirety, (2)
 * distributions including binary code include the above copyright notice and
 * this paragraph in its entirety in the documentation or other materials
 * provided with the distribution, and (3) all advertising materials mentioning
 * features or use of this software display the following acknowledgement:
 * ``This product includes software developed by the University of California,
 * Lawrence Berkeley Laboratory and its contributors.'' Neither the name of
 * the University nor the names of its contributors may be used to endorse
 * or promote products derived from this software without specific prior
 * written permission.
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 */

//
//  Created by Anumita Biswas on 7/17/12.
//

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <netinet/in.h>
#include <netdb.h>
#include <errno.h>
#include <arpa/inet.h>
#include <err.h>
#include <sysexits.h>
#include <getopt.h>

#include "conn_lib.h"

struct so_cordreq socorder;
static void showmpinfo(int s);

#define MSG_HDR "Message Header"
#define RESPONSE "I got your message"

static int verbose = 0;

static int32_t thiszone = 0;	/* time difference with gmt */

char *setup_buffer1(int bufsz)
{
	int i = 0, j = 1;
	char *buf;

	buf = malloc(bufsz);
	if (!buf)
		return NULL;

	bzero(buf, bufsz);
	strlcpy(buf, MSG_HDR, sizeof(MSG_HDR));

	for (i = sizeof(MSG_HDR); i < bufsz; i++) {
		buf[i] = j;
		j++;
		if (j >= 255)
			j = 1;
	}
        return buf;
}

char *setup_buffer2(int bufsz)
{
	int i = 0;
	char j = 'A';
	char *buf;

	buf = malloc(bufsz);
	if (!buf)
		return NULL;

	bzero(buf, bufsz);
	strlcpy(buf, MSG_HDR, sizeof(MSG_HDR));

	for (i = sizeof(MSG_HDR); i < bufsz; i++) {
		buf[i] = j;
		j++;
		if (j >= 'z')
			j = 'A';
	}
        return buf;
}

char *setup_buffer3(int bufsz)
{
	char *buf;

	buf = malloc(bufsz);
	if (!buf)
		return NULL;

	bzero(buf, bufsz);
	return buf;
}

/*
 * Returns the difference between gmt and local time in seconds.
 * Use gmtime() and localtime() to keep things simple.
 * from tcpdump/gmt2local.c
 */
static int32_t
gmt2local(time_t t)
{
	int dt, dir;
	struct tm *gmt, *loc;
	struct tm sgmt;

	if (t == 0)
		t = time(NULL);
	gmt = &sgmt;
	*gmt = *gmtime(&t);
	loc = localtime(&t);
	dt = (loc->tm_hour - gmt->tm_hour) * 60 * 60 +
	(loc->tm_min - gmt->tm_min) * 60;

	/*
	 * If the year or julian day is different, we span 00:00 GMT
	 * and must add or subtract a day. Check the year first to
	 * avoid problems when the julian day wraps.
	 */
	dir = loc->tm_year - gmt->tm_year;
	if (dir == 0)
		dir = loc->tm_yday - gmt->tm_yday;
	dt += dir * 24 * 60 * 60;

	return (dt);
}

/*
 * Print the timestamp
 * from tcpdump/util.c
 */
static void
ts_print(void)
{
	int s;
	struct timeval tv;

	gettimeofday(&tv, NULL);

	/* Default */
	s = (tv.tv_sec + thiszone) % 86400;
	printf("%02d:%02d:%02d.%06u ", s / 3600, (s % 3600) / 60, s % 60,
	       (u_int32_t)tv.tv_usec);
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
	{ "--host addr", "address of server to connect to", 1 },
	{ "--port n", "port of server to connect to", 1 },
	{ "--reqlen n", "length of request (256 by default)", 0 },
	{ "--rsplen n", "length of response (256 by default)", 0 },
	{ "--ntimes n", "number of time to send request (1 by default)", 0 },
	{ "--alt_addr addr", "alternate server to connect to", 0 },
	{ "--verbose", "increase verbosity", 0 },
	{ "--help", "display this help", 0 },

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
		printf(" %-24s # %s\n", option_desc->option, option_desc->description);
	}
	printf("\n");
	printf("# legacy usage: ");
}

static struct option longopts[] = {
	{ "host",		required_argument,	NULL,		'c' },
	{ "port",		required_argument,	NULL,		'p' },
	{ "reqlen",		required_argument,	NULL,		'r' },
	{ "rsplen",		required_argument,	NULL,		'R' },
	{ "ntimes",		required_argument,	NULL,		'n' },
	{ "alt_addr",		required_argument,	NULL,		'a' },
	{ "help",		no_argument,		NULL,		'h' },
	{ "verbose",		no_argument,		NULL,		'v' },
	{ "quiet",		no_argument,		NULL,		'q' },
	{ NULL,			0,			NULL,		0 }
};

static int
sprint_sockaddr(char *str, socklen_t strlen, struct sockaddr *sa)
{
	int retval = 0;

	if (sa->sa_family == AF_INET) {
		struct sockaddr_in      *sin = (struct sockaddr_in*)sa;
		char str4[INET_ADDRSTRLEN];

		inet_ntop(AF_INET, &sin->sin_addr, str4, sizeof(str4));

		retval = snprintf(str, strlen, "%s:%u", str4, ntohs(sin->sin_port));
	} else  if (sa->sa_family == AF_INET6) {
		struct sockaddr_in6     *sin6 = (struct sockaddr_in6*)sa;
		char                    str6[INET6_ADDRSTRLEN];
		char                    ifname[IF_NAMESIZE];
		char                    scopestr[2 + IF_NAMESIZE];

		inet_ntop(AF_INET6, &sin6->sin6_addr, str6, sizeof(str6));

		if (sin6->sin6_scope_id == 0)
			*scopestr = '\0';
		else {
			if_indextoname(sin6->sin6_scope_id, ifname);
			snprintf(scopestr, sizeof(scopestr), "%%%s", ifname);
		}

		retval = snprintf(str, strlen, "%s%s:%u",
			str6,
			scopestr,
			ntohs(sin6->sin6_port));
	}
	return (retval);
}

int main(int argc, char * const *argv)
{
	int sockfd, portno;
	ssize_t n;
	int reqlen = 256;
	int rsplen = 256;
	int ntimes = 1;
	char *buffer = NULL;
	char *buffer1;
	char *buffer2;
	char *buffer3;
	struct addrinfo *ares = NULL, ahints;
	struct addrinfo *altres = NULL;
	int retval = 0;
	int which_buf = 0;
	sae_connid_t cid1, cid2;
	int iter;
	int bytes_to_rdwr;
	int ch;
	const char *host_arg = NULL;
	const char *port_arg = NULL;
	const char *reqlen_arg = "256";
	const char *rsplen_arg = "256";
	const char *ntimes_arg = "1";
	const char *alt_addr_arg = NULL;
	const char *alt_port_arg = "0";
	int gotopt = 0;

	thiszone = gmt2local(0);

	while ((ch = getopt_long(argc, argv, "a:c:hn:p:qr:R:v", longopts, NULL)) != -1) {
		gotopt = 1;
		switch (ch) {
			case 'a':
				alt_addr_arg = optarg;
				break;
			case 'c':
				host_arg = optarg;
				break;
			case 'n':
				ntimes_arg = optarg;
				break;
			case 'p':
				port_arg = optarg;
				break;
			case 'q':
				verbose--;
				break;
			case 'r':
				reqlen_arg = optarg;
				break;
			case 'R':
				rsplen_arg = optarg;
				break;
			case 'v':
				verbose++;
				break;
			default:
				usage(argv[0]);
				exit(EX_USAGE);
		}
	}

	if (gotopt == 0) {
		if (argc == 12) {
			host_arg = argv[1];
			port_arg = argv[2];
			reqlen_arg = argv[3];
			rsplen_arg = argv[4];
			ntimes_arg = argv[5];
			alt_addr_arg = argv[6];
		} else {
			usage(argv[0]);
			exit(EX_USAGE);
		}
	}

	if (host_arg == NULL)
		errx(EX_USAGE, "missing required host option\n");

	if (port_arg == NULL)
		errx(EX_USAGE, "missing required port option\n");
	portno = atoi(port_arg);
	if (portno < 0 || portno > 65535)
		errx(EX_USAGE, "invalid port %s\n", port_arg);

	if (reqlen_arg != NULL) {
		reqlen = atoi(reqlen_arg);
		if (reqlen < 0 || reqlen > 1024 * 1024)
			errx(EX_USAGE, "invalid request length %s\n", reqlen_arg);
	}

	if (rsplen_arg != NULL) {
		rsplen = atoi(rsplen_arg);
		if (rsplen < 0 || rsplen > 1024 * 1024)
			errx(EX_USAGE, "invalid response length %s\n", rsplen_arg);
	}

	if (ntimes_arg != NULL) {
		ntimes = atoi(ntimes_arg);
		if (ntimes < 1)
			errx(EX_USAGE, "invalid ntimes option %s\n", ntimes_arg);
	}

	buffer1 = setup_buffer1(reqlen);
	if (!buffer1) {
		printf("client: failed to alloc buffer space \n");
		return -1;
	}

	buffer2 = setup_buffer2(reqlen);
	if (!buffer2) {
		printf("client: failed to alloc buffer space \n");
		return -1;
	}

	buffer3 = setup_buffer3(rsplen);
	if (!buffer3) {
		printf("client: failed to alloc buffer space \n");
		return -1;
	}

	if (verbose > 0)
		printf("host: %s port: %s reqlen: %d rsplen: %d ntimes: %d alt_addr: %s\n",
			host_arg, port_arg, reqlen, rsplen, ntimes, alt_addr_arg);

	sockfd = socket(AF_MULTIPATH, SOCK_STREAM, 0);
	if (sockfd < 0)
		err(EX_OSERR, "ERROR opening socket");

	memset(&ahints, 0, sizeof(struct addrinfo));
	ahints.ai_family = AF_INET;
	ahints.ai_socktype = SOCK_STREAM;
	ahints.ai_protocol = IPPROTO_TCP;

	retval = getaddrinfo(host_arg, port_arg, &ahints, &ares);
	if (retval != 0)
		printf("getaddrinfo(%s, %s) failed %d\n", host_arg, port_arg, retval);

	bytes_to_rdwr = reqlen;

	cid1 = cid2 = SAE_CONNID_ANY;
	int ifscope = 0;
	int error = 0;

	if (verbose > 0) {
		char str[2 * INET6_ADDRSTRLEN];

		ts_print();

		sprint_sockaddr(str, sizeof(str), ares->ai_addr);
		printf("connectx(%s, %d, %d)\n", str, ifscope, cid1);
	}
	sa_endpoints_t sa;
	bzero(&sa, sizeof(sa));
	sa.sae_dstaddr = ares->ai_addr;
	sa.sae_dstaddrlen = ares->ai_addrlen;
	sa.sae_srcif = ifscope;

	error = connectx(sockfd, &sa, SAE_ASSOCID_ANY, 0, NULL, 0, NULL, &cid1);
	if (error != 0)
		err(EX_OSERR, "ERROR connecting");

	iter = 0;

	while (ntimes) {
		if (iter == 0) {
			/* Add alternate path if available */

			if (alt_addr_arg && alt_addr_arg[0] != 0) {
				retval = getaddrinfo(alt_addr_arg, alt_port_arg, &ahints, &altres);

				if (retval != 0)
					printf("client: alternate address resolution failed. \n");
				else {
					printf("client: connecting to alternate address (ifscope %d)\n", ifscope);

					if (verbose > 0) {
						char str[2 * INET6_ADDRSTRLEN];

						ts_print();

						sprint_sockaddr(str, sizeof(str), altres->ai_addr);
						printf("connectx(%s, %d, %d)\n", str, ifscope, cid1);
					}
					sa_endpoints_t sa;
					bzero(&sa, sizeof(sa));
					sa.sae_srcif = ifscope;
					sa.sae_srcaddr = altres->ai_addr;
					sa.sae_srcaddrlen = altres->ai_addrlen;
					sa.sae_dstaddr = ares->ai_addr;
					sa.sae_dstaddrlen = ares->ai_addrlen;

					error = connectx(sockfd, &sa, SAE_ASSOCID_ANY, 0, NULL, 0, NULL, &cid2);
					if (error < 0) {
						err(EX_OSERR, "ERROR setting up alternate path");
					}
				}
			}
		}

		if (which_buf == 0) {
			buffer = buffer1;
			which_buf = 1;
		} else {
			buffer = buffer2;
			which_buf = 0;
		}

		while (bytes_to_rdwr) {
			if (verbose) {
				ts_print();
				printf("writing %d bytes\n", bytes_to_rdwr);
			}
			n = write(sockfd, buffer, bytes_to_rdwr);
			if (n <= 0) {
				err(EX_OSERR, "ERROR writing to socket");
			}
			if (n <= bytes_to_rdwr)
				bytes_to_rdwr -= n;
			else {
				errx(EX_DATAERR, "ERROR extra data write %zd %d\n", n, bytes_to_rdwr);
			}
		}
		bytes_to_rdwr = rsplen;
		while (bytes_to_rdwr) {
			if (verbose) {
				ts_print();
				printf("reading %d bytes\n", rsplen);
			}
			n = read(sockfd, buffer3, rsplen);

			if (n <= 0) {
				err(EX_OSERR, "ERROR reading from socket");
			}
			if (n <= bytes_to_rdwr)
				bytes_to_rdwr -= n;
			else {
				errx(EX_DATAERR, "ERROR extra bytes read n:%zd expected:%d\n", n, bytes_to_rdwr);
			}
		}
		bytes_to_rdwr = reqlen;
		ntimes--;
		iter++;
	}

	printf("client: Req size %d Rsp size %d Read/Write %d times \n", reqlen, rsplen, iter);

	showmpinfo(sockfd);

	if (verbose) {
		ts_print();
		printf("close(%d)\n", sockfd);
	}
	close(sockfd);

	freeaddrinfo(ares);
	if (altres)
		freeaddrinfo(altres);
	return 0;
}

#define	CIF_BITS	\
"\020\1CONNECTING\2CONNECTED\3DISCONNECTING\4DISCONNECTED\5BOUND_IF"\
"\6BOUND_IP\7BOUND_PORT\10PREFERRED\11MP_CAPABLE\12MP_READY" \
"\13MP_DEGRADED"

/*
 * Print a value a la the %b format of the kernel's printf
 */
static void
printb(const char *s, unsigned v, const char *bits)
{
	int i, any = 0;
	char c;

	if (bits && *bits == 8)
		printf("%s=%o", s, v);
	else
		printf("%s=%x", s, v);
	bits++;
	if (bits) {
		putchar('<');
		while ((i = *bits++) != '\0') {
			if (v & (1 << (i-1))) {
				if (any)
					putchar(',');
				any = 1;
				for (; (c = *bits) > 32; bits++)
					putchar(c);
			} else {
				for (; *bits > 32; bits++)
					;
			}
		}
		putchar('>');
	}
}

static int
showconninfo(int s, sae_connid_t cid)
{
	char buf[INET6_ADDRSTRLEN];
	conninfo_t *cfo = NULL;
	int err;

	err = copyconninfo(s, cid, &cfo);
	if (err != 0) {
		printf("getconninfo failed for cid %d\n", cid);
		goto out;
	}

	printf("%6d:\t", cid);
	printb("flags", cfo->ci_flags, CIF_BITS);
	printf("\n");

	if (cfo->ci_src != NULL) {
		printf("\tsrc %s port %d\n", inet_ntop(cfo->ci_src->sa_family,
						       (cfo->ci_src->sa_family == AF_INET) ?
						       (void *)&((struct sockaddr_in *)cfo->ci_src)->
						       sin_addr.s_addr :
						       (void *)&((struct sockaddr_in6 *)cfo->ci_src)->sin6_addr,
						       buf, sizeof (buf)),
		       (cfo->ci_src->sa_family == AF_INET) ?
		       ntohs(((struct sockaddr_in *)cfo->ci_src)->sin_port) :
		       ntohs(((struct sockaddr_in6 *)cfo->ci_src)->sin6_port));
	}
	if (cfo->ci_dst != NULL) {
		printf("\tdst %s port %d\n", inet_ntop(cfo->ci_dst->sa_family,
						       (cfo->ci_dst->sa_family == AF_INET) ?
						       (void *)&((struct sockaddr_in *)cfo->ci_dst)->
						       sin_addr.s_addr :
						       (void *)&((struct sockaddr_in6 *)cfo->ci_dst)->sin6_addr,
						       buf, sizeof (buf)),
		       (cfo->ci_dst->sa_family == AF_INET) ?
		       ntohs(((struct sockaddr_in *)cfo->ci_dst)->sin_port) :
		       ntohs(((struct sockaddr_in6 *)cfo->ci_dst)->sin6_port));
	}
	if (cfo->ci_aux_data != NULL) {
		switch (cfo->ci_aux_type) {
			case CIAUX_TCP:
				printf("\tTCP aux info available\n");
				break;
			default:
				printf("\tUnknown aux type %d\n", cfo->ci_aux_type);
				break;
		}
	}
out:
	if (cfo != NULL)
		freeconninfo(cfo);

	return (err);
}

static void
showmpinfo(int s)
{
	uint32_t aid_cnt = 0, cid_cnt = 0;
	sae_associd_t *aid = NULL;
	sae_connid_t *cid = NULL;
	int i, error = 0;

	error = copyassocids(s, &aid, &aid_cnt);
	if (error != 0) {
		printf("copyassocids failed\n");
		goto done;
	} else {
		printf("found %d associations", aid_cnt);
		if (aid_cnt > 0) {
			printf(" with IDs:");
			for (i = 0; i < aid_cnt; i++)
				printf(" %d\n", aid[i]);
		}
		printf("\n");
	}

	/* just do an association for now */
	error = copyconnids(s, SAE_ASSOCID_ANY, &cid, &cid_cnt);
	if (error != 0) {
		warn("getconnids failed\n");
		goto done;
	} else {
		printf("found %d connections", cid_cnt);
		if (cid_cnt > 0) {
			printf(":\n");
			for (i = 0; i < cid_cnt; i++) {
				if (showconninfo(s, cid[i]) != 0)
					break;
			}
		}
		printf("\n");
	}

done:
	if (aid != NULL)
		freeassocids(aid);
	if (cid != NULL)
		freeconnids(cid);
}
