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
#include <stdlib.h>
#include "base.h"
#include "inet.h"
#include "session.h"
#include "capture.h"
#include "support.h"
#include "ecn.h"
#include <errno.h>

struct TcpSession session;

int EstablishSession(uint32 sourceAddress, 
		     uint16 sourcePort, 
		     uint32 targetAddress,
                     uint16 targetPort, 
		     int ip_optlen,   // AM: add support for IP options
		     char *ip_opt,    // AM: add support for IP options
		     int mss,     
		     int optlen,  
		     char *opt, 
		     int maxwin, 
		     int maxpkts, 
		     uint8 iptos, 
		     uint8 tcp_flags) // AM: Add a tcp_flags parameter
{

  int rawSocket;

  struct IPPacket *p = NULL;
  struct IPPacket *synPacket;
  char *read_packet;
  struct pcap_pkthdr pi;
  int synAckReceived = 0;
  int numRetransmits = 0;
  double timeoutTime;
  double ts1 = 0, ts2;
  int flag = 1;
	
  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("In EstablishSession...\n");
  }

  arc4random_stir();

  session.src = sourceAddress;
  session.sport = sourcePort;
  session.dst = targetAddress;
  session.dport = targetPort;
  session.rcv_wnd = maxwin * mss;
  session.snd_nxt = arc4random(); /* random initial sequence number */
  session.iss = session.snd_nxt;
  session.rcv_nxt = 0;
  session.irs = 0;
  session.mss = mss ;
  session.maxseqseen = 0 ; 
  session.epochTime = GetTime();
  session.maxpkts = maxpkts; 
  session.num_unwanted_drops = 0;
  session.num_reordered = 0;
  session.num_rtos = 0;
  session.num_dup_acks = 0;
  session.num_pkts_0_dup_acks = 0;
  session.num_pkts_1_dup_acks = 0;
  session.num_pkts_2_dup_acks = 0;
  session.num_pkts_3_dup_acks = 0;
  session.num_pkts_4_or_more_dup_acks = 0;
  session.num_dupack_ret = 0;
  session.num_reord_ret = 0;
  session.num_reordered = 0;
  session.num_dup_transmissions = 0;
  session.ignore_result = 0;
  session.curr_ttl = 0;

  if ((session.mtu < 1) || (session.mtu > 1460)) {
    session.mtu = 1500;
  }

  if (session.verbose) {
    printf("session.MTU = %d\n", session.mtu);
  }

  if ((session.dataRcvd = (uint8 *)calloc(sizeof(uint8), mss * session.maxpkts)) == NULL) {
    perror("ERROR: no memmory to store data:\n");
    printf("RETURN CODE: %d\n", ERR_MEM_ALLOC);
    Quit(ERR_MEM_ALLOC);
  }
  
  /* Now open a raw socket for sending our "fake" TCP segments */
  if ((rawSocket = socket(AF_INET, SOCK_RAW, IPPROTO_RAW)) < 0) {
    perror("ERROR: couldn't open socket:");
    printf("RETURN CODE: %d\n", ERR_SOCKET_OPEN);
    Quit(ERR_SOCKET_OPEN);
  }

  if (setsockopt(rawSocket, IPPROTO_IP, IP_HDRINCL, (char *)&flag,sizeof(flag)) < 0) {
    perror("ERROR: couldn't set raw socket options:");
    printf("RETURN CODE: %d\n", ERR_SOCKOPT);
    Quit(ERR_SOCKOPT);
  }

  session.socket = rawSocket;

  /* Allocate SYN packet */
  synPacket = AllocateIPPacket(ip_optlen, optlen, 0, "EstablishSession (SYN)");

  /* Copy IP options at the end of IpHeader structure - New */
  if (ip_optlen > 0) {
    memcpy((char *)synPacket->ip + sizeof(struct IpHeader), ip_opt, ip_optlen);
  }

  /* Copy TCP options at the end of TcpHeader structure - New */
  if (optlen > 0) {
    memcpy((char *)synPacket->tcp + sizeof(struct TcpHeader), opt, optlen);
  }

  /* Send SYN Pkt */
  SendSessionPacket(synPacket, 
  		    sizeof(struct IpHeader) + ip_optlen + sizeof(struct TcpHeader) + optlen, 
  		    TCPFLAGS_SYN | tcp_flags, 
		    ip_optlen, /* IP opt len */
		    optlen,    /* TCP opt len */
		    iptos);	

  timeoutTime = GetTime() + SYNTIMEOUT;

  /* 
   * Wait for SYN/ACK and retransmit SYN if appropriate 
   * not great, but it gets the job done 
   */

  while(!synAckReceived && numRetransmits < MAXSYNRETRANSMITS) {

    while(GetTime() < timeoutTime) {

      /* Have we captured any packets? */
  
      if ((read_packet = (char *)CaptureGetPacket(&pi)) != NULL) {

	p = (struct IPPacket *)FindHeaderBoundaries(read_packet);

	/* Received a packet from us to them */
	if (INSESSION(p, session.src, session.sport, session.dst, session.dport)) {

	  /* Is it a SYN? */
	  if (p->tcp->tcp_flags & TCPFLAGS_SYN) {

	    if (session.debug >= SESSION_DEBUG_LOW) {
	      printf("xmit\n");
	      PrintTcpPacket(p); 
	    }
	    
	    StorePacket(p);

	    ts1 = pi.ts.tv_sec + (double)pi.ts.tv_usec/1000000.0;
	    session.totSeenSent ++ ;

	  }

	  free(p);
	  continue;


	}

	if (INSESSION(p, session.dst, session.dport, session.src, session.sport)) {

	  /* Is it a SYN/ACK? */
	  if (p->tcp->tcp_flags & (TCPFLAGS_SYN | TCPFLAGS_ACK)) {

	    timeoutTime = GetTime(); /* force exit */
	    synAckReceived++;
	    ts2 = pi.ts.tv_sec + (double)pi.ts.tv_usec/1000000.0;
	    session.rtt = ts2 - ts1 ;

	    if (numRetransmits > 0) {			
	      session.rtt_unreliable = 1;
	      printf("##### Unreliable\n");	/* ACK for which SYN? */
	    }

	    if (session.debug >= SESSION_DEBUG_LOW) {
	      printf("rcvd:\n");
	      PrintTcpPacket(p);
	      printf("Connection setup took %d ms\n",(int)((ts2 - ts1) * 1000.0));
	    }

	    StorePacket(p);

	    /* Save ttl for,admittedly poor,indications of reverse route change */
	    session.ttl = p->ip->ip_ttl;
	    session.snd_wnd = ntohl(p->tcp->tcp_win);
	    session.totRcvd++;

	    free(p);	    
	    break ;

	  }

	}

	free(p->ip);
	free(p->tcp);
	free(p);

      }

    }

    if (!synAckReceived) {

      if (session.debug >= SESSION_DEBUG_LOW) {
	printf("SYN timeout. Retransmitting\n");
      }

      SendSessionPacket(synPacket, 
			sizeof(struct IpHeader) + ip_optlen + sizeof(struct TcpHeader) + optlen, 
			TCPFLAGS_SYN | tcp_flags, 
			ip_optlen, /* IP opt len */
			optlen,    /* TCP opt len */
			iptos);	 

      timeoutTime = GetTime() + SYNTIMEOUT;
      numRetransmits++;
    }
  }

  if (numRetransmits >= MAXSYNRETRANSMITS) {
    printf("ERROR: Could not establish contact after %d retries\nRETURN CODE: %d\n", 
	   numRetransmits, NO_CONNECTION);
    Quit(NO_CONNECTION);
  }
  
  /* Update session variables */
  session.irs = ntohl(p->tcp->tcp_seq);
  session.dataRcvd[0] = 1 ;
  session.rcv_nxt = session.irs + 1; /* SYN/ACK takes up a byte of seq space */
  session.snd_nxt = session.iss + 1; /* SYN takes up a byte of seq space */
  session.snd_una = session.iss + 1;
  session.maxseqseen = ntohl(p->tcp->tcp_seq);
  
  session.initSession = 1;
  if (session.debug >= SESSION_DEBUG_LOW) {
    printf("src = %s:%d (%u)\n", InetAddress(session.src), session.sport, session.iss);
    printf("dst = %s:%d (%u)\n", InetAddress(session.dst), session.dport, session.irs);
  }

  free(synPacket->ip);
  free(synPacket->tcp);
  free(synPacket); 

  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("Out of EstablishSession...\n");
  }

  session.start_time = GetTime();

  return 1;

}

int PrepareRequest(char *data, char *filename) 
{

  char h1[] = "GET ";
  char h2[] = " HTTP/1.1";
  char h3[] = "Host: ";
  char h4[] = "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11; DigExt; TBIT)";
  char h5[] = "Accept: */*";

  /* New */
  char h7[] = "Pragma: no-cache";
  char h8[] = "Cache-control: no-chache";
  char deffile[] = DEFAULT_FILENAME;
  

  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("In PrepareRequest...\n");
  }

  if (filename == NULL) {
    filename = deffile;
  }
  

  if (strlen(session.targetName) > 0) {

    sprintf(data, 

	    "%s/%s %s\r\n%s\r\n%s\r\n%s\r\n%s\r\n%s%s\r\n\r\n", 
	    h1, 
	    filename, 
	    h2,
	    h4,
	    h7,
	    h8,
	    h5,
	    h3,
	    session.targetName);
  }else {

    sprintf(data,
	    "%s%s%s\r\n%s\r\n\r\n", 
	    h1, 
	    filename, 
	    h2,
	    h4);
  }

  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("Out PrepareRequest...\n");
  }

  return ((int)strlen(data));

}


void SendRequest(char *filename, void (*ackData)(struct IPPacket *p)) 
{

  struct IPPacket *p, *datapkt;
  struct pcap_pkthdr pi;
  char *read_packet;
  int i;
  int sendflag = 1;
  double startTime = 0;
  char *dataptr; 
  char data[MAXREQUESTLEN];
  int datalen;
  int ipsz; 

  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("In SendRequest...\n");
  }

  datalen = PrepareRequest(data, filename);

  ipsz = sizeof(struct IpHeader) + sizeof(struct TcpHeader) + datalen + 1; 

  /* Allocate space for IP data packet */
  datapkt = AllocateIPPacket(0, 0, datalen + 1, "SendRequest (Data)");

  dataptr = (char *)datapkt->tcp + sizeof(struct TcpHeader);
  memcpy((void *)dataptr, (void *)data, datalen);
  
  /* Send the data packet. Try to "achieve" reliability by sending the
   * packet upto 5 times, wating for 2 seconds between packets (BAD
   * busy-wait loop) 
   */
  
  i = 0 ;
  while(1) {

    if (sendflag == 1) {

      SendSessionPacket(datapkt, 
			ipsz, 
			TCPFLAGS_PSH | TCPFLAGS_ACK, 
			0,  /* ip opt len */ 
			0,  /* tcp opt len */
			0); /* tos */

      startTime = GetTime();	
      sendflag = 0 ; 
      i++;

    }

    /* Check if we have received any packets */
    if ((read_packet = (char *)CaptureGetPacket(&pi)) != NULL) {

      p = (struct IPPacket *)FindHeaderBoundaries(read_packet);

      /*
       * packet that we sent?
       */

      if (INSESSION(p,session.src,session.sport,session.dst,session.dport) &&
	  (p->tcp->tcp_flags == (TCPFLAGS_PSH | TCPFLAGS_ACK)) &&
	  (ntohl(p->tcp->tcp_seq) == session.snd_nxt) &&
	  (ntohl(p->tcp->tcp_ack) <= session.rcv_nxt)) {

	if (session.debug >= SESSION_DEBUG_LOW) {
	  printf("xmit %d\n", i);
	  PrintTcpPacket(p);
	}

	StorePacket(p);

	free(p);

	//session.snd_nxt += datalen + 1;
	session.totSeenSent++;
	continue;

      } 
      /*
       * packet from them? 
       */ 

      if (INSESSION(p,session.dst,session.dport,session.src,session.sport) &&
	  (p->tcp->tcp_flags & TCPFLAGS_ACK) &&
	  (ntohl(p->tcp->tcp_seq) == session.rcv_nxt) &&
	  (ntohl(p->tcp->tcp_ack) >= session.snd_una)) {


	session.snd_una = ntohl(p->tcp->tcp_ack);

	if (p->ip->ip_ttl != session.ttl) {
	  printf("#### WARNING: route may have changed (ttl was %d, is	%d).\n",
		 session.ttl, p->ip->ip_ttl);
	  session.ttl = p->ip->ip_ttl;
	}

	if (session.debug >= SESSION_DEBUG_LOW) {
	  printf("rcvd %d\n", i);
	  PrintTcpPacket(p);
	}

	StorePacket(p);
	session.totRcvd ++;
	session.snd_nxt += datalen + 1;
	
	/* if the packet also contains data, receive it and send an ack if needed */
	(*ackData)(p);

	free(p);
	break;

      }

      free(p);

    }

    if ((GetTime() - startTime >= REXMITDELAY) &&
	(sendflag == 0) && (i < MAXDATARETRANSMITS)) {
      sendflag = 1 ;
    }

    if (i >= MAXDATARETRANSMITS) {
      printf ("ERROR: sent request 5 times without response\nRETURN CODE: %d\n", 
	      SEND_REQUEST_FAILED);
      Quit(SEND_REQUEST_FAILED);
    }

  }	

  free(datapkt->ip);
  free(datapkt->tcp);
  free(datapkt);

  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("Out of SendRequest...\n");
  }
}

void SendSessionPacket(struct IPPacket *p,
    uint16 ip_len, uint8  tcp_flags, uint16 ip_optlen, uint16 optlen,
    uint8  iptos)
{
	if (session.debug >= SESSION_DEBUG_HIGH) {
	    printf("In SendSessionPacket...\n");
	}
	WriteIPPacket(p,
	    session.src, session.dst, session.sport, session.dport,
	    session.snd_nxt, session.rcv_nxt, tcp_flags,
	    session.rcv_wnd, 0,
	    (ip_len - sizeof(struct IpHeader) - ip_optlen - sizeof(struct TcpHeader) - optlen),
	    ip_optlen, optlen, iptos, 0);


  /* Store packet here rather than in rcvData() because otherwise some
   * ACKs may not be accounted for upon receiving reordered packets */

  StorePacket(p);

  SendPkt(p, 
	  ip_len,    /* Total IP datagram size */
	  ip_optlen, /* ip options len */
	  optlen);   /* tcp options len */

  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("Out of SendSessionPacket...\n");
  }

}


void SendICMPReply(struct IPPacket *p) 
{

  struct ICMPUnreachableErrorPacket *icmp_pkt;
  int icmpsz;

  struct IpHeader *ip = p->ip;
  struct TcpHeader *tcp = p->tcp;

  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("In SendICMPReply...\n");
  }

  icmpsz = sizeof(struct ICMPUnreachableErrorPacket);
  if ((icmp_pkt = (struct ICMPUnreachableErrorPacket *)calloc(icmpsz + 1, 1)) == NULL) {
    perror("ERROR: no space for ICMP packet:");
    Quit(ERR_MEM_ALLOC) ; 
  }

  /* Fill IP Header of ICMP packet */
  bzero((char *)icmp_pkt, sizeof(struct ICMPUnreachableErrorPacket)); 
  icmp_pkt->ip.ip_src  = ip->ip_dst;
  icmp_pkt->ip.ip_dst  = ip->ip_src;
  icmp_pkt->ip.ip_p    = IPPROTOCOL_ICMP;
  icmp_pkt->ip.ip_xsum =
    htons((uint16)(sizeof(struct IcmpHeader) + sizeof(struct IpHeader) + sizeof(struct IpHeader) + 8)); /* pseudo hdr */
  icmp_pkt->ip.ip_ttl  = 60;
  icmp_pkt->ip.ip_tos  = 0x00;
  icmp_pkt->ip.ip_vhl  = 0x45;
#ifdef __FreeBSD__
  icmp_pkt->ip.ip_off  = IP_DF;
  icmp_pkt->ip.ip_len  = (uint16)(sizeof(struct ICMPUnreachableErrorPacket));
#else /* __FreeBSD__ */
  icmp_pkt->ip.ip_off  = htons(IP_DF);
  icmp_pkt->ip.ip_len   = htons((uint16)((sizeof (struct ICMPUnreachableErrorPacket) + 8 + 1)));
#endif /* __FreeBSD__ */

  /* Fill ICMP header */
  icmp_pkt->icmp.icmp_type   = 0x3;
  icmp_pkt->icmp.icmp_code   = 0x4;
  icmp_pkt->icmp.icmp_xsum   = 0;
  icmp_pkt->icmp.icmp_unused = 0;
  icmp_pkt->icmp.icmp_mtu    = htons(session.mtu);

  /* Fill in ip header of offending packet */
  icmp_pkt->off_ip.ip_src = ip->ip_src;
  icmp_pkt->off_ip.ip_dst = ip->ip_dst;
  icmp_pkt->off_ip.ip_p   = ip->ip_p;
  icmp_pkt->off_ip.ip_xsum = ip->ip_xsum;
  icmp_pkt->off_ip.ip_ttl = ip->ip_ttl;
  icmp_pkt->off_ip.ip_tos = ip->ip_tos;
  icmp_pkt->off_ip.ip_vhl = ip->ip_vhl;
  icmp_pkt->off_ip.ip_p   = ip->ip_p;
#ifdef __FreeBSD__
  icmp_pkt->off_ip.ip_off = ntohs(ip->ip_off);
  icmp_pkt->off_ip.ip_len = ntohs(ip->ip_len);
#else /* __FreeBSD__ */
  icmp_pkt->off_ip.ip_off = ip->ip_off;
  icmp_pkt->off_ip.ip_len = ip->ip_len;
#endif /* __FreeBSD__ */
 
  icmp_pkt->tcp_sport = tcp->tcp_sport;
  icmp_pkt->tcp_dport = tcp->tcp_dport;
  icmp_pkt->tcp_seqno = (uint32)tcp->tcp_seq;

  icmp_pkt->icmp.icmp_xsum = InetChecksum((uint16 *)(&(icmp_pkt->icmp)), NULL,
					    (uint16)(sizeof(struct IcmpHeader) + sizeof(struct IpHeader) + 8), 0);

  if (session.verbose) {
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
    printf("TCP Packet: %lu\n", sizeof(struct IPPacket));
    PrintTcpPacket(p);
    printf("ICMP Packet: %lu\n", sizeof(struct ICMPUnreachableErrorPacket));
    PrintICMPUnreachableErrorPacket(icmp_pkt);
    printf("++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n"); 
  }

  SendICMPPkt(icmp_pkt, sizeof(struct ICMPUnreachableErrorPacket));

  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("Out of SendICMPReply...\n");
  }

}

void SendPkt(struct IPPacket *p, uint16 ip_len, int ip_optlen,
	int tcp_optlen) {
	int nbytes, datalen;
	struct sockaddr_in sockAddr;
	char *assembled_pkt;

	if (session.debug >= SESSION_DEBUG_HIGH) {
		printf("In SendPkt...\n");
	}
	/*  Assemble contiguos packet to be sent */
	if ((assembled_pkt = (char *)calloc(1, ip_len)) == NULL) {
		printf("SendPkt: Cannot allocate memory for assembled packet\n");
		Quit(ERR_MEM_ALLOC);
	}
	/* Copy IP Header and options, if any */
	memcpy((char *)assembled_pkt, (char *)(p->ip),
	    sizeof(struct IpHeader) + ip_optlen);

  /* Copy TCP Header and options, if any */
  memcpy((char *)(assembled_pkt + sizeof(struct IpHeader) + ip_optlen), 
	 (char *)(p->tcp), 
	 sizeof(struct TcpHeader) + tcp_optlen);

  /* Copy data bytes, if any */
  datalen = ip_len - ((sizeof(struct IpHeader) + ip_optlen + sizeof(struct TcpHeader) + tcp_optlen));

  if (datalen > 0) {
    memcpy((char *)assembled_pkt + sizeof(struct IpHeader) + ip_optlen + sizeof(struct TcpHeader) + tcp_optlen, 
  	   (char *)p->tcp + sizeof(struct TcpHeader) + tcp_optlen, datalen);
  }


  sockAddr.sin_family  = AF_INET;
  sockAddr.sin_addr.s_addr = session.dst;

  if ((nbytes = (int)sendto(session.socket,
		       (char *)assembled_pkt, 
		       ip_len, 
		       0,
		       (struct sockaddr *)&sockAddr,
		       sizeof(sockAddr))) < ip_len) {
    printf("#### WARNING: only sent %d of %d bytes\n", nbytes, ip_len);
    perror("here");

  }

  session.totSent++;

  free(assembled_pkt);

  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("Out SendPkt...\n");
  }

}



void SendICMPPkt(struct ICMPUnreachableErrorPacket *p, uint16 len) {

  ssize_t nbytes;
  struct sockaddr_in sockAddr;   

  sockAddr.sin_family = AF_INET;
  sockAddr.sin_addr.s_addr = session.dst;
  
  nbytes = sendto(session.socket, (char *)p, len, 0, 
		  (struct sockaddr *)&sockAddr, 
		  sizeof(sockAddr));

  if (nbytes < len) {
    printf("#### WARNING: only sent %zd of %d (errno: %d) bytes\n",
	   nbytes, len, errno);
    perror("here");
  }

  session.totSent++ ;

}

void rcvData (void (*ackData)(struct IPPacket *p))
{

  struct pcap_pkthdr pi;
  struct IPPacket *p;
  char *read_packet;
  double startTime = GetTime () ;
  
  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("In rcvData...\n");
  }

  while (1) {

    if ((GetTime() - startTime) > (MAXDATARETRANSMITS * REXMITDELAY)) {
      printf ("ERROR: no Data received for %f seconds\nRETURN CODE: %d\n", 
	      (MAXDATARETRANSMITS*REXMITDELAY), NO_DATA_RCVD);
      Quit(NO_DATA_RCVD) ;
    }

    if ((read_packet = (char *)CaptureGetPacket(&pi)) != NULL) {

      p = (struct IPPacket *)FindHeaderBoundaries(read_packet);

      /*
       * Packet that we sent?
       */

      if (INSESSION(p,session.src,session.sport,session.dst,session.dport) &&
	  ((p->tcp->tcp_flags & TCPFLAGS_ACK) || (p->tcp->tcp_flags & TCPFLAGS_FIN)) &&
	  (ntohl(p->tcp->tcp_seq) == session.snd_nxt) &&
	  (ntohl(p->tcp->tcp_ack) <= session.rcv_nxt)) {
	
	if (session.debug >= SESSION_DEBUG_LOW) {
	  printf("xmit:\n");
	  PrintTcpPacket(p);
	}

	session.totSeenSent++ ;

	free(p);
	continue;

      } 

      /*
       * Data that we were expecting?
       */ 

      if (INSESSION(p,session.dst,session.dport,session.src,session.sport) &&
	  (p->tcp->tcp_flags & TCPFLAGS_ACK) &&
	  (ntohl(p->tcp->tcp_ack) >= session.snd_una)) {

	if (p->ip->ip_ttl != session.ttl) {
	  printf("#### WARNING: route may have changed (ttl was %d, is	%d).\n",
		 session.ttl, p->ip->ip_ttl);
	  session.ttl = p->ip->ip_ttl;
	}

	if (session.debug >= SESSION_DEBUG_LOW) {
	  printf("rcvd: \n");
	  PrintTcpPacket(p);
	}

	session.totRcvd++ ;
	startTime = GetTime () ;
	StorePacket(p);

	/* if the packet also contains data, receive it, and send an ack if needed */
	ECNAckData(p);

	free(p);
	continue ;

      } else {

	free(p);

      }
    }
  }
}


