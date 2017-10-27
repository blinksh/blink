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
#include <stdlib.h>
#include <assert.h>
#include "base.h"
#include "inet.h"
#include "session.h"
#include "capture.h"
#include "support.h"
#include "history.h"
#include "ecn.h"

extern struct TcpSession session;
extern struct History history[];

#define	ESTABLISH_SUCCESS		0
#define	ESTABLISH_FAILURE_EARLY_RST	1
#define	ESTABLISH_FAILURE_NO_REPLY	2
int EstablishTcpConnection(u_int8_t syn_flags, u_int8_t ip_tos)
{
  struct IPPacket *synPacket = NULL, *ackPacket = NULL;
  char *read_packet;
  struct pcap_pkthdr pi;
  int synAckReceived = 0;
  int numRetransmits = 0;
  double timeoutTime;
  int tcpoptlen = 4; /* For negotiating MSS */
  u_int8_t *opt = NULL;
  struct IPPacket *p = NULL;

  /* allocate the syn packet -- Changed for new IPPacket structure */
  synPacket = AllocateIPPacket(0, tcpoptlen, 0, "ECN (SYN)");
  opt = (((u_int8_t *)synPacket->tcp) + sizeof(struct TcpHeader));
  opt[0] = (u_int8_t)TCPOPT_MAXSEG;
  opt[1] = (u_int8_t)TCPOLEN_MAXSEG;
  *((u_int16_t *)((u_int8_t *)opt + 2)) = htons(session.mss);

  SendSessionPacket(synPacket,
    sizeof(struct IpHeader) + sizeof(struct TcpHeader) + tcpoptlen,
    TCPFLAGS_SYN | syn_flags, 0, tcpoptlen, ip_tos);
  timeoutTime = GetTime() + 1;

  /* 
   * Wait for SYN/ACK and retransmit SYN if appropriate 
   * not great, but it gets the job done 
   */

  while(!synAckReceived && numRetransmits < 3) {
    while(GetTime() < timeoutTime) {
      /* Have we captured any packets? */
      if ((read_packet = (char *)CaptureGetPacket(&pi)) != NULL) {
        p = (struct IPPacket *)FindHeaderBoundaries(read_packet);
        /* Received a packet from us to them */
        if (INSESSION(p, session.src, session.sport,
          session.dst, session.dport)) {
            /* Is it a SYN/ACK? */
            if (p->tcp->tcp_flags & TCPFLAGS_SYN) {
              if (session.debug >= SESSION_DEBUG_LOW) {
                PrintTcpPacket(p); 
              }
              StorePacket(p);
              session.totSeenSent++ ;
            } else {
              processBadPacket(p);
            }
            continue;
        }

        /* Received a packet from them to us */
        if (INSESSION(p, session.dst, session.dport, session.src,
          session.sport)) {
          /* Is it a SYN/ACK? */
          if ((p->tcp->tcp_flags & TCPFLAGS_SYN) &&
            (p->tcp->tcp_flags & TCPFLAGS_ACK)) {
            timeoutTime = GetTime(); /* force exit */
            synAckReceived++;
            if (session.debug >= SESSION_DEBUG_LOW) {
            PrintTcpPacket(p);
            }
            StorePacket(p);

            /*
             * Save ttl for,admittedly poor,indications of reverse
             * route change
             */
            session.ttl = p->ip->ip_ttl;
            session.snd_wnd = ntohl(p->tcp->tcp_win);
            session.totRcvd ++;
            break;
          } else {
            if ((p->tcp->tcp_flags)& (TCPFLAGS_RST)) {
              printf ("ERROR: EARLY_RST\n");
              return(ESTABLISH_FAILURE_EARLY_RST);
            }
          }
        }
      }
    }

    if (!synAckReceived) {
      if (session.debug >= SESSION_DEBUG_LOW) {
        printf("SYN timeout. Retransmitting\n");
      }
      SendSessionPacket(synPacket, 
        sizeof(struct IpHeader) + sizeof(struct TcpHeader) + tcpoptlen,
        TCPFLAGS_SYN | syn_flags, 0, tcpoptlen, ip_tos);
      timeoutTime = GetTime() + 1;
      numRetransmits++;
    }
  }

  if (numRetransmits >= 3) {
    printf("ERROR: No connection after 3 retries...\nRETURN CODE: %d\n",
      NO_CONNECTION);
    return(ESTABLISH_FAILURE_NO_REPLY);
  }
  if (session.debug >= SESSION_DEBUG_LOW)
    printf("Received SYN-ACK, try to send the third Ack\n");
  /* Update session variables */
  session.irs = ntohl(p->tcp->tcp_seq);
  session.dataRcvd[0] = 1 ;
  session.rcv_nxt = session.irs + 1;	/* SYN/ACK takes up a byte of seq space */
  session.snd_nxt = session.iss + 1;	/* SYN takes up a byte of seq space */
  session.snd_una = session.iss + 1;
  session.maxseqseen = ntohl(p->tcp->tcp_seq);
  session.initSession = 1;
  if (session.debug >= SESSION_DEBUG_LOW) {
    printf("src = %s:%d (%u)\n", InetAddress(session.src),
      session.sport, session.iss);
    printf("dst = %s:%d (%u)\n",InetAddress(session.dst),
      session.dport, session.irs);
  }

  /* allocate the syn packet -- Changed for new IPPacket structure */
  ackPacket = AllocateIPPacket(0, 0, 0, "Third ACK");
  /* send an ACK */
  SendSessionPacket(ackPacket,
    sizeof(struct IpHeader) + sizeof(struct TcpHeader),
    TCPFLAGS_ACK, 0, 0, 0);
  FreeIPPacket(&synPacket);
  FreeIPPacket(&ackPacket);
  return(ESTABLISH_SUCCESS);
}

void ECNTest(u_int32_t sourceAddress, u_int16_t sourcePort,
  u_int32_t targetAddress, u_int16_t targetPort, int mss) 
{
  int rawSocket, rc, flag = 1;

  arc4random_stir();

  session.src = sourceAddress;
  session.sport = sourcePort;
  session.dst = targetAddress;
  session.dport = targetPort;
  session.rcv_wnd = 5*mss;
  /* random initial sequence number */
  session.snd_nxt = arc4random();
  session.iss = session.snd_nxt;
  session.rcv_nxt = 0;
  session.irs = 0;
  session.mss = mss;
  session.maxseqseen = 0;
  session.epochTime = GetTime ();
  session.maxpkts = 1000;
/*   session.debug = SESSION_DEBUG_LOW; */
  session.debug = 0;
  if ((session.dataRcvd = (u_int8_t *)calloc(sizeof(u_int8_t),
    mss * session.maxpkts)) == NULL) {
    printf("no memmory to store data:\nRETURN CODE: %d",
      ERR_MEM_ALLOC);
    Quit(ERR_MEM_ALLOC);
  }

  if ((rawSocket = socket(AF_INET, SOCK_RAW, IPPROTO_RAW)) < 0) {
    perror("ERROR: couldn't open socket:"); 
    Quit(ERR_SOCKET_OPEN);
  }

  if (setsockopt(rawSocket, IPPROTO_IP, IP_HDRINCL,
      (char *)&flag, sizeof(flag)) < 0) {
    perror("ERROR: couldn't set raw socket options:");
      Quit(ERR_SOCKOPT);
  }

  session.socket = rawSocket;

  /* Establish a TCP connections with ECN bits */
  rc = EstablishTcpConnection(TCPFLAGS_ECN_ECHO | TCPFLAGS_CWR, 0);
  switch (rc) {
    case ESTABLISH_FAILURE_EARLY_RST:
    {
      /* Received a RST when ECN bits are used. Try again without ECN */
      rc = EstablishTcpConnection(0, 0);
      if (rc == ESTABLISH_FAILURE_EARLY_RST) {
        printf("Received RST with or without ECN negotiation\n");
        printf("The server might not be listening on this port\n");
        Quit(EARLY_RST);
      } else if (rc == ESTABLISH_SUCCESS) {
        printf("Received RST with ECN.\n");
        printf("Connection established successfully without ECN\n");
        Quit(ECN_SYN_DROP);
      } else if (rc == ESTABLISH_FAILURE_NO_REPLY) {
        printf("Received RST with ECN\n");
        printf("Exceed max SYN retransmits without ECN\n");
        Quit(NO_CONNECTION);
      }
      break;
    }
    case ESTABLISH_FAILURE_NO_REPLY:
    {
      /* No reply after retring, try again without ECN */
      rc = EstablishTcpConnection(0, 0);
      if (rc == ESTABLISH_FAILURE_EARLY_RST) {
        printf("Exceeded max SYN retransmits with ECN\n");
        printf("Received RST without ECN\n");
        Quit(NO_CONNECTION);
      } else if (rc == ESTABLISH_FAILURE_NO_REPLY) {
        printf("Exceeded max SYN retransmits with ECN\n");
        printf("Exceeded max SYN retransmits without ECN\n");
        Quit(NO_CONNECTION);
      } else {
        printf("Exceeded max SYN retransmits with ECN\n");
        printf("Connection established successfully without ECN\n");
        Quit(ECN_SYN_DROP);
      }
      break;
    }
  }

  /* Test for propogation of CE correctly */
  DataPkt(session.filename, 3, 0);
	
  checkECN();
  return;
}

void DataPkt (char *filename, u_int8_t iptos, u_int8_t tcp_flags) 
{
  struct IPPacket *p, *datapkt;
  struct pcap_pkthdr pi;
  char *read_packet;
  int i ;
  int sendflag = 1 ;
  u_int16_t lastSeqSent = session.snd_nxt; 
  double startTime = 0;
  char *dataptr ; 
  char data[MAXREQUESTLEN];
  int datalen;
  int ipsz;

  datalen = PrepareRequest (data, filename);

  datapkt = AllocateIPPacket(0, 0, datalen + 1, "ECN (datapkt)");

  dataptr = (char *)datapkt->tcp + sizeof(struct TcpHeader);
  memcpy((void *)dataptr,(void *)data, datalen);

  ipsz = sizeof(struct IpHeader) + sizeof(struct TcpHeader) + datalen + 1; 
  
  /* send the data packet
   * we try to "achieve" reliability by
   * sending the packet upto 5 times, wating for
   * 2 seconds between packets
   * BAD busy-wait loop
   */

  i = 0 ;
  while(1) {

    if (sendflag == 1) {
      SendSessionPacket(datapkt, ipsz,
        TCPFLAGS_PSH | TCPFLAGS_ACK | tcp_flags, 0, 0, iptos);

      startTime = GetTime();	
      sendflag = 0 ; 
      i++ ;
    }

    /* Check if we have received any packets */
    if ((read_packet =(char *)CaptureGetPacket(&pi)) != NULL) {
      p = (struct IPPacket *)FindHeaderBoundaries(read_packet);

      /*
       * packet that we sent?
       */

      if (INSESSION(p,session.src, session.sport,
        session.dst,session.dport) &&
        (p->tcp->tcp_flags == (TCPFLAGS_PSH | TCPFLAGS_ACK)) &&
        SEQ_GT(ntohl(p->tcp->tcp_seq), lastSeqSent) &&
        SEQ_LEQ(ntohl(p->tcp->tcp_ack), session.rcv_nxt)) {
        lastSeqSent = ntohl(p->tcp->tcp_seq);
        if (session.debug >= SESSION_DEBUG_LOW) {
          printf("xmit %d\n", i);
          PrintTcpPacket(p);
        }
        StorePacket(p);
        session.snd_nxt += datalen + 1;
        session.totSeenSent ++ ;
        continue ;
      }

      /*
       * from them? 
       */ 
      if (INSESSION(p, session.dst, session.dport, session.src,
        session.sport) && (p->tcp->tcp_flags & TCPFLAGS_ACK) &&
        (ntohl(p->tcp->tcp_seq) == session.rcv_nxt) &&
        SEQ_GT(ntohl(p->tcp->tcp_ack), session.snd_una)) {
          session.snd_una = ntohl(p->tcp->tcp_ack);
          session.snd_nxt = session.snd_una;
          if (p->ip->ip_ttl != session.ttl) {
            session.ttl = p->ip->ip_ttl;
          }
          if (session.debug >= SESSION_DEBUG_LOW) {
            printf("rcvd %d\n", i);
	          PrintTcpPacket(p);
	        }
	        StorePacket(p);
	        session.totRcvd ++;
	        break ;
      }
      /* 
       * otherwise, this is a bad packet
       * we must quit
       */
      //processBadPacket(p);
    }
    if ((GetTime() - startTime >= 1) && (sendflag == 0) && (i < 3)) {
      sendflag = 1 ;
    }
    if (i >= 3) {
      printf ("ERROR: sent request 3 times without response\n");
      return;
    }
  }	

  FreeIPPacket(&datapkt);

  /* process any response by sending Acks */
  rcvData (ECNAckData);
}

void ECNAckData (struct IPPacket *p) 
{

  uint32 seq = history[session.hsz - 1].seqno;
  uint16 datalen = history[session.hsz - 1].dlen;
  int fin = history[session.hsz - 1].fin; 
  int rst = history[session.hsz - 1].rst;
  int i;
  struct IPPacket *ackpkt = NULL;
  static int ECT_00 = 0;
  static int ECT_01 = 0;
  static int ECT_10 = 0;
  static int ECT_11 = 0;
  static int ECN_ECHO = 0;
  static int send_cwr = 0;
  static int send_ece = 0;
  uint8 tcp_flags = 0;


  /* Legend:
   * ECN_ECHO: counts packets with TCP header ECN bit set
   * ECT_XX: counts packets with ECT codepoint XX (IP)
   */
  
  if (datalen > session.mss) {
    printf ("ERROR: mss=%d datalen=%d\nRETURN CODE: %d\n",
      session.mss, datalen, MSS_ERR);
    Quit(MSS_ERR);
  }

  if (datalen > 0) {
    char *http_code = (char *)calloc(4, sizeof(char));
    if (seq - session.irs == 1) {
      /* Response to request packet --> check HTTP response code */
      memcpy(http_code, ((char *)(p->tcp) + sizeof(struct TcpHeader) +
        history[session.hsz - 1].optlen + 9), 3);
      if (strncmp(http_code, HTTP_OK, 3) != 0) {
      	printf("HTTP ERROR - HTTP RESPONSE CODE: %s\nRETURN CODE: %d\n",
          http_code, atoi(http_code));
      	Quit(atoi(http_code));
      }
    }

    session.totDataPktsRcvd++;

    if (session.verbose) {
      printf ("r %f %d %d\n", 
	      GetTime() - session.epochTime, 
	      seq - session.irs, 
	      seq - session.irs + datalen);
    }

  }

  /* Check if packet has the ECN_ECHO flag set */
  if (history[session.hsz - 1].ecn_echo) {
    ECN_ECHO += 1;
  }

  if ((p->ip->ip_tos & 0x17) == 0) {
    ECT_00 += 1;
  }
  if ((p->ip->ip_tos & 0x17) == 1) {
    ECT_01 += 1;
  }
  if ((p->ip->ip_tos & 0x17) == 2) {
    ECT_10 += 1;
  }
  if ((p->ip->ip_tos & 0x17) == 3) {
    ECT_11 += 1;
  }

  if(session.maxseqseen < seq + datalen - 1) {
    session.maxseqseen = seq + datalen - 1; 
  } else {
    if (datalen > 0) {
      if (reordered(p) != 1) {
      	session.num_unwanted_drops += 1;
      }
    }
  }

  /* from TCP/IP vol. 2, p 808 */
  if (SEQ_LEQ(session.rcv_nxt, seq) &&
    SEQ_LT(seq, (session.rcv_nxt + session.rcv_wnd))  &&
    SEQ_LEQ(session.rcv_nxt, (seq + datalen)) &&
    SEQ_LT((seq+datalen-1), (session.rcv_nxt + session.rcv_wnd))) {
    int start, end;
    start = seq - session.irs ; 
    end = start + datalen ; 
    
    for (i = start ; i < end ; i++) {
      session.dataRcvd[i] = 1 ; 
    }

    start = session.rcv_nxt - session.irs ; 
    end = session.mss * session.maxpkts ; 

    for (i = start ; i < end ; i++) {
      if (session.dataRcvd[i] == 0) {
        break ;
      }
      session.rcv_nxt++ ;
    }
  }

  if (datalen > 0) {
   if (session.verbose) {
      printf ("a %f %d\n", GetTime() - session.epochTime,
        session.rcv_nxt - session.irs);
    }
    ackpkt = AllocateIPPacket(0, 0, 0, "NewECN (ACK)");
    if ((p->ip->ip_tos & 0x17) == 3) {
      tcp_flags = TCPFLAGS_ACK | TCPFLAGS_ECN_ECHO;
    } else {
      tcp_flags = TCPFLAGS_ACK;
    }

    if (send_cwr == 2 && send_ece < 2) {
      /* Send ECE as if a CE was received, we have to get CWR back */
      send_ece = 1;
      tcp_flags |= TCPFLAGS_ECN_ECHO;
    }

    SendSessionPacket (ackpkt,
      sizeof(struct IpHeader) + sizeof(struct TcpHeader),
      tcp_flags, 0, 0, 0); 
  }

  if (send_cwr == 0 && (p->tcp->tcp_flags & TCPFLAGS_ECN_ECHO)) {
    /* Send CWR atleast once if ECN ECHO is set */
    int datalen;
    struct IPPacket *datapkt;
    char *dataptr;
    char data[MAXREQUESTLEN];
    int ipsz;

    datalen = PrepareRequest(data, NULL);
    datapkt = AllocateIPPacket(0, 0, datalen + 1, "ECN (datapkt)");
    dataptr = (char *)datapkt->tcp + sizeof(struct TcpHeader);
    memcpy((void *)dataptr, (void *)data, datalen);
    ipsz = sizeof(struct IpHeader) + sizeof(struct TcpHeader) +
      datalen + 1;

    SendSessionPacket(datapkt, ipsz,
      TCPFLAGS_PSH | TCPFLAGS_ACK | TCPFLAGS_CWR, 0, 0, 2);

    session.snd_nxt += (datalen + 1);
    send_cwr = 1;
    FreeIPPacket(&datapkt);
  }

  if (send_cwr == 1 && !(p->tcp->tcp_flags & TCPFLAGS_ECN_ECHO)) {
    /* ECE was reset in response to CWR, move to the next state of probing */
    send_cwr = 2;
  }

  if (send_ece == 1 && (p->tcp->tcp_flags & TCPFLAGS_CWR)) {
    /* Received CWR in response to ECE */
    send_ece =  2;
  }

  if (SEQ_GT(ntohl(p->tcp->tcp_ack), session.snd_una))
    session.snd_una = ntohl(p->tcp->tcp_ack);
  if (SEQ_LT(session.snd_nxt, session.snd_una))
    session.snd_nxt = session.snd_una;

  if (fin || rst) {
    /* Increment sequence number for FIN rcvd */
    session.rcv_nxt++;
    if (ECT_01 == 0 && ECT_10 == 0) {
      printf("Never received ECT(0) or ECT(1) in ToS field: FAIL\n");
    }
    if (ECT_11 > 3) {
      /* If we received more than 3 CE, flag it as an error */
      printf("Received too many ECT_CE (%d): FAIL\n", ECT_11);
    }
    printf ("Totdata = %d ECN_ECHO: %d ECT00: %d ECT01: %d ECT10: %d ECT11: %d drops: %d\n",
      session.rcv_nxt - session.irs, ECN_ECHO, ECT_00,
      ECT_01, ECT_10, ECT_11, session.num_unwanted_drops);
    if (fin) {
      SendSessionPacket (ackpkt,
        sizeof(struct IpHeader) + sizeof(struct TcpHeader),
        tcp_flags, 0, 0, 0);
    }
    checkECN();
    Quit(SUCCESS); 
  }
}

void checkECN () 
{
  int i; 
  int sr = 0; /* sr=1: SYN/ACK rcvd */
  int se = 0; /* se=0: no CWR/no ECHO; se=1: no CWR/ECHO; se=2: CWR/ECHO */
  int ar = 0; /* ar=0: no ACK rcvd; ar=1: ACK rcvd */
  int ae = 0; /* ae=0: ACK/no ECHO; ae=1: ACK/ECHO */
  int we = 0; /* we=0: no ECHO; we=1 ECHO/CWR; we=2 ECHO/CWR/ECHO stop */
  int ee = 0; /* ee=0 never sent ECE; ee=1 sent ECE; ee=2 ECE / CWR */ 
  
  for (i = 0 ; i < session.hsz; i++) {
    if ((history[i].type == RCVD) && (history[i].syn == 1) &&
      (history[i].ack == 1)) {
      sr = 1;
      if (history[i].ecn_echo == 1) {
        se = 1;
        if (history[i].cwr == 1) {
          se = 2;
        }
      }
    } 
  }

  for (i = 0 ; i < session.hsz; i++) {
    if (history[i].type == RCVD && history[i].syn == 0 &&
      history[i].ack == 1) {
      ar = 1;
      if (history[i].ecn_echo == 1) {
    	  ae = 1;
      }
    }
  }

  for (i = 0; i < session.hsz; i++) {
    if (history[i].type == SENT && history[i].dlen > 0 &&
      history[i].cwr == 1) {
      we = 1;
      continue;
    }
    if (we == 1 && history[i].type == RCVD && history[i].ecn_echo == 0) {
      we = 2;
      break;
    }
    if (we == 2 && history[i].type == RCVD && history[i].ecn_echo == 1) {
      we = 1;
      break;
    }
  }

  for (i = 0; i < session.hsz; i++) {
    if (history[i].type == SENT && history[i].ecn_echo == 1) {
      ee = 1;
      continue;
    }
    if (ee == 1 && history[i].type == RCVD && history[i].dlen > 0 &&
      history[i].cwr == 1) {
      /* Received cwr in response to ECE */
      ee = 2;
      break;
    }
  }

  printf ("sr=%d se=%d ar=%d ae=%d we=%d\n", sr, se, ar, ae, we);
  switch (sr) {
    case 0:
      printf("No SYN/ACK received from server\n");
      break;
    case 1:
      printf("SYN/ACK received: PASS \n");
      break;
    default:
      printf("Unknown value for sr: %d\n", sr);
      break;
  }
  switch (se) {
    case 0:
      printf("No CWR or ECE on SYN/ACK, server does not support ECN\n");
      break;
    case 1:
      printf("ECE flag set on SYN/ACK, server supports ECN: PASS\n");
      break;
    case 2:
      printf("Both CWR and ECE set on SYN/ACK, incompatible SYN/ACK\n");
      break;
    default:
      printf("Unknown value for se: %d\n", se);
      break; 
  }

  switch (ar) {
    case 0:
      printf("No ACK received\n");
      break;
    case 1:
      printf("ACK received: PASS\n");
      break;
    default:
      printf("Unknown value for ar: %d\n", ar);
      break;
  }

  switch (ae) {
    case 0:
      printf("Received ACKS but never ECE\n");
      break;
    case 1:
      printf("Received ACKs with ECE, in response to simulated CE bit: PASS\n");
      break;
    default:
      printf("Unknown value for ae: %d\n", ae);
      break;
  }

  switch (we) {
    case 0:
      printf("Never received ECE\n");
      break;
    case 1:
      printf("Received ECE and sent CWR\n");
      break;
    case 2:
      printf("Received ECE, sent CWR and stopped receiving ECE afterwards: PASS\n");
      break;
    default:
      printf("Unknown value for we: %d\n", we);
      break;
  }

  switch (ee) {
    case 0:
      printf("Never sent ECE\n");
      break;
    case 1:
      printf("Sent ECE to simulate receiving CE \n");
      break;
    case 2:
      printf("Sent ECE and received CWR in response: PASS\n");
      break;
    default:
      printf("Unknown value for ee: %d\n", ee);
      break;
  }
  return;
}

void DataPktPathCheck(char *filename, u_int8_t iptos, u_int8_t tcp_flags)
{
  struct IPPacket *p, *datapkt;
  struct pcap_pkthdr pi;
  char *read_packet;
  int i ;
  int sendflag = 1 ;
  u_int16_t lastSeqSent = session.snd_nxt;
  double startTime = 0;
  char *dataptr;
  char data[MAXREQUESTLEN];
  int datalen;
  int ipsz;
  unsigned int init_ttl;

  datalen = PrepareRequest (data, filename);

  datapkt = AllocateIPPacket(0, 0, datalen + 1, "ECN (datapkt)");

  dataptr = (char *)datapkt->tcp + sizeof(struct TcpHeader);
  memcpy((void *)dataptr,(void *)data, datalen);

  ipsz = sizeof(struct IpHeader) + sizeof(struct TcpHeader) + datalen + 1;
  /* send the data packet
   * we try to "achieve" reliability by
   * sending the packet upto 5 times, wating for
   * 2 seconds between packets
   * BAD busy-wait loop
   */

  i = 0 ;
  init_ttl = 1;
  while(1) {

    if (sendflag == 1) {
      session.curr_ttl = ++init_ttl;
      if (init_ttl > 64) /* reached the max */
        break;
      SendSessionPacket(datapkt, ipsz,
        TCPFLAGS_PSH | TCPFLAGS_ACK | tcp_flags, 0, 0, 0x3);

      startTime = GetTime();
      sendflag = 0;
      i++ ;
    }

    /* Check if we have received any packets */
    if ((read_packet =(char *)CaptureGetPacket(&pi)) != NULL) {

      p = (struct IPPacket *)FindHeaderBoundaries(read_packet);

      /*
       * packet that we sent?
       */

      if (INSESSION(p,session.src, session.sport,
        session.dst,session.dport) &&
        (p->tcp->tcp_flags == (TCPFLAGS_PSH | TCPFLAGS_ACK)) &&
        SEQ_GT(ntohl(p->tcp->tcp_seq), lastSeqSent) &&
        SEQ_LEQ(ntohl(p->tcp->tcp_ack), session.rcv_nxt)) {
        lastSeqSent = ntohl(p->tcp->tcp_seq);
        if (session.debug >= SESSION_DEBUG_LOW) {
          printf("xmit %d\n", i);
          PrintTcpPacket(p);
        }
        StorePacket(p);
        session.snd_nxt += datalen + 1;
        session.totSeenSent ++ ;
        continue ;
      }

      /*
       * from them?
       */
      if (INSESSION(p, session.dst, session.dport, session.src,
        session.sport) && (p->tcp->tcp_flags & TCPFLAGS_ACK) &&
        (ntohl(p->tcp->tcp_seq) == session.rcv_nxt) &&
        ntohl(p->tcp->tcp_ack) == session.snd_nxt) {
          session.snd_una = ntohl(p->tcp->tcp_ack);
          session.snd_nxt = session.snd_una;
          if (p->ip->ip_ttl != session.ttl) {
            session.ttl = p->ip->ip_ttl;
          }
          if (session.debug >= SESSION_DEBUG_LOW) {
            printf("rcvd %d\n", i);
	          PrintTcpPacket(p);
	  }
	  StorePacket(p);
	  session.totRcvd ++;
	  break ;
      }
      /*
       * ICMP ttl exceeded
       */
      if (p->ip->ip_p == IPPROTOCOL_ICMP) {
        uint16_t ip_hl;
        struct IcmpHeader *icmp;
        ip_hl = (p->ip->ip_vhl & 0x0f) << 2;
	void *nexthdr;

        icmp = (struct IcmpHeader *)((char *)p->ip + ip_hl);
        nexthdr = (void *)icmp;
        if (icmp->icmp_type == ICMP_TIMXCEED) {
          struct IpHeader off_ip;
          struct TcpHeader off_tcp;

          bzero(&off_ip, sizeof(struct IpHeader));
          nexthdr = nexthdr + sizeof(struct IcmpHeader);
          memcpy((void *)&off_ip, nexthdr,
            sizeof(struct IpHeader));
          nexthdr += sizeof(struct IpHeader);

          bzero(&off_tcp, sizeof(struct TcpHeader));
          memcpy(&off_tcp, nexthdr, 4);
          if (session.src == off_ip.ip_src &&
            session.dst == off_ip.ip_dst) {
            printf("Received ICMP TTL exceeded from %s:"
              "ttl used %u ip_tos 0x%x sport %u dport %u\n",
              InetAddress(p->ip->ip_src), init_ttl, off_ip.ip_tos,
              ntohs(off_tcp.tcp_sport), ntohs(off_tcp.tcp_dport));
          }
        }
      }
      /*
       * otherwise, this is a bad packet
       * we must quit
       */
      //processBadPacket(p);
    }
    if ((GetTime() - startTime >= 1) && (sendflag == 0)) {
      sendflag = 1;
      session.snd_nxt = session.snd_una;
    }
  }

  FreeIPPacket(&datapkt);
}
void ECNPathCheckTest(u_int32_t sourceAddress, u_int16_t sourcePort,
    u_int32_t targetAddress, u_int16_t targetPort, int mss)
{
  int rawSocket, rc, flag;

  arc4random_stir();

  session.src = sourceAddress;
  session.sport = sourcePort;
  session.dst = targetAddress;
  session.dport = targetPort;
  session.rcv_wnd = 5*mss;
  session.snd_nxt = arc4random();
  session.iss = session.snd_nxt;
  session.rcv_nxt = 0;
  session.irs = 0;
  session.mss = mss;
  session.maxseqseen = 0;
  session.epochTime = GetTime();
  session.maxpkts = 1000;
  session.debug = 0;

  if ((session.dataRcvd = (u_int8_t *)calloc(sizeof(u_int8_t),
    mss * session.maxpkts)) == NULL) {
    printf("no memory to store data, error: %d \n", ERR_MEM_ALLOC);
    Quit(ERR_MEM_ALLOC);
  }

  if ((rawSocket = socket(AF_INET, SOCK_RAW, IPPROTO_RAW)) < 0) {
    perror("ERROR: couldn't open socket:");
    Quit(ERR_SOCKET_OPEN);
  }

  flag = 1;
  if (setsockopt(rawSocket, IPPROTO_IP, IP_HDRINCL,
      (char *)&flag, sizeof(flag)) < 0) {
    perror("ERROR: couldn't set raw socket options:");
      Quit(ERR_SOCKOPT);
  }

  session.socket = rawSocket;

  /* Establish a TCP connections with ECN bits */
  rc = EstablishTcpConnection(TCPFLAGS_ECN_ECHO | TCPFLAGS_CWR, 0);
  switch (rc) {
    case ESTABLISH_FAILURE_EARLY_RST:
    {
      /* Received a RST when ECN bits are used. Try again without ECN */
      rc = EstablishTcpConnection(0, 0);
      if (rc == ESTABLISH_FAILURE_EARLY_RST) {
        printf("Received RST with or without ECN negotiation\n");
        printf("The server might not be listening on this port\n");
        Quit(EARLY_RST);
      } else if (rc == ESTABLISH_SUCCESS) {
        printf("Received RST with ECN.\n");
        printf("Connection established successfully without ECN\n");
        Quit(ECN_SYN_DROP);
      } else if (rc == ESTABLISH_FAILURE_NO_REPLY) {
        printf("Received RST with ECN\n");
        printf("Exceed max SYN retransmits without ECN\n");
        Quit(NO_CONNECTION);
      }
      break;
    }
    case ESTABLISH_FAILURE_NO_REPLY:
    {
      /* No reply after retring, try again without ECN */
      rc = EstablishTcpConnection(0, 0);
      if (rc == ESTABLISH_FAILURE_EARLY_RST) {
        printf("Exceeded max SYN retransmits with ECN\n");
        printf("Received RST without ECN\n");
        Quit(NO_CONNECTION);
      } else if (rc == ESTABLISH_FAILURE_NO_REPLY) {
        printf("Exceeded max SYN retransmits with ECN\n");
        printf("Exceeded max SYN retransmits without ECN\n");
        Quit(NO_CONNECTION);
      } else {
        printf("Exceeded max SYN retransmits with ECN\n");
        printf("Connection established successfully without ECN\n");
        Quit(ECN_SYN_DROP);
      }
      break;
    }
  }

  DataPktPathCheck(session.filename, 3, 0);
  return;
}


void
SynTest(u_int32_t sourceAddress, u_int16_t sourcePort,
    u_int32_t targetAddress, u_int16_t targetPort, int mss, int syn_reply)
{
	int rawSocket, flag;
	struct IPPacket *synPacket = NULL, *ackPacket = NULL;
	char *read_packet;
	struct pcap_pkthdr pi;
	int synAckReceived = 0;
	int numRetransmits = 0;
	double timeoutTime;
	int tcpoptlen = 4; /* For negotiating MSS */
	u_int8_t *opt = NULL;
	struct IPPacket *p = NULL;

	arc4random_stir();

	session.src = sourceAddress;
	session.sport = sourcePort;
	session.dst = targetAddress;
	session.dport = targetPort;
	session.rcv_wnd = 5*mss;
	session.snd_nxt = arc4random();
	session.iss = session.snd_nxt;
	session.rcv_nxt = 0;
	session.irs = 0;
	session.mss = mss;
	session.maxseqseen = 0;
	session.epochTime = GetTime();
	session.maxpkts = 1000;

	if ((session.dataRcvd = (u_int8_t *)calloc(sizeof(u_int8_t),
						   mss * session.maxpkts)) == NULL) {
		printf("no memory to store data, error: %d \n", ERR_MEM_ALLOC);
		Quit(ERR_MEM_ALLOC);
	}

	if ((rawSocket = socket(AF_INET, SOCK_RAW, IPPROTO_RAW)) < 0) {
		perror("ERROR: couldn't open socket:");
		Quit(ERR_SOCKET_OPEN);
	}

	flag = 1;
	if (setsockopt(rawSocket, IPPROTO_IP, IP_HDRINCL,
		       (char *)&flag, sizeof(flag)) < 0) {
		perror("ERROR: couldn't set raw socket options:");
		Quit(ERR_SOCKOPT);
	}

	session.socket = rawSocket;


	/* allocate the syn packet -- Changed for new IPPacket structure */
	synPacket = AllocateIPPacket(0, tcpoptlen, 0, "ECN (SYN)");
	opt = (((u_int8_t *)synPacket->tcp) + sizeof(struct TcpHeader));
	opt[0] = (u_int8_t)TCPOPT_MAXSEG;
	opt[1] = (u_int8_t)TCPOLEN_MAXSEG;
	*((u_int16_t *)((u_int8_t *)opt + 2)) = htons(session.mss);

	SendSessionPacket(synPacket,
			  sizeof(struct IpHeader) + sizeof(struct TcpHeader) + tcpoptlen,
			  TCPFLAGS_SYN , 0, tcpoptlen, 0);
	timeoutTime = GetTime() + 1;

	/*
	 * Wait for SYN/ACK and retransmit SYN if appropriate
	 * not great, but it gets the job done
	 */

	while(!synAckReceived && numRetransmits < 3) {
		while(GetTime() < timeoutTime) {
			/* Have we captured any packets? */
			if ((read_packet = (char *)CaptureGetPacket(&pi)) != NULL) {
				p = (struct IPPacket *)FindHeaderBoundaries(read_packet);
				/* Received a packet from us to them */
				if (INSESSION(p, session.src, session.sport,
					      session.dst, session.dport)) {
					/* Is it a SYN/ACK? */
					if (p->tcp->tcp_flags & TCPFLAGS_SYN) {
						if (session.debug >= SESSION_DEBUG_LOW) {
							PrintTcpPacket(p);
						}
						StorePacket(p);
						session.totSeenSent++ ;
					} else {
						processBadPacket(p);
					}
					continue;
				}

				/* Received a packet from them to us */
				if (INSESSION(p, session.dst, session.dport, session.src,
					      session.sport)) {
					/* Is it a SYN/ACK? */
					if ((p->tcp->tcp_flags & TCPFLAGS_SYN) &&
					    (p->tcp->tcp_flags & TCPFLAGS_ACK)) {
						timeoutTime = GetTime(); /* force exit */
						synAckReceived++;
						if (session.debug >= SESSION_DEBUG_LOW) {
							PrintTcpPacket(p);
						}
						StorePacket(p);

						/*
						 * Save ttl for,admittedly poor,indications of reverse
						 * route change
						 */
						session.ttl = p->ip->ip_ttl;
						session.snd_wnd = ntohl(p->tcp->tcp_win);
						session.totRcvd ++;
						break;
					} else {
						if ((p->tcp->tcp_flags)& (TCPFLAGS_RST)) {
							printf ("ERROR: EARLY_RST\n");
							goto done;
						}
					}
				}
			}
		}

		if (!synAckReceived) {
			if (session.debug >= SESSION_DEBUG_LOW) {
				printf("SYN timeout. Retransmitting\n");
			}
			SendSessionPacket(synPacket,
					  sizeof(struct IpHeader) + sizeof(struct TcpHeader) + tcpoptlen,
					  TCPFLAGS_SYN , 0, tcpoptlen, 0);
			timeoutTime = GetTime() + 1;
			numRetransmits++;
		}
	}

	if (numRetransmits >= 3) {
		printf("ERROR: No connection after 3 retries...\nRETURN CODE: %d\n",
		       NO_CONNECTION);
		goto done;
	}
	if (session.debug >= SESSION_DEBUG_LOW)
		printf("Received SYN-ACK\n");
	if (syn_reply != 0) {
		/* Update session variables */
		session.irs = ntohl(p->tcp->tcp_seq);
		session.dataRcvd[0] = 1 ;
		session.rcv_nxt = session.irs + 1;	/* SYN/ACK takes up a byte of seq space */
		session.snd_nxt = session.iss + 1;	/* SYN takes up a byte of seq space */
		session.snd_una = session.iss + 1;
		session.maxseqseen = ntohl(p->tcp->tcp_seq);
		session.initSession = 1;
		if (session.debug >= SESSION_DEBUG_LOW) {
			printf("try to send the %s\n", syn_reply == TCPFLAGS_ACK ? "third Ack" : "RST");
			printf("src = %s:%d (%u)\n", InetAddress(session.src),
			       session.sport, session.iss);
			printf("dst = %s:%d (%u)\n",InetAddress(session.dst),
			       session.dport, session.irs);
		}

		/* allocate the syn packet -- Changed for new IPPacket structure */
		ackPacket = AllocateIPPacket(0, 0, 0, "SYN reply");
		/* send an ACK */
		SendSessionPacket(ackPacket,
				  sizeof(struct IpHeader) + sizeof(struct TcpHeader),
				  syn_reply, 0, 0, 0);
		FreeIPPacket(&ackPacket);
	}
done:
	FreeIPPacket(&synPacket);
}
