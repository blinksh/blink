/*
 * Copyright (c) 2009-2015 Apple Inc. All rights reserved.
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
 * Usage for frame_delay
 *
 * Server
 *	./frame_delay -m server -t <tcp/udp> -p <port> -n <num_frames> -f <frame_size>
 *
 * Client
 *	./frame_delay -m client -t <tcp/udp> -i <srv_ipv4_add> -p <srv_port> -n <num_frames> -f <frame_size> -d <delay_ms>  -k <traffic_class>
 */

/*
 * TODO list :
 *				1. UDP fragmentation and reassembly
 */

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>

/* Server Static variable */
static int so, srv_so;
static int srv_port = 0;
static struct sockaddr_in laddr, dst_addr;
/* Client Static variable */
static struct sockaddr_in srv_addr;
static uint32_t tc = 0;
/* Usage */
void ErrorUsage(void);
/* str2svc */
uint32_t str2svc(const char *str);
/* Show Stastics */
void ShowStastics(int64_t *DiffsBuf, int num_frames);
/* Returns difference between two timevals in microseconds */
int64_t time_diff(struct timeval *b, struct timeval *a);
/* tcp server */
void tcpServer(int frame_size, int num_frames, char *buf, int64_t *DiffsBuf);
/* udp server */
void udpServer(int frame_size, int num_frames, char *buf, int64_t *DiffsBuf);
/* tcp server */
void tcpClient(int num_frames, int frame_size,
			   const char *buf, struct timespec sleep_time);
/* udp server */
void udpClient(int num_frames, int frame_size,
			   const char *buf, struct timespec sleep_time);

/* Main function */
int
main(int argc, char *argv[])
{
	int num_frames = 0, frame_size = 0, delay_ms = 0, rc = 0;
	char *buf = NULL, ch, *type = NULL, *mode = NULL, *ip_addr = NULL;
	int64_t *DiffsBuf;
	struct timespec sleep_time;

	while ((ch = getopt(argc, argv, "m:p:f:n:t:d:i:k:")) != -1) {
		switch (ch) {
			case 'm': {
				mode = optarg;
				break;
			}
			case 'p': {
				srv_port = atoi(optarg);
				break;
			}
			case 'f' : {
				frame_size = atoi(optarg);
				break;
			}
			case 'n' : {
				num_frames = atoi(optarg);
				break;
			}
			case 'i': {
				ip_addr = optarg;
				bzero(&srv_addr, sizeof(srv_addr));
				rc = inet_aton(optarg, &srv_addr.sin_addr);
				if (rc == 0) {
					perror("inet_ntoa failed");
					exit(1);
				}
			}
			case 'd': {
				delay_ms = atoi(optarg);
				break;
			}
			case 't' : {
				type = optarg;
				break;
			}
			case 'k': {
				tc = str2svc(optarg);
				break;
			}
			default: {
				printf("Invalid option: %c\n", ch);
				ErrorUsage();
			}
		}
	}
	/* General check for both server and client */
	if (srv_port <= 0 || frame_size <= 0 || num_frames <= 0 || !mode || !type) {
		ErrorUsage();
	}
	if ( strcmp(type, "tcp") != 0 && strcmp(type, "udp") != 0 ) {
		ErrorUsage();
	}
	/* Allocate memory for buf */
	buf = calloc(1, frame_size);
	if (buf == NULL) {
		printf("malloc failed\n");
		exit(1);
	}
	if ( strcmp(mode, "server") == 0 ) {
		/* Server */
		printf("<LOG>   :   Start %s server on port %d with expected frame size of %d\n",
			   type, srv_port, frame_size);
		DiffsBuf = (int64_t *)calloc(num_frames, sizeof(int64_t));
		if (DiffsBuf == NULL) {
			printf("malloc failed\n");
			exit(1);
		}
		if( strcmp(type, "tcp") == 0) {
			/* tcpServer */
			tcpServer(frame_size, num_frames, buf, DiffsBuf);
		} else {
			/* updServer */
			udpServer(frame_size, num_frames, buf, DiffsBuf);
		}
	}
	else if ( strcmp(mode, "client") == 0 ){
		if ( !ip_addr || (tc > 0 && (tc < SO_TC_BK_SYS || tc > SO_TC_CTL)) ){
			ErrorUsage();
		 }
		/* Client */
		printf("<LOG>   :   Start sending %d %s frames to %s:%d with a frame size of %d\n",
			   num_frames, type, ip_addr, srv_port, frame_size);
		/* Resolving sleep time bug : delay_ms should just be calculated once */
		bzero(&sleep_time, sizeof(sleep_time));
		while (delay_ms >= 1000) {
			sleep_time.tv_sec++;
			delay_ms -= 1000;
		}
		sleep_time.tv_nsec = delay_ms * 1000 * 1000;
		if( strcmp(type, "tcp") == 0) {
			/* Call TCP client */
			tcpClient(num_frames, frame_size, buf, sleep_time);
		} else {
			/* Call UDP client */
			udpClient(num_frames, frame_size, buf, sleep_time);
		}
	} else {
		ErrorUsage();
	}
}

/* Error usage */
void
ErrorUsage(void) {
	printf("Correct Usage");
	printf("Server : frame_delay -m server -t <tcp/udp> -p <port> -n <num_frames> -f <frame_size>\n");
	printf("Client : frame_delay -m client -t <tcp/udp> -i <srv_ipv4_add> -p <srv_port> -n <num_frames> -f <frame_size> -d <delay_ms>  -k <traffic_class>\n");
	exit(1);
}

/* str2svc */
uint32_t
str2svc(const char *str)
{
	uint32_t svc;
	char *endptr;

	if (str == NULL || *str == '\0')
		svc = UINT32_MAX;
	else if (strcasecmp(str, "BK_SYS") == 0)
		return SO_TC_BK_SYS;
	else if (strcasecmp(str, "BK") == 0)
		return SO_TC_BK;
	else if (strcasecmp(str, "BE") == 0)
		return SO_TC_BE;
	else if (strcasecmp(str, "RD") == 0)
		return SO_TC_RD;
	else if (strcasecmp(str, "OAM") == 0)
		return SO_TC_OAM;
	else if (strcasecmp(str, "AV") == 0)
		return SO_TC_AV;
	else if (strcasecmp(str, "RV") == 0)
		return SO_TC_RV;
	else if (strcasecmp(str, "VI") == 0)
		return SO_TC_VI;
	else if (strcasecmp(str, "VO") == 0)
		return SO_TC_VO;
	else if (strcasecmp(str, "CTL") == 0)
		return SO_TC_CTL;
	else {
		svc = (uint32_t)strtoul(str, &endptr, 0);
		if (*endptr != '\0')
			svc = UINT32_MAX;
	}
	return (svc);
}

/* Show Stastics */
void
ShowStastics(int64_t *DiffsBuf, int num_frames) {
	int i = 0;
	int64_t sum = 0, mean = 0;

	/* Mean */
	while(i < num_frames)
		sum += DiffsBuf[i++];
	mean = sum / num_frames;
	printf("<LOG>   :   Mean: %.2f usecs\n", sum / (double)num_frames);
	/* Popular Standard Deviation */
	i = 0;
	sum = 0;
	while(i < num_frames) {
		sum += (DiffsBuf[i]-mean)*(DiffsBuf[i]-mean);
		i++;
	}
	printf("<LOG>   :   Popular Standard Deviation: %.2f usecs\n",
		   sqrt(sum/(double)num_frames));
}

/* Returns difference between two timevals in microseconds */
int64_t
time_diff(struct timeval *b, struct timeval *a)
{
	int64_t usecs;
	usecs = (a->tv_sec - b->tv_sec) * 1000 * 1000;
	usecs += (int64_t)(a->tv_usec - b->tv_usec);
	return(usecs);
}

/* Server */

/* tcp server */
void
tcpServer(int frame_size, int num_frames, char *buf, int64_t *DiffsBuf) {
	int rc = 0, i = 0, ignore_count = 0;
	uint32_t dst_len = 0;
	struct timeval before, after;
	ssize_t bytes;
	int64_t usecs;
	/* New change from Padama */
	uint64_t prev_frame_ts = 0, prev_recv = 0, frame_ts = 0, cur_recv = 0;
	uint64_t min_variation = 0, max_variation = 0, avg_variation = 0;

	printf("<LOG>   :   TCP Server\n");
	so = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
	if (so == -1) {
		perror("failed to create socket");
		exit(1);
	}
	bzero(&laddr, sizeof(laddr));
	laddr.sin_family = AF_INET;
	laddr.sin_port = htons(srv_port);
	rc = bind(so, (const struct sockaddr *)&laddr, sizeof(laddr));
	if (rc != 0) {
		perror("failed to bind");
		exit(1);
	}
	rc = listen(so, 10);
	if (rc != 0) {
		perror("failed to listen");
		exit(1);
	}
	srv_so = accept(so, (struct sockaddr *)&dst_addr, &dst_len);
	if (srv_so == -1) {
		perror("failed to accept");
		exit(1);
	}
	while (1) {
		if ( i == num_frames ) {
			printf("<LOG>   :   Completed\n");
			break;
		}
		printf("<LOG>   :   Waiting for receiving\n");
		bzero(&before, sizeof(before));
		bzero(&after, sizeof(after));
		rc = gettimeofday(&before, NULL);
		if (rc == -1) {
			perror("gettimeofday failed");
			exit(1);
		}
		bytes = recv(srv_so, buf, frame_size, MSG_WAITALL);
		if (bytes == -1) {
			perror("recv failed");
			exit(1);
		}
		else if (bytes > 0 && bytes != frame_size) {
			printf("Client exited\n");
			printf("Didn't recv the complete frame, bytes %ld\n",
				   bytes);
			exit(1);
		}
		else if (bytes == 0) {
			break;
		}
		rc = gettimeofday(&after, NULL);
		if (rc == -1) {
			perror("gettimeofday failed");
			exit(1);
		}
		cur_recv = after.tv_sec * 1000 * 1000 + after.tv_usec;
		memcpy((void *)&frame_ts, buf, sizeof(frame_ts));
		if (prev_frame_ts > 0) {
			int64_t d_variation = 0;
			d_variation = (int64_t)((cur_recv - prev_recv) -
									(frame_ts - prev_frame_ts));
			/* printf("Frame %u ts %llu d_variation %lld usecs\n",
			 i, frame_ts, d_variation);*/
			if (d_variation > 0) {
				if (min_variation == 0)
					min_variation = d_variation;
				else
					min_variation = ((min_variation <= d_variation) ?
									 min_variation : d_variation);
				max_variation = ((max_variation >= d_variation) ?
								 max_variation : d_variation);
				avg_variation += d_variation;
			} else {
				ignore_count++;
			}
		}
		prev_recv = cur_recv;
		prev_frame_ts = frame_ts;
		++i;
		/* Compute the time differenc */
		usecs = time_diff(&before, &after);
		DiffsBuf[i] = usecs;
		printf("<LOG>   :   Frame %d received after %lld usecs\n", i, usecs);
	}
	if (i != ignore_count)
		avg_variation = avg_variation / (i - ignore_count);
	else
		avg_variation = 0;

	printf("<LOG>   :   Received frames: %u\n", i);
	printf("<LOG>   :   Ignored frames: %u\n", ignore_count);
	printf("<LOG>   :   Minimum delay variation: %llu usecs\n", min_variation);
	printf("<LOG>   :   Maximum delay variation: %llu usecs\n", max_variation);
	printf("<LOG>   :   Average delay variation: %llu usecs\n", avg_variation);
	ShowStastics(DiffsBuf, num_frames);
}

/* udp server */
void
udpServer(int frame_size, int num_frames, char *buf, int64_t *DiffsBuf) {
	int rc = 0, i = 0, ignore_count = 0;
	uint32_t dst_len = 0;
	ssize_t bytes;
	struct timeval before, after;
	int64_t usecs;
	/* New change from Padama */
	uint64_t prev_frame_ts = 0, prev_recv = 0, frame_ts = 0, cur_recv = 0;
	uint64_t min_variation = 0, max_variation = 0, avg_variation = 0;

	printf("<LOG>   :   UDP Server\n");
	so = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (so == -1) {
		perror("failed to create socket");
		exit(1);
	}
	bzero(&laddr,sizeof(laddr));
	laddr.sin_family = AF_INET;
	laddr.sin_addr.s_addr=htonl(INADDR_ANY);
	laddr.sin_port=htons(srv_port);
	rc = bind(so, (struct sockaddr *)&laddr,sizeof(laddr));
	if (rc != 0) {
		perror("failed to bind");
		exit(1);
	}
	while (1) {
		if ( i == num_frames ) {
			printf("<LOG>   :   Completed\n");
			break;
		}
		printf("<LOG>   :   Waiting for receiving\n");
		bzero(&before, sizeof(before));
		bzero(&after, sizeof(after));
		rc = gettimeofday(&before, NULL);
		if (rc == -1) {
			perror("gettimeofday failed");
			exit(1);
		}
		bytes = recvfrom(so, buf, frame_size, 0, (struct sockaddr *)&dst_addr, &dst_len);
		if (bytes == -1) {
			perror("recv failed");
			exit(1);
		}
		else if (bytes > 0 && bytes != frame_size) {
			printf("Client exited\n");
			printf("Didn't recv the complete frame, bytes %ld\n",
				   bytes);
			exit(1);
		}
		else if (bytes == 0) {
			break;
		}
		rc = gettimeofday(&after, NULL);
		if (rc == -1) {
			perror("gettimeofday failed");
			exit(1);
		}
		cur_recv = after.tv_sec * 1000 * 1000 + after.tv_usec;
		memcpy((void *)&frame_ts, buf, sizeof(frame_ts));
		if (prev_frame_ts > 0) {
			int64_t d_variation = 0;

			d_variation = (int64_t)((cur_recv - prev_recv) -
									(frame_ts - prev_frame_ts));
			/* printf("Frame %u ts %llu d_variation %lld usecs\n",
			 i, frame_ts, d_variation);*/
			if (d_variation > 0) {
				if (min_variation == 0)
					min_variation = d_variation;
				else
					min_variation = ((min_variation <= d_variation) ?
									 min_variation : d_variation);
				max_variation = ((max_variation >= d_variation) ?
								 max_variation : d_variation);
				avg_variation += d_variation;
			} else {
				ignore_count++;
			}
		}
		prev_recv = cur_recv;
		prev_frame_ts = frame_ts;
		++i;
		/* Compute the time differenc */
		usecs = time_diff(&before, &after);
		DiffsBuf[i] = usecs;
		printf("<LOG>   :   Frame %d received after %lld usecs\n", i, usecs);
	}
	if (i != ignore_count)
		avg_variation = avg_variation / (i - ignore_count);
	else
		avg_variation = 0;
	printf("<LOG>   :   Received frames: %u\n", i);
	printf("<LOG>   :   Ignored frames: %u\n", ignore_count);
	printf("<LOG>   :   Minimum delay variation: %llu usecs\n", min_variation);
	printf("<LOG>   :   Maximum delay variation: %llu usecs\n", max_variation);
	printf("<LOG>   :   Average delay variation: %llu usecs\n", avg_variation);
	ShowStastics(DiffsBuf, num_frames);
}

/* Client */
void
tcpClient(int num_frames, int frame_size,
			   const char *buf, struct timespec sleep_time){
	int rc = 0, i = 0;
	ssize_t bytes;

	printf("<LOG>   :   TCP Client\n");
	so = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);

	if (so <= 0) {
		perror("creating socket failed");
		exit(1);
	}
	srv_addr.sin_port = htons(srv_port);
	srv_addr.sin_len = sizeof(srv_addr);
	srv_addr.sin_family = AF_INET;
	rc = connect(so, (const struct sockaddr *)&srv_addr,
				 sizeof(srv_addr));
	if (rc != 0) {
		perror("connect failed");
		exit(1);
	}
	if (tc > 0) {
		rc = setsockopt(so, SOL_SOCKET, SO_TRAFFIC_CLASS, &tc,
						sizeof(tc));
		if (rc == -1) {
			perror("failed to set traffic class");
			exit(1);
		}
	}
	for (i = 0; i < num_frames; ++i) {
		struct timeval fts;
		uint64_t frame_ts;
		/* Add a timestamp to the frame */
		rc = gettimeofday(&fts, NULL);
		if (rc == -1) {
			perror("faile to get time of day");
			exit(1);
		}
		frame_ts = fts.tv_sec * 1000 * 1000 + fts.tv_usec;
		memcpy((void *)buf, (const void *)&frame_ts, sizeof(frame_ts));
		bytes = send(so, buf, frame_size, 0);
		if (bytes == -1) {
			perror("send failed \n");
			exit(1);
		}
		if (bytes != frame_size) {
			printf("failed to send all bytes, sent %ld\n", bytes);
			exit (1);
		}
		rc = nanosleep(&sleep_time, NULL);
		if (rc == -1) {
			perror("sleep failed");
			exit(1);
		}
		printf("<LOG>   :   Sent %u frames as a whole\n", (i + 1));
	}
}

void
udpClient(int num_frames, int frame_size,
			   const char *buf, struct timespec sleep_time){
	int rc = 0, i = 0;
	ssize_t bytes;

	printf("<LOG>   :   UDP Client\n");
	so = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (so <= 0) {
		perror("creating socket failed");
		exit(1);
	}
	srv_addr.sin_port = htons(srv_port);
	srv_addr.sin_len = sizeof(srv_addr);
	srv_addr.sin_family = AF_INET;
	if (tc > 0) {
		rc = setsockopt(so, SOL_SOCKET, SO_TRAFFIC_CLASS, &tc,
						sizeof(tc));
		if (rc == -1) {
			perror("failed to set traffic class");
			exit(1);
		}
	}
	for (i = 0; i < num_frames; ++i) {
		struct timeval fts;
		uint64_t frame_ts;
		/* Add a timestamp to the frame */
		rc = gettimeofday(&fts, NULL);
		if (rc == -1) {
			perror("faile to get time of day");
			exit(1);
		}
		frame_ts = fts.tv_sec * 1000 * 1000 + fts.tv_usec;
		memcpy((void *)buf, (const void *)&frame_ts, sizeof(frame_ts));
		bytes = sendto(so, buf, frame_size, 0, (struct sockaddr *)&srv_addr, sizeof(srv_addr));
		if (bytes == -1) {
			perror("send failed \n");
			exit(1);
		}
		if (bytes != frame_size) {
			printf("failed to send all bytes, sent %ld\n", bytes);
			exit (1);
		}
		rc = nanosleep(&sleep_time, NULL);
		if (rc == -1) {
			perror("sleep failed");
			exit(1);
		}
		printf("<LOG>   :   Sent %u frames as a whole\n", (i + 1));
	}
}


