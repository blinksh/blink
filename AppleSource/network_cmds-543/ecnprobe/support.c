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
#include "base.h"
#include "inet.h"
#include "session.h"
#include "capture.h"
#include "support.h"

extern struct TcpSession session; 

void SendReset()
{
  struct IPPacket *p;
  int i;

  if (session.dont_send_reset)
	  return;

  if ((p = (struct IPPacket *)calloc(1, sizeof(struct IPPacket))) == NULL) {
    perror("ERROR: Could not allocate RST packet:") ;
    Quit(ERR_MEM_ALLOC) ; 
  }

  if ((p->ip = (struct IpHeader *)calloc(1, sizeof(struct IpHeader))) == NULL) {
    perror("ERROR: Could not allocate IP Header for RST packet:") ;
    Quit(ERR_MEM_ALLOC) ; 
  }

  if ((p->tcp = (struct TcpHeader *)calloc(1, sizeof(struct TcpHeader))) == NULL) {
    perror("ERROR: Could not allocate TCP Header for RST packet:") ;
    Quit(ERR_MEM_ALLOC) ; 
  }
  
  for (i = 0; i < MAXRESETRETRANSMITS; i++) {
    SendSessionPacket(p, 
		      //sizeof(struct IPPacket), 
		      sizeof(struct IpHeader) + sizeof(struct TcpHeader),
		      TCPFLAGS_RST, 
		      0,
		      0, 
		      0);
  }

/*  free(p->ip);
  free(p->tcp);
  free(p);
*/

}

#if 0
/* make a clean exit on interrupts */
void  SigHandle (int signo)
{
  Cleanup () ; 
  fflush(stdout); 
  fflush(stderr); 
  exit(-1);
}


void Cleanup()
{

  char ipfw_rule[100];
  int r;

  /* If a firewall rule has been installed then remove it */
  if (session.initFirewall > 0) {
    
#ifdef linux
#define IP_FW_DEL	(IP_FW_DELETE)
#endif /* linux */

    sprintf(ipfw_rule, "ipfw del 00%d", session.firewall_rule_number); 
    r = system(ipfw_rule);

  }

  if (session.initSession > 0) {

    SendReset();
    shutdown(session.socket,2);

  }

  if (session.initCapture > 0) {
    CaptureEnd();
  }

}

void Quit(int how)
{

  Cleanup();
  fflush(stdout);
  fflush(stderr);
  exit(how);

}
#endif /* 0 */

double GetTime()
{
  struct timeval tv;
  struct timezone tz;
  double postEpochSecs;
  
  if (gettimeofday(&tv, &tz) < 0) {
    perror("GetTime");
    exit(-1);
  }
  
  postEpochSecs = (double)tv.tv_sec + ((double)tv.tv_usec/(double)1000000.0);
  return postEpochSecs;
}

double GetTimeMicroSeconds()
{
  struct timeval tv;
  struct timezone tz;
  double postEpochMicroSecs;
  
  if (gettimeofday(&tv, &tz) < 0) {
    perror("GetTimeMicroSeconds");
    exit(-1);
  }
  
  postEpochMicroSecs = (double)tv.tv_sec * 1000000 + (double)tv.tv_usec;
  return postEpochMicroSecs;

}

void PrintTimeStamp(struct timeval *ts)
{
  (void)printf("%02d:%02d:%02d.%06u ",
	       (unsigned int)ts->tv_sec / 3600,
	       ((unsigned int)ts->tv_sec % 3600) / 60,
	       (unsigned int)ts->tv_sec % 60, (unsigned int)ts->tv_usec);
}

void processBadPacket (struct IPPacket *p)
{

  if (session.debug == SESSION_DEBUG_HIGH) {
    printf("In ProcessBadPacket...\n");
  }
  /*
   * reset? the other guy does not like us?
   */
  if (INSESSION(p,session.dst,session.dport,session.src,session.sport) && (p->tcp->tcp_flags & TCPFLAGS_RST)) {
    printf("ERROR: EARLY_RST.\nRETURN CODE: %d\n", EARLY_RST);
    Quit(EARLY_RST);
  }
  /*
   * some other packet between us that is none of the above
   */
  if (INSESSION(p, session.src, session.sport, session.dst, session.dport) ||
      INSESSION(p, session.dst, session.dport, session.src, session.sport)) {

    printf("ERROR: Unexpected packet\nRETURN CODE: %d\n", UNEXPECTED_PKT);
    printf("Expecting:\n");
    printf("\tsrc = %s:%d (seq=%u, ack=%u)\n",
	   InetAddress(session.src), session.sport,
	   session.snd_nxt-session.iss,
	   session.rcv_nxt-session.irs);
    printf("\tdst = %s:%d (seq=%u, ack=%u)\n",
	   InetAddress(session.dst),session.dport,
	   session.rcv_nxt-session.irs, session.snd_una-session.iss);
    printf("Received:\n\t");
    PrintTcpPacket(p);
    printf ("session.snd_nxt=%d, session.rcv_nxt=%d, session.snd_una=%d\n", 
	    session.snd_nxt-session.iss, session.rcv_nxt-session.irs, session.snd_una-session.iss);
    Quit(UNEXPECTED_PKT);
  }
  /*
   * none of the above, 
   * so we must be seeing packets 
   * from some other flow!
   */
  else {
    printf("ERRROR: Received packet from different flow\nRETURN CODE: %d\n", DIFF_FLOW);
    PrintTcpPacket(p);
    Quit(DIFF_FLOW) ;
  }

  if (session.debug == SESSION_DEBUG_HIGH) {
    printf("Out ProcessBadPacket...\n");
  }
}

void busy_wait (double wait)
{
  double now = GetTime();
  double x = now ;
  while ((x - now) < wait) {
    x = GetTime();
  }
}
