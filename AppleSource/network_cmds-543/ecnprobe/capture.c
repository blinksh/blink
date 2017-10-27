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
#include <stdlib.h>
#include <stdio.h>
#include "gmt2local.h"
#include "pcap.h"
#include "inet.h"
#include "capture.h"

/* set snaplen to max etherenet packet size */
#define DEFAULT_SNAPLEN 1500 

pcap_t *pc;		/* pcap device */
int datalinkOffset;	/* offset of ip packet from datalink packet */
int captureDebug = 1;
unsigned int thisTimeZone;

void CaptureInit(u_int32_t sourceIP, u_int16_t sourcePort,
		 u_int32_t targetIP, u_int16_t targetPort, char *dev)
{

  char *device = NULL;
  char errbuf[PCAP_ERRBUF_SIZE];
  int snaplen = DEFAULT_SNAPLEN;
  int promisc = 1;
  int timeout = 10;  /* timeout in 1 second (10 ms) */
  char filtercmds[255];
  bpf_u_int32 netmask = 0;
  struct bpf_program filter;
  char source[18];
  char target[18];
  int i;

  /* Get local time zone for interpreting timestamps */
  /* XXX - does this belong here? */
  thisTimeZone = gmt2local(0);

  if (dev != NULL) {
    device = dev;
  } else {
    device = pcap_lookupdev(errbuf);
    if (device == NULL) {
      fprintf(stderr, "Can't find capture device: %s\n", errbuf);
      exit(-1);
    }
  }
 
  if (captureDebug) {
    printf("Device name is %s\n", device);
  }
  pc = pcap_open_live(device, snaplen, promisc, timeout, errbuf);
  if (pc == NULL) {
    fprintf(stderr,"Can't open capture device %s: %s\n",device, errbuf);
    exit(-1);
  } 

  /* XXX why do we need to do this? */
  i = pcap_snapshot(pc);
  if (snaplen < i) {
    fprintf(stderr, "Warning: snaplen raised to %d from %d",
	    snaplen, i);
  }

  if ((i = pcap_datalink(pc)) < 0) {
    fprintf(stderr,"Unable to determine datalink type for %s: %s\n",
	    device, errbuf);
    exit(-1);
  }

  switch(i) {

    case DLT_EN10MB: datalinkOffset = 14; break;
    case DLT_IEEE802: datalinkOffset = 22; break;
    case DLT_NULL: datalinkOffset = 4; break;
    case DLT_SLIP: 
    case DLT_PPP: datalinkOffset = 24; break;
    case DLT_RAW: datalinkOffset = 0; break;
    default: 
       fprintf(stderr,"Unknown datalink type %d\n",i);
       exit(-1);
       break;

  }

  if (InetAddress(sourceIP) < 0) {
    fprintf(stderr, "Invalid source IP address (%d)\n", sourceIP);
    exit(-1);
  }

  strncpy(source, InetAddress(sourceIP), sizeof(source) - 1);
  strncpy(target, InetAddress(targetIP), sizeof(target) - 1);

  /* Setup initial filter */
  sprintf(filtercmds,
    "(host %s && host %s && port %d) || icmp\n",
    source, target, targetPort);

  if (captureDebug) {
    printf("datalinkOffset = %d\n", datalinkOffset);
    printf("filter = %s\n", filtercmds);
  }
  if (pcap_compile(pc, &filter, filtercmds, 1, netmask) < 0) {
    printf("Error: %s", pcap_geterr(pc));
    exit(-1);
  }

  if (pcap_setfilter(pc, &filter) < 0) {
    fprintf(stderr, "Can't set filter: %s",pcap_geterr(pc));
    exit(-1);
  }
  
  if (captureDebug) {
    printf("Listening on %s...\n", device);
  }

}

char *CaptureGetPacket(struct pcap_pkthdr *pi)
{

  const u_char *p;

  p = pcap_next(pc, (struct pcap_pkthdr *)pi);

  if (p != NULL) {
    p += datalinkOffset;
  }

  pi->ts.tv_sec = (pi->ts.tv_sec + thisTimeZone) % 86400;

  return (char *)p;

}


void CaptureEnd()
{
  struct pcap_stat stat;

  if (pcap_stats(pc, &stat) < 0) {
    (void)fprintf(stderr, "pcap_stats: %s\n", pcap_geterr(pc));
  }
  else {
    (void)fprintf(stderr, "%d packets received by filter\n", stat.ps_recv); 
    (void)fprintf(stderr, "%d packets dropped by kernel\n", stat.ps_drop);
  }

  pcap_close(pc);
}

