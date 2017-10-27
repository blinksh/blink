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

#ifndef _INET_H_
#define _INET_H_

/* XXX These are machine/compiler dependent */
typedef unsigned char uint8;
typedef unsigned short uint16;
typedef unsigned int uint32;

#define IPPROTOCOL_ICMP		1
#define IPPROTOCOL_IGMP		2
#define IPPROTOCOL_TCP		6
#define IPPROTOCOL_UDP		17
#define IP_DF 0x4000

/* ICMP type */
#define ICMP_TIMXCEED	11

/* TCP Flags */
#define TCPFLAGS_FIN	0x01
#define TCPFLAGS_SYN	0x02
#define TCPFLAGS_RST	0x04
#define TCPFLAGS_PSH	0x08
#define TCPFLAGS_ACK	0x10
#define TCPFLAGS_URG	0x20
#define TCPFLAGS_ECN_ECHO	0x40
#define TCPFLAGS_CWR	0x80

/* IP Options Parameters -- for IP Options te*/
#define IPOPT_EOL            0x0
#define IPOLEN_EOL           0x1
#define IPOPT_NOP            0x1
#define IPOLEN_NOP           0x1
#define IPOPT_RR             0x7
#define IPOLEN_RR           0x27 /* Maximum length; up to 9 IP addresses */
#define IPOPT_TS            0x44
#define IPOLEN_TS           0x28
#define IPOPT_FAKED         0xff
#define IPOLEN_FAKED         0x4

/* TCP Options Parameters */
#define TCPOPT_EOL             0 
#define TCPOLEN_EOL            1
#define TCPOPT_NOP             1
#define TCPOLEN_NOP            1
#define TCPOPT_MAXSEG          2
#define TCPOLEN_MAXSEG         4
#define TCPOPT_WINDOW          3
#define TCPOLEN_WINDOW         3
#define TCPOPT_SACK_PERMITTED  4   
#define TCPOLEN_SACK_PERMITTED 2
#define TCPOPT_SACK            5   
#define TCPOPT_TIMESTAMP       8
#define TCPOLEN_TIMESTAMP     10
#define TCPOPT_FAKED        0x19
#define TCPOLEN_FAKED        0x4

struct IpHeader {
  uint8		ip_vhl;	 /* version (4bits) & header length (4 bits) */
  uint8		ip_tos;	 /* type of service */
  uint16	ip_len;  /* length of IP datagram */
  uint16	ip_id;	 /* identification (for frags) */ 
  uint16	ip_off;  /* offset (within a fragment) and flags (3 bits) */
  uint8		ip_ttl;  /* time to live */
  uint8		ip_p;	 /* protocol number */
  uint16	ip_xsum; /* checksum */
  uint32	ip_src;  /* source address */
  uint32	ip_dst;  /* destination address */
};

/* Pseudo header for doing TCP checksum calculation */
struct PseudoIpHeader {
  uint32	filler[2];
  uint8		zero;
  uint8		ip_p;
  uint16	ip_len;
  uint32	ip_src;
  uint32	ip_dst;
};

struct TcpHeader {
  uint16	tcp_sport;	/* source port */
  uint16	tcp_dport;	/* destination port */
  uint32	tcp_seq;	/* sequence number */
  uint32	tcp_ack;	/* acknoledgement number */
  uint8		tcp_hl;		/* header length (4 bits) */
  uint8		tcp_flags;	/* flags */
  uint16	tcp_win;	/* advertized window size */
  uint16	tcp_xsum;	/* checksum */
  uint16	tcp_urp;	/* urgent pointer */
};



struct IcmpHeader {
  uint8	        icmp_type;	/* ICMP message type */
  uint8  	icmp_code;	/* Message code */
  uint16	icmp_xsum;	/* checksum */
  uint16	icmp_unused;	/* unused field */
  uint16	icmp_mtu;	/* MTU of limiting interface */
};

struct IPPacket {
  struct IpHeader *ip;
  struct TcpHeader *tcp;
};

struct ICMPUnreachableErrorPacket {
  struct IpHeader ip;
  struct IcmpHeader icmp;
  struct IpHeader off_ip;
  /* 8-first bytes of TCP header */
  uint16 tcp_sport;
  uint16 tcp_dport;
  uint32 tcp_seqno;
};

struct ICMPTimeExceededErrorPacket {
  struct IpHeader ip;
  struct IcmpHeader icmp;
  struct IpHeader off_ip;
  /* 8-first bytes of Tcpheader */
  uint16 tcp_sport;
  uint16 tcp_dport;
  uint32 tcp_seqno;
};

char *InetAddress(uint32 addr);

uint16 InetChecksum(uint16 *ip_addr, uint16 *tcp_addr,  uint16 ip_len, uint16 tcp_len);

void PrintTcpPacket(struct IPPacket *p);
void PrintICMPUnreachableErrorPacket(struct ICMPUnreachableErrorPacket *p);

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
		   uint8 iptos, 
		   uint8 u4tf); 

void ReadIPPacket(struct IPPacket *p, uint32 *src, uint32 *dst, 
		  uint16 *sport, uint16 *dport, uint32 *seq, uint32 *ack, 
		  uint8 *flags, uint16 *win, uint16 *urp, uint16 *datalen, 
		  uint16 *ip_optlen, uint16 *optlen);

void StorePacket (struct IPPacket *p); 

struct IPPacket *FindHeaderBoundaries(char *p);

struct IPPacket *AllocateIPPacket(int ip_optlen, int tcp_optlen, int datalen, char *str);

void FreeIPPacket(struct IPPacket **pkt_p);

#endif /* _INET_H_ */
