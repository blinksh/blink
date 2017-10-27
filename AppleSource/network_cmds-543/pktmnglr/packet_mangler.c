/*
 * Copyright (c) 2014 Apple Inc. All rights reserved.
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

//
//  Created by Prabhakar Lakhera on 06/23/14.
//

#include <stdio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <sys/errno.h>
#include <sys/sys_domain.h>
#include <sys/ioctl.h>
#include <sys/kern_control.h>
#include <sys/queue.h>
#include <netinet/in.h>
#include <stdio.h>
#include <err.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <ctype.h>
#include <sysexits.h>
#include <net/packet_mangler.h>


#define BUF_MAX 1000
int doit();

Pkt_Mnglr_Flow dir = INOUT;
struct addrinfo * p_localaddr = NULL;
struct addrinfo * p_remoteaddr = NULL;
struct sockaddr_storage l_saddr = {0};
struct sockaddr_storage r_saddr = {0};

int sf = -1;
uint32_t duration  = 0;
uint32_t protocol = 0;
uint32_t proto_act_mask = 0;
uint32_t ip_act_mask = 0;
uint16_t local_port = 0;
uint16_t remote_port = 0;
uint8_t activate = 1;

static const char *
basename(const char * str)
{
    const char *last_slash = strrchr(str, '/');
    
    if (last_slash == NULL)
        return (str);
    else
        return (last_slash + 1);
}

struct option_desc {
    const char *option;
    const char *description;
    int required;
};

struct option_desc option_desc_list[] = {
    { "-h ", "Help", 0 },
    { "-f flow", "flow direction to apply mangler on. Values can be: in/out/inout. default is inout", 0 },
    { "-l IP address ", "Local IP we are interested in ", 0 },
    { "-r IP address ", "Remote IP we are interested in", 0 },
    { "-m IP action mask ", "IP action mask", 0 },
    { "-t time", "Run duration for which packet mangler will run. A value of 0 means forever (till program is killed).", 0 },
    { "-p IP Protocol ", "IP protocol i.e. one of tcp, udp, icmp, icmpv6", 0 },
    { "-L Local port ", "Local port", 0 },
    { "-R Remote port ", "Remote port", 0 },
    { "-M Protocol action mask ", "Protocol action mask", 0 },
    { NULL, NULL, 0 }  /* Mark end of list */
};


static void
usage(const char *cmd)
{
    struct option_desc *option_desc;
    char * usage_str = (char *)malloc(BUF_MAX);
    size_t usage_len;
    
    if (usage_str == NULL)
        err(1, "%s: malloc(%d)", __func__, BUF_MAX);
    
    usage_len = snprintf(usage_str, BUF_MAX, "# usage: %s ", basename(cmd));
    
    for (option_desc = option_desc_list; option_desc->option != NULL; option_desc++) {
        int len;
        
        if (option_desc->required)
            len = snprintf(usage_str + usage_len, BUF_MAX - usage_len, "%s ", option_desc->option);
        else
            len = snprintf(usage_str + usage_len, BUF_MAX - usage_len, "[%s] ", option_desc->option);
        if (len < 0)
            err(1, "%s: snprintf(", __func__);
        
        usage_len += len;
        if (usage_len > BUF_MAX)
            break;
    }
    printf("%s\n", usage_str);
    printf("options:\n");
    
    for (option_desc = option_desc_list; option_desc->option != NULL; option_desc++) {
        printf(" %-20s # %s\n", option_desc->option, option_desc->description);
    }
    
}

int
main(int argc, char * const argv[]) {
    int ch;
    int error;
    
    if (argc == 1) {
        usage(argv[0]);
        exit(0);
    }
    
    while ((ch = getopt(argc, argv, "hf:l:r:t:p:m:M:L:R:")) != -1) {
        switch (ch) {
            case 'h':
                usage(argv[0]);
                exit(0);
                break;
            case 'f': {
                if (strcasecmp(optarg, "in") == 0) {
                    dir = IN;
                } else if (strcasecmp(optarg, "out") == 0) {
                    dir = OUT;
                } else if (strcasecmp(optarg, "inout") == 0) {
                    dir = INOUT;
                } else {
                    usage(argv[0]);
                    errx(1, "syntax error");
                }
            }
                break;
            case 'l':
                if ((error = getaddrinfo(optarg, NULL, NULL, &p_localaddr)))
                    errx(1, "getaddrinfo returned error: %s", gai_strerror(error));
                
                break;
            case 'r':
                if ((error = getaddrinfo(optarg, NULL, NULL, &p_remoteaddr)))
                    errx(1, "getaddrinfo returned error: %s", gai_strerror(error));
                
                break;
            case 'm':
                ip_act_mask = (uint32_t)atoi(optarg);
                break;
            case 't':
                duration = (uint32_t)atoi(optarg);
                break;
            case 'p':
                /* Only support tcp for now */
                if (strcasecmp(optarg, "tcp") == 0) {
                    protocol = IPPROTO_TCP;
                } else if (strcasecmp(optarg, "udp") == 0) {
                    protocol = IPPROTO_UDP;
                    errx(1, "Protocol not supported.");
                } else if (strcasecmp(optarg, "icmp") == 0) {
                    protocol = IPPROTO_ICMP;
                    errx(1, "Protocol not supported.");
                } else if (strcasecmp(optarg, "icmpv6") == 0) {
                    protocol = IPPROTO_ICMPV6;
                    errx(1, "Protocol not supported.");
                } else {
                    errx(1, "Protocol not supported.");
                }
                break;
                
            case 'L':
                local_port = (uint16_t)atoi(optarg);
                break;
            case 'R':
                remote_port = (uint16_t)atoi(optarg);
                break;
            case 'M':
                proto_act_mask = (uint32_t)atoi(optarg);
                break;
                
            default:
                warnx("# syntax error, unknow option '%d'", ch);
                usage(argv[0]);
                exit(0);
        }
    }
    
    if (p_localaddr && p_remoteaddr) {
        if (p_localaddr->ai_family!=p_remoteaddr->ai_family) {
            errx(1, "The address families for local and remote address"
                 " when both present, must be equal");
        }
    }
    
    
    doit();
    
    return (0);
}


int
doit()
{
    struct sockaddr_ctl addr;
    
    sf = socket(PF_SYSTEM, SOCK_DGRAM, SYSPROTO_CONTROL);
    if (sf == -1) {
        err(1, "socket()");
    }
    
    /* Connect the socket */
    bzero(&addr, sizeof(addr));
    addr.sc_len = sizeof(addr);
    addr.sc_family = AF_SYSTEM;
    addr.ss_sysaddr = AF_SYS_CONTROL;
    
    {
        struct ctl_info info;
        memset(&info, 0, sizeof(info));
        strncpy(info.ctl_name, PACKET_MANGLER_CONTROL_NAME, sizeof(info.ctl_name));
        if (ioctl(sf, CTLIOCGINFO, &info)) {
            perror("Could not get ID for kernel control.\n");
            exit(-1);
        }
        addr.sc_id = info.ctl_id;
        addr.sc_unit = 1;
    }
    
    if (connect(sf, (struct sockaddr *)&addr, sizeof(struct sockaddr_ctl)) == -1) {
        err(1, "connect()");
    }
    
    if (setsockopt(sf, SYSPROTO_CONTROL, PKT_MNGLR_OPT_DIRECTION,
                   &dir, sizeof(uint32_t)) == -1) {
        err(1, "setsockopt could not set direction.");
    }
    
    /* Set the IP addresses for the flow */
    if (p_localaddr) {
        l_saddr = *((struct sockaddr_storage *)(p_localaddr->ai_addr));
        
        if (setsockopt(sf, SYSPROTO_CONTROL, PKT_MNGLR_OPT_LOCAL_IP,
                       &l_saddr, sizeof(struct sockaddr_storage)) == -1) {
            err(1, "setsockopt could not set local address.");
        }
        freeaddrinfo(p_localaddr);
        p_localaddr = NULL;
    }
    
    if (p_remoteaddr) {
        r_saddr = *((struct sockaddr_storage *)(p_remoteaddr->ai_addr));
        
        if (setsockopt(sf, SYSPROTO_CONTROL, PKT_MNGLR_OPT_REMOTE_IP,
                       &r_saddr, sizeof(struct sockaddr_storage)) == -1) {
            err(1, "setsockopt could not set remote address.");
        }
        freeaddrinfo(p_remoteaddr);
        p_remoteaddr = NULL;
    }
    
    /* Set ports for the flow */
    if (local_port && (setsockopt(sf, SYSPROTO_CONTROL, PKT_MNGLR_OPT_LOCAL_PORT,
                                  &local_port, sizeof(uint16_t)) == -1)) {
        err(1, "setsockopt could not set local port.");
        
    }
    
    if (remote_port && (setsockopt(sf, SYSPROTO_CONTROL, PKT_MNGLR_OPT_REMOTE_PORT,
                                   &remote_port, sizeof(uint16_t)) == -1)) {
        err(1, "setsockopt could not set remote port.");
        
    }
    
    if (protocol && setsockopt(sf, SYSPROTO_CONTROL, PKT_MNGLR_OPT_PROTOCOL,
                               &protocol, sizeof(uint32_t)) == -1) {
        err(1, "setsockopt could not set protocol.");
    }
    
    if (proto_act_mask &&
        (setsockopt(sf, SYSPROTO_CONTROL, PKT_MNGLR_OPT_PROTO_ACT_MASK,
                    &proto_act_mask, sizeof(uint32_t))==-1)) {
        err(1, "setsockopt could not set protocol action mask.");
    }
    
    if (setsockopt(sf, SYSPROTO_CONTROL, PKT_MNGLR_OPT_ACTIVATE,
                   &activate, sizeof(uint8_t))== -1) {
        err(1, "setsockopt could not activate packet mangler.");
    }
    
    if (!duration) {
        pause();
    } else {
        sleep(duration);
    }
    
    close(sf);
    return 0;
}
