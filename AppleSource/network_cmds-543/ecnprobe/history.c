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
#include "support.h"
#include "history.h"

extern struct TcpSession session;
struct History history[MAXHSZ]; 

void StorePacket (struct IPPacket *p) {

  uint32 src, dst, seq, ack ;
  uint16 sport, dport, win, urp, datalen, optlen; 
  uint16 ip_optlen;
  uint8 flags;
  
  ReadIPPacket(p, 
	       &src, &dst, 
	       &sport, &dport, 
	       &seq, 
	       &ack, 
	       &flags, 
	       &win,
	       &urp, 
	       &datalen, 
	       &ip_optlen, 
	       &optlen); 

  if (src == session.src) {
    history[session.hsz].type = SENT; 
  } else {
    history[session.hsz].type = RCVD ;
  }

  history[session.hsz].timestamp = GetTime () - session.epochTime; 
  history[session.hsz].seqno = seq; 
  history[session.hsz].nextbyte = seq + datalen; 
  history[session.hsz].ackno = ack ; 
  history[session.hsz].fin = (flags & TCPFLAGS_FIN) ? 1 : 0;
  history[session.hsz].syn = (flags & TCPFLAGS_SYN) ? 1 : 0;
  history[session.hsz].rst = (flags & TCPFLAGS_RST) ? 1 : 0;
  history[session.hsz].psh = (flags & TCPFLAGS_PSH) ? 1 : 0;
  history[session.hsz].ack = (flags & TCPFLAGS_ACK) ? 1 : 0;
  history[session.hsz].urg = (flags & TCPFLAGS_URG) ? 1 : 0;
  history[session.hsz].ecn_echo = (flags & TCPFLAGS_ECN_ECHO) ? 1:0;
  history[session.hsz].cwr = (flags & TCPFLAGS_CWR) ? 1 : 0;
  history[session.hsz].ip_optlen = ip_optlen;
  history[session.hsz].optlen = optlen ;

  /* Grab IP Options from Ip Header - New */
  if (ip_optlen > 0) {
    if ((history[session.hsz].ip_opt = calloc(sizeof(uint8), ip_optlen)) == NULL) {
      printf("StorePacket Error: Could not allocate history memory\nRETURN CODE: %d\n", ERR_MEM_ALLOC);
      Quit (ERR_MEM_ALLOC); 
    }
    memcpy(history[session.hsz].ip_opt, (char *)p->ip + sizeof(struct IpHeader), ip_optlen);
  }


  /* Grab TCP options from TCP Header */
  if (optlen > 0) {
    if ((history[session.hsz].opt = calloc(sizeof(uint8), optlen)) == NULL) {
      Quit (ERR_MEM_ALLOC); 
    }

    memcpy(history[session.hsz].opt, (char *)p->tcp + sizeof(struct TcpHeader), optlen);
  }

  history[session.hsz].dlen = datalen; 
  
  if ((history[session.hsz].data = calloc(sizeof(uint8), datalen)) == NULL) {
    Quit (ERR_MEM_ALLOC); 
  }

  /* Copy data bytes */
  memcpy(history[session.hsz].data, 
	 (char *)p->tcp + sizeof(struct TcpHeader) + optlen, 
	 datalen);

  session.hsz++;

  if (session.hsz >= MAXHSZ) {
    Quit(TOO_MANY_PKTS); 
  }

}

int reordered(struct IPPacket *p) {

  int i;
  int count = 0;	
  double ts = -99999;

  /*
   * This might be either an unwanted packet drop, or just a reordering. 
   * Test: 
   *  If we have not sent three acks for this packet
   *  AND the gap between this packet and previous one is "small" (i.e. not a timeout)
   *  then its a reordering, and not a retransmission. 
   */
  
  /* count the number of (dup) ACKs sent */
  for (i = 0; i < session.hsz; i++) {
    if ((history[i].type == SENT) && 
	(history[i].ack)) {
      if (history[i].ackno == history[session.hsz - 1].seqno) 
	count += 1; 
    }
  }

  if (count > 0) {

    session.num_dup_acks += count - 1;

    switch (count) {
    case 1: /* no dup acks */
      session.num_pkts_0_dup_acks += 1;
      break;

    case 2: /* 1 dup acks */
      session.num_pkts_1_dup_acks += 1;
      break;
      
    case 3: /* 2 dup acks */
      session.num_pkts_2_dup_acks += 1;
      break;
      
    case 4: /* 3 dup acks */
      session.num_pkts_3_dup_acks += 1;
      break;
    
    default:
      session.num_pkts_4_or_more_dup_acks += 1;
      break;
    }
  }

  /* 3 dup acks? => Fast retransmission */
  if (count > 3) {
    printf("Fast retransmit...\n");
    return 3; 
  }

  /* Compute elapsed time between this packet and the previously RCVD packet */
  for (i = (session.hsz - 2); i >= 0; i--) {
    if ((history[i].type == RCVD) && (history[i].dlen > 0)) {
      ts = history[i].timestamp; 
      break; 
    }
  }

  if ((history[session.hsz - 1].timestamp - ts) > RTT_TO_MULT * (session.rtt + PLOTDIFF)) {
    printf ("RTO ===> %f %f\n", history[session.hsz - 1].timestamp, ts);
    return 2;
  }

  printf ("#### Acks %d\n", count);
  printf ("#### reordering detected\n");
  session.num_reordered++;
  
  return 1;

}
