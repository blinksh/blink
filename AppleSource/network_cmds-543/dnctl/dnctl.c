/*
 * Copyright (c) 2002-2015 Apple Inc. All rights reserved.
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
 * Copyright (c) 2002-2003 Luigi Rizzo
 * Copyright (c) 1996 Alex Nash, Paul Traina, Poul-Henning Kamp
 * Copyright (c) 1994 Ugen J.S.Antsilevich
 *
 * Idea and grammar partially left from:
 * Copyright (c) 1993 Daniel Boulet
 *
 * Redistribution and use in source forms, with and without modification,
 * are permitted provided that this entire comment appears intact.
 *
 * Redistribution in binary form may occur without any restrictions.
 * Obviously, it would be nice if you gave credit where credit is due
 * but requiring it would be too onerous.
 *
 * This software is provided ``AS IS'' without any warranties of any kind.
 */

/*
 * Ripped off ipfw2.c
 */

#include <sys/param.h>
#include <sys/socket.h>
#include <sys/sysctl.h>

#include <ctype.h>
#include <err.h>
#include <errno.h>
#include <netdb.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <sysexits.h>

#include <net/if.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/ip_dummynet.h>
#include <arpa/inet.h>

/*
 * Limit delay to avoid computation overflow
 */
#define MAX_DELAY (INT_MAX / 1000)


int
do_quiet,		/* Be quiet in add and flush */
do_pipe,		/* this cmd refers to a pipe */
do_sort,		/* field to sort results (0 = no) */
test_only,		/* only check syntax */
verbose;

#define	IP_MASK_ALL	0xffffffff

/*
 * _s_x is a structure that stores a string <-> token pairs, used in
 * various places in the parser. Entries are stored in arrays,
 * with an entry with s=NULL as terminator.
 * The search routines are match_token() and match_value().
 * Often, an element with x=0 contains an error string.
 *
 */
struct _s_x {
	char const *s;
	int x;
};

enum tokens {
	TOK_NULL=0,
    
	TOK_ACCEPT,
	TOK_COUNT,
	TOK_PIPE,
	TOK_QUEUE,
    
	TOK_PLR,
	TOK_NOERROR,
	TOK_BUCKETS,
	TOK_DSTIP,
	TOK_SRCIP,
	TOK_DSTPORT,
	TOK_SRCPORT,
	TOK_ALL,
	TOK_MASK,
	TOK_BW,
	TOK_DELAY,
	TOK_RED,
	TOK_GRED,
	TOK_DROPTAIL,
	TOK_PROTO,
	TOK_WEIGHT,

	TOK_DSTIP6,
	TOK_SRCIP6,
};

struct _s_x dummynet_params[] = {
	{ "plr",		TOK_PLR },
	{ "noerror",		TOK_NOERROR },
	{ "buckets",		TOK_BUCKETS },
	{ "dst-ip",		TOK_DSTIP },
	{ "src-ip",		TOK_SRCIP },
	{ "dst-port",		TOK_DSTPORT },
	{ "src-port",		TOK_SRCPORT },
	{ "proto",		TOK_PROTO },
	{ "weight",		TOK_WEIGHT },
	{ "all",		TOK_ALL },
	{ "mask",		TOK_MASK },
	{ "droptail",		TOK_DROPTAIL },
	{ "red",		TOK_RED },
	{ "gred",		TOK_GRED },
	{ "bw",			TOK_BW },
	{ "bandwidth",		TOK_BW },
	{ "delay",		TOK_DELAY },
	{ "pipe",		TOK_PIPE },
	{ "queue",		TOK_QUEUE },
	{ "dst-ipv6",		TOK_DSTIP6},
	{ "dst-ip6",		TOK_DSTIP6},
	{ "src-ipv6",		TOK_SRCIP6},
	{ "src-ip6",		TOK_SRCIP6},
	{ "dummynet-params",	TOK_NULL },
	{ NULL, 0 }	/* terminator */
};

static void show_usage(void);


void n2mask(struct in6_addr *, int );
unsigned long long align_uint64(const uint64_t *);

/* n2mask sets n bits of the mask */
void
n2mask(struct in6_addr *mask, int n)
{
    static int      minimask[9] =
    { 0x00, 0x80, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc, 0xfe, 0xff };
    u_char          *p;
    
    memset(mask, 0, sizeof(struct in6_addr));
    p = (u_char *) mask;
    for (; n > 0; p++, n -= 8) {
        if (n >= 8)
            *p = 0xff;
        else
            *p = minimask[n];
    }
    return;
}

/*
 * The following is used to generate a printable argument for
 * 64-bit numbers, irrespective of platform alignment and bit size.
 * Because all the printf in this program use %llu as a format,
 * we just return an unsigned long long, which is larger than
 * we need in certain cases, but saves the hassle of using
 * PRIu64 as a format specifier.
 * We don't care about inlining, this is not performance critical code.
 */
unsigned long long
align_uint64(const uint64_t *pll)
{
    uint64_t ret;
    
    bcopy (pll, &ret, sizeof(ret));
    return ret;
}

/*
 * conditionally runs the command.
 */
static int
do_cmd(int optname, void *optval, socklen_t *optlen)
{
	static int s = -1;	/* the socket */
	int i;
    
	if (test_only)
		return 0;
    
	if (s == -1)
		s = socket(AF_INET, SOCK_RAW, IPPROTO_RAW);
	if (s < 0)
		err(EX_UNAVAILABLE, "socket");
	    
	if (optname == IP_DUMMYNET_GET)
		i = getsockopt(s, IPPROTO_IP, optname, optval, optlen);
	else
		i = setsockopt(s, IPPROTO_IP, optname, optval, optlen ? *optlen : 0);
	return i;
}

/**
 * match_token takes a table and a string, returns the value associated
 * with the string (-1 in case of failure).
 */
static int
match_token(struct _s_x *table, char *string)
{
	struct _s_x *pt;
	size_t i = strlen(string);
    
	for (pt = table ; i && pt->s != NULL ; pt++)
		if (strlen(pt->s) == i && !bcmp(string, pt->s, i))
			return pt->x;
	return -1;
};

static int
sort_q(const void *pa, const void *pb)
{
	int rev = (do_sort < 0);
	int field = rev ? -do_sort : do_sort;
	long long res = 0;
	const struct dn_flow_queue *a = pa;
	const struct dn_flow_queue *b = pb;
    
	switch (field) {
        case 1: /* pkts */
            res = a->len - b->len;
            break;
        case 2: /* bytes */
            res = a->len_bytes - b->len_bytes;
            break;
            
        case 3: /* tot pkts */
            res = a->tot_pkts - b->tot_pkts;
            break;
            
        case 4: /* tot bytes */
            res = a->tot_bytes - b->tot_bytes;
            break;
	}
	if (res < 0)
		res = -1;
	if (res > 0)
		res = 1;
	return (int)(rev ? res : -res);
}

static void
list_queues(struct dn_flow_set *fs, struct dn_flow_queue *q)
{
	int l;
	int index_printed = 0, indexes = 0;
	char buff[255];
    struct protoent *pe;
    
	printf("    mask: 0x%02x 0x%08x/0x%04x -> 0x%08x/0x%04x\n",
           fs->flow_mask.proto,
           fs->flow_mask.src_ip, fs->flow_mask.src_port,
           fs->flow_mask.dst_ip, fs->flow_mask.dst_port);
	if (fs->rq_elements == 0)
		return;
    
	printf("BKT Prot ___Source IP/port____ "
           "____Dest. IP/port____ Tot_pkt/bytes Pkt/Byte Drp\n");
	if (do_sort != 0)
		heapsort(q, fs->rq_elements, sizeof(struct dn_flow_queue), sort_q);

	/* Print IPv4 flows */
	for (l = 0; l < fs->rq_elements; l++) {
		struct in_addr ina;

        /* XXX: Should check for IPv4 flows */
		if (IS_IP6_FLOW_ID(&(q[l].id)))
			continue;

		if (!index_printed) {
			index_printed = 1;
			if (indexes > 0)	/* currently a no-op */
				printf("\n");
			indexes++;
			printf("    "
                   "mask: 0x%02x 0x%08x/0x%04x -> 0x%08x/0x%04x\n",
                   fs->flow_mask.proto,
                   fs->flow_mask.src_ip, fs->flow_mask.src_port,
                   fs->flow_mask.dst_ip, fs->flow_mask.dst_port);
            
			printf("BKT Prot ___Source IP/port____ "
                   "____Dest. IP/port____ "
                   "Tot_pkt/bytes Pkt/Byte Drp\n");
		}
        
		printf("%3d ", q[l].hash_slot);
		pe = getprotobynumber(q[l].id.proto);
		if (pe)
			printf("%-4s ", pe->p_name);
		else
			printf("%4u ", q[l].id.proto);
		ina.s_addr = htonl(q[l].id.src_ip);
		printf("%15s/%-5d ",
               inet_ntoa(ina), q[l].id.src_port);
		ina.s_addr = htonl(q[l].id.dst_ip);
		printf("%15s/%-5d ",
               inet_ntoa(ina), q[l].id.dst_port);
		printf("%4llu %8llu %2u %4u %3u\n",
               align_uint64(&q[l].tot_pkts),
               align_uint64(&q[l].tot_bytes),
               q[l].len, q[l].len_bytes, q[l].drops);
		if (verbose)
			printf("   S %20llu  F %20llu\n",
                   align_uint64(&q[l].S), align_uint64(&q[l].F));
	}

	/* Print IPv6 flows */
	index_printed = 0;
	for (l = 0; l < fs->rq_elements; l++) {
		if (!IS_IP6_FLOW_ID(&(q[l].id)))
			continue;
        
		if (!index_printed) {
			index_printed = 1;
			if (indexes > 0)
				printf("\n");
			indexes++;
			printf("\n        mask: proto: 0x%02x, flow_id: 0x%08x,  ",
                   fs->flow_mask.proto, fs->flow_mask.flow_id6);
			inet_ntop(AF_INET6, &(fs->flow_mask.src_ip6),
                      buff, sizeof(buff));
			printf("%s/0x%04x -> ", buff, fs->flow_mask.src_port);
			inet_ntop( AF_INET6, &(fs->flow_mask.dst_ip6),
                      buff, sizeof(buff) );
			printf("%s/0x%04x\n", buff, fs->flow_mask.dst_port);
            
			printf("BKT ___Prot___ _flow-id_ "
                   "______________Source IPv6/port_______________ "
                   "_______________Dest. IPv6/port_______________ "
                   "Tot_pkt/bytes Pkt/Byte Drp\n");
		}
		printf("%3d ", q[l].hash_slot);
		pe = getprotobynumber(q[l].id.proto);
		if (pe != NULL)
			printf("%9s ", pe->p_name);
		else
			printf("%9u ", q[l].id.proto);
		printf("%7d  %39s/%-5d ", q[l].id.flow_id6,
               inet_ntop(AF_INET6, &(q[l].id.src_ip6), buff, sizeof(buff)),
               q[l].id.src_port);
		printf(" %39s/%-5d ",
               inet_ntop(AF_INET6, &(q[l].id.dst_ip6), buff, sizeof(buff)),
               q[l].id.dst_port);
		printf(" %4llu %8llu %2u %4u %3u\n",
               align_uint64(&q[l].tot_pkts),
               align_uint64(&q[l].tot_bytes),
               q[l].len, q[l].len_bytes, q[l].drops);
		if (verbose)
			printf("   S %20llu  F %20llu\n",
                   align_uint64(&q[l].S),
                   align_uint64(&q[l].F));
	}
}

static void
print_flowset_parms(struct dn_flow_set *fs, char *prefix)
{
	int l;
	char qs[30];
	char plr[30];
	char red[90];	/* Display RED parameters */
    
	l = fs->qsize;
	if (fs->flags_fs & DN_QSIZE_IS_BYTES) {
		if (l >= 8192)
			snprintf(qs, sizeof(qs), "%d KB", l / 1024);
		else
			snprintf(qs, sizeof(qs), "%d B", l);
	} else
		snprintf(qs, sizeof(qs), "%3d sl.", l);
	if (fs->plr)
		snprintf(plr, sizeof(plr), "plr %f", 1.0 * fs->plr / (double)(0x7fffffff));
	else
		plr[0] = '\0';
	if (fs->flags_fs & DN_IS_RED)	/* RED parameters */
		snprintf(red, sizeof(red),
                 "\n\t  %cRED w_q %f min_th %d max_th %d max_p %f",
                 (fs->flags_fs & DN_IS_GENTLE_RED) ? 'G' : ' ',
                 1.0 * fs->w_q / (double)(1 << SCALE_RED),
                 SCALE_VAL(fs->min_th),
                 SCALE_VAL(fs->max_th),
                 1.0 * fs->max_p / (double)(1 << SCALE_RED));
	else
		snprintf(red, sizeof(red), "droptail");
    
	printf("%s %s%s %d queues (%d buckets) %s\n",
           prefix, qs, plr, fs->rq_elements, fs->rq_size, red);
}

static void
list_pipes(void *data, size_t nbytes, int ac, char *av[])
{
	unsigned int rulenum;
	void *next = data;
	struct dn_pipe *p = (struct dn_pipe *) data;
	struct dn_flow_set *fs;
	struct dn_flow_queue *q;
	size_t l;
    
	if (ac > 0)
		rulenum = (unsigned int)strtoul(*av++, NULL, 10);
	else
		rulenum = 0;
	for (; nbytes >= sizeof(struct dn_pipe); p = (struct dn_pipe *)next) {
		double b = p->bandwidth;
		char buf[30];
		char prefix[80];
        
		if (p->next.sle_next != (struct dn_pipe *)DN_IS_PIPE)
			break;	/* done with pipes, now queues */
        
		/*
		 * compute length, as pipe have variable size
		 */
		l = sizeof(struct dn_pipe) + p->fs.rq_elements * sizeof(struct dn_flow_queue);
		next = (char *)p + l;
		nbytes -= l;
        
		if (rulenum != 0 && rulenum != p->pipe_nr)
			continue;
        
		/*
		 * Print rate (or clocking interface)
		 */
		if (p->if_name[0] != '\0')
			snprintf(buf, sizeof(buf), "%s", p->if_name);
		else if (b == 0)
			snprintf(buf, sizeof(buf), "unlimited");
		else if (b >= 1000000)
			snprintf(buf, sizeof(buf), "%7.3f Mbit/s", b/1000000);
		else if (b >= 1000)
			snprintf(buf, sizeof(buf), "%7.3f Kbit/s", b/1000);
		else
			snprintf(buf, sizeof(buf), "%7.3f bit/s ", b);
        
		snprintf(prefix, sizeof(prefix), "%05d: %s %4d ms ",
                 p->pipe_nr, buf, p->delay);
		print_flowset_parms(&(p->fs), prefix);
		if (verbose)
			printf("   V %20qd\n", p->V >> MY_M);
        
		q = (struct dn_flow_queue *)(p+1);
		list_queues(&(p->fs), q);
	}
	for (fs = next; nbytes >= sizeof *fs; fs = next) {
		char prefix[80];
        
		if (fs->next.sle_next != (struct dn_flow_set *)DN_IS_QUEUE)
			break;
		l = sizeof(struct dn_flow_set) + fs->rq_elements * sizeof(struct dn_flow_queue);
		next = (char *)fs + l;
		nbytes -= l;
		q = (struct dn_flow_queue *)(fs+1);
		snprintf(prefix, sizeof(prefix), "q%05d: weight %d pipe %d ",
                 fs->fs_nr, fs->weight, fs->parent_nr);
		print_flowset_parms(fs, prefix);
		list_queues(fs, q);
	}
}

static void
list(int ac, char *av[], int show_counters)
{
	void *data = NULL;
	socklen_t nbytes;
	int exitval = EX_OK;
    
	int nalloc = 1024;	/* start somewhere... */
    
	if (test_only) {
		fprintf(stderr, "Testing only, list disabled\n");
		return;
	}
    
	ac--;
	av++;
    
	/* get rules or pipes from kernel, resizing array as necessary */
	nbytes = nalloc;
    
	while (nbytes >= nalloc) {
		nalloc = nalloc * 2 + 200;
		nbytes = nalloc;
		if ((data = realloc(data, nbytes)) == NULL)
			err(EX_OSERR, "realloc");
		
		if (do_cmd(IP_DUMMYNET_GET, data, &nbytes) < 0) {
			if (errno == ENOBUFS) {
				nbytes = 0;
				break;
			}
			err(EX_OSERR, "getsockopt(IP_DUMMYNET_GET)");
			
		}
	}
    
    list_pipes(data, nbytes, ac, av);
    
	free(data);
    
	if (exitval != EX_OK)
		exit(exitval);
}

static void
show_usage(void)
{
	fprintf(stderr, "usage: dnctl [options]\n"
            "do \"dnctl -h\" or see dnctl manpage for details\n"
            );
	exit(EX_USAGE);
}

static void
help(void)
{
	fprintf(stderr,
            "dnclt [-acdeftTnNpqS] <command> where <command> is one of:\n"
            "{pipe|queue} N config PIPE-BODY\n"
            "[pipe|queue] {zero|delete|show} [N{,N}]\n"
           );
    exit(0);
}

static void
delete(int ac, char *av[])
{
	struct dn_pipe p;
	int i;
	int exitval = EX_OK;
    socklen_t len;
    
	memset(&p, 0, sizeof(struct dn_pipe));
    
	av++; ac--;
    
	while (ac && isdigit(**av)) {
		i = atoi(*av); av++; ac--;

        if (do_pipe == 1)
            p.pipe_nr = i;
        else
            p.fs.fs_nr = i;
        len = sizeof(struct dn_pipe);
        i = do_cmd(IP_DUMMYNET_DEL, &p, &len);
        if (i) {
            exitval = 1;
            warn("rule %u: setsockopt(IP_DUMMYNET_DEL)",
                 do_pipe == 1 ? p.pipe_nr : p.fs.fs_nr);
        }
    }
	if (exitval != EX_OK)
		exit(exitval);
}

/*
 * the following macro returns an error message if we run out of
 * arguments.
 */
#define	NEED1(msg)	{if (!ac) errx(EX_USAGE, msg);}
#define	NEED2(msg, arg)	{if (!ac) errx(EX_USAGE, msg, arg);}

static void
config_pipe(int ac, char **av)
{
	struct dn_pipe p;
	int i;
	char *end;
	void *par = NULL;
    socklen_t len;
    
	memset(&p, 0, sizeof(struct dn_pipe));
    
	av++; ac--;
	/* Pipe number */
	if (ac && isdigit(**av)) {
		i = atoi(*av); av++; ac--;
		if (do_pipe == 1)
			p.pipe_nr = i;
		else
			p.fs.fs_nr = i;
	}
	while (ac > 0) {
		double d;
		int tok = match_token(dummynet_params, *av);
		ac--; av++;
        
		switch(tok) {
            case TOK_NOERROR:
                p.fs.flags_fs |= DN_NOERROR;
                break;
                
            case TOK_PLR:
                NEED1("plr needs argument 0..1\n");
                d = strtod(av[0], NULL);
                if (d > 1)
                    d = 1;
                else if (d < 0)
                    d = 0;
                p.fs.plr = (int)(d*0x7fffffff);
                ac--; av++;
                break;
                
            case TOK_QUEUE:
                NEED1("queue needs queue size\n");
                end = NULL;
                p.fs.qsize = (int)strtoul(av[0], &end, 0);
                if (*end == 'K' || *end == 'k') {
                    p.fs.flags_fs |= DN_QSIZE_IS_BYTES;
                    p.fs.qsize *= 1024;
                } else if (*end == 'B' || !strncmp(end, "by", 2)) {
                    p.fs.flags_fs |= DN_QSIZE_IS_BYTES;
                }
                ac--; av++;
                break;
                
            case TOK_BUCKETS:
                NEED1("buckets needs argument\n");
                p.fs.rq_size = (int)strtoul(av[0], NULL, 0);
                ac--; av++;
                break;
                
            case TOK_MASK:
                NEED1("mask needs mask specifier\n");
                /*
                 * per-flow queue, mask is dst_ip, dst_port,
                 * src_ip, src_port, proto measured in bits
                 */
                par = NULL;
                
                p.fs.flow_mask.dst_ip = 0;
                p.fs.flow_mask.src_ip = 0;
                p.fs.flow_mask.dst_port = 0;
                p.fs.flow_mask.src_port = 0;
                p.fs.flow_mask.proto = 0;
                end = NULL;
                
                while (ac >= 1) {
                    uint32_t *p32 = NULL;
                    uint16_t *p16 = NULL;
                    struct in6_addr *pa6 = NULL;
                    uint32_t a;
                    
                    tok = match_token(dummynet_params, *av);
                    ac--; av++;
                    switch(tok) {
                        case TOK_ALL:
                            /*
                             * special case, all bits significant
                             */
                            p.fs.flow_mask.dst_ip = ~0;
                            p.fs.flow_mask.src_ip = ~0;
                            p.fs.flow_mask.dst_port = ~0;
                            p.fs.flow_mask.src_port = ~0;
                            p.fs.flow_mask.proto = ~0;
                            n2mask(&(p.fs.flow_mask.dst_ip6), 128);
                            n2mask(&(p.fs.flow_mask.src_ip6), 128);
                            p.fs.flags_fs |= DN_HAVE_FLOW_MASK;
                            goto end_mask;
                            
                        case TOK_DSTIP:
                            p32 = &p.fs.flow_mask.dst_ip;
                            break;
                            
                        case TOK_SRCIP:
                            p32 = &p.fs.flow_mask.src_ip;
                            break;
                            
                        case TOK_DSTIP6:
                            pa6 = &(p.fs.flow_mask.dst_ip6);
                            break;
                            
                        case TOK_SRCIP6:
                            pa6 = &(p.fs.flow_mask.src_ip6);
                            break;
                            
                        case TOK_DSTPORT:
                            p16 = &p.fs.flow_mask.dst_port;
                            break;
                            
                        case TOK_SRCPORT:
                            p16 = &p.fs.flow_mask.src_port;
                            break;
                            
                        case TOK_PROTO:
                            break;
                            
                        default:
                            ac++; av--; /* backtrack */
                            goto end_mask;
                    }
                    if (ac < 1)
                        errx(EX_USAGE, "mask: value missing");
                    if (*av[0] == '/') {
                        a = (int)strtoul(av[0]+1, &end, 0);
                        if (pa6 == NULL)
                            a = (a == 32) ? ~0 : (1 << a) - 1;
                    } else
                        a = (int)strtoul(av[0], &end, 0);
                    if (p32 != NULL)
                        *p32 = a;
                    else if (p16 != NULL) {
                        if (a > 65535)
                            errx(EX_DATAERR,
                                 "mask: must be 16 bit");
                        *p16 = (uint16_t)a;
                    } else if (pa6 != NULL) {
                        if (a > 128)
                            errx(EX_DATAERR,
                                 "in6addr invalid mask len");
                        else
                            n2mask(pa6, a);
                    } else {
                        if (a > 255)
                            errx(EX_DATAERR,
                                 "mask: must be 8 bit");
                        p.fs.flow_mask.proto = (uint8_t)a;
                    }
                    if (a != 0)
                        p.fs.flags_fs |= DN_HAVE_FLOW_MASK;
                    ac--; av++;
                } /* end while, config masks */
end_mask:
                break;
                
            case TOK_RED:
            case TOK_GRED:
                NEED1("red/gred needs w_q/min_th/max_th/max_p\n");
                p.fs.flags_fs |= DN_IS_RED;
                if (tok == TOK_GRED)
                    p.fs.flags_fs |= DN_IS_GENTLE_RED;
                /*
                 * the format for parameters is w_q/min_th/max_th/max_p
                 */
                if ((end = strsep(&av[0], "/"))) {
                    double w_q = strtod(end, NULL);
                    if (w_q > 1 || w_q <= 0)
                        errx(EX_DATAERR, "0 < w_q <= 1");
                    p.fs.w_q = (int) (w_q * (1 << SCALE_RED));
                }
                if ((end = strsep(&av[0], "/"))) {
                    p.fs.min_th = (int)strtoul(end, &end, 0);
                    if (*end == 'K' || *end == 'k')
                        p.fs.min_th *= 1024;
                }
                if ((end = strsep(&av[0], "/"))) {
                    p.fs.max_th = (int)strtoul(end, &end, 0);
                    if (*end == 'K' || *end == 'k')
                        p.fs.max_th *= 1024;
                }
                if ((end = strsep(&av[0], "/"))) {
                    double max_p = strtod(end, NULL);
                    if (max_p > 1 || max_p <= 0)
                        errx(EX_DATAERR, "0 < max_p <= 1");
                    p.fs.max_p = (int)(max_p * (1 << SCALE_RED));
                }
                ac--; av++;
                break;
                
            case TOK_DROPTAIL:
                p.fs.flags_fs &= ~(DN_IS_RED|DN_IS_GENTLE_RED);
                break;
                
            case TOK_BW:
                NEED1("bw needs bandwidth or interface\n");
                if (do_pipe != 1)
                    errx(EX_DATAERR, "bandwidth only valid for pipes");
                /*
                 * set clocking interface or bandwidth value
                 */
                if (av[0][0] >= 'a' && av[0][0] <= 'z') {
                    int l = sizeof(p.if_name)-1;
                    /* interface name */
                    strncpy(p.if_name, av[0], l);
                    p.if_name[l] = '\0';
                    p.bandwidth = 0;
                } else {
                    p.if_name[0] = '\0';
                    p.bandwidth = (int)strtoul(av[0], &end, 0);
                    if (*end == 'K' || *end == 'k') {
                        end++;
                        p.bandwidth *= 1000;
                    } else if (*end == 'M') {
                        end++;
                        p.bandwidth *= 1000000;
                    }
                    if (*end == 'B' || !strncmp(end, "by", 2))
                        p.bandwidth *= 8;
                    if (p.bandwidth < 0)
                        errx(EX_DATAERR, "bandwidth too large");
                }
                ac--; av++;
                break;
                
            case TOK_DELAY:
                if (do_pipe != 1)
                    errx(EX_DATAERR, "delay only valid for pipes");
                NEED2("delay needs argument 0..%d\n", MAX_DELAY);
                p.delay = (int)strtoul(av[0], NULL, 0);
                ac--; av++;
                break;
                
            case TOK_WEIGHT:
                if (do_pipe == 1)
                    errx(EX_DATAERR,"weight only valid for queues");
                NEED1("weight needs argument 0..100\n");
                p.fs.weight = (int)strtoul(av[0], &end, 0);
                ac--; av++;
                break;
                
            case TOK_PIPE:
                if (do_pipe == 1)
                    errx(EX_DATAERR,"pipe only valid for queues");
                NEED1("pipe needs pipe_number\n");
                p.fs.parent_nr = strtoul(av[0], &end, 0);
                ac--; av++;
                break;
                
            default:
                errx(EX_DATAERR, "unrecognised option ``%s''", *(--av));
		}
	}
	if (do_pipe == 1) {
		if (p.pipe_nr == 0)
			errx(EX_DATAERR, "pipe_nr must be > 0");
		if (p.delay > MAX_DELAY)
			errx(EX_DATAERR, "delay must be < %d ms", MAX_DELAY);
	} else { /* do_pipe == 2, queue */
		if (p.fs.parent_nr == 0)
			errx(EX_DATAERR, "pipe must be > 0");
		if (p.fs.weight >100)
			errx(EX_DATAERR, "weight must be <= 100");
	}
	if (p.fs.flags_fs & DN_QSIZE_IS_BYTES) {
		if (p.fs.qsize > 1024*1024)
			errx(EX_DATAERR, "queue size must be < 1MB");
	} else {
		if (p.fs.qsize > 100)
			errx(EX_DATAERR, "2 <= queue size <= 100");
	}
	if (p.fs.flags_fs & DN_IS_RED) {
		size_t len;
		int lookup_depth, avg_pkt_size;
		double s, idle, weight, w_q;
		struct clockinfo ck;
		int t;
        
		if (p.fs.min_th >= p.fs.max_th)
		    errx(EX_DATAERR, "min_th %d must be < than max_th %d",
                 p.fs.min_th, p.fs.max_th);
		if (p.fs.max_th == 0)
		    errx(EX_DATAERR, "max_th must be > 0");
        
		len = sizeof(int);
		if (sysctlbyname("net.inet.ip.dummynet.red_lookup_depth",
                         &lookup_depth, &len, NULL, 0) == -1)
            
		    errx(1, "sysctlbyname(\"%s\")",
                 "net.inet.ip.dummynet.red_lookup_depth");
		if (lookup_depth == 0)
		    errx(EX_DATAERR, "net.inet.ip.dummynet.red_lookup_depth"
                 " must be greater than zero");
        
		len = sizeof(int);
		if (sysctlbyname("net.inet.ip.dummynet.red_avg_pkt_size",
                         &avg_pkt_size, &len, NULL, 0) == -1)
            
		    errx(1, "sysctlbyname(\"%s\")",
                 "net.inet.ip.dummynet.red_avg_pkt_size");
		if (avg_pkt_size == 0)
			errx(EX_DATAERR,
                 "net.inet.ip.dummynet.red_avg_pkt_size must"
                 " be greater than zero");
        
		len = sizeof(struct clockinfo);
		if (sysctlbyname("kern.clockrate", &ck, &len, NULL, 0) == -1)
			errx(1, "sysctlbyname(\"%s\")", "kern.clockrate");
        
		/*
		 * Ticks needed for sending a medium-sized packet.
		 * Unfortunately, when we are configuring a WF2Q+ queue, we
		 * do not have bandwidth information, because that is stored
		 * in the parent pipe, and also we have multiple queues
		 * competing for it. So we set s=0, which is not very
		 * correct. But on the other hand, why do we want RED with
		 * WF2Q+ ?
		 */
		if (p.bandwidth==0) /* this is a WF2Q+ queue */
			s = 0;
		else
			s = ck.hz * avg_pkt_size * 8 / p.bandwidth;
        
		/*
		 * max idle time (in ticks) before avg queue size becomes 0.
		 * NOTA:  (3/w_q) is approx the value x so that
		 * (1-w_q)^x < 10^-3.
		 */
		w_q = ((double)p.fs.w_q) / (1 << SCALE_RED);
		idle = s * 3. / w_q;
		p.fs.lookup_step = (int)idle / lookup_depth;
		if (!p.fs.lookup_step)
			p.fs.lookup_step = 1;
		weight = 1 - w_q;
		for (t = p.fs.lookup_step; t > 0; --t)
			weight *= weight;
		p.fs.lookup_weight = (int)(weight * (1 << SCALE_RED));
	}
    len = sizeof(struct dn_pipe);
	i = do_cmd(IP_DUMMYNET_CONFIGURE, &p, &len);
	if (i)
		err(1, "setsockopt(%s)", "IP_DUMMYNET_CONFIGURE");
}

static void
flush(int force)
{
	if (!force && !do_quiet) { /* need to ask user */
		int c;
        
		printf("Are you sure? [yn] ");
		fflush(stdout);
		do {
			c = toupper(getc(stdin));
			while (c != '\n' && getc(stdin) != '\n')
				if (feof(stdin))
					return; /* and do not flush */
		} while (c != 'Y' && c != 'N');
		printf("\n");
		if (c == 'N')	/* user said no */
			return;
	}
	
    if (do_cmd(IP_DUMMYNET_FLUSH, NULL, 0) < 0)
        err(EX_UNAVAILABLE, "setsockopt(IP_DUMMYNET_FLUSH)");
	
	if (!do_quiet)
		printf("Flushed all pipes.\n");
}

/*
 * Free a the (locally allocated) copy of command line arguments.
 */
static void
free_args(int ac, char **av)
{
	int i;
    
	for (i=0; i < ac; i++)
		free(av[i]);
	free(av);
}

/*
 * Called with the arguments (excluding program name).
 * Returns 0 if successful, 1 if empty command, errx() in case of errors.
 */
static int
parse_args(int oldac, char **oldav)
{
	int ch, ac, save_ac;
	char **av, **save_av;
	int do_acct = 0;		/* Show packet/byte count */
	int do_force = 0;		/* Don't ask for confirmation */
    
#define WHITESP		" \t\f\v\n\r"
	if (oldac == 0)
		return 1;
	else if (oldac == 1) {
		/*
		 * If we are called with a single string, try to split it into
		 * arguments for subsequent parsing.
		 * But first, remove spaces after a ',', by copying the string
		 * in-place.
		 */
		char *arg = oldav[0];	/* The string... */
		size_t l = strlen(arg);
		int copy = 0;		/* 1 if we need to copy, 0 otherwise */
		int i, j;
		for (i = j = 0; i < l; i++) {
			if (arg[i] == '#')	/* comment marker */
				break;
			if (copy) {
				arg[j++] = arg[i];
				copy = !index("," WHITESP, arg[i]);
			} else {
				copy = !index(WHITESP, arg[i]);
				if (copy)
					arg[j++] = arg[i];
			}
		}
		if (!copy && j > 0)	/* last char was a 'blank', remove it */
			j--;
		l = j;			/* the new argument length */
		arg[j++] = '\0';
		if (l == 0)		/* empty string! */
			return 1;
        
		/*
		 * First, count number of arguments. Because of the previous
		 * processing, this is just the number of blanks plus 1.
		 */
		for (i = 0, ac = 1; i < l; i++)
			if (index(WHITESP, arg[i]) != NULL)
				ac++;
        
		av = calloc(ac, sizeof(char *));
        
		/*
		 * Second, copy arguments from cmd[] to av[]. For each one,
		 * j is the initial character, i is the one past the end.
		 */
		for (ac = 0, i = j = 0; i < l; i++)
			if (index(WHITESP, arg[i]) != NULL || i == l-1) {
				if (i == l-1)
					i++;
				av[ac] = calloc(i-j+1, 1);
				bcopy(arg+j, av[ac], i-j);
				ac++;
				j = i + 1;
			}
	} else {
		/*
		 * If an argument ends with ',' join with the next one.
		 * Just add its length to 'l' and continue. When we have a string
		 * without a ',' ending, we'll have the combined length in 'l' 
		 */
		int first, i;
		size_t l;
        
		av = calloc(oldac, sizeof(char *));
		for (first = i = ac = 0, l = 0; i < oldac; i++) {
			char *arg = oldav[i];
			size_t k = strlen(arg);
			
			l += k;
			if (arg[k-1] != ',' || i == oldac-1) {
				size_t buflen = l+1;
				/* Time to copy. */
				av[ac] = calloc(l+1, 1);
				for (l=0; first <= i; first++) {
					strlcat(av[ac]+l, oldav[first], buflen-l);
					l += strlen(oldav[first]);
				}
				ac++;
				l = 0;
				first = i+1;
			}
		}
	}
    
	/* Set the force flag for non-interactive processes */
	do_force = !isatty(STDIN_FILENO);
    
	/* Save arguments for final freeing of memory. */
	save_ac = ac;
	save_av = av;
    
	optind = optreset = 0;
	while ((ch = getopt(ac, av, "afhnqsv")) != -1)
		switch (ch) {
            case 'a':
                do_acct = 1;
                break;
                
            case 'f':
                do_force = 1;
                break;
                
            case 'h': /* help */
                free_args(save_ac, save_av);
                help();
                break;	/* NOTREACHED */
                
            case 'n':
                test_only = 1;
                break;
                
            case 'q':
                do_quiet = 1;
                break;
                
            case 's': /* sort */
                do_sort = atoi(optarg);
                break;
                
            case 'v': /* verbose */
                verbose = 1;
                break;
                
            default:
                free_args(save_ac, save_av);
                return 1;
		}
    
	ac -= optind;
	av += optind;
	NEED1("bad arguments, for usage summary ``dnctl''");
    
	/*
	 * An undocumented behaviour of dnctl1 was to allow rule numbers first,
	 * e.g. "100 add allow ..." instead of "add 100 allow ...".
	 * In case, swap first and second argument to get the normal form.
	 */
	if (ac > 1 && isdigit(*av[0])) {
		char *p = av[0];
        
		av[0] = av[1];
		av[1] = p;
	}
    
	/*
	 * optional: pipe or queue
	 */
	do_pipe = 0;
	if (!strncmp(*av, "pipe", strlen(*av)))
		do_pipe = 1;
	else if (!strncmp(*av, "queue", strlen(*av)))
		do_pipe = 2;
	if (do_pipe) {
		ac--;
		av++;
	}
	NEED1("missing command");
    
	/*
	 * For pipes and queues we normally say 'pipe NN config'
	 * but the code is easier to parse as 'pipe config NN'
	 * so we swap the two arguments.
	 */
	if (do_pipe > 0 && ac > 1 && isdigit(*av[0])) {
		char *p = av[0];
        
		av[0] = av[1];
		av[1] = p;
	}
    
    if (do_pipe && !strncmp(*av, "config", strlen(*av)))
		config_pipe(ac, av);
	else if (!strncmp(*av, "delete", strlen(*av)))
		delete(ac, av);
	else if (!strncmp(*av, "flush", strlen(*av)))
		flush(do_force);
	else if (!strncmp(*av, "print", strlen(*av)) ||
	         !strncmp(*av, "list", strlen(*av)))
		list(ac, av, do_acct);
	else if (!strncmp(*av, "show", strlen(*av)))
		list(ac, av, 1 /* show counters */);
	else
		errx(EX_USAGE, "bad command `%s'", *av);
    
	/* Free memory allocated in the argument parsing. */
	free_args(save_ac, save_av);
	return 0;
}

static void
dnctl_readfile(int ac, char *av[])
{
#define MAX_ARGS	32
	char	buf[BUFSIZ];
	char	*cmd = NULL, *filename = av[ac-1];
	int	c, lineno=0;
	FILE	*f = NULL;
	pid_t	preproc = 0;
        
	while ((c = getopt(ac, av, "np:q")) != -1) {
		switch(c) {
            case 'n':
                test_only = 1;
                break;
                
            case 'p':
                cmd = optarg;
                /*
                 * Skip previous args and delete last one, so we
                 * pass all but the last argument to the preprocessor
                 * via av[optind-1]
                 */
                av += optind - 1;
                ac -= optind - 1;
                av[ac-1] = NULL;
                fprintf(stderr, "command is %s\n", av[0]);
                break;
                
            case 'q':
                do_quiet = 1;
                break;
                
            default:
                errx(EX_USAGE, "bad arguments, for usage"
                     " summary ``dnctl''");
		}
        
		if (cmd != NULL)
			break;
	}
    
	if (cmd == NULL && ac != optind + 1) {
		fprintf(stderr, "ac %d, optind %d\n", ac, optind);
		errx(EX_USAGE, "extraneous filename arguments");
	}
    
	if ((f = fopen(filename, "r")) == NULL)
		err(EX_UNAVAILABLE, "fopen: %s", filename);
    
	if (cmd != NULL) {			/* pipe through preprocessor */
		int pipedes[2];
        
		if (pipe(pipedes) == -1)
			err(EX_OSERR, "cannot create pipe");
        
		preproc = fork();
		if (preproc == -1)
			err(EX_OSERR, "cannot fork");
        
		if (preproc == 0) {
			/*
			 * Child, will run the preprocessor with the
			 * file on stdin and the pipe on stdout.
			 */
			if (dup2(fileno(f), 0) == -1
			    || dup2(pipedes[1], 1) == -1)
				err(EX_OSERR, "dup2()");
			fclose(f);
			close(pipedes[1]);
			close(pipedes[0]);
			execvp(cmd, av);
			err(EX_OSERR, "execvp(%s) failed", cmd);
		} else { /* parent, will reopen f as the pipe */
			fclose(f);
			close(pipedes[1]);
			if ((f = fdopen(pipedes[0], "r")) == NULL) {
				int savederrno = errno;
                
				(void)kill(preproc, SIGTERM);
				errno = savederrno;
				err(EX_OSERR, "fdopen()");
			}
		}
	}
    
	while (fgets(buf, BUFSIZ, f)) {		/* read commands */
		char linename[16];
		char *args[1];
        
		lineno++;
		snprintf(linename, sizeof(linename), "Line %d", lineno);
		setprogname(linename); /* XXX */
		args[0] = buf;
		parse_args(1, args);
	}
	fclose(f);
	if (cmd != NULL) {
		int status;
        
		if (waitpid(preproc, &status, 0) == -1)
			errx(EX_OSERR, "waitpid()");
		if (WIFEXITED(status) && WEXITSTATUS(status) != EX_OK)
			errx(EX_UNAVAILABLE,
                 "preprocessor exited with status %d",
                 WEXITSTATUS(status));
		else if (WIFSIGNALED(status))
			errx(EX_UNAVAILABLE,
                 "preprocessor exited with signal %d",
                 WTERMSIG(status));
	}
}

int
main(int ac, char *av[])
{
	/*
	 * If the last argument is an absolute pathname, interpret it
	 * as a file to be preprocessed.
	 */
    
	if (ac > 1 && av[ac - 1][0] == '/' && access(av[ac - 1], R_OK) == 0)
		dnctl_readfile(ac, av);
	else {
		if (parse_args(ac-1, av+1))
			show_usage();
	}
	return EX_OK;
}
