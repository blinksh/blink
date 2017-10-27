/* 
   Copyright (c) 2000  
   International Computer Science Institute
   All rights reserved.

   This file may contain software code originally developed for the
   Sting project. The Sting software carries the following copyright:

   Copyright (c) 1998, 1999
   Stefan Savage and the University of Washington.
   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:
   1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
   2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
   3. All advertising materials mentioning features or use of this software
   must display the following acknowledgment:
   This product includes software developed by ACIRI, the AT&T
   Center for Internet Research at ICSI (the International Computer
   Science Institute). This product may also include software developed
   by Stefan Savage at the University of Washington.  
   4. The names of ACIRI, ICSI, Stefan Savage and University of Washington
   may not be used to endorse or promote products derived from this software
   without specific prior written permission.

   THIS SOFTWARE IS PROVIDED BY ICSI AND CONTRIBUTORS ``AS IS'' AND
   ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
   IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
   ARE DISCLAIMED.  IN NO EVENT SHALL ICSI OR CONTRIBUTORS BE LIABLE
   FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
   DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
   OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
   HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
   LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
   OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
   SUCH DAMAGE.
*/

#include <sys/types.h>
#include <sys/param.h>
#include <sys/time.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/socket.h>
#include <stdlib.h>
#include <netdb.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <spawn.h>
#include <ifaddrs.h>
#include "inet.h"
#include "capture.h"
#include "support.h"
#include "session.h"
#include "ecn.h"
#include "history.h"

extern struct TcpSession session;

void usage (char *name);
int GetCannonicalInfo(char *string, u_int32_t *address);
int BindTcpPort(int sockfd) ;

void usage(char *name)
{
	printf("%s [options]\n", name);
	printf("\t-n <target hostname | ipaddress>\n");
	printf("\t-p <target port>\n");
	printf("\t-m <mss>\n");
	printf("\t-M <mtu>\n");
	printf("\t-w <sourcePort>\n");
	printf("\t-s <source hostname or ip address>\n");
	printf("\t-f <file-name to get>\n");
	printf("\t-d <interface name>\n");
	printf("\t-C for CE path check\n");
	printf("\t-S [A|R|X] SYN followed by ACK or RST or nothing\n");
	printf("\t-F [set|clear|skip] how to handle firewall rules\n");
	return;
}

void SetupFirewall(u_int32_t targetIP, u_int16_t port, char *dev)
{
	char pfcmd[512];
	char *pf_file_name = "/tmp/pf.conf";
	int pf_fd = 0, rc;
	ssize_t bytes;
	char *args[4];

	bzero(pfcmd, sizeof(pfcmd));

	bzero(args, sizeof(args));
	sprintf(pfcmd, "block in quick on %s inet proto tcp from %s port %u\n",
		dev, InetAddress(targetIP), port);
	if (session.debug >= SESSION_DEBUG_LOW)
		printf("PF rule: %s\n", pfcmd);

	pf_fd = open(pf_file_name, O_RDWR|O_TRUNC|O_CREAT);
	if (pf_fd < 0) {
		perror("failed to open pf file");
		exit(1);
	}
	bytes = write(pf_fd, pfcmd, strlen(pfcmd) + 1);
	close(pf_fd);
	args[0] = "pfctl";
	args[1] = "-d";
	args[2] = NULL;
	rc = posix_spawn(NULL, "/sbin/pfctl", NULL, NULL, args, NULL);
	if (rc != 0) {
		printf("Failed to exec: pfctl -d: %d\n", rc);
		Quit(FAIL);
	}

	args[1] = "-f";
	args[2] = pf_file_name;
	args[3] = NULL;
	rc = posix_spawn(NULL, "/sbin/pfctl", NULL, NULL, args, NULL);
	if (rc != 0) {
		printf("Failed to exec: pfctl -f /tmp/pf.conf: %d\n", rc);
		Quit(FAIL);
	}

	args[1] = "-e";
	args[2] = NULL;
	rc = posix_spawn(NULL, "/sbin/pfctl", NULL, NULL, args, NULL);
	if (rc != 0) {
		printf("Failed to exec: pfctl -e: %d\n", rc);
		Quit(FAIL);
	}
}

void CleanupFirewall()
{
	char * args[3];
	int rc;

	args[0] = "pfctl";
	args[1] = "-d";
	args[2] = NULL;
	rc = posix_spawn(NULL, "/sbin/pfctl", NULL, NULL, args, NULL);
	if (rc != 0) {
		printf("Failed to exec: pfctl -d: %d\n", rc);
		Quit(FAIL);
	}
}

void Cleanup()
{
	if (session.initSession > 0) {
		shutdown(session.socket, 2);
	}
	if (session.initCapture > 0) {
		CaptureEnd();
	}
	if (session.initFirewall > 0) {
		CleanupFirewall();
	}
}

void Quit(int how)
{
	SendReset();
	Cleanup();
	fflush(stdout);
	fflush(stderr);
	exit(how);
}

void SigHandle(int signo)
{
	Cleanup();
	fflush(stdout);
	fflush(stderr);
	exit(-1);
}

int GetCannonicalInfo(char *string, u_int32_t *address)
{
	struct hostent *hp;
	/* Is string in dotted decimal format? */
	if ((*address = inet_addr(string)) == INADDR_NONE) {
		/* No, then lookup IP address */
		if ((hp = gethostbyname(string)) == NULL) {
			/* Can't find IP address */
			printf("ERROR: Couldn't obtain address for %s\n"
			    "RETURN CODE: %d\n", string, FAIL);
			return(-1);
		} else {
			strncpy(string, hp->h_name, MAXHOSTNAMELEN-1);
			memcpy((void *)address, (void *)hp->h_addr,
			    hp->h_length);
		}
	} else {
		if ((hp = gethostbyaddr((char *)address, sizeof(*address),
		    AF_INET)) == NULL) {
			/*
			 * Can't get cannonical hostname, so just use 
			 * input string
			 */
			if (session.debug) {
				printf("WARNING: Couldn't obtain cannonical"
				    " name for %s\nRETURN CODE: %d",
				    string, NO_SRC_CANON_INFO);
      			}
			/* strncpy(name, string, MAXHOSTNAMELEN - 1);*/
		} else {
			/* strncpy(name, hp->h_name, MAXHOSTNAMELEN - 1);*/
		}
	}
	return(0);
}

int BindTcpPort(int sockfd)
{
	struct sockaddr_in sockName;
	int port, result;
	int randomOffset;

#define START_PORT (50*1024)
#define END_PORT   (0xFFFF)

	/*
	 * Choose random offset to reduce likelihood of
	 * collision with last run
	 */
	randomOffset = (int)(1000.0*drand48());

	/* Try to find a free port in the range START_PORT+1..END_PORT */
	port = START_PORT+randomOffset;
	do {
		++port;
		sockName.sin_addr.s_addr = INADDR_ANY;
		sockName.sin_family = AF_INET;
		sockName.sin_port = 0; //htons(port);
		result = bind(sockfd, (struct sockaddr *)&sockName,
               	    sizeof(sockName));
	} while ((result < 0) && (port < END_PORT));


	if (result < 0) {
		/* No free ports */
		perror("bind");	
		port = 0;
	} else {
		socklen_t len = sizeof(sockName);
		result = getsockname(sockfd, (struct sockaddr *)&sockName, &len);
		if (result < 0) {
			perror("getsockname");
			port = 0;
		} else {
			port = ntohs(sockName.sin_port);
		}
	}
	return port;

}

#define	FIREWALL_DEFAULT 0
#define	FIREWALL_SET_ONLY 1
#define	FIREWALL_CLEAR_ONLY 2
#define FIREWALL_SKIP 3

int main(int argc, char **argv)
{
	u_int32_t targetIpAddress =  0;
	u_int16_t targetPort = DEFAULT_TARGETPORT;
	u_int16_t sourcePort = 0;
	u_int32_t sourceIpAddress = 0;
	int mss = DEFAULT_MSS;
	int mtu = DEFAULT_MTU;
	int fd, opt, usedev = 0, rc = 0, path_check = 0;
	int syn_test = 0, syn_reply = 0;
	struct sockaddr_in saddr;
	char dev[11];  /* device name for pcap init */
	struct ifaddrs *ifap, *tmp;
	int firewall_mode = FIREWALL_DEFAULT;

	bzero(&session, sizeof(session));
	while ((opt = getopt(argc, argv, "n:p:w:m:M:s:d:f:-CS:vF:")) != -1) {
		switch (opt) {
			case 'n':
				if (strlen(optarg) > (MAXHOSTNAMELEN - 1)) {
					printf("Target host name too long, max %u chars\n", MAXHOSTNAMELEN);
					Quit(FAIL);
				}
				strncpy(session.targetHostName, optarg,
					MAXHOSTNAMELEN);
				strncpy(session.targetName, session.targetHostName,
					MAXHOSTNAMELEN);
				break;
			case 'p':
				targetPort = atoi(optarg);
				break;
			case 'm':
				mss = atoi(optarg);
				break;
			case 'M':
				mtu = atoi(optarg);
				break;
			case 'w':
				sourcePort = atoi(optarg);
				break;
			case 's':
				if (strlen(optarg) > (MAXHOSTNAMELEN - 1)) {
					printf("Source host name too long, max %u chars\n", MAXHOSTNAMELEN);
					Quit(FAIL);
				}
				strncpy(session.sourceHostName, optarg,
					MAXHOSTNAMELEN);
				break;
			case 'd':
				if (strlen(optarg) > (sizeof(dev) - 1)) {
					printf("Interface nae is too large, max %lu chars\n", (sizeof(dev) - 1));
					Quit(FAIL);
				}
				bzero(dev, sizeof(dev));
				strncpy(dev, optarg, (sizeof(dev) - 1));
				usedev = 1;
				break;
			case 'f':
				if (strlen(optarg) > 0) {
					session.filename = strndup(optarg, strlen(optarg) + 1);
				} else {
					printf("Invalid file name \n");
				}
				break;
			case 'F':
				if (strcasecmp(optarg, "default") == 0)
					firewall_mode = FIREWALL_DEFAULT;
				else if (strcasecmp(optarg, "set") == 0)
					firewall_mode = FIREWALL_SET_ONLY;
				else if (strcasecmp(optarg, "clear") == 0)
					firewall_mode = FIREWALL_CLEAR_ONLY;
				else if (strcasecmp(optarg, "skip") == 0)
					firewall_mode = FIREWALL_SKIP;
				else
					printf("firewall mode\n");
				break;
			case 'C':
				path_check = 1;
				break;
			case 'S':
				syn_test = 1;
				if (strcasecmp(optarg, "A") == 0)
					syn_reply = TCPFLAGS_ACK;
				else if (strcasecmp(optarg, "R") == 0)
					syn_reply = TCPFLAGS_RST;
				else if (strcasecmp(optarg, "X") == 0)
					syn_reply = 0;
				else
					printf("Invalid SYN reply \n");
				break;
			case 'v':
				session.debug++;
				break;
			default:
				usage(argv[0]);
				exit(1);
		}
	}
	signal(SIGTERM, SigHandle);
	signal(SIGINT, SigHandle);
	signal(SIGHUP, SigHandle);

	if (GetCannonicalInfo(session.targetHostName, &targetIpAddress) < 0)
	{
		printf("Failed to convert targetIP address\n");
		Quit(NO_TARGET_CANON_INFO);
	}
	/*
	 if (GetCannonicalInfo(session.sourceHostName, &sourceIpAddress) < 0)
	 {
		printf("Failed to convert source IP address\n");
		Quit(NO_TARGET_CANON_INFO);
	 }
	 */
	rc = getifaddrs(&ifap);
	if (rc != 0 || ifap == NULL) {
		printf("Failed to get source addresswith getifaddrs: %d\n", rc);
		Quit(FAIL);
	}
	tmp = ifap;
	sourceIpAddress = 0;
	bzero(session.sourceHostName, MAXHOSTNAMELEN);
	for (tmp = ifap; tmp != NULL; tmp = tmp->ifa_next) {
		struct sockaddr_in *sin;
		if (tmp->ifa_addr == NULL)
			continue;
		if (tmp->ifa_addr->sa_family != PF_INET)
			continue;
		if (usedev == 1) {
			/* we know which interface to use */
			if (strcmp(dev, tmp->ifa_name) == 0) {
				sin = (struct sockaddr_in *)tmp->ifa_addr;
				sourceIpAddress = sin->sin_addr.s_addr;
				strncpy(session.sourceHostName,
					inet_ntoa(sin->sin_addr),
					MAXHOSTNAMELEN);
			} else {
				continue;
			}
		} else {
			/* pick the first address */
			bzero(dev, sizeof(dev));
			sin = (struct sockaddr_in *)tmp->ifa_addr;
			sourceIpAddress = sin->sin_addr.s_addr;
			strncpy(session.sourceHostName,
				inet_ntoa(sin->sin_addr),
				MAXHOSTNAMELEN);
			strncpy(dev, tmp->ifa_name, sizeof(dev));
		}
	}
	freeifaddrs(ifap);
	if (sourceIpAddress == 0) {
		printf("Failed to get source Ip address\n");
		Quit(FAIL);
	}

	if (sourcePort == 0) {
		bzero(&saddr, sizeof(saddr));
		saddr.sin_family = AF_INET;
		if ((fd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
			printf("Can't open socket\n");
			return (-1);
		}
		if ((sourcePort = BindTcpPort(fd)) == 0) {
			printf("Can't bind to port\n");
			return (-1);
		}
	}
	printf("Source: %s:%d\n", session.sourceHostName, sourcePort);
	printf("Destination: %s:%d\n", session.targetHostName, targetPort);

	switch (firewall_mode) {
		case FIREWALL_DEFAULT:
			SetupFirewall(targetIpAddress, targetPort, dev);
			session.initFirewall = 1;
			break;
		case FIREWALL_SET_ONLY:
			SetupFirewall(targetIpAddress, targetPort, dev);
			goto done;
		case FIREWALL_CLEAR_ONLY:
			session.initFirewall = 1;
			goto done;
		case FIREWALL_SKIP:
			break;
	}

	CaptureInit(sourceIpAddress, sourcePort, targetIpAddress,
		    targetPort, dev);
	session.initCapture = 1;


	printf("Starting ECN test\n");
	if (syn_test) {
		session.dont_send_reset = 1;
		SynTest(sourceIpAddress, sourcePort, targetIpAddress,
			targetPort, mss, syn_reply);
	} else if (path_check) {
		ECNPathCheckTest(sourceIpAddress, sourcePort, targetIpAddress,
				 targetPort, mss);
	} else {
		ECNTest(sourceIpAddress, sourcePort, targetIpAddress,
			targetPort, mss);
	}
done:
	Quit(SUCCESS);
	close(session.socket);
	return (0);
}
