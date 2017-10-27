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
#include "history.h"

extern struct TcpSession session;
extern struct History history[];

/*
 * Deal with struct in_addr type agreement once and for all
 */
char *InetAddress(uint32 addr)
{

  struct in_addr s;
  s.s_addr = addr;

  //printf("In InetAddress:\n");
  //printf("addr = %s (%0x)\n", inet_ntoa(s), addr);

  return (inet_ntoa(s));
}

/*
 * Really slow implementation of ip checksum
 * ripped off from rfc1071
 */

uint16 InetChecksum(uint16 *ip, uint16 *tcp, uint16 ip_len, uint16 tcp_len) {

  uint32 sum = 0;

  uint32 ip_count = ip_len;
  uint32 tcp_count = tcp_len;
  uint16 *ip_addr = ip;
  uint16 *tcp_addr = tcp;

  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("In InetChecksum...\n");
    printf("iplen: %d, tcplen: %d\n", ip_len, tcp_len);
  }


  while(ip_count > 1) {
    //printf("ip[%d]: %x\n", ip_len - ip_count, htons(*ip_addr));
    sum += *ip_addr++;
    ip_count -= 2;
  }

  while(tcp_count > 1) {
    //printf("tcp[%d]: %x\n", tcp_len - tcp_count, htons(*tcp_addr));
    sum += *tcp_addr++;
    tcp_count -= 2;
  }

  if(ip_count > 0) {
    sum += *(uint8 *)ip_addr;
  }

  if(tcp_count > 0) {
    sum += *(uint8 *)tcp_addr;
  }

  while (sum >> 16) {
    sum = (sum & 0xffff) + (sum >> 16);
  }

  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("Out InetChecksum...\n");
  }

  return(~sum);

}


void WriteIPPacket(struct IPPacket *p,
		   uint32 src, 
		   uint32 dst, 
		   uint16 sport, 
		   uint16 dport,
		   uint32 seq, 
		   uint32 ack, 
		   uint8 flags, 
		   uint16 win,
		   uint16 urp, 
		   uint16 datalen, 
		   uint16 ip_optlen,
		   uint16 optlen, 
		   uint8  iptos, 
		   uint8  u4tf) 
{

  struct IpHeader *ip = p->ip;
  struct TcpHeader *tcp = p->tcp;

  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("In WriteIPPacket...\n");
  }

  /* Zero out IpHeader to ensure proper checksum computation */
  bzero((char *)(p->ip), sizeof(struct IpHeader));
 
  ip->ip_src = src;
  ip->ip_dst = dst;
  ip->ip_p = IPPROTOCOL_TCP;
  ip->ip_xsum =
    htons((uint16)(sizeof(struct TcpHeader) + datalen + optlen)); /* pseudo hdr */

  tcp->tcp_sport = htons(sport);
  tcp->tcp_dport = htons(dport);
  tcp->tcp_seq = htonl(seq);
  tcp->tcp_ack = htonl(ack);
  tcp->tcp_hl = (sizeof(struct TcpHeader) + optlen) << 2;
  tcp->tcp_hl = tcp->tcp_hl | u4tf;
  tcp->tcp_flags = flags;

  tcp->tcp_win = htons(win);
  tcp->tcp_urp = htons(urp);
	
  tcp->tcp_xsum = 0;
  tcp->tcp_xsum = InetChecksum((uint16 *)ip, (uint16 *)tcp, 
			       (uint16)sizeof(struct IpHeader), /* IP Options should aren't included */
			       (uint16)(sizeof(struct TcpHeader) + datalen + optlen));

  /* Fill in real ip header */
  if (session.curr_ttl != 0) {
    ip->ip_ttl = session.curr_ttl;
  }else {
    ip->ip_ttl = 60;
  }

  //printf("TTL: %d\n", ip->ip_ttl);
    
  ip->ip_tos = iptos;

  /* IP  Version and Header len field */
  ip->ip_vhl = 0x40 + 0x5 + (int)(ip_optlen/4);
  ip->ip_p = IPPROTOCOL_TCP;

  ip->ip_off = IP_DF;
  ip->ip_len = (uint16)(sizeof(struct IpHeader) + ip_optlen + sizeof(struct TcpHeader) + optlen + datalen);

  ip->ip_xsum = 0;
  ip->ip_xsum = InetChecksum((uint16 *)ip, NULL,
			       (uint16)sizeof(struct IpHeader) + ip_optlen, /* IP Options should aren't included */
			       0);

  if (session.debug >= SESSION_DEBUG_HIGH) {
    printf("Out WriteIPPacket...\n");
  }

}

void ReadIPPacket(struct IPPacket *p,
		  uint32 *src, 
		  uint32 *dst, 
		  uint16 *sport, 
		  uint16 *dport,
		  uint32 *seq, 
		  uint32 *ack, 
		  uint8 *flags, 
		  uint16 *win,
		  uint16 *urp, 
		  uint16 *datalen, 
		  uint16 *ip_optlen,
		  uint16 *optlen) 
{

  /* TODO: Add reading of IP options, if any */

  struct IpHeader *ip = p->ip;
  struct TcpHeader *tcp = p->tcp;

  uint16 ip_len;
  uint16 ip_hl;
  uint16 tcp_hl;

  /* XXX do checksum check? */
  if (ip->ip_p != IPPROTOCOL_TCP && ip->ip_p != IPPROTOCOL_ICMP) {
    printf("Unexpected protocol packet: %u\n", ip->ip_p);
    Quit(ERR_CHECKSUM);
  }

  *src = ip->ip_src;
  *dst = ip->ip_dst;
  *sport = ntohs(tcp->tcp_sport);
  *dport = ntohs(tcp->tcp_dport);
  *seq = ntohl(tcp->tcp_seq);
  *ack = ntohl(tcp->tcp_ack);
  *flags = tcp->tcp_flags;
  *win = ntohs(tcp->tcp_win);
  *urp = ntohs(tcp->tcp_urp);

  tcp_hl = tcp->tcp_hl >> 2;
  ip_len = ntohs(ip->ip_len);
  ip_hl = (ip->ip_vhl & 0x0f) << 2;
  *datalen = (ip_len - ip_hl) - tcp_hl;
  *ip_optlen = ip_hl - (unsigned int)sizeof(struct IpHeader); /* added to support IP Options */
  *optlen = tcp_hl - (unsigned int)sizeof(struct TcpHeader);

}

void PrintICMPUnreachableErrorPacket(struct ICMPUnreachableErrorPacket *p)
{

  struct IpHeader *ip = &p->ip;
  struct IcmpHeader *icmp = &p->icmp;
  struct IpHeader *off_ip = &p->off_ip;

  printf("IPHdr: ");
  printf("%s > ", InetAddress(ip->ip_src));
  printf("%s ", InetAddress(ip->ip_dst));
  printf(" datalen: %u\n", ip->ip_len);
  printf("ICMPHdr: ");
  printf("Type: %u  Code: %u MTU next hop: %u xsum: %x\n",
	 icmp->icmp_type, 
	 icmp->icmp_code, 
	 ntohs(icmp->icmp_mtu),
	 icmp->icmp_xsum);
  printf("Off IPHdr: ");
  printf("%s > ", InetAddress(off_ip->ip_src));
  printf("%s ", InetAddress(off_ip->ip_dst));
  printf(" datalen: %u ",   off_ip->ip_len);
  printf("tcp sport: %u ",  ntohs(p->tcp_sport));
  printf("tcp dport: %u ",  ntohs(p->tcp_dport));
  printf("tcp seqno: %u\n", (uint32)ntohl(p->tcp_seqno));

}

void PrintTcpPacket(struct IPPacket *p)
{

  struct IpHeader *ip = p->ip;
  struct TcpHeader *tcp = p->tcp;

  char *opt; 
  int optlen; 
  char *ip_opt;
  int ip_optlen;
  int i;
 
  printf("%s.%u > ", InetAddress(ip->ip_src), ntohs(tcp->tcp_sport));
  printf("%s.%u ", InetAddress(ip->ip_dst), ntohs(tcp->tcp_dport));

  if (tcp->tcp_flags & TCPFLAGS_SYN) {
    printf("S");
  }

  if (tcp->tcp_flags & TCPFLAGS_ACK) {
    printf("A");
  }

  if (tcp->tcp_flags & TCPFLAGS_FIN) {
    printf("F");
  }

  if (tcp->tcp_flags & TCPFLAGS_ECN_ECHO) {
    printf("E");
  }

  if (tcp->tcp_flags & TCPFLAGS_CWR) {
    printf("W");
  }

  if (tcp->tcp_flags & TCPFLAGS_RST) {
    printf("R");
  }
  if (tcp->tcp_flags & TCPFLAGS_PSH) {
    printf("P");
  }

  if (tcp->tcp_flags & TCPFLAGS_URG) {
    printf("U");
  }

  if (INSESSION(p,session.src,session.sport,session.dst,session.dport)) {
    printf(" seq: %u, ack: %u", (uint32)ntohl(tcp->tcp_seq) - session.iss, (uint32)ntohl(tcp->tcp_ack) - session.irs);
  } else {
    printf(" seq: %u, ack: %u", (uint32)ntohl(tcp->tcp_seq) - session.irs, (uint32)ntohl(tcp->tcp_ack) - session.iss);
  }

  /* IP Options */
  ip_optlen = ((ip->ip_vhl & 0x0f) << 2) - sizeof(struct IpHeader);
  ip_opt = (char *)ip + sizeof(struct IpHeader);

  i = 0;
  while (i < ip_optlen) {
    
    switch ((unsigned char)ip_opt[i]) {
    case IPOPT_NOP:
      printf(" ipopt%d: %s ", i + 1, "IPOPT_NOP");
      i = i + 1;
      break;

    case IPOPT_EOL:
      printf(" ipopt%d: %s ", i + 1, "IPOPT_EOL");
      i = ip_optlen + 1;
      break;
      
    case IPOPT_RR:
      printf(" ipopt%d: %s ", i + 1, "IPOPT_RR");
      i = i + IPOLEN_RR;
      break;

    default:
      printf("ip_opt%d: UNKNOWN ", i + 1);
      i = i + (uint8)ip_opt[i+1] ;
    }
  }

  printf(" win: %u, urg: %u, ttl: %d", ntohs(tcp->tcp_win), ntohs(tcp->tcp_urp), ip->ip_ttl);
  printf(" datalen: %u, optlen: %u ", 
	 ip->ip_len - ((ip->ip_vhl &0x0f) << 2) - (tcp->tcp_hl >> 2),
	 (tcp->tcp_hl >> 2) - (unsigned int)sizeof(struct TcpHeader));  


  /* TCP Options */
  optlen = (tcp->tcp_hl >> 2) - (unsigned int)sizeof (struct TcpHeader) ;
  opt = (char *)tcp + sizeof(struct TcpHeader);

  i = 0 ;

  while (i < optlen) {

    switch ((unsigned char)opt[i]) {

    case TCPOPT_EOL: 
      printf (" opt%d: %s ", i + 1, "TCPOPT_EOL");
      i = optlen + 1; 
      break ; 

    case TCPOPT_NOP:
      printf (" opt%d: %s ", i + 1, "TCPOPT_NOP");
      i++ ; 
      break ;

    case TCPOPT_MAXSEG:
      printf (" opt%d: %s: %d ", i + 1, "TCPOPT_MAXSEG", ntohs(*(uint16 *)((char *)opt+2)));
      i = i + TCPOLEN_MAXSEG ; 
      break ;

    case TCPOPT_WINDOW:
      printf (" opt%d: %s ", i + 1, "TCPOPT_WINDOW");
      i = i + TCPOLEN_WINDOW ;
      break ; 

    case TCPOPT_SACK_PERMITTED:
      printf (" opt%d: %s ", i + 1, "TCPOPT_SACK_PERMITTED");
      i = i + TCPOLEN_SACK_PERMITTED ; 
      break ; 

    case TCPOPT_TIMESTAMP:
      printf (" opt%d: %s ", i + 1, "TCPOPT_TIMESTAMP");
      i = i + TCPOLEN_TIMESTAMP ; 
      break ; 

    default: 
      printf (" opt%d c:%d l:%d: UNKNOWN ", i + 1, (uint8)opt[i], (uint8)opt[i+1]);
      if ((uint8)opt[i+1] > 0) {
	i = i + (uint8)opt[i+1] ;
      } else {
	Quit(20); 
      }
      break ;
    } 
  }
  printf ("\n");
}


struct IPPacket *FindHeaderBoundaries(char *p) {

  struct IPPacket *packet;
  uint16 ip_hl;

  if ((packet = (struct IPPacket *)calloc(1, sizeof(struct IPPacket))) == NULL) { 
    printf("FindHeaderBoundaries: Cannot allocate memory for read packet\nRETURN CODE: %d\n", ERR_MEM_ALLOC);
    Quit(ERR_MEM_ALLOC);
  }

  packet->ip = (struct IpHeader *)p;

  if (packet->ip->ip_p != IPPROTOCOL_TCP &&
    packet->ip->ip_p != IPPROTOCOL_ICMP) {
    printf("Error: Unexpected protocol packet: %u \n",  packet->ip->ip_p);
    Quit(ERR_CHECKSUM);
  }

  ip_hl = (packet->ip->ip_vhl & 0x0f) << 2;

  packet->tcp = (struct TcpHeader *)((char *)p + ip_hl);
  return packet;

}


struct IPPacket *
AllocateIPPacket(int ip_optlen, int tcp_optlen, int datalen, char *str)
{
	struct IPPacket *p;

	if (session.debug >= SESSION_DEBUG_HIGH) {
		printf("In AllocateIPPacket: %s...\n", str);
	}

	if ((p = (struct IPPacket *)calloc(1, sizeof(struct IPPacket)))
	    == NULL) {
		printf("%s ERROR: No space for packet\nRETURN CODE: %d",
		    str, ERR_MEM_ALLOC);
		Quit(ERR_MEM_ALLOC);
	}

	if ((p->ip = (struct IpHeader *)calloc(1, 
	    sizeof(struct IpHeader) + ip_optlen)) == NULL) {
		printf("%s ERROR: No IpHeader space for packet\n"
		    "RETURN CODE: %d", str, ERR_MEM_ALLOC);
		Quit(ERR_MEM_ALLOC);
	}

	if ((p->tcp = (struct TcpHeader *)calloc(1,
	    sizeof(struct TcpHeader) + tcp_optlen + datalen)) == NULL) {
		printf("%s ERROR: No TcpHeader space for packet\n"
		    "RETURN CODE: %d", str, ERR_MEM_ALLOC);
		Quit(ERR_MEM_ALLOC);
	}

	if (session.debug >= SESSION_DEBUG_HIGH) {
		printf("Out of AllocateIPPacket: %s...\n", str);
	}
	return(p);
}

void
FreeIPPacket(struct IPPacket **pkt_p)
{
	struct IPPacket *pkt;
	if (pkt_p == NULL)
		return;
	if ((pkt = *pkt_p) == NULL)
		return;
	if (pkt->ip != NULL) {
		free(pkt->ip);
		pkt->ip = NULL;
	}
	if (pkt->tcp != NULL) {
		free(pkt->tcp);
		pkt->tcp = NULL;
	}
	free(pkt);
	*pkt_p = NULL;
}

