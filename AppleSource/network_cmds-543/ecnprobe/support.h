
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

#include <signal.h>

#define MAXRESETRETRANSMITS (3)
/*#define INSESSION(p, src, sport, dst, dport)			\
		(((p)->ip.ip_src == (src)) && ((p)->ip.ip_dst == (dst)) &&	\
		 ((p)->ip.ip_p == IPPROTOCOL_TCP) &&			\
		 ((p)->tcp.tcp_sport == htons(sport)) &&			\
		 ((p)->tcp.tcp_dport == htons(dport)))*/

#define INSESSION(p, src, sport, dst, dport)			\
		(((p)->ip->ip_src == (src)) && ((p)->ip->ip_dst == (dst)) &&	\
		 ((p)->ip->ip_p == IPPROTOCOL_TCP) &&			\
		 ((p)->tcp->tcp_sport == htons(sport)) &&			\
		 ((p)->tcp->tcp_dport == htons(dport)))

#define SEQ_LT(a,b) ((int)((a)-(b)) < 0)
#define SEQ_LEQ(a,b) ((int)((a)-(b)) <= 0)
#define SEQ_GT(a,b) ((int)((a)-(b)) > 0)
#define SEQ_GEQ(a,b) ((int)((a)-(b)) >= 0)

#define DEFAULT_TARGETPORT  (80)
#define DEFAULT_MSS	1360
#define DEFAULT_MTU 1500
#define	RTT_TO_MULT	5
#define PLOTDIFF 0.00009

/* Response codes */
#define  FAIL                        -1
#define  SUCCESS                      0
#define  NO_TARGET_CANON_INFO         1
#define  NO_LOCAL_HOSTNAME            2
#define  NO_SRC_CANON_INFO            3
#define  NO_SESSION_ESTABLISH         4
#define  MSS_TOO_SMALL                5
#define  BAD_ARGS                     6
#define  FIREWALL_ERR                 7
#define  ERR_SOCKET_OPEN              8
#define  ERR_SOCKOPT                  9
#define  ERR_MEM_ALLOC               10
#define  NO_CONNECTION               11
#define  MSS_ERR                     12
#define  BUFFER_OVERFLOW             13
#define  UNWANTED_PKT_DROP           14
#define  EARLY_RST                   15
#define  UNEXPECTED_PKT              16
#define  DIFF_FLOW                   17
#define  ERR_CHECKSUM                18
#define  NOT_ENOUGH_PKTS             19
#define  BAD_OPT_LEN                 20
#define  TOO_MANY_PKTS               21
#define  NO_DATA_RCVD                22
#define  NO_TRGET_SPECIFIED          23
#define  BAD_OPTIONS                 24
#define  TOO_MANY_TIMEOUTS           25
#define  TOO_MANY_RXMTS              26
#define  NO_SACK                     27
#define  ERR_IN_SB_CALC              28
#define  TOO_MANY_HOLES              29
#define  TOO_MANY_DROPS              30
#define  UNWANTED_PKT_REORDER        31
#define  NO_PMTUD_ENABLED            32
#define  UNKNOWN_BEHAVIOR            33
#define  NO_SYNACK_RCVD              34
#define  SEND_REQUEST_FAILED         35
#define  PKT_SIZE_CHANGED            36
#define	 ECN_SYN_DROP                37

#define DEFAULT_FILENAME "/"

#define RTT_TO_MULT 5
#define SYNTIMEOUT    (2.0)
#define REXMITDELAY   (2.0)
#define MAXSYNRETRANSMITS  (6)
#define MAXDATARETRANSMITS  (6)

/* HTTP Response Codes */
#define HTTP_OK                     "200"


void SendReset(); 
void SigHandle (int signo);
void Cleanup(); 
void Quit(int how);
double GetTime(); 
double GetTimeMicroSeconds(); 
void PrintTimeStamp(struct timeval *ts); 
void processBadPacket (struct IPPacket *p);
void busy_wait (double wait);
