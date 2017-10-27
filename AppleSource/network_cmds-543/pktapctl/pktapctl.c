/*
 * Copyright (c) 2012 Apple Inc. All rights reserved.
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

#include <sys/types.h>
#include <sys/socket.h>
#include <sys/sockio.h>
#include <sys/ioctl.h>
#include <net/pktap.h>
#include <stdio.h>
#include <unistd.h>
#include <err.h>
#include <stdlib.h>
#include <string.h>

const char *ifname = NULL;
unsigned int ifindex = 0;
int do_get = 0;
int num_filter_entries = 0;
struct pktap_filter set_filter[PKTAP_MAX_FILTERS];

static const char *parameters_format = "     %-24s %s\n";

static void
usage(const char *s)
{
    printf("# usage: %s -i <ifname> -g -p <filter_rule> -s <filter_rule> -h\n", s);
    printf(" Get or set filtering rules on a pktap interface\n");
    printf(" Options:\n");
    printf(parameters_format, "-h", "display this help");
    printf(parameters_format, "-i <ifname>", "name pktap interface");
    printf(parameters_format, "-g", "get filter rules");
    printf(parameters_format, "-p <filter_rule> param", "add a pass rule");
    printf(parameters_format, "-s <filter_rule> param", "add a skip rule");
    printf(" Format of <filter_rule> parameter:\n");
    printf(parameters_format, "type <iftype>", "interfaces of given type");
    printf(parameters_format, "", "use 0 for any interface type");
    printf(parameters_format, "name <ifname>", "interface of given name");
}

static void
print_filter_entry(struct pktap_filter *filter)
{
    printf("filter_op: %u filter_param %u ", filter->filter_op, filter->filter_param);
    if (filter->filter_param == PKTAP_FILTER_PARAM_IF_TYPE)
        printf("%u", filter->filter_param_if_type);
    else if (filter->filter_param == PKTAP_FILTER_PARAM_IF_NAME)
        printf("%s", filter->filter_param_if_name);
}

int main(int argc, char * const argv[])
{
    int ch;
    struct ifdrv ifdr;
    int fd = -1;
    int i;
    
    //printf("sizeof(struct pktap_filter) %lu\n", sizeof(struct pktap_filter));
    //printf("sizeof(pktap_filter) %lu\n", sizeof(set_filter));
    
    while ((ch = getopt(argc, argv, "ghi:p:s:")) != -1) {
        switch (ch) {
            case 'g':
                do_get++;
                break;
            
            case 'h':
                usage(argv[0]);
                exit(0);
                /* NOT REACHED */
                
            case 'i':
                ifname = optarg;
                
                ifindex = if_nametoindex(ifname);
                if (ifindex == 0)
                    err(1, "if_nametoindex(%s) failed", ifname);
                
                break;

            case 'p':
            case 's': {
                /* -p (type|name) <value> */
                struct pktap_filter entry;
                                
                if (num_filter_entries >= PKTAP_MAX_FILTERS)
                    errx(1, "Too many filter entries, max is %u", PKTAP_MAX_FILTERS);
                if (optind + 1 > argc)
                    errx(1, "-%c needs two arguments optind %d argc %d", ch, optind, argc);
                if (ch == 'p')
                    entry.filter_op = PKTAP_FILTER_OP_PASS;
                else
                    entry.filter_op = PKTAP_FILTER_OP_SKIP;
                if (strcmp(optarg, "type") == 0) {
                    entry.filter_param = PKTAP_FILTER_PARAM_IF_TYPE;
                    entry.filter_param_if_type = (uint32_t)strtoul(argv[optind], NULL, 0);
                } else if (strcmp(optarg, "name") == 0) {
                    entry.filter_param = PKTAP_FILTER_PARAM_IF_NAME;
                    snprintf(entry.filter_param_if_name, sizeof(entry.filter_param_if_name), "%s", argv[optind]);
                } else
                    errx(1, "syntax error -p %s", optarg);
                printf("Addin entry: ");
                print_filter_entry(&entry);
                printf("\n");
                set_filter[num_filter_entries] = entry;
                
                num_filter_entries++;
                optind++;
                break;
            }
                
            case '?':
            default:
                err(1, "syntax error");
                exit(0);
                /* NOT REACHED */
        }
    }
    if (ifname == NULL)
        errx(1, "missing interface");

    fd = socket(PF_INET, SOCK_DGRAM, 0);
    if (fd == -1)
        err(1, "socket(PF_INET, SOCK_DGRAM, 0)");
    
    if (num_filter_entries > 0) {
        for (i = num_filter_entries; i < PKTAP_MAX_FILTERS; i++) {
            struct pktap_filter *filter = set_filter + i;
            filter->filter_op = PKTAP_FILTER_OP_NONE;
            filter->filter_param = PKTAP_FILTER_PARAM_NONE;
        }
        
        snprintf(ifdr.ifd_name, sizeof(ifdr.ifd_name), "%s", ifname);
        ifdr.ifd_cmd = PKTP_CMD_FILTER_SET;
        ifdr.ifd_len = sizeof(set_filter);
        ifdr.ifd_data = &set_filter[0];
        
        if (ioctl(fd, SIOCSDRVSPEC, &ifdr) == -1)
            err(1, "ioctl(SIOCSDRVSPEC)");
        
    }
    
    if (do_get) {
        struct pktap_filter get_filter[PKTAP_MAX_FILTERS];

        snprintf(ifdr.ifd_name, sizeof(ifdr.ifd_name), "%s", ifname);
        ifdr.ifd_cmd = PKTP_CMD_FILTER_GET;
        ifdr.ifd_len = sizeof(get_filter);
        ifdr.ifd_data = &get_filter[0];

        if (ioctl(fd, SIOCGDRVSPEC, &ifdr) == -1)
            err(1, "ioctl(SIOCGDRVSPEC)");
        
        for (i = 0; i < PKTAP_MAX_FILTERS; i++) {
            struct pktap_filter *filter = get_filter + i;
            
            printf("[%d] ", i);
            print_filter_entry(filter);
            printf("\n");
        }
    }
    
    return 0;
}

