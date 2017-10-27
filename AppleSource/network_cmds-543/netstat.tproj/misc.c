/*
 * Copyright (c) 2017 Apple Inc. All rights reserved.
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

#include <sys/sysctl.h>

#include <net/net_api_stats.h>
#include <err.h>
#include <stdio.h>

#include "netstat.h"

void
print_net_api_stats(uint32_t off __unused, char *name, int af __unused)
{
	static struct net_api_stats pnet_api_stats;
	struct net_api_stats net_api_stats;
	size_t len = sizeof(struct net_api_stats);
	const char *mibvar = "net.api_stats";

	if (sysctlbyname(mibvar, &net_api_stats, &len, 0, 0) < 0) {
		warn("sysctl: %s", mibvar);
		return;
	}

#define	STATDIFF(f) (net_api_stats.f - pnet_api_stats.f)
#define	p(f, m) if (STATDIFF(f) || sflag <= 1) \
	printf(m, STATDIFF(f), plural(STATDIFF(f)))
#define	p1a(f, m) if (STATDIFF(f) || sflag <= 1) \
	printf(m, STATDIFF(f))

	if (interval && vflag > 0)
		print_time();
	printf ("%s:\n", name);

	p(nas_iflt_attach_count, "\t%lld interface filter%s currently attached\n");
	p(nas_iflt_attach_total, "\t%lld interface filter%s attached since boot\n");
	p(nas_iflt_attach_os_total, "\t%lld interface filter%s attached since boot by OS\n");

	p(nas_ipf_add_count, "\t%lld IP filter%s currently attached\n");
	p(nas_ipf_add_total, "\t%lld IP filter%s attached since boot\n");
	p(nas_ipf_add_os_total, "\t%lld IP filter%s attached since boot by OS\n");

	p(nas_sfltr_register_count, "\t%lld socket filter%s currently attached\n");
	p(nas_sfltr_register_total, "\t%lld socket filter%s attached since boot\n");
	p(nas_sfltr_register_os_total, "\t%lld socket filter%s attached since boot by OS\n");

	p(nas_socket_alloc_total, "\t%lld socket%s allocated since boot\n");
	p(nas_socket_in_kernel_total, "\t%lld socket%s allocated in-kernel since boot\n");
	p(nas_socket_in_kernel_os_total, "\t%lld socket%s allocated in-kernel by OS\n");
	p(nas_socket_necp_clientuuid_total, "\t%lld socket%s with NECP client UUID since boot\n");

	p(nas_socket_domain_local_total, "\t%lld local domain socket%s allocated since boot\n");
	p(nas_socket_domain_route_total, "\t%lld route domain socket%s allocated since boot\n");
	p(nas_socket_domain_inet_total, "\t%lld inet domain socket%s allocated since boot\n");
	p(nas_socket_domain_inet6_total, "\t%lld inet6 domain socket%s allocated since boot\n");
	p(nas_socket_domain_system_total, "\t%lld system domain socket%s allocated since boot\n");
	p(nas_socket_domain_multipath_total, "\t%lld multipath domain socket%s allocated since boot\n");
	p(nas_socket_domain_key_total, "\t%lld key domain socket%s allocated since boot\n");
	p(nas_socket_domain_ndrv_total, "\t%lld ndrv domain socket%s allocated since boot\n");
	p(nas_socket_domain_other_total, "\t%lld other domains socket%s allocated since boot\n");

	p(nas_socket_inet_stream_total, "\t%lld IPv4 stream socket%s created since boot\n");
	p(nas_socket_inet_dgram_total, "\t%lld IPv4 datagram socket%s created since boot\n");
	p(nas_socket_inet_dgram_connected, "\t%lld IPv4 datagram socket%s connected\n");
	p(nas_socket_inet_dgram_dns, "\t%lld IPv4 DNS socket%s\n");
	p(nas_socket_inet_dgram_no_data, "\t%lld IPv4 datagram socket%s without data\n");

	p(nas_socket_inet6_stream_total, "\t%lld IPv6 stream socket%s created since boot\n");
	p(nas_socket_inet6_dgram_total, "\t%lld IPv6 datagram socket%s created since boot\n");
	p(nas_socket_inet6_dgram_connected, "\t%lld IPv6 datagram socket%s connected\n");
	p(nas_socket_inet6_dgram_dns, "\t%lld IPv6 DNS socket%s\n");
	p(nas_socket_inet6_dgram_no_data, "\t%lld IPv6 datagram socket%s without data\n");

	p(nas_socket_mcast_join_total, "\t%lld socket multicast join%s since boot\n");
	p(nas_socket_mcast_join_os_total, "\t%lld socket multicast join%s since boot by OS\n");

	p(nas_nx_flow_inet_stream_total, "\t%lld IPv4 stream nexus flow%s added since boot\n");
	p(nas_nx_flow_inet_dgram_total, "\t%lld IPv4 datagram nexus flow%s added since boot\n");

	p(nas_nx_flow_inet6_stream_total, "\t%lld IPv6 stream nexus flow%s added since boot\n");
	p(nas_nx_flow_inet6_dgram_total, "\t%lld IPv6 datagram nexus flow%s added since boot\n");

	p(nas_ifnet_alloc_count, "\t%lld interface%s currently allocated\n");
	p(nas_ifnet_alloc_total, "\t%lld interface%s allocated since boot\n");
	p(nas_ifnet_alloc_os_count, "\t%lld interface%s currently allocated by OS\n");
	p(nas_ifnet_alloc_os_total, "\t%lld extended interface%s allocated since boot by OS\n");

	p(nas_pf_addrule_total, "\t%lld PF addrule operation%s since boot\n");
	p(nas_pf_addrule_os, "\t%lld PF addrule operation%s since boot by OS\n");

	p(nas_vmnet_total, "\t%lld vmnet start%s since boot\n");

#undef STATDIFF
#undef p
#undef p1a
}

