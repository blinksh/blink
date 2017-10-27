/*
 * Copyright (c) 1999-2009 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * "Portions Copyright (c) 1999 Apple Computer, Inc.  All Rights
 * Reserved.  This file contains Original Code and/or Modifications of
 * Original Code as defined in and that are subject to the Apple Public
 * Source License Version 1.0 (the 'License').  You may not use this file
 * except in compliance with the License.  Please obtain a copy of the
 * License at http://www.apple.com/publicsource and read it before using
 * this file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE OR NON-INFRINGEMENT.  Please see the
 * License for the specific language governing rights and limitations
 * under the License."
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/*
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that: (1) source code distributions
 * retain the above copyright notice and this paragraph in its entirety, (2)
 * distributions including binary code include the above copyright notice and
 * this paragraph in its entirety in the documentation or other materials
 * provided with the distribution, and (3) all advertising materials mentioning
 * features or use of this software display the following acknowledgement:
 * ``This product includes software developed by the University of California,
 * Lawrence Berkeley Laboratory and its contributors.'' Neither the name of
 * the University nor the names of its contributors may be used to endorse
 * or promote products derived from this software without specific prior
 * written permission.
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
 */

#include <sys/cdefs.h>

#ifndef lint
__unused char    copyright[] =
"@(#) Copyright (c) 1990 The Regents of the University of California.\n\
 All rights reserved.\n";
#endif				/* not lint */

/*
 * rarpd - Reverse ARP Daemon
 *
 * Usage:	rarpd -a [ -d -f ]
 *		rarpd [ -d -f ] interface
 */

#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>
#include <string.h>
#include <strings.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/time.h>
#include <net/bpf.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <net/if_types.h>
#include <netinet/in.h>
#include <netinet/if_ether.h>
#include <sys/errno.h>
#include <sys/file.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <dirent.h>

#define FATAL		1	/* fatal error occurred */
#define NONFATAL	0	/* non fatal error occurred */

/*
 * The structure for each interface.
 */
struct if_info {
	int     ii_fd;		/* BPF file descriptor */
	u_char  ii_eaddr[6];	/* Ethernet address of this interface */
	in_addr_t ii_ipaddr;	/* IP address of this interface */
	in_addr_t ii_netmask;	/* subnet or net mask */
	struct if_info *ii_next;
};
/*
 * The list of all interfaces that are being listened to.  rarp_loop()
 * "selects" on the descriptors in this list.
 */
struct if_info *iflist;

int    rarp_open     __P((char *));
int    rarp_bootable __P((in_addr_t));
void   init_one      __P((char *));
void   init_all      __P((void));
void   rarp_loop     __P((void));
void   lookup_eaddr  __P((char *, u_char *));
void   lookup_ipaddr __P((char *, in_addr_t *, in_addr_t *));
void   usage         __P((void));
void   rarp_process  __P((struct if_info *, u_char *));
void   rarp_reply    __P((struct if_info *, struct ether_header *, in_addr_t));
void   update_arptab __P((u_char *, in_addr_t));
void   err           __P((int, const char *,...));
void   debug         __P((const char *,...));
in_addr_t ipaddrtonetmask __P((in_addr_t));

int     aflag = 0;		/* listen on "all" interfaces  */
int     dflag = 0;		/* print debugging messages */
int     fflag = 0;		/* don't fork */

int
main(argc, argv)
	int     argc;
	char  **argv;
{
	int     op, pid, devnull, f;
	char   *ifname, *hostname, *name;

	extern int optind, opterr;

	if ((name = strrchr(argv[0], '/')) != NULL)
		++name;
	else
		name = argv[0];
	if (*name == '-')
		++name;

	/* All error reporting is done through syslogs. */
	openlog(name, LOG_PID | LOG_CONS, LOG_DAEMON);

	opterr = 0;
	while ((op = getopt(argc, argv, "adf")) != EOF) {
		switch (op) {
		case 'a':
			++aflag;
			break;

		case 'd':
			++dflag;
			break;

		case 'f':
			++fflag;
			break;

		default:
			usage();
			/* NOTREACHED */
		}
	}
	ifname = argv[optind++];
	hostname = ifname ? argv[optind] : 0;
	if ((aflag && ifname) || (!aflag && ifname == 0))
		usage();

	if (aflag)
		init_all();
	else
		init_one(ifname);

	if ((!fflag) && (!dflag)) {
		pid = fork();
		if (pid > 0)
			/* Parent exits, leaving child in background. */
			exit(0);
		else
			if (pid == -1) {
				err(FATAL, "cannot fork");
				/* NOTREACHED */
			}
		/* Fade into the background */
		f = open("/dev/tty", O_RDWR);
		if (f >= 0) {
			if (ioctl(f, TIOCNOTTY, 0) < 0) {
				err(FATAL, "TIOCNOTTY: %s", strerror(errno));
				/* NOTREACHED */
			}
			(void) close(f);
		}
		(void) chdir("/");
		(void) setpgid(0, getpid());
		devnull = open("/dev/null", O_RDWR);
		if (devnull >= 0) {
			(void) dup2(devnull, 0);
			(void) dup2(devnull, 1);
			(void) dup2(devnull, 2);
			if (devnull > 2)
				(void) close(devnull);
		}
	}
	rarp_loop();
	/* NOTREACHED */
	return 0;
}
/*
 * Add 'ifname' to the interface list.  Lookup its IP address and network
 * mask and Ethernet address, and open a BPF file for it.
 */
void
init_one(ifname)
	char   *ifname;
{
	struct if_info *p;

	p = (struct if_info *)malloc(sizeof(*p));
	if (p == 0) {
		err(FATAL, "malloc: %s", strerror(errno));
		/* NOTREACHED */
	}
	p->ii_next = iflist;
	iflist = p;

	p->ii_fd = rarp_open(ifname);
	lookup_eaddr(ifname, p->ii_eaddr);
	lookup_ipaddr(ifname, &p->ii_ipaddr, &p->ii_netmask);
}
/*
 * Initialize all "candidate" interfaces that are in the system
 * configuration list.  A "candidate" is up, not loopback and not
 * point to point.
 */
void
init_all()
{
	char inbuf[8192];
	struct ifconf ifc;
	struct ifreq *ifr;
	int fd;
	int i, len;

	if ((fd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
		err(FATAL, "socket: %s", strerror(errno));
		/* NOTREACHED */
	}

	ifc.ifc_len = sizeof(inbuf);
	ifc.ifc_buf = inbuf;
	if (ioctl(fd, SIOCGIFCONF, (caddr_t)&ifc) < 0 ||
	    ifc.ifc_len < sizeof(struct ifreq)) {
		err(FATAL, "init_all: SIOCGIFCONF: %s", strerror(errno));
		/* NOTREACHED */
	}
	ifr = ifc.ifc_req;
	for (i = 0; i < ifc.ifc_len;
	     i += len, ifr = (struct ifreq *)((caddr_t)ifr + len)) {
		len = sizeof(ifr->ifr_name) + ifr->ifr_addr.sa_len;
		if (ioctl(fd, SIOCGIFFLAGS, (caddr_t)ifr) < 0) {
			err(FATAL, "init_all: SIOCGIFFLAGS: %s",
			    strerror(errno));
			/* NOTREACHED */
		}
		if ((ifr->ifr_flags &
		    (IFF_UP | IFF_LOOPBACK | IFF_POINTOPOINT)) != IFF_UP)
			continue;
		init_one(ifr->ifr_name);
	}
	(void) close(fd);
}

void
usage()
{
	(void) fprintf(stderr, "usage: rarpd -a [ -d -f ]\n");
	(void) fprintf(stderr, "       rarpd [ -d -f ] interface\n");
	exit(1);
}

static int
bpf_open()
{
	int     fd;
	int     n = 0;
	char    device[sizeof "/dev/bpf000"];

	/* Go through all the minors and find one that isn't in use. */
	do {
		(void) snprintf(device, sizeof(device), "/dev/bpf%d", n++);
		fd = open(device, O_RDWR);
	} while (fd < 0 && errno == EBUSY);

	if (fd < 0) {
		err(FATAL, "%s: %s", device, strerror(errno));
		/* NOTREACHED */
	}
	return fd;
}
/*
 * Open a BPF file and attach it to the interface named 'device'.
 * Set immediate mode, and set a filter that accepts only RARP requests.
 */
int
rarp_open(device)
	char   *device;
{
	int     fd;
	struct ifreq ifr;
	u_int   dlt;
	int     immediate;

	static struct bpf_insn insns[] = {
		BPF_STMT(BPF_LD | BPF_H | BPF_ABS, 12),
		BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, ETHERTYPE_REVARP, 0, 3),
		BPF_STMT(BPF_LD | BPF_H | BPF_ABS, 20),
		BPF_JUMP(BPF_JMP | BPF_JEQ | BPF_K, ARPOP_REVREQUEST, 0, 1),
		BPF_STMT(BPF_RET | BPF_K, sizeof(struct ether_arp) +
		    sizeof(struct ether_header)),
		BPF_STMT(BPF_RET | BPF_K, 0),
	};
	static struct bpf_program filter = {
		sizeof insns / sizeof(insns[0]),
		insns
	};

	fd = bpf_open();

	/* Set immediate mode so packets are processed as they arrive. */
	immediate = 1;
	if (ioctl(fd, BIOCIMMEDIATE, &immediate) < 0) {
		err(FATAL, "BIOCIMMEDIATE: %s", strerror(errno));
		/* NOTREACHED */
	}
	(void) strncpy(ifr.ifr_name, device, sizeof ifr.ifr_name);
	if (ioctl(fd, BIOCSETIF, (caddr_t) & ifr) < 0) {
		err(FATAL, "BIOCSETIF: %s", strerror(errno));
		/* NOTREACHED */
	}
	/* Check that the data link layer is an Ethernet; this code won't work
	 * with anything else. */
	if (ioctl(fd, BIOCGDLT, (caddr_t) & dlt) < 0) {
		err(FATAL, "BIOCGDLT: %s", strerror(errno));
		/* NOTREACHED */
	}
	if (dlt != DLT_EN10MB) {
		err(FATAL, "%s is not an ethernet", device);
		/* NOTREACHED */
	}
	/* Set filter program. */
	if (ioctl(fd, BIOCSETF, (caddr_t) & filter) < 0) {
		err(FATAL, "BIOCSETF: %s", strerror(errno));
		/* NOTREACHED */
	}
	return fd;
}
/*
 * Perform various sanity checks on the RARP request packet.  Return
 * false on failure and log the reason.
 */
static int
rarp_check(p, len)
	u_char *p;
	int     len;
{
	struct ether_header *ep = (struct ether_header *) p;
	struct ether_arp *ap = (struct ether_arp *) (p + sizeof(*ep));

	(void) debug("got a packet");

	if (len < sizeof(*ep) + sizeof(*ap)) {
		err(NONFATAL, "truncated request");
		return 0;
	}
	/* XXX This test might be better off broken out... */
	if (ntohs (ep->ether_type) != ETHERTYPE_REVARP ||
	    ntohs (ap->arp_hrd) != ARPHRD_ETHER ||
	    ntohs (ap->arp_op) != ARPOP_REVREQUEST ||
	    ntohs (ap->arp_pro) != ETHERTYPE_IP ||
	    ap->arp_hln != 6 || ap->arp_pln != 4) {
		err(NONFATAL, "request fails sanity check");
		return 0;
	}
	if (bcmp((char *) &ep->ether_shost, (char *) &ap->arp_sha, 6) != 0) {
		err(NONFATAL, "ether/arp sender address mismatch");
		return 0;
	}
	if (bcmp((char *) &ap->arp_sha, (char *) &ap->arp_tha, 6) != 0) {
		err(NONFATAL, "ether/arp target address mismatch");
		return 0;
	}
	return 1;
}

/*
 * Loop indefinitely listening for RARP requests on the
 * interfaces in 'iflist'.
 */
void
rarp_loop()
{
	u_char *buf, *bp, *ep;
	int     cc, fd;
	fd_set  fds, listeners;
	int     bufsize, maxfd = 0;
	struct if_info *ii;

	if (iflist == 0) {
		err(FATAL, "no interfaces");
		/* NOTREACHED */
	}
	if (ioctl(iflist->ii_fd, BIOCGBLEN, (caddr_t) & bufsize) < 0) {
		err(FATAL, "BIOCGBLEN: %s", strerror(errno));
		/* NOTREACHED */
	}
	buf = (u_char *) malloc((unsigned) bufsize);
	if (buf == 0) {
		err(FATAL, "malloc: %s", strerror(errno));
		/* NOTREACHED */
	}
	/*
         * Find the highest numbered file descriptor for select().
         * Initialize the set of descriptors to listen to.
         */
	FD_ZERO(&fds);
	for (ii = iflist; ii; ii = ii->ii_next) {
		FD_SET(ii->ii_fd, &fds);
		if (ii->ii_fd > maxfd)
			maxfd = ii->ii_fd;
	}
	while (1) {
		listeners = fds;
		if (select(maxfd + 1, &listeners, (struct fd_set *) 0,
			(struct fd_set *) 0, (struct timeval *) 0) < 0) {
			err(FATAL, "select: %s", strerror(errno));
			/* NOTREACHED */
		}
		for (ii = iflist; ii; ii = ii->ii_next) {
			fd = ii->ii_fd;
			if (!FD_ISSET(fd, &listeners))
				continue;
	again:
			cc = read(fd, (char *) buf, bufsize);
			/* Don't choke when we get ptraced */
			if (cc < 0 && errno == EINTR)
				goto again;
			/* Due to a SunOS bug, after 2^31 bytes, the file
			 * offset overflows and read fails with EINVAL.  The
			 * lseek() to 0 will fix things. */
			if (cc < 0) {
				if (errno == EINVAL &&
				    (lseek(fd, 0, SEEK_CUR) + bufsize) < 0) {
					(void) lseek(fd, 0, 0);
					goto again;
				}
				err(FATAL, "read: %s", strerror(errno));
				/* NOTREACHED */
			}
			/* Loop through the packet(s) */
#define bhp ((struct bpf_hdr *)bp)
			bp = buf;
			ep = bp + cc;
			while (bp < ep) {
				register int caplen, hdrlen;

				caplen = bhp->bh_caplen;
				hdrlen = bhp->bh_hdrlen;
				if (rarp_check(bp + hdrlen, caplen))
					rarp_process(ii, bp + hdrlen);
				bp += BPF_WORDALIGN(hdrlen + caplen);
			}
		}
	}
}
#ifndef TFTP_DIR
#define TFTP_DIR "/tftpboot"
#endif

/*
 * True if this server can boot the host whose IP address is 'addr'.
 * This check is made by looking in the tftp directory for the
 * configuration file.
 */
int
rarp_bootable(addr)
	in_addr_t  addr;
{
	register struct dirent *dent;
	register DIR *d;
	char    ipname[9];
	static DIR *dd = 0;

	(void) snprintf(ipname, sizeof(ipname), "%08X", addr);
	/* If directory is already open, rewind it.  Otherwise, open it. */
	if ((d = dd) != NULL)
		rewinddir(d);
	else {
		if (chdir(TFTP_DIR) == -1) {
			err(FATAL, "chdir: %s", strerror(errno));
			/* NOTREACHED */
		}
		d = opendir(".");
		if (d == 0) {
			err(FATAL, "opendir: %s", strerror(errno));
			/* NOTREACHED */
		}
		dd = d;
	}
	while ((dent = readdir(d)) != NULL)
		if (strncmp(dent->d_name, ipname, 8) == 0)
			return 1;
	return 0;
}
/*
 * Given a list of IP addresses, 'alist', return the first address that
 * is on network 'net'; 'netmask' is a mask indicating the network portion
 * of the address.
 */
in_addr_t
choose_ipaddr(alist, net, netmask)
	in_addr_t **alist;
	in_addr_t  net;
	in_addr_t  netmask;
{
	for (; *alist; ++alist) {
		if ((**alist & netmask) == net)
			return **alist;
	}
	return 0;
}
/*
 * Answer the RARP request in 'pkt', on the interface 'ii'.  'pkt' has
 * already been checked for validity.  The reply is overlaid on the request.
 */
void
rarp_process(ii, pkt)
	struct if_info *ii;
	u_char *pkt;
{
	struct ether_header *ep;
	struct hostent *hp;
	in_addr_t  target_ipaddr;
	char    ename[256];
	struct	in_addr in;

	ep = (struct ether_header *) pkt;

	if (ether_ntohost(ename, (struct ether_addr *)&ep->ether_shost) != 0 ||
	    (hp = gethostbyname(ename)) == 0)
		return;

	/* Choose correct address from list. */
	if (hp->h_addrtype != AF_INET) {
		err(FATAL, "cannot handle non IP addresses");
		/* NOTREACHED */
	}
	target_ipaddr = choose_ipaddr((in_addr_t **) hp->h_addr_list,
	    ii->ii_ipaddr & ii->ii_netmask, ii->ii_netmask);

	if (target_ipaddr == 0) {
		in.s_addr = ii->ii_ipaddr & ii->ii_netmask;
		err(NONFATAL, "cannot find %s on net %s\n",
		    ename, inet_ntoa(in));
		return;
	}
	if (rarp_bootable(htonl(target_ipaddr)))
		rarp_reply(ii, ep, target_ipaddr);
}
/*
 * Lookup the ethernet address of the interface attached to the BPF
 * file descriptor 'fd'; return it in 'eaddr'.
 */
void
lookup_eaddr(ifname, eaddr)
	char *ifname;
	u_char *eaddr;
{
	char inbuf[8192];
	struct ifconf ifc;
	struct ifreq *ifr;
	struct sockaddr_dl *sdl;
	int fd;
	int i, len;

	/* We cannot use SIOCGIFADDR on the BPF descriptor.
	   We must instead get all the interfaces with SIOCGIFCONF
	   and find the right one.  */

	/* Use datagram socket to get Ethernet address. */
	if ((fd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
		err(FATAL, "socket: %s", strerror(errno));
		/* NOTREACHED */
	}

	ifc.ifc_len = sizeof(inbuf);
	ifc.ifc_buf = inbuf;
	if (ioctl(fd, SIOCGIFCONF, (caddr_t)&ifc) < 0 ||
	    ifc.ifc_len < sizeof(struct ifreq)) {
		err(FATAL, "lookup_eaddr: SIOGIFCONF: %s", strerror(errno));
		/* NOTREACHED */
	}
	ifr = ifc.ifc_req;
	for (i = 0; i < ifc.ifc_len;
	     i += len, ifr = (struct ifreq *)((caddr_t)ifr + len)) {
		len = sizeof(ifr->ifr_name) + ifr->ifr_addr.sa_len;
		sdl = (struct sockaddr_dl *)&ifr->ifr_addr;
		if (sdl->sdl_family != AF_LINK || sdl->sdl_type != IFT_ETHER ||
		    sdl->sdl_alen != 6)
			continue;
		if (!strncmp(ifr->ifr_name, ifname, sizeof(ifr->ifr_name))) {
			bcopy((caddr_t)LLADDR(sdl), (caddr_t)eaddr, 6);
			if (dflag)
				fprintf(stderr, "%s: %x:%x:%x:%x:%x:%x\n",
				    ifr->ifr_name, eaddr[0], eaddr[1],
				    eaddr[2], eaddr[3], eaddr[4], eaddr[5]);
			return;
		}
	}

	err(FATAL, "lookup_eaddr: Never saw interface `%s'!", ifname);
}
/*
 * Lookup the IP address and network mask of the interface named 'ifname'.
 */
void
lookup_ipaddr(ifname, addrp, netmaskp)
	char   *ifname;
	in_addr_t *addrp;
	in_addr_t *netmaskp;
{
	int     fd;
	struct ifreq ifr;

	/* Use datagram socket to get IP address. */
	if ((fd = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
		err(FATAL, "socket: %s", strerror(errno));
		/* NOTREACHED */
	}
	(void) strncpy(ifr.ifr_name, ifname, sizeof ifr.ifr_name);
	if (ioctl(fd, SIOCGIFADDR, (char *) &ifr) < 0) {
		err(FATAL, "SIOCGIFADDR: %s", strerror(errno));
		/* NOTREACHED */
	}
	*addrp = ((struct sockaddr_in *) & ifr.ifr_addr)->sin_addr.s_addr;
	if (ioctl(fd, SIOCGIFNETMASK, (char *) &ifr) < 0) {
		perror("SIOCGIFNETMASK");
		exit(1);
	}
	*netmaskp = ((struct sockaddr_in *) & ifr.ifr_addr)->sin_addr.s_addr;
	/* If SIOCGIFNETMASK didn't work, figure out a mask from the IP
	 * address class. */
	if (*netmaskp == 0)
		*netmaskp = ipaddrtonetmask(*addrp);

	(void) close(fd);
}
/*
 * Poke the kernel arp tables with the ethernet/ip address combinataion
 * given.  When processing a reply, we must do this so that the booting
 * host (i.e. the guy running rarpd), won't try to ARP for the hardware
 * address of the guy being booted (he cannot answer the ARP).
 */
void
update_arptab(ep, ipaddr)
	u_char *ep;
	in_addr_t  ipaddr;
{
	//int     s;
	struct arpreq request;
	struct sockaddr_in *sin;

	request.arp_flags = 0;
	sin = (struct sockaddr_in *) & request.arp_pa;
	sin->sin_family = AF_INET;
	sin->sin_addr.s_addr = ipaddr;
	request.arp_ha.sa_family = AF_UNSPEC;
	/* This is needed #if defined(COMPAT_43) && BYTE_ORDER != BIG_ENDIAN,
	   because AF_UNSPEC is zero and the kernel assumes that a zero
	   sa_family means that the real sa_family value is in sa_len.  */
	request.arp_ha.sa_len = 16; /* XXX */
	bcopy((char *) ep, (char *) request.arp_ha.sa_data, 6);

#if 0
	s = socket(AF_INET, SOCK_DGRAM, 0);
	if (ioctl(s, SIOCSARP, (caddr_t) & request) < 0) {
		err(NONFATAL, "SIOCSARP: %s", strerror(errno));
	}
	(void) close(s);
#endif
}
/*
 * Build a reverse ARP packet and sent it out on the interface.
 * 'ep' points to a valid ARPOP_REVREQUEST.  The ARPOP_REVREPLY is built
 * on top of the request, then written to the network.
 *
 * RFC 903 defines the ether_arp fields as follows.  The following comments
 * are taken (more or less) straight from this document.
 *
 * ARPOP_REVREQUEST
 *
 * arp_sha is the hardware address of the sender of the packet.
 * arp_spa is undefined.
 * arp_tha is the 'target' hardware address.
 *   In the case where the sender wishes to determine his own
 *   protocol address, this, like arp_sha, will be the hardware
 *   address of the sender.
 * arp_tpa is undefined.
 *
 * ARPOP_REVREPLY
 *
 * arp_sha is the hardware address of the responder (the sender of the
 *   reply packet).
 * arp_spa is the protocol address of the responder (see the note below).
 * arp_tha is the hardware address of the target, and should be the same as
 *   that which was given in the request.
 * arp_tpa is the protocol address of the target, that is, the desired address.
 *
 * Note that the requirement that arp_spa be filled in with the responder's
 * protocol is purely for convenience.  For instance, if a system were to use
 * both ARP and RARP, then the inclusion of the valid protocol-hardware
 * address pair (arp_spa, arp_sha) may eliminate the need for a subsequent
 * ARP request.
 */
void
rarp_reply(ii, ep, ipaddr)
	struct if_info *ii;
	struct ether_header *ep;
	in_addr_t  ipaddr;
{
	int     n;
	struct ether_arp *ap = (struct ether_arp *) (ep + 1);
	int     len;

	update_arptab((u_char *) & ap->arp_sha, ipaddr);

	/* Build the rarp reply by modifying the rarp request in place. */
	ep->ether_type = htons(ETHERTYPE_REVARP);
	ap->ea_hdr.ar_hrd = htons(ARPHRD_ETHER);
	ap->ea_hdr.ar_pro = htons(ETHERTYPE_IP);
	ap->arp_op = htons(ARPOP_REVREPLY);

	bcopy((char *) &ap->arp_sha, (char *) &ep->ether_dhost, 6);
	bcopy((char *) ii->ii_eaddr, (char *) &ep->ether_shost, 6);
	bcopy((char *) ii->ii_eaddr, (char *) &ap->arp_sha, 6);

	bcopy((char *) &ipaddr, (char *) ap->arp_tpa, 4);
	/* Target hardware is unchanged. */
	bcopy((char *) &ii->ii_ipaddr, (char *) ap->arp_spa, 4);

	len = sizeof(*ep) + sizeof(*ap);
	n = write(ii->ii_fd, (char *) ep, len);
	if (n != len) {
		err(NONFATAL, "write: only %d of %d bytes written", n, len);
	}
}
/*
 * Get the netmask of an IP address.  This routine is used if
 * SIOCGIFNETMASK doesn't work.
 */
in_addr_t
ipaddrtonetmask(addr)
	in_addr_t  addr;
{
	if (IN_CLASSA(addr))
		return IN_CLASSA_NET;
	if (IN_CLASSB(addr))
		return IN_CLASSB_NET;
	if (IN_CLASSC(addr))
		return IN_CLASSC_NET;
	err(FATAL, "unknown IP address class: %08X", addr);
	/* NOTREACHED */
	return 0;
}

#if __STDC__
#include <stdarg.h>
#else
#include <varargs.h>
#endif

void
#if __STDC__
err(int fatal, const char *fmt,...)
#else
err(fmt, va_alist)
	int     fatal;
	char   *fmt;
va_dcl
#endif
{
	va_list ap;
#if __STDC__
	va_start(ap, fmt);
#else
	va_start(ap);
#endif
	if (dflag) {
		if (fatal)
			(void) fprintf(stderr, "rarpd: error: ");
		else
			(void) fprintf(stderr, "rarpd: warning: ");
		(void) vfprintf(stderr, fmt, ap);
		(void) fprintf(stderr, "\n");
	}
	vsyslog(LOG_ERR, fmt, ap);
	va_end(ap);
	if (fatal)
		exit(1);
	/* NOTREACHED */
}

void
#if __STDC__
debug(const char *fmt,...)
#else
debug(fmt, va_alist)
	char   *fmt;
va_dcl
#endif
{
	va_list ap;

	if (dflag) {
#if __STDC__
		va_start(ap, fmt);
#else
		va_start(ap);
#endif
		(void) fprintf(stderr, "rarpd: ");
		(void) vfprintf(stderr, fmt, ap);
		va_end(ap);
		(void) fprintf(stderr, "\n");
	}
}
