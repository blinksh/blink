/*
 * Copyright (c) 2009-2017 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 *
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */

/*
 * Copyright (c) 1983, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <sys/cdefs.h>

#ifndef lint
__unused static const char copyright[] =
"@(#) Copyright (c) 1983, 1993\n\
	The Regents of the University of California.  All rights reserved.\n";
#endif /* not lint */

#include <sys/param.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#ifndef __APPLE__
#include <sys/module.h>
#include <sys/linker.h>
#endif

#include <net/ethernet.h>
#include <net/if.h>
#include <net/if_var.h>
#include <net/if_dl.h>
#include <net/if_types.h>
#include <net/if_mib.h>
#include <net/route.h>
#include <net/pktsched/pktsched.h>
#include <net/network_agent.h>

/* IP */
#include <netinet/in.h>
#include <netinet/in_var.h>
#include <arpa/inet.h>
#include <netdb.h>

#include <ifaddrs.h>
#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sysexits.h>

#include "ifconfig.h"

/*
 * Since "struct ifreq" is composed of various union members, callers
 * should pay special attention to interprete the value.
 * (.e.g. little/big endian difference in the structure.)
 */
struct	ifreq ifr;

char	name[IFNAMSIZ];
int	setaddr;
int	setmask;
int	doalias;
int	clearaddr;
int	newaddr = 1;
int	noload;
int all;

int bond_details = 0;
int	supmedia = 0;
#if TARGET_OS_EMBEDDED
int	verbose = 1;
int	showrtref = 1;
#else /* !TARGET_OS_EMBEDDED */
int	verbose = 0;
int	showrtref = 0;
#endif /* !TARGET_OS_EMBEDDED */
int	printkeys = 0;		/* Print keying material for interfaces. */

static	int ifconfig(int argc, char *const *argv, int iscreate,
		const struct afswtch *afp);
static	void status(const struct afswtch *afp, const struct sockaddr_dl *sdl,
		struct ifaddrs *ifa);
static char *bytes_to_str(unsigned long long bytes);
static char *bps_to_str(unsigned long long rate);
static char *ns_to_str(unsigned long long nsec);
static	void tunnel_status(int s);
static	void usage(void);
static char *sched2str(unsigned int s);
static char *tl2str(unsigned int s);
static char *ift2str(unsigned int t, unsigned int f, unsigned int sf);

static struct afswtch *af_getbyname(const char *name);
static struct afswtch *af_getbyfamily(int af);
static void af_other_status(int);

static struct option *opts = NULL;

void
opt_register(struct option *p)
{
	p->next = opts;
	opts = p;
}

static void
usage(void)
{
	char options[1024];
	struct option *p;

	/* XXX not right but close enough for now */
	options[0] = '\0';
	for (p = opts; p != NULL; p = p->next) {
		strlcat(options, p->opt_usage, sizeof(options));
		strlcat(options, " ", sizeof(options));
	}

	fprintf(stderr,
	"usage: ifconfig %sinterface address_family [address [dest_address]]\n"
	"                [parameters]\n"
	"       ifconfig interface create\n"
	"       ifconfig -a %s[-d] [-m] [-u] [-v] [address_family]\n"
	"       ifconfig -l [-d] [-u] [address_family]\n"
	"       ifconfig %s[-d] [-m] [-u] [-v]\n",
		options, options, options);
	exit(1);
}

int
main(int argc, char *argv[])
{
	int c, namesonly, downonly, uponly;
	const struct afswtch *afp = NULL;
	int ifindex;
	struct ifaddrs *ifap, *ifa;
	struct ifreq paifr;
	const struct sockaddr_dl *sdl;
	char options[1024], *cp;
	const char *ifname;
	struct option *p;
	size_t iflen;

	all = downonly = uponly = namesonly = noload = 0;

	/* Parse leading line options */
#ifndef __APPLE__
	strlcpy(options, "adklmnuv", sizeof(options));
#else
	strlcpy(options, "abdlmruv", sizeof(options));
#endif
	for (p = opts; p != NULL; p = p->next)
		strlcat(options, p->opt, sizeof(options));
	while ((c = getopt(argc, argv, options)) != -1) {
		switch (c) {
		case 'a':	/* scan all interfaces */
			all++;
			break;
		case 'b':	/* bond detailed output */
			bond_details++;
			break;				
		case 'd':	/* restrict scan to "down" interfaces */
			downonly++;
			break;
#ifndef __APPLE__
		case 'k':
			printkeys++;
			break;
#endif
		case 'l':	/* scan interface names only */
			namesonly++;
			break;
		case 'm':	/* show media choices in status */
			supmedia = 1;
			break;
#ifndef __APPLE__
		case 'n':	/* suppress module loading */
			noload++;
			break;
#endif
		case 'r':
			showrtref++;
			break;
		case 'u':	/* restrict scan to "up" interfaces */
			uponly++;
			break;
		case 'v':
			verbose++;
			break;
		default:
			for (p = opts; p != NULL; p = p->next)
				if (p->opt[0] == c) {
					p->cb(optarg);
					break;
				}
			if (p == NULL)
				usage();
			break;
		}
	}
	argc -= optind;
	argv += optind;

	/* -l cannot be used with -a or -q or -m or -b */
	if (namesonly &&
	    (all || supmedia || bond_details))
		usage();

	/* nonsense.. */
	if (uponly && downonly)
		usage();

	/* no arguments is equivalent to '-a' */
	if (!namesonly && argc < 1)
		all = 1;

	/* -a and -l allow an address family arg to limit the output */
	if (all || namesonly) {
		if (argc > 1)
			usage();

		ifname = NULL;
		if (argc == 1) {
			afp = af_getbyname(*argv);
			if (afp == NULL)
				usage();
			if (afp->af_name != NULL)
				argc--, argv++;
			/* leave with afp non-zero */
		}
	} else {
		/* not listing, need an argument */
		if (argc < 1)
			usage();

		ifname = *argv;
		argc--, argv++;

#ifdef notdef
		/* check and maybe load support for this interface */
		ifmaybeload(ifname);
#endif
		ifindex = if_nametoindex(ifname);
		if (ifindex == 0) {
			/*
			 * NOTE:  We must special-case the `create' command
			 * right here as we would otherwise fail when trying
			 * to find the interface.
			 */
			if (argc > 0 && (strcmp(argv[0], "create") == 0 ||
			    strcmp(argv[0], "plumb") == 0)) {
				iflen = strlcpy(name, ifname, sizeof(name));
				if (iflen >= sizeof(name))
					errx(1, "%s: cloning name too long",
					    ifname);
				ifconfig(argc, argv, 1, NULL);
				exit(0);
			}
			errx(1, "interface %s does not exist", ifname);
		}
	}

	/* Check for address family */
	if (argc > 0) {
		afp = af_getbyname(*argv);
		if (afp != NULL)
			argc--, argv++;
	}

	if (getifaddrs(&ifap) != 0)
		err(EXIT_FAILURE, "getifaddrs");
	cp = NULL;
	ifindex = 0;
	for (ifa = ifap; ifa; ifa = ifa->ifa_next) {
		memset(&paifr, 0, sizeof(paifr));
		strncpy(paifr.ifr_name, ifa->ifa_name, sizeof(paifr.ifr_name));
		if (sizeof(paifr.ifr_addr) >= ifa->ifa_addr->sa_len) {
			memcpy(&paifr.ifr_addr, ifa->ifa_addr,
			    ifa->ifa_addr->sa_len);
		}

		if (ifname != NULL && strcmp(ifname, ifa->ifa_name) != 0)
			continue;
		if (ifa->ifa_addr->sa_family == AF_LINK)
			sdl = (const struct sockaddr_dl *) ifa->ifa_addr;
		else
			sdl = NULL;
		if (cp != NULL && strcmp(cp, ifa->ifa_name) == 0)
			continue;
		iflen = strlcpy(name, ifa->ifa_name, sizeof(name));
		if (iflen >= sizeof(name)) {
			warnx("%s: interface name too long, skipping",
			    ifa->ifa_name);
			continue;
		}
		cp = ifa->ifa_name;

		if (downonly && (ifa->ifa_flags & IFF_UP) != 0)
			continue;
		if (uponly && (ifa->ifa_flags & IFF_UP) == 0)
			continue;
		ifindex++;
		/*
		 * Are we just listing the interfaces?
		 */
		if (namesonly) {
			if (ifindex > 1)
				printf(" ");
			fputs(name, stdout);
			continue;
		}

		if (argc > 0)
			ifconfig(argc, argv, 0, afp);
		else
			status(afp, sdl, ifa);
	}
	if (namesonly)
		printf("\n");
	freeifaddrs(ifap);

	exit(0);
}

static struct afswtch *afs = NULL;

void
af_register(struct afswtch *p)
{
	p->af_next = afs;
	afs = p;
}

static struct afswtch *
af_getbyname(const char *name)
{
	struct afswtch *afp;

	for (afp = afs; afp !=  NULL; afp = afp->af_next)
		if (strcmp(afp->af_name, name) == 0)
			return afp;
	return NULL;
}

static struct afswtch *
af_getbyfamily(int af)
{
	struct afswtch *afp;

	for (afp = afs; afp != NULL; afp = afp->af_next)
		if (afp->af_af == af)
			return afp;
	return NULL;
}

static void
af_other_status(int s)
{
	struct afswtch *afp;
	uint8_t afmask[howmany(AF_MAX, NBBY)];

	memset(afmask, 0, sizeof(afmask));
	for (afp = afs; afp != NULL; afp = afp->af_next) {
		if (afp->af_other_status == NULL)
			continue;
		if (afp->af_af != AF_UNSPEC && isset(afmask, afp->af_af))
			continue;
		afp->af_other_status(s);
		setbit(afmask, afp->af_af);
	}
}

static void
af_all_tunnel_status(int s)
{
	struct afswtch *afp;
	uint8_t afmask[howmany(AF_MAX, NBBY)];

	memset(afmask, 0, sizeof(afmask));
	for (afp = afs; afp != NULL; afp = afp->af_next) {
		if (afp->af_status_tunnel == NULL)
			continue;
		if (afp->af_af != AF_UNSPEC && isset(afmask, afp->af_af))
			continue;
		afp->af_status_tunnel(s);
		setbit(afmask, afp->af_af);
	}
}

static struct cmd *cmds = NULL;

void
cmd_register(struct cmd *p)
{
	p->c_next = cmds;
	cmds = p;
}

static const struct cmd *
cmd_lookup(const char *name)
{
#define	N(a)	(sizeof(a)/sizeof(a[0]))
	const struct cmd *p;

	for (p = cmds; p != NULL; p = p->c_next)
		if (strcmp(name, p->c_name) == 0)
			return p;
	return NULL;
#undef N
}

struct callback {
	callback_func *cb_func;
	void	*cb_arg;
	struct callback *cb_next;
};
static struct callback *callbacks = NULL;

void
callback_register(callback_func *func, void *arg)
{
	struct callback *cb;

	cb = malloc(sizeof(struct callback));
	if (cb == NULL)
		errx(1, "unable to allocate memory for callback");
	cb->cb_func = func;
	cb->cb_arg = arg;
	cb->cb_next = callbacks;
	callbacks = cb;
}

/* specially-handled commands */
static void setifaddr(const char *, int, int, const struct afswtch *);
static const struct cmd setifaddr_cmd = DEF_CMD("ifaddr", 0, setifaddr);

static void setifdstaddr(const char *, int, int, const struct afswtch *);
static const struct cmd setifdstaddr_cmd =
	DEF_CMD("ifdstaddr", 0, setifdstaddr);

static int
ifconfig(int argc, char *const *argv, int iscreate, const struct afswtch *afp)
{
	const struct afswtch *nafp;
	struct callback *cb;
	int s;

	strncpy(ifr.ifr_name, name, sizeof ifr.ifr_name);
top:
	if (afp == NULL)
		afp = af_getbyname("inet");
	ifr.ifr_addr.sa_family =
		afp->af_af == AF_LINK || afp->af_af == AF_UNSPEC ?
		AF_INET : afp->af_af;

	if ((s = socket(ifr.ifr_addr.sa_family, SOCK_DGRAM, 0)) < 0)
		err(1, "socket(family %u,SOCK_DGRAM", ifr.ifr_addr.sa_family);

	while (argc > 0) {
		const struct cmd *p;

		p = cmd_lookup(*argv);
		if (p == NULL) {
			/*
			 * Not a recognized command, choose between setting
			 * the interface address and the dst address.
			 */
			p = (setaddr ? &setifdstaddr_cmd : &setifaddr_cmd);
		}
		if (p->c_u.c_func || p->c_u.c_func2) {
			if (iscreate && !p->c_iscloneop) { 
				/*
				 * Push the clone create callback so the new
				 * device is created and can be used for any
				 * remaining arguments.
				 */
				cb = callbacks;
				if (cb == NULL)
					errx(1, "internal error, no callback");
				callbacks = cb->cb_next;
				cb->cb_func(s, cb->cb_arg);
				iscreate = 0;
				/*
				 * Handle any address family spec that
				 * immediately follows and potentially
				 * recreate the socket.
				 */
				nafp = af_getbyname(*argv);
				if (nafp != NULL) {
					argc--, argv++;
					if (nafp != afp) {
						close(s);
						afp = nafp;
						goto top;
					}
				}
			}
			if (p->c_parameter == NEXTARG) {
				if (argv[1] == NULL)
					errx(1, "'%s' requires argument",
					    p->c_name);
				p->c_u.c_func(argv[1], 0, s, afp);
				argc--, argv++;
			} else if (p->c_parameter == OPTARG) {
				p->c_u.c_func(argv[1], 0, s, afp);
				if (argv[1] != NULL)
					argc--, argv++;
			} else if (p->c_parameter == NEXTARG2) {
				if (argc < 3)
					errx(1, "'%s' requires 2 arguments",
					    p->c_name);
				p->c_u.c_func2(argv[1], argv[2], s, afp);
				argc -= 2, argv += 2;
			} else
				p->c_u.c_func(*argv, p->c_parameter, s, afp);
		}
		argc--, argv++;
	}

	/*
	 * Do any post argument processing required by the address family.
	 */
	if (afp->af_postproc != NULL)
		afp->af_postproc(s, afp);
	/*
	 * Do deferred callbacks registered while processing
	 * command-line arguments.
	 */
	for (cb = callbacks; cb != NULL; cb = cb->cb_next)
		cb->cb_func(s, cb->cb_arg);
	/*
	 * Do deferred operations.
	 */
	if (clearaddr) {
		if (afp->af_ridreq == NULL || afp->af_difaddr == 0) {
			warnx("interface %s cannot change %s addresses!",
			      name, afp->af_name);
			clearaddr = 0;
		}
	}
	if (clearaddr) {
		int ret;
		strncpy(afp->af_ridreq, name, sizeof ifr.ifr_name);
		ret = ioctl(s, afp->af_difaddr, afp->af_ridreq);
		if (ret < 0) {
			if (errno == EADDRNOTAVAIL && (doalias >= 0)) {
				/* means no previous address for interface */
			} else
				Perror("ioctl (SIOCDIFADDR)");
		}
	}
	if (newaddr) {
		if (afp->af_addreq == NULL || afp->af_aifaddr == 0) {
			warnx("interface %s cannot change %s addresses!",
			      name, afp->af_name);
			newaddr = 0;
		}
	}
	if (newaddr && (setaddr || setmask)) {
		strncpy(afp->af_addreq, name, sizeof ifr.ifr_name);
		if (ioctl(s, afp->af_aifaddr, afp->af_addreq) < 0)
			Perror("ioctl (SIOCAIFADDR)");
	}

	close(s);
	return(0);
}

/*ARGSUSED*/
static void
setifaddr(const char *addr, int param, int s, const struct afswtch *afp)
{
	if (afp->af_getaddr == NULL)
		return;
	/*
	 * Delay the ioctl to set the interface addr until flags are all set.
	 * The address interpretation may depend on the flags,
	 * and the flags may change when the address is set.
	 */
	setaddr++;
	if (doalias == 0 && afp->af_af != AF_LINK)
		clearaddr = 1;
	afp->af_getaddr(addr, (doalias >= 0 ? ADDR : RIDADDR));
}

static void
settunnel(const char *src, const char *dst, int s, const struct afswtch *afp)
{
	struct addrinfo *srcres, *dstres;
	int ecode;

	if (afp->af_settunnel == NULL) {
		warn("address family %s does not support tunnel setup",
			afp->af_name);
		return;
	}

	if ((ecode = getaddrinfo(src, NULL, NULL, &srcres)) != 0)
		errx(1, "error in parsing address string: %s",
		    gai_strerror(ecode));

	if ((ecode = getaddrinfo(dst, NULL, NULL, &dstres)) != 0)  
		errx(1, "error in parsing address string: %s",
		    gai_strerror(ecode));

	if (srcres->ai_addr->sa_family != dstres->ai_addr->sa_family)
		errx(1,
		    "source and destination address families do not match");

	afp->af_settunnel(s, srcres, dstres);

	freeaddrinfo(srcres);
	freeaddrinfo(dstres);
}

/* ARGSUSED */
static void
deletetunnel(const char *vname, int param, int s, const struct afswtch *afp)
{

	if (ioctl(s, SIOCDIFPHYADDR, &ifr) < 0)
		err(1, "SIOCDIFPHYADDR");
}

static void
setifnetmask(const char *addr, int dummy __unused, int s,
    const struct afswtch *afp)
{
	if (afp->af_getaddr != NULL) {
		setmask++;
		afp->af_getaddr(addr, MASK);
	}
}

static void
setifbroadaddr(const char *addr, int dummy __unused, int s,
    const struct afswtch *afp)
{
	if (afp->af_getaddr != NULL)
		afp->af_getaddr(addr, DSTADDR);
}

static void
setifipdst(const char *addr, int dummy __unused, int s,
    const struct afswtch *afp)
{
	const struct afswtch *inet;

	inet = af_getbyname("inet");
	if (inet == NULL)
		return;
	inet->af_getaddr(addr, DSTADDR);
	clearaddr = 0;
	newaddr = 0;
}

static void
notealias(const char *addr, int param, int s, const struct afswtch *afp)
{
#define rqtosa(x) (&(((struct ifreq *)(afp->x))->ifr_addr))
	if (setaddr && doalias == 0 && param < 0)
		if (afp->af_addreq != NULL && afp->af_ridreq != NULL)
			bcopy((caddr_t)rqtosa(af_addreq),
			      (caddr_t)rqtosa(af_ridreq),
			      rqtosa(af_addreq)->sa_len);
	doalias = param;
	if (param < 0) {
		clearaddr = 1;
		newaddr = 0;
	} else
		clearaddr = 0;
#undef rqtosa
}

/*ARGSUSED*/
static void
setifdstaddr(const char *addr, int param __unused, int s, 
    const struct afswtch *afp)
{
	if (afp->af_getaddr != NULL)
		afp->af_getaddr(addr, DSTADDR);
}

/*
 * Note: doing an SIOCIGIFFLAGS scribbles on the union portion
 * of the ifreq structure, which may confuse other parts of ifconfig.
 * Make a private copy so we can avoid that.
 */
static void
setifflags(const char *vname, int value, int s, const struct afswtch *afp)
{
	struct ifreq		my_ifr;
	int flags;

	bcopy((char *)&ifr, (char *)&my_ifr, sizeof(struct ifreq));

 	if (ioctl(s, SIOCGIFFLAGS, (caddr_t)&my_ifr) < 0) {
 		Perror("ioctl (SIOCGIFFLAGS)");
 		exit(1);
 	}
	strncpy(my_ifr.ifr_name, name, sizeof (my_ifr.ifr_name));
	flags = my_ifr.ifr_flags;
	
	if (value < 0) {
		value = -value;
		flags &= ~value;
	} else
		flags |= value;
	my_ifr.ifr_flags = flags & 0xffff;
	if (ioctl(s, SIOCSIFFLAGS, (caddr_t)&my_ifr) < 0)
		Perror(vname);
}

void
setifcap(const char *vname, int value, int s, const struct afswtch *afp)
{
	int flags;

 	if (ioctl(s, SIOCGIFCAP, (caddr_t)&ifr) < 0) {
 		Perror("ioctl (SIOCGIFCAP)");
 		exit(1);
 	}
	flags = ifr.ifr_curcap;
	if (value < 0) {
		value = -value;
		flags &= ~value;
	} else
		flags |= value;
	flags &= ifr.ifr_reqcap;
	ifr.ifr_reqcap = flags;
	if (ioctl(s, SIOCSIFCAP, (caddr_t)&ifr) < 0)
		Perror(vname);
}

static void
setifmetric(const char *val, int dummy __unused, int s, 
    const struct afswtch *afp)
{
	strncpy(ifr.ifr_name, name, sizeof (ifr.ifr_name));
	ifr.ifr_metric = atoi(val);
	if (ioctl(s, SIOCSIFMETRIC, (caddr_t)&ifr) < 0)
		warn("ioctl (set metric)");
}

static void
setifmtu(const char *val, int dummy __unused, int s, 
    const struct afswtch *afp)
{
	strncpy(ifr.ifr_name, name, sizeof (ifr.ifr_name));
	ifr.ifr_mtu = atoi(val);
	if (ioctl(s, SIOCSIFMTU, (caddr_t)&ifr) < 0)
		warn("ioctl (set mtu)");
}

#ifndef __APPLE__
static void
setifname(const char *val, int dummy __unused, int s, 
    const struct afswtch *afp)
{
	char *newname;

	newname = strdup(val);
	if (newname == NULL) {
		warn("no memory to set ifname");
		return;
	}
	ifr.ifr_data = newname;
	if (ioctl(s, SIOCSIFNAME, (caddr_t)&ifr) < 0) {
		warn("ioctl (set name)");
		free(newname);
		return;
	}
	strlcpy(name, newname, sizeof(name));
	free(newname);
}
#endif

static void
setrouter(const char *vname, int value, int s, const struct afswtch *afp)
{
	if (afp->af_setrouter == NULL) {
		warn("address family %s does not support router mode",
		    afp->af_name);
		return;
	}

	afp->af_setrouter(s, value);
}

static void
setifdesc(const char *val, int dummy __unused, int s, const struct afswtch *afp)
{
	struct if_descreq ifdr;

	bzero(&ifdr, sizeof (ifdr));
	strncpy(ifdr.ifdr_name, name, sizeof (ifdr.ifdr_name));
	ifdr.ifdr_len = strlen(val);
	strncpy((char *)ifdr.ifdr_desc, val, sizeof (ifdr.ifdr_desc));

	if (ioctl(s, SIOCSIFDESC, (caddr_t)&ifdr) < 0) {
		warn("ioctl (set desc)");
	}
}

static void
settbr(const char *val, int dummy __unused, int s, const struct afswtch *afp)
{
	struct if_linkparamsreq iflpr;
	long double bps;
	u_int64_t rate;
	u_int32_t percent = 0;
	char *cp;

	errno = 0;
	bzero(&iflpr, sizeof (iflpr));
	strncpy(iflpr.iflpr_name, name, sizeof (iflpr.iflpr_name));

	bps = strtold(val, &cp);
	if (val == cp || errno != 0) {
		warn("Invalid value '%s'", val);
		return;
	}
	rate = (u_int64_t)bps;
	if (cp != NULL) {
		if (!strcmp(cp, "b") || !strcmp(cp, "bps")) {
			; /* nothing */
		} else if (!strcmp(cp, "Kb") || !strcmp(cp, "Kbps")) {
			rate *= 1000;
		} else if (!strcmp(cp, "Mb") || !strcmp(cp, "Mbps")) {
			rate *= 1000 * 1000;
		} else if (!strcmp(cp, "Gb") || !strcmp(cp, "Gbps")) {
			rate *= 1000 * 1000 * 1000;
		} else if (!strcmp(cp, "%")) {
			percent = rate;
			if (percent == 0 || percent > 100) {
				printf("Value out of range '%s'", val);
				return;
			}
		} else if (*cp != '\0') {
			printf("Unknown unit '%s'", cp);
			return;
		}
	}
	iflpr.iflpr_output_tbr_rate = rate;
	iflpr.iflpr_output_tbr_percent = percent;
	if (ioctl(s, SIOCSIFLINKPARAMS, &iflpr) < 0 &&
	    errno != ENOENT && errno != ENXIO && errno != ENODEV) {
		warn("ioctl (set link params)");
	} else if (errno == ENXIO) {
		printf("TBR cannot be set on %s\n", name);
	} else if (errno == ENOENT || rate == 0) {
		printf("%s: TBR is now disabled\n", name);
	} else if (errno == ENODEV) {
		printf("%s: requires absolute TBR rate\n", name);
	} else if (percent != 0) {
		printf("%s: TBR rate set to %u%% of effective link rate\n",
		    name, percent);
	} else {
		printf("%s: TBR rate set to %s\n", name, bps_to_str(rate));
	}
}

static void
setthrottle(const char *val, int dummy __unused, int s,
    const struct afswtch *afp)
{
	struct if_throttlereq iftr;
	char *cp;

	errno = 0;
	bzero(&iftr, sizeof (iftr));
	strncpy(iftr.ifthr_name, name, sizeof (iftr.ifthr_name));

	iftr.ifthr_level = strtold(val, &cp);
	if (val == cp || errno != 0) {
		warn("Invalid value '%s'", val);
		return;
	}

	if (ioctl(s, SIOCSIFTHROTTLE, &iftr) < 0 && errno != ENXIO) {
		warn("ioctl (set throttling level)");
	} else if (errno == ENXIO) {
		printf("throttling level cannot be set on %s\n", name);
	} else {
		printf("%s: throttling level set to %d\n", name,
		    iftr.ifthr_level);
	}
}

static void
setdisableoutput(const char *val, int dummy __unused, int s,
    const struct afswtch *afp)
{
	struct ifreq ifr;
	char *cp;
	errno = 0;
	bzero(&ifr, sizeof (ifr));
	strncpy(ifr.ifr_name, name, sizeof (ifr.ifr_name));

	ifr.ifr_ifru.ifru_disable_output = strtold(val, &cp);
	if (val == cp || errno != 0) {
		warn("Invalid value '%s'", val);
		return;
	}

	if (ioctl(s, SIOCSIFDISABLEOUTPUT, &ifr) < 0 && errno != ENXIO) {
		warn("ioctl set disable output");
	} else if (errno == ENXIO) {
		printf("output thread can not be disabled on %s\n", name);
	} else {
		printf("output %s on %s\n",
		    ((ifr.ifr_ifru.ifru_disable_output == 0) ? "enabled" : "disabled"),
		    name);
	}
}

static void
setlog(const char *val, int dummy __unused, int s,
    const struct afswtch *afp)
{
	char *cp;

	errno = 0;
	strncpy(ifr.ifr_name, name, sizeof(ifr.ifr_name));

	ifr.ifr_log.ifl_level = strtold(val, &cp);
	if (val == cp || errno != 0) {
		warn("Invalid value '%s'", val);
		return;
	}
	ifr.ifr_log.ifl_flags = (IFRLOGF_DLIL|IFRLOGF_FAMILY|IFRLOGF_DRIVER|
	    IFRLOGF_FIRMWARE);

	if (ioctl(s, SIOCSIFLOG, &ifr) < 0)
		warn("ioctl (set logging parameters)");
}

void
setcl2k(const char *vname, int value, int s, const struct afswtch *afp)
{
	strncpy(ifr.ifr_name, name, sizeof(ifr.ifr_name));
	ifr.ifr_ifru.ifru_2kcl = value;
	
	if (ioctl(s, SIOCSIF2KCL, (caddr_t)&ifr) < 0)
		Perror(vname);
}

void
setexpensive(const char *vname, int value, int s, const struct afswtch *afp)
{
	strncpy(ifr.ifr_name, name, sizeof(ifr.ifr_name));
	ifr.ifr_ifru.ifru_expensive = value;
	
	if (ioctl(s, SIOCSIFEXPENSIVE, (caddr_t)&ifr) < 0)
		Perror(vname);
}

void
settimestamp(const char *vname, int value, int s, const struct afswtch *afp)
{
	strncpy(ifr.ifr_name, name, sizeof(ifr.ifr_name));
	
	if (value == 0) {
		if (ioctl(s, SIOCSIFTIMESTAMPDISABLE, (caddr_t)&ifr) < 0)
			Perror(vname);
	} else {
		if (ioctl(s, SIOCSIFTIMESTAMPENABLE, (caddr_t)&ifr) < 0)
			Perror(vname);
	}
}

void
setecnmode(const char *val, int dummy __unused, int s,
    const struct afswtch *afp)
{
	char *cp;

	if (strcmp(val, "default") == 0)
		ifr.ifr_ifru.ifru_ecn_mode = IFRTYPE_ECN_DEFAULT;
	else if (strcmp(val, "enable") == 0)
		ifr.ifr_ifru.ifru_ecn_mode = IFRTYPE_ECN_ENABLE;
	else if (strcmp(val, "disable") == 0)
		ifr.ifr_ifru.ifru_ecn_mode = IFRTYPE_ECN_DISABLE;
	else {
		ifr.ifr_ifru.ifru_ecn_mode = strtold(val, &cp);
		if (val == cp || errno != 0) {
			warn("Invalid ECN mode value '%s'", val);
			return;
		}
	}
	
	strncpy(ifr.ifr_name, name, sizeof(ifr.ifr_name));
	
	if (ioctl(s, SIOCSECNMODE, (caddr_t)&ifr) < 0)
		Perror("ioctl(SIOCSECNMODE)");
}

#if defined(SIOCSQOSMARKINGMODE) && defined(SIOCSQOSMARKINGENABLED)

void
setqosmarking(const char *cmd, const char *arg, int s, const struct afswtch *afp)
{
	u_long ioc;

#if (DEBUG | DEVELOPMENT)
	printf("%s(%s, %s)\n", __func__, cmd, arg);
#endif /* (DEBUG | DEVELOPMENT) */
	
	strncpy(ifr.ifr_name, name, sizeof(ifr.ifr_name));
	
	if (strcmp(cmd, "mode") == 0) {
		ioc = SIOCSQOSMARKINGMODE;
		
		if (strcmp(arg, "fastlane") == 0)
			ifr.ifr_qosmarking_mode = IFRTYPE_QOSMARKING_FASTLANE;
		else if (strcasecmp(arg, "none") == 0 || strcasecmp(arg, "off") == 0)
			ifr.ifr_qosmarking_mode = IFRTYPE_QOSMARKING_MODE_NONE;
		else
			err(EX_USAGE, "bad value for qosmarking mode: %s", arg);
	} else if (strcmp(cmd, "enabled") == 0) {
		ioc = SIOCSQOSMARKINGENABLED;
		if (strcmp(arg, "1") == 0 || strcasecmp(arg, "on") == 0||
		    strcasecmp(arg, "yes") == 0 || strcasecmp(arg, "true") == 0)
			ifr.ifr_qosmarking_enabled = 1;
		else if (strcmp(arg, "0") == 0 || strcasecmp(arg, "off") == 0||
			 strcasecmp(arg, "no") == 0 || strcasecmp(arg, "false") == 0)
			ifr.ifr_qosmarking_enabled = 0;
		else
			err(EX_USAGE, "bad value for qosmarking enabled: %s", arg);
	} else {
		err(EX_USAGE, "qosmarking takes mode or enabled");
	}
	
	if (ioctl(s, ioc, (caddr_t)&ifr) < 0)
		err(EX_OSERR, "ioctl(%s, %s)", cmd, arg);
}

void
setfastlane(const char *cmd, const char *arg, int s, const struct afswtch *afp)
{
	strncpy(ifr.ifr_name, name, sizeof(ifr.ifr_name));
	
	warnx("### fastlane is obsolete, use qosmarking ###");
	
	if (strcmp(cmd, "capable") == 0) {
		if (strcmp(arg, "1") == 0 || strcasecmp(arg, "on") == 0||
		    strcasecmp(arg, "yes") == 0 || strcasecmp(arg, "true") == 0)
			setqosmarking("mode", "fastlane", s, afp);
		else if (strcmp(arg, "0") == 0 || strcasecmp(arg, "off") == 0||
			 strcasecmp(arg, "no") == 0 || strcasecmp(arg, "false") == 0)
			setqosmarking("mode", "off", s, afp);
		else
			err(EX_USAGE, "bad value for fastlane %s", cmd);
	} else if (strcmp(cmd, "enable") == 0) {
		if (strcmp(arg, "1") == 0 || strcasecmp(arg, "on") == 0||
		    strcasecmp(arg, "yes") == 0 || strcasecmp(arg, "true") == 0)
			setqosmarking("enabled", "1", s, afp);
		else if (strcmp(arg, "0") == 0 || strcasecmp(arg, "off") == 0||
			 strcasecmp(arg, "no") == 0 || strcasecmp(arg, "false") == 0)
			setqosmarking("enabled", "0", s, afp);
		else
			err(EX_USAGE, "bad value for fastlane %s", cmd);
	} else {
		err(EX_USAGE, "fastlane takes capable or enable");
	}
}

#else /* defined(SIOCSQOSMARKINGMODE) && defined(SIOCSQOSMARKINGENABLED) */

void
setfastlane(const char *cmd, const char *arg, int s, const struct afswtch *afp)
{
	int value;
	u_long ioc;
	
	strncpy(ifr.ifr_name, name, sizeof(ifr.ifr_name));
	
	if (strcmp(cmd, "capable") == 0)
		ioc = SIOCSFASTLANECAPABLE;
	else if (strcmp(cmd, "enable") == 0)
		ioc = SIOCSFASTLEENABLED;
	else
		err(EX_USAGE, "fastlane takes capable or enabled");
	
	if (strcmp(arg, "1") == 0 || strcasecmp(arg, "on") == 0||
	    strcasecmp(arg, "yes") == 0 || strcasecmp(arg, "true") == 0)
		value = 1;
	else if (strcmp(arg, "0") == 0 || strcasecmp(arg, "off") == 0||
		 strcasecmp(arg, "no") == 0 || strcasecmp(arg, "false") == 0)
		value = 0;
	else
		err(EX_USAGE, "bad value for fastlane %s", cmd);
	
	if (ioc == SIOCSFASTLANECAPABLE)
		ifr.ifr_fastlane_capable = value;
	else
		ifr.ifr_fastlane_enabled = value;
	
	if (ioctl(s, ioc, (caddr_t)&ifr) < 0)
		err(EX_OSERR, "ioctl(%s, %s)", cmd, arg);
}


void
setqosmarking(const char *cmd, const char *arg, int s, const struct afswtch *afp)
{
	if (strcmp(cmd, "mode") == 0) {
		if (strcmp(arg, "fastlane") == 0)
			setfastlane("capable", "on", s, afp);
		else if (strcmp(arg, "none") == 0)
			setfastlane("capable", "off", s, afp);
		else
			err(EX_USAGE, "bad value for qosmarking mode: %s", arg);
	} else if (strcmp(cmd, "enabled") == 0) {
		if (strcmp(arg, "1") == 0 || strcasecmp(arg, "on") == 0||
		    strcasecmp(arg, "yes") == 0 || strcasecmp(arg, "true") == 0)
			setfastlane("enable", "on", s, afp);
		else if (strcmp(arg, "0") == 0 || strcasecmp(arg, "off") == 0||
			 strcasecmp(arg, "no") == 0 || strcasecmp(arg, "false") == 0)
			setfastlane("enable", "off", s, afp);
		else
			err(EX_USAGE, "bad value for qosmarking enabled: %s", arg);
	} else {
		err(EX_USAGE, "qosmarking takes mode or enabled");
	}
}

#endif /* defined(SIOCSQOSMARKINGMODE) && defined(SIOCSQOSMARKINGENABLED) */

#define	IFFBITS \
"\020\1UP\2BROADCAST\3DEBUG\4LOOPBACK\5POINTOPOINT\6SMART\7RUNNING" \
"\10NOARP\11PROMISC\12ALLMULTI\13OACTIVE\14SIMPLEX\15LINK0\16LINK1\17LINK2" \
"\20MULTICAST"

#define	IFEFBITS \
"\020\1AUTOCONFIGURING\5FASTLN_CAP\6IPV6_DISABLED\7ACCEPT_RTADV\10TXSTART\11RXPOLL" \
"\12VLAN\13BOND\14ARPLL\15NOWINDOWSCALE\16NOAUTOIPV6LL\17EXPENSIVE\20ROUTER4" \
"\21ROUTER6\22LOCALNET_PRIVATE\23ND6ALT\24RESTRICTED_RECV\25AWDL\26NOACKPRI" \
"\27AWDL_RESTRICTED\30CL2K\31ECN_ENABLE\32ECN_DISABLE\33CHANNEL_DRV\34CA" \
"\35SENDLIST\36DIRECTLINK\37FASTLN_ON\40UPDOWNCHANGE"

#define	IFCAPBITS \
"\020\1RXCSUM\2TXCSUM\3VLAN_MTU\4VLAN_HWTAGGING\5JUMBO_MTU" \
"\6TSO4\7TSO6\10LRO\11AV\12TXSTATUS\13CHANNEL_IO\14HW_TIMESTAMP\15SW_TIMESTAMP" \
"\16PARTIAL_CSUM\17ZEROINVERT_CSUM"

#define	IFRLOGF_BITS \
"\020\1DLIL\21FAMILY\31DRIVER\35FIRMWARE"

/*
 * Print the status of the interface.  If an address family was
 * specified, show only it; otherwise, show them all.
 */
static void
status(const struct afswtch *afp, const struct sockaddr_dl *sdl,
	struct ifaddrs *ifa)
{
	struct ifaddrs *ift;
	int allfamilies, s;
	struct ifstat ifs;
	struct if_descreq ifdr;
	struct if_linkparamsreq iflpr;
	int mib[6];
	struct ifmibdata_supplemental ifmsupp;
	size_t miblen = sizeof(struct ifmibdata_supplemental);
	u_int64_t eflags = 0;
	int curcap = 0;
	
	if (afp == NULL) {
		allfamilies = 1;
		afp = af_getbyname("inet");
	} else
		allfamilies = 0;

	ifr.ifr_addr.sa_family = afp->af_af == AF_LINK ? AF_INET : afp->af_af;
	strncpy(ifr.ifr_name, name, sizeof(ifr.ifr_name));

	s = socket(ifr.ifr_addr.sa_family, SOCK_DGRAM, 0);
	if (s < 0)
		err(1, "socket(family %u,SOCK_DGRAM)", ifr.ifr_addr.sa_family);

	printf("%s: ", name);
	printb("flags", ifa->ifa_flags, IFFBITS);
	if (ioctl(s, SIOCGIFMETRIC, &ifr) != -1)
		if (ifr.ifr_metric)
			printf(" metric %d", ifr.ifr_metric);
	if (ioctl(s, SIOCGIFMTU, &ifr) != -1)
		printf(" mtu %d", ifr.ifr_mtu);
	if (showrtref && ioctl(s, SIOCGIFGETRTREFCNT, &ifr) != -1)
		printf(" rtref %d", ifr.ifr_route_refcnt);
	if (verbose) {
		unsigned int ifindex = if_nametoindex(ifa->ifa_name);
		if (ifindex != 0)
			printf(" index %u", ifindex);
	}
	putchar('\n');

	if (verbose && ioctl(s, SIOCGIFEFLAGS, (caddr_t)&ifr) != -1 &&
	    (eflags = ifr.ifr_eflags) != 0) {
		printb("\teflags", eflags, IFEFBITS);
		putchar('\n');
	}

	if (ioctl(s, SIOCGIFCAP, (caddr_t)&ifr) == 0) {
		if (ifr.ifr_curcap != 0) {
			curcap = ifr.ifr_curcap;
			printb("\toptions", ifr.ifr_curcap, IFCAPBITS);
			putchar('\n');
		}
		if (supmedia && ifr.ifr_reqcap != 0) {
			printb("\tcapabilities", ifr.ifr_reqcap, IFCAPBITS);
			putchar('\n');
		}
	}
	
	tunnel_status(s);

	for (ift = ifa; ift != NULL; ift = ift->ifa_next) {
		if (ift->ifa_addr == NULL)
			continue;
		if (strcmp(ifa->ifa_name, ift->ifa_name) != 0)
			continue;
		if (allfamilies) {
			const struct afswtch *p;
			p = af_getbyfamily(ift->ifa_addr->sa_family);
			if (p != NULL && p->af_status != NULL)
				p->af_status(s, ift);
		} else if (afp->af_af == ift->ifa_addr->sa_family)
			afp->af_status(s, ift);
	}
#if 0
	if (allfamilies || afp->af_af == AF_LINK) {
		const struct afswtch *lafp;

		/*
		 * Hack; the link level address is received separately
		 * from the routing information so any address is not
		 * handled above.  Cobble together an entry and invoke
		 * the status method specially.
		 */
		lafp = af_getbyname("lladdr");
		if (lafp != NULL) {
			info.rti_info[RTAX_IFA] = (struct sockaddr *)sdl;
			lafp->af_status(s, &info);
		}
	}
#endif
	if (allfamilies)
		af_other_status(s);
	else if (afp->af_other_status != NULL)
		afp->af_other_status(s);

	strncpy(ifs.ifs_name, name, sizeof ifs.ifs_name);
	if (ioctl(s, SIOCGIFSTATUS, &ifs) == 0) 
		printf("%s", ifs.ascii);

	/* The rest is for when verbose is set; if not set, we're done */
	if (!verbose)
		goto done;

	if (ioctl(s, SIOCGIFTYPE, &ifr) != -1) {
		char *c = ift2str(ifr.ifr_type.ift_type,
		    ifr.ifr_type.ift_family, ifr.ifr_type.ift_subfamily);
		if (c != NULL)
			printf("\ttype: %s\n", c);
	}

	if (verbose > 0) {
		struct if_agentidsreq ifar;
		memset(&ifar, 0, sizeof(ifar));

		strlcpy(ifar.ifar_name, name, sizeof(ifar.ifar_name));

		if (ioctl(s, SIOCGIFAGENTIDS, &ifar) != -1) {
			if (ifar.ifar_count != 0) {
				ifar.ifar_uuids = calloc(ifar.ifar_count, sizeof(uuid_t));
				if (ifar.ifar_uuids != NULL) {
					if (ioctl(s, SIOCGIFAGENTIDS, &ifar) != 1) {
						for (int agent_i = 0; agent_i < ifar.ifar_count; agent_i++) {
							struct netagent_req nar;
							memset(&nar, 0, sizeof(nar));

							uuid_copy(nar.netagent_uuid, ifar.ifar_uuids[agent_i]);

							if (ioctl(s, SIOCGIFAGENTDATA, &nar) != 1) {
								printf("\tagent domain:%s type:%s flags:0x%x desc:\"%s\"\n",
									   nar.netagent_domain, nar.netagent_type,
									   nar.netagent_flags, nar.netagent_desc);
							}
						}
					}
					free(ifar.ifar_uuids);
				}
			}
		}
	}

	if (ioctl(s, SIOCGIFLINKQUALITYMETRIC, &ifr) != -1) {
		int lqm = ifr.ifr_link_quality_metric;
		if (verbose > 1) {
			printf("\tlink quality: %d ", lqm);
			if (lqm == IFNET_LQM_THRESH_OFF)
				printf("(off)");
			else if (lqm == IFNET_LQM_THRESH_UNKNOWN)
				printf("(unknown)");
			else if (lqm > IFNET_LQM_THRESH_UNKNOWN &&
				 lqm <= IFNET_LQM_THRESH_BAD)
				printf("(bad)");
			else if (lqm > IFNET_LQM_THRESH_UNKNOWN &&
				 lqm <= IFNET_LQM_THRESH_POOR)
				printf("(poor)");
			else if (lqm > IFNET_LQM_THRESH_POOR &&
			    lqm <= IFNET_LQM_THRESH_GOOD)
				printf("(good)");
			else
				printf("(?)");
			printf("\n");
		} else if (lqm > IFNET_LQM_THRESH_UNKNOWN) {
			printf("\tlink quality: %d ", lqm);
			if (lqm <= IFNET_LQM_THRESH_BAD)
				printf("(bad)");
			else if (lqm <= IFNET_LQM_THRESH_POOR)
				printf("(poor)");
			else if (lqm <= IFNET_LQM_THRESH_GOOD)
				printf("(good)");
			else
				printf("(?)");
			printf("\n");
		}
	}

	if (verbose > 0) {
		if (ioctl(s, SIOCGIFINTERFACESTATE, &ifr) != -1) {
			printf("\tstate");
			if (ifr.ifr_interface_state.valid_bitmask &
			    IF_INTERFACE_STATE_RRC_STATE_VALID) {
				uint8_t rrc_state = ifr.ifr_interface_state.rrc_state;
				
				printf(" rrc: %u ", rrc_state);
				if (rrc_state == IF_INTERFACE_STATE_RRC_STATE_CONNECTED)
					printf("(connected)");
				else if (rrc_state == IF_INTERFACE_STATE_RRC_STATE_IDLE)
					printf("(idle)");
				else
					printf("(?)");
			}
			if (ifr.ifr_interface_state.valid_bitmask &
			    IF_INTERFACE_STATE_INTERFACE_AVAILABILITY_VALID) {
				uint8_t ifavail = ifr.ifr_interface_state.interface_availability;
				
				printf(" availability: %u ", ifavail);
				if (ifavail == IF_INTERFACE_STATE_INTERFACE_AVAILABLE)
					printf("(true)");
				else if (ifavail == IF_INTERFACE_STATE_INTERFACE_UNAVAILABLE)
					printf("(false)");
				else
					printf("(?)");
			} else {
				printf(" availability: (not valid)");
			}
			if (verbose > 1 &&
			    ifr.ifr_interface_state.valid_bitmask &
			    IF_INTERFACE_STATE_LQM_STATE_VALID) {
				int8_t lqm = ifr.ifr_interface_state.lqm_state;
				
				printf(" lqm: %d", lqm);
				
				if (lqm == IFNET_LQM_THRESH_OFF)
					printf("(off)");
				else if (lqm == IFNET_LQM_THRESH_UNKNOWN)
					printf("(unknown)");
				else if (lqm == IFNET_LQM_THRESH_BAD)
					printf("(bad)");
				else if (lqm == IFNET_LQM_THRESH_POOR)
					printf("(poor)");
				else if (lqm == IFNET_LQM_THRESH_GOOD)
					printf("(good)");
				else
					printf("(?)");
			}
		}
		printf("\n");
	}
	
	bzero(&iflpr, sizeof (iflpr));
	strncpy(iflpr.iflpr_name, name, sizeof (iflpr.iflpr_name));
	if (ioctl(s, SIOCGIFLINKPARAMS, &iflpr) != -1) {
		u_int64_t ibw_max = iflpr.iflpr_input_bw.max_bw;
		u_int64_t ibw_eff = iflpr.iflpr_input_bw.eff_bw;
		u_int64_t obw_max = iflpr.iflpr_output_bw.max_bw;
		u_int64_t obw_eff = iflpr.iflpr_output_bw.eff_bw;
		u_int64_t obw_tbr = iflpr.iflpr_output_tbr_rate;
		u_int32_t obw_pct = iflpr.iflpr_output_tbr_percent;
		u_int64_t ilt_max = iflpr.iflpr_input_lt.max_lt;
		u_int64_t ilt_eff = iflpr.iflpr_input_lt.eff_lt;
		u_int64_t olt_max = iflpr.iflpr_output_lt.max_lt;
		u_int64_t olt_eff = iflpr.iflpr_output_lt.eff_lt;


		if (eflags & IFEF_TXSTART) {
			u_int32_t flags = iflpr.iflpr_flags;
			u_int32_t sched = iflpr.iflpr_output_sched;
			struct if_throttlereq iftr;

			printf("\tscheduler: %s%s ",
			    (flags & IFLPRF_ALTQ) ? "ALTQ_" : "",
			    sched2str(sched));
			if (flags & IFLPRF_DRVMANAGED)
				printf("(driver managed)");
			printf("\n");

			bzero(&iftr, sizeof (iftr));
			strncpy(iftr.ifthr_name, name,
			    sizeof (iftr.ifthr_name));
			if (ioctl(s, SIOCGIFTHROTTLE, &iftr) != -1 &&
			    iftr.ifthr_level != IFNET_THROTTLE_OFF)
				printf("\tthrottling: level %d (%s)\n",
				    iftr.ifthr_level, tl2str(iftr.ifthr_level));
		}

		if (obw_tbr != 0 && obw_eff > obw_tbr)
			obw_eff = obw_tbr;

		if (ibw_max != 0 || obw_max != 0) {
			if (ibw_max == obw_max && ibw_eff == obw_eff &&
			    ibw_max == ibw_eff && obw_tbr == 0) {
				printf("\tlink rate: %s\n",
				    bps_to_str(ibw_max));
			} else {
				printf("\tuplink rate: %s [eff] / ",
				    bps_to_str(obw_eff));
				if (obw_tbr != 0) {
					if (obw_pct == 0)
						printf("%s [tbr] / ",
						    bps_to_str(obw_tbr));
					else
						printf("%s [tbr %u%%] / ",
						    bps_to_str(obw_tbr),
						    obw_pct);
				}
				printf("%s", bps_to_str(obw_max));
				if (obw_tbr != 0)
					printf(" [max]");
				printf("\n");
				if (ibw_eff == ibw_max) {
					printf("\tdownlink rate: %s\n",
					    bps_to_str(ibw_max));
				} else {
					printf("\tdownlink rate: "
					    "%s [eff] / ", bps_to_str(ibw_eff));
					printf("%s [max]\n",
					    bps_to_str(ibw_max));
				}
			}
		} else if (obw_tbr != 0) {
			printf("\tuplink rate: %s [tbr]\n",
			    bps_to_str(obw_tbr));
		}

		if (ilt_max != 0 || olt_max != 0) {
			if (ilt_max == olt_max && ilt_eff == olt_eff &&
			    ilt_max == ilt_eff) {
				printf("\tlink latency: %s\n",
				    ns_to_str(ilt_max));
			} else {
				if (olt_max != 0 && olt_eff == olt_max) {
					printf("\tuplink latency: %s\n",
					    ns_to_str(olt_max));
				} else if (olt_max != 0) {
					printf("\tuplink latency: "
					    "%s [eff] / ", ns_to_str(olt_eff));
					printf("%s [max]\n",
					    ns_to_str(olt_max));
				}
				if (ilt_max != 0 && ilt_eff == ilt_max) {
					printf("\tdownlink latency: %s\n",
					    ns_to_str(ilt_max));
				} else if (ilt_max != 0) {
					printf("\tdownlink latency: "
					    "%s [eff] / ", ns_to_str(ilt_eff));
					printf("%s [max]\n",
					    ns_to_str(ilt_max));
				}
			}
		}
	}

	/* Common OID prefix */
	mib[0] = CTL_NET;
	mib[1] = PF_LINK;
	mib[2] = NETLINK_GENERIC;
	mib[3] = IFMIB_IFDATA;
	mib[4] = if_nametoindex(name);
	mib[5] = IFDATA_SUPPLEMENTAL;
	if (sysctl(mib, 6, &ifmsupp, &miblen, (void *)0, 0) == -1)
		err(1, "sysctl IFDATA_SUPPLEMENTAL");

	if (ifmsupp.ifmd_data_extended.ifi_alignerrs != 0) {
		printf("\tunaligned pkts: %llu\n",
		    ifmsupp.ifmd_data_extended.ifi_alignerrs);
	}
	if (ifmsupp.ifmd_data_extended.ifi_dt_bytes != 0) {
		printf("\tdata milestone interval: %s\n",
		    bytes_to_str(ifmsupp.ifmd_data_extended.ifi_dt_bytes));
	}

	bzero(&ifdr, sizeof (ifdr));
	strncpy(ifdr.ifdr_name, name, sizeof (ifdr.ifdr_name));
	if (ioctl(s, SIOCGIFDESC, &ifdr) != -1 && ifdr.ifdr_len) {
		printf("\tdesc: %s\n", ifdr.ifdr_desc);
	}

	if (ioctl(s, SIOCGIFLOG, &ifr) != -1 && ifr.ifr_log.ifl_level) {
		printf("\tlogging: level %d ", ifr.ifr_log.ifl_level);
		printb("facilities", ifr.ifr_log.ifl_flags, IFRLOGF_BITS);
		putchar('\n');
	}

	if (ioctl(s, SIOCGIFDELEGATE, &ifr) != -1 && ifr.ifr_delegated) {
		char delegatedif[IFNAMSIZ+1];
		if (if_indextoname(ifr.ifr_delegated, delegatedif) != NULL)
			printf("\teffective interface: %s\n", delegatedif);
	}

	if (ioctl(s, SIOCGSTARTDELAY, &ifr) != -1) {
		if (ifr.ifr_start_delay_qlen > 0 &&
		    ifr.ifr_start_delay_timeout > 0) {
			printf("\ttxstart qlen: %u packets "
			    "timeout: %u microseconds\n",
			    ifr.ifr_start_delay_qlen,
			    ifr.ifr_start_delay_timeout/1000);
		}
	}
#if defined(IFCAP_HW_TIMESTAMP) && defined(IFCAP_SW_TIMESTAMP)
	if ((curcap & (IFCAP_HW_TIMESTAMP | IFCAP_SW_TIMESTAMP)) &&
	    ioctl(s, SIOCGIFTIMESTAMPENABLED, &ifr) != -1) {
		printf("\ttimestamp: %s\n",
		       (ifr.ifr_intval != 0) ? "enabled" : "disabled");
	}
#endif
#if defined(SIOCGQOSMARKINGENABLED) && defined(SIOCGQOSMARKINGMODE)
	if (ioctl(s, SIOCGQOSMARKINGENABLED, &ifr) != -1) {
		printf("\tqosmarking enabled: %s mode: ",
		       ifr.ifr_qosmarking_enabled ? "yes" : "no");
		if (ioctl(s, SIOCGQOSMARKINGMODE, &ifr) != -1) {
			switch (ifr.ifr_qosmarking_mode) {
				case IFRTYPE_QOSMARKING_FASTLANE:
					printf("fastlane\n");
					break;
				case IFRTYPE_QOSMARKING_MODE_NONE:
					printf("none\n");
					break;
				default:
					printf("unknown (%u)\n", ifr.ifr_qosmarking_mode);
					break;
			}
		}
	}
#endif /* defined(SIOCGQOSMARKINGENABLED) && defined(SIOCGQOSMARKINGMODE) */
done:
	close(s);
	return;
}

#define	KILOBYTES	1024
#define	MEGABYTES	(KILOBYTES * KILOBYTES)
#define	GIGABYTES	(KILOBYTES * KILOBYTES * KILOBYTES)

static char *
bytes_to_str(unsigned long long bytes)
{
        static char buf[32];
        const char *u;
        long double n = bytes, t;

        if (bytes >= GIGABYTES) {
                t = n / GIGABYTES;
                u = "GB";
        } else if (n >= MEGABYTES) {
                t = n / MEGABYTES;
                u = "MB";
        } else if (n >= KILOBYTES) {
                t = n / KILOBYTES;
                u = "KB";
        } else {
                t = n;
                u = "bytes";
        }

        snprintf(buf, sizeof (buf), "%-4.2Lf %s", t, u);
        return (buf);
}

#define	GIGABIT_PER_SEC	1000000000	/* gigabit per second */
#define MEGABIT_PER_SEC	1000000		/* megabit per second */
#define	KILOBIT_PER_SEC	1000		/* kilobit per second */

static char *
bps_to_str(unsigned long long rate)
{
        static char buf[32];
        const char *u;
        long double n = rate, t;

        if (rate >= GIGABIT_PER_SEC) {
                t = n / GIGABIT_PER_SEC;
                u = "Gbps";
        } else if (n >= MEGABIT_PER_SEC) {
                t = n / MEGABIT_PER_SEC;
                u = "Mbps";
        } else if (n >= KILOBIT_PER_SEC) {
                t = n / KILOBIT_PER_SEC;
                u = "Kbps";
        } else {
                t = n;
                u = "bps ";
        }

        snprintf(buf, sizeof (buf), "%-4.2Lf %4s", t, u);
        return (buf);
}

#define	NSEC_PER_SEC	1000000000	/* nanosecond per second */
#define	USEC_PER_SEC	1000000		/* microsecond per second */
#define	MSEC_PER_SEC	1000		/* millisecond per second */

static char *
ns_to_str(unsigned long long nsec)
{
        static char buf[32];
        const char *u;
        long double n = nsec, t;

        if (nsec >= NSEC_PER_SEC) {
                t = n / NSEC_PER_SEC;
                u = "sec ";
        } else if (n >= USEC_PER_SEC) {
                t = n / USEC_PER_SEC;
                u = "msec";
        } else if (n >= MSEC_PER_SEC) {
                t = n / MSEC_PER_SEC;
                u = "usec";
        } else {
                t = n;
                u = "nsec";
        }

        snprintf(buf, sizeof (buf), "%-4.2Lf %4s", t, u);
        return (buf);
}

static void
tunnel_status(int s)
{
	af_all_tunnel_status(s);
}

void
Perror(const char *cmd)
{
	switch (errno) {

	case ENXIO:
		errx(1, "%s: no such interface", cmd);
		break;

	case EPERM:
		errx(1, "%s: permission denied", cmd);
		break;

	default:
		err(1, "%s", cmd);
	}
}

/*
 * Print a value a la the %b format of the kernel's printf
 */
void
printb(const char *s, unsigned v, const char *bits)
{
	int i, any = 0;
	char c;

	if (bits && *bits == 8)
		printf("%s=%o", s, v);
	else
		printf("%s=%x", s, v);
	bits++;
	if (bits) {
		putchar('<');
		while ((i = *bits++) != '\0') {
			if (v & (1 << (i-1))) {
				if (any)
					putchar(',');
				any = 1;
				for (; (c = *bits) > 32; bits++)
					putchar(c);
			} else
				for (; *bits > 32; bits++)
					;
		}
		putchar('>');
	}
}

#ifndef __APPLE__
void
ifmaybeload(const char *name)
{
#define MOD_PREFIX_LEN		3	/* "if_" */
	struct module_stat mstat;
	int fileid, modid;
	char ifkind[IFNAMSIZ + MOD_PREFIX_LEN], ifname[IFNAMSIZ], *dp;
	const char *cp;

	/* loading suppressed by the user */
	if (noload)
		return;

	/* trim the interface number off the end */
	strlcpy(ifname, name, sizeof(ifname));
	for (dp = ifname; *dp != 0; dp++)
		if (isdigit(*dp)) {
			*dp = 0;
			break;
		}

	/* turn interface and unit into module name */
	strlcpy(ifkind, "if_", sizeof(ifkind));
	strlcpy(ifkind + MOD_PREFIX_LEN, ifname,
	    sizeof(ifkind) - MOD_PREFIX_LEN);

	/* scan files in kernel */
	mstat.version = sizeof(struct module_stat);
	for (fileid = kldnext(0); fileid > 0; fileid = kldnext(fileid)) {
		/* scan modules in file */
		for (modid = kldfirstmod(fileid); modid > 0;
		     modid = modfnext(modid)) {
			if (modstat(modid, &mstat) < 0)
				continue;
			/* strip bus name if present */
			if ((cp = strchr(mstat.name, '/')) != NULL) {
				cp++;
			} else {
				cp = mstat.name;
			}
			/* already loaded? */
			if (strncmp(ifname, cp, strlen(ifname) + 1) == 0 ||
			    strncmp(ifkind, cp, strlen(ifkind) + 1) == 0)
				return;
		}
	}

	/* not present, we should try to load it */
	kldload(ifkind);
}
#endif

static struct cmd basic_cmds[] = {
	DEF_CMD("up",		IFF_UP,		setifflags),
	DEF_CMD("down",		-IFF_UP,	setifflags),
	DEF_CMD("arp",		-IFF_NOARP,	setifflags),
	DEF_CMD("-arp",		IFF_NOARP,	setifflags),
	DEF_CMD("debug",	IFF_DEBUG,	setifflags),
	DEF_CMD("-debug",	-IFF_DEBUG,	setifflags),
#ifdef IFF_PPROMISC
	DEF_CMD("promisc",	IFF_PPROMISC,	setifflags),
	DEF_CMD("-promisc",	-IFF_PPROMISC,	setifflags),
#endif /* IFF_PPROMISC */
	DEF_CMD("add",		IFF_UP,		notealias),
	DEF_CMD("alias",	IFF_UP,		notealias),
	DEF_CMD("-alias",	-IFF_UP,	notealias),
	DEF_CMD("delete",	-IFF_UP,	notealias),
	DEF_CMD("remove",	-IFF_UP,	notealias),
#ifdef notdef
#define	EN_SWABIPS	0x1000
	DEF_CMD("swabips",	EN_SWABIPS,	setifflags),
	DEF_CMD("-swabips",	-EN_SWABIPS,	setifflags),
#endif
	DEF_CMD_ARG("netmask",			setifnetmask),
	DEF_CMD_ARG("metric",			setifmetric),
	DEF_CMD_ARG("broadcast",		setifbroadaddr),
	DEF_CMD_ARG("ipdst",			setifipdst),
	DEF_CMD_ARG2("tunnel",			settunnel),
	DEF_CMD("-tunnel", 0,			deletetunnel),
	DEF_CMD("deletetunnel", 0,		deletetunnel),
	DEF_CMD("link0",	IFF_LINK0,	setifflags),
	DEF_CMD("-link0",	-IFF_LINK0,	setifflags),
	DEF_CMD("link1",	IFF_LINK1,	setifflags),
	DEF_CMD("-link1",	-IFF_LINK1,	setifflags),
	DEF_CMD("link2",	IFF_LINK2,	setifflags),
	DEF_CMD("-link2",	-IFF_LINK2,	setifflags),
#ifdef IFF_MONITOR
	DEF_CMD("monitor",	IFF_MONITOR:,	setifflags),
	DEF_CMD("-monitor",	-IFF_MONITOR,	setifflags),
#endif /* IFF_MONITOR */
#ifdef IFF_STATICARP
	DEF_CMD("staticarp",	IFF_STATICARP,	setifflags),
	DEF_CMD("-staticarp",	-IFF_STATICARP,	setifflags),
#endif /* IFF_STATICARP */
#ifdef IFCAP_RXCSUM
	DEF_CMD("rxcsum",	IFCAP_RXCSUM,	setifcap),
	DEF_CMD("-rxcsum",	-IFCAP_RXCSUM,	setifcap),
#endif /* IFCAP_RXCSUM */
#ifdef IFCAP_TXCSUM
	DEF_CMD("txcsum",	IFCAP_TXCSUM,	setifcap),
	DEF_CMD("-txcsum",	-IFCAP_TXCSUM,	setifcap),
#endif /* IFCAP_TXCSUM */
#ifdef IFCAP_NETCONS
	DEF_CMD("netcons",	IFCAP_NETCONS,	setifcap),
	DEF_CMD("-netcons",	-IFCAP_NETCONS,	setifcap),
#endif /* IFCAP_NETCONS */
#ifdef IFCAP_POLLING
	DEF_CMD("polling",	IFCAP_POLLING,	setifcap),
	DEF_CMD("-polling",	-IFCAP_POLLING,	setifcap),
#endif /* IFCAP_POLLING */
#ifdef IFCAP_TSO
	DEF_CMD("tso",		IFCAP_TSO,	setifcap),
	DEF_CMD("-tso",		-IFCAP_TSO,	setifcap),
#endif /* IFCAP_TSO */
#ifdef IFCAP_LRO
	DEF_CMD("lro",		IFCAP_LRO,	setifcap),
	DEF_CMD("-lro",		-IFCAP_LRO,	setifcap),
#endif /* IFCAP_LRO */
#ifdef IFCAP_WOL
	DEF_CMD("wol",		IFCAP_WOL,	setifcap),
	DEF_CMD("-wol",		-IFCAP_WOL,	setifcap),
#endif /* IFCAP_WOL */
#ifdef IFCAP_WOL_UCAST
	DEF_CMD("wol_ucast",	IFCAP_WOL_UCAST,	setifcap),
	DEF_CMD("-wol_ucast",	-IFCAP_WOL_UCAST,	setifcap),
#endif /* IFCAP_WOL_UCAST */
#ifdef IFCAP_WOL_MCAST
	DEF_CMD("wol_mcast",	IFCAP_WOL_MCAST,	setifcap),
	DEF_CMD("-wol_mcast",	-IFCAP_WOL_MCAST,	setifcap),
#endif /* IFCAP_WOL_MCAST */
#ifdef IFCAP_WOL_MAGIC
	DEF_CMD("wol_magic",	IFCAP_WOL_MAGIC,	setifcap),
	DEF_CMD("-wol_magic",	-IFCAP_WOL_MAGIC,	setifcap),
#endif /* IFCAP_WOL_MAGIC */
	DEF_CMD("normal",	-IFF_LINK0,	setifflags),
	DEF_CMD("compress",	IFF_LINK0,	setifflags),
	DEF_CMD("noicmp",	IFF_LINK1,	setifflags),
	DEF_CMD_ARG("mtu",			setifmtu),
#ifdef notdef
	DEF_CMD_ARG("name",			setifname),
#endif /* notdef */
#ifdef IFCAP_AV
	DEF_CMD("av", IFCAP_AV, setifcap),
	DEF_CMD("-av", -IFCAP_AV, setifcap),
#endif /* IFCAP_AV */
	DEF_CMD("router",	1,		setrouter),
	DEF_CMD("-router",	0,		setrouter),
	DEF_CMD_ARG("desc",			setifdesc),
	DEF_CMD_ARG("tbr",			settbr),
	DEF_CMD_ARG("throttle",			setthrottle),
	DEF_CMD_ARG("log",			setlog),
	DEF_CMD("cl2k",	1,			setcl2k),
	DEF_CMD("-cl2k",	0,		setcl2k),
	DEF_CMD("expensive",	1,		setexpensive),
	DEF_CMD("-expensive",	0,		setexpensive),
	DEF_CMD("timestamp",	1,		settimestamp),
	DEF_CMD("-timestamp",	0,		settimestamp),
	DEF_CMD_ARG("ecn",			setecnmode),
	DEF_CMD_ARG2("fastlane",		setfastlane),
	DEF_CMD_ARG2("qosmarking",		setqosmarking),
	DEF_CMD_ARG("disable_output",		setdisableoutput),
};

static __constructor void
ifconfig_ctor(void)
{
#define	N(a)	(sizeof(a) / sizeof(a[0]))
	int i;

	for (i = 0; i < N(basic_cmds);  i++)
		cmd_register(&basic_cmds[i]);
#undef N
}

static char *
sched2str(unsigned int s)
{
	char *c;

	switch (s) {
	case PKTSCHEDT_NONE:
		c = "NONE";
		break;
	case PKTSCHEDT_TCQ:
		c = "TCQ";
		break;
	case PKTSCHEDT_QFQ:
		c = "QFQ";
		break;
	case PKTSCHEDT_FQ_CODEL:
		c = "FQ_CODEL";
		break;
	default:
		c = "UNKNOWN";
		break;
	}

	return (c);
}

static char *
tl2str(unsigned int s)
{
	char *c;

	switch (s) {
	case IFNET_THROTTLE_OFF:
		c = "off";
		break;
	case IFNET_THROTTLE_OPPORTUNISTIC:
		c = "opportunistic";
		break;
	default:
		c = "unknown";
		break;
	}

	return (c);
}

static char *
ift2str(unsigned int t, unsigned int f, unsigned int sf)
{
	static char buf[256];
	char *c = NULL;

	switch (t) {
	case IFT_ETHER:
		switch (sf) {
		case IFRTYPE_SUBFAMILY_USB:
			c = "USB Ethernet";
			break;
		case IFRTYPE_SUBFAMILY_BLUETOOTH:
			c = "Bluetooth PAN";
			break;
		case IFRTYPE_SUBFAMILY_WIFI:
			c = "Wi-Fi";
			break;
		case IFRTYPE_SUBFAMILY_THUNDERBOLT:
			c = "IP over Thunderbolt";
			break;
		case IFRTYPE_SUBFAMILY_ANY:
		default:
			c = "Ethernet";
			break;
		}
		break;

	case IFT_IEEE1394:
		c = "IP over FireWire";
		break;

	case IFT_PKTAP:
		c = "Packet capture";
		break;

	case IFT_CELLULAR:
		c = "Cellular";
		break;

	case IFT_BRIDGE:
	case IFT_PFLOG:
	case IFT_PFSYNC:
	case IFT_OTHER:
	case IFT_PPP:
	case IFT_LOOP:
	case IFT_GIF:
	case IFT_STF:
	case IFT_L2VLAN:
	case IFT_IEEE8023ADLAG:
	default:
		break;
	}

	if (verbose > 1) {
		if (c == NULL) {
			(void) snprintf(buf, sizeof (buf),
			    "0x%x family: %u subfamily: %u",
			    ifr.ifr_type.ift_type, ifr.ifr_type.ift_family,
			    ifr.ifr_type.ift_subfamily);
		} else {
			(void) snprintf(buf, sizeof (buf),
			    "%s (0x%x) family: %u subfamily: %u", c,
			    ifr.ifr_type.ift_type, ifr.ifr_type.ift_family,
			    ifr.ifr_type.ift_subfamily);
		}
		c = buf;
	}

	return (c);
}
