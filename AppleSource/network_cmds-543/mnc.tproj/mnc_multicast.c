/*
 * $Id: mnc_multicast.c,v 1.8 2004/09/22 19:14:23 colmmacc Exp $
 *
 * mnc_multicast.c -- Multicast NetCat
 *
 * Colm MacCarthaigh, <colm@apache.org>
 *
 * copyright (c) 2007, Colm MacCarthaigh.
 * Copyright (c) 2004 - 2006, HEAnet Ltd. 
 *
 * This software is an open source.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * Neither the name of the HEAnet Ltd. nor the names of its contributors may
 * be used to endorse or promote products derived from this software without
 * specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 */

#ifndef WINDOWS

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <string.h>
#include <netdb.h>
#include <errno.h>

#else

#include <sys/types.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <stdlib.h>

#endif

#include "mnc.h"

#ifndef MCAST_JOIN_GROUP

#ifdef IP_ADD_SOURCE_MEMBERSHIP
int mnc_join_ipv4_ssm(int socket, struct addrinfo * group, 
                      struct addrinfo * source, char * iface)
{
	struct	ip_mreq_source	multicast_request;

	if (iface != NULL)
	{
		/* See if interface is a literal IPv4 address */
		if ((multicast_request.imr_interface.s_addr = 
		     inet_addr(iface)) == INADDR_NONE)
		{
			mnc_warning("Invalid interface address\n");
			return -1;
		}
	}
	else
	{
		/* set the interface to the default */
		multicast_request.imr_interface.s_addr = htonl(INADDR_ANY);
	}

	multicast_request.imr_multiaddr.s_addr = 
	                ((struct sockaddr_in *)group->ai_addr)->sin_addr.s_addr;

	multicast_request.imr_sourceaddr.s_addr = 
	               ((struct sockaddr_in *)source->ai_addr)->sin_addr.s_addr;
	
	/* Set the socket option */
	if (setsockopt(socket, IPPROTO_IP, IP_ADD_SOURCE_MEMBERSHIP,
	               (char *) &multicast_request, 
	               sizeof(multicast_request)) != 0)
	{
		mnc_warning("Could not join the multicast group: %s\n", 
		            strerror(errno));

		return -1;
	}
	
	return 0;
}
#else

int mnc_join_ipv4_ssm(int socket, struct addrinfo * group, 
                      struct addrinfo * source, char * iface)
{
	mnc_warning("Sorry, No support for IPv4 source-specific multicast in this build\n");
	
	return -1;
}
#endif

int mnc_join_ipv6_ssm(int socket, struct addrinfo * group, 
                      struct addrinfo * source, char * iface)
{
	mnc_warning("Sorry, No support for IPv6 source-specific multicast in this build\n");
	
	return -1;
}
#else /* if MCAST_JOIN_GROUP  .. */

#define mnc_join_ipv6_asm(a, b, c)      mnc_join_ip_asm((a), (b), (c))
#define mnc_join_ipv4_asm(a, b, c)      mnc_join_ip_asm((a), (b), (c))

int mnc_join_ip_asm(int socket, struct addrinfo * group, char * iface)
{
	struct	group_req	multicast_request;
	int			ip_proto;

	if (group->ai_family == AF_INET6)
	{
		ip_proto = IPPROTO_IPV6;
	}
	else
	{
		ip_proto = IPPROTO_IP;
	}
	
	if (iface != NULL)
	{
		if ((multicast_request.gr_interface = if_nametoindex(iface)) 
		    == 0)
		{
			mnc_warning("Ignoring unknown interface: %s\n", iface);
		}
	}
	else
	{
		multicast_request.gr_interface = 0;
	}		
			
	memcpy(&multicast_request.gr_group, group->ai_addr, group->ai_addrlen);

	/* Set the socket option */
	if (setsockopt(socket, ip_proto, MCAST_JOIN_GROUP, (char *)
	               &multicast_request, sizeof(multicast_request)) != 0)
	{
		mnc_warning("Could not join the multicast group: %s\n", 
		            strerror(errno));

		return -1;
	}
	
	return 0;
}

#endif /* MCAST_JOIN_GROUP */

#ifndef MCAST_JOIN_SOURCE_GROUP
int mnc_join_ipv4_asm(int socket, struct addrinfo * group, char * iface)
{
	struct	ip_mreq		multicast_request;
	
	if (iface != NULL)
	{
		/* See if interface is a literal IPv4 address */
		if ((multicast_request.imr_interface.s_addr = 
		     inet_addr(iface)) == INADDR_NONE)
		{
			mnc_warning("Invalid interface address\n");
			return -1;
		}
	}
	else
	{
		/* Set the interface to the default */
		multicast_request.imr_interface.s_addr = htonl(INADDR_ANY);
	}

	multicast_request.imr_multiaddr.s_addr = 
	                ((struct sockaddr_in *)group->ai_addr)->sin_addr.s_addr;

	/* Set the socket option */
	if (setsockopt(socket, IPPROTO_IP, IP_ADD_MEMBERSHIP, 
	               (char *) &multicast_request, 
	               sizeof(multicast_request)) != 0)
	{
		mnc_warning("Could not join the multicast group: %s\n", 
		            strerror(errno));

		return -1;
	}
	
	return 0;
}

int mnc_join_ipv6_asm(int socket, struct addrinfo * group, char * iface)
{
	mnc_warning("Sorry, No support for IPv6 any-source multicast in this build\n");
	
	return -1;
}
#else /* if MCAST_JOIN_SOURCE_GROUP ... */

#define mnc_join_ipv4_ssm(a, b, c, d)   mnc_join_ip_ssm((a), (b), (c), (d))
#define mnc_join_ipv6_ssm(a, b, c, d)   mnc_join_ip_ssm((a), (b), (c), (d))

int mnc_join_ip_ssm(int socket, struct addrinfo * group, 
                      struct addrinfo * source,
                      char * iface)
{
	struct	group_source_req	multicast_request;
	int				ip_proto;

	if (group->ai_family == AF_INET6)
	{
		ip_proto = IPPROTO_IPV6;
	}
	else
	{
		ip_proto = IPPROTO_IP;
	}
	
	if (iface != NULL)
	{
		if ((multicast_request.gsr_interface = if_nametoindex(iface)) 
		    == 0)
		{
			mnc_warning("Ignoring unknown interface: %s\n", iface);
		}
	}
	else
	{
		multicast_request.gsr_interface = 0;
	}		
	
	memcpy(&multicast_request.gsr_group, group->ai_addr, group->ai_addrlen);
	memcpy(&multicast_request.gsr_source, source->ai_addr, 
	       source->ai_addrlen);

	/* Set the socket option */
	if (setsockopt(socket, ip_proto, MCAST_JOIN_SOURCE_GROUP, 
	               (char *) &multicast_request, 
	               sizeof(multicast_request)) != 0)
	{
		mnc_warning("Could not join the multicast group: %s\n", 
		            strerror(errno));

		return -1;
	}
	
	return 0;
}
#endif /* MCAST_JOIN_SOURCE_GROUP */

int multicast_setup_listen(int socket, struct addrinfo * group, 
                            struct addrinfo * source, char * iface)
{
        size_t rcvbuf;

#ifndef WINDOWS
	/* bind to the group address before anything */
	if (bind(socket, group->ai_addr, group->ai_addrlen) != 0)
	{
		mnc_warning("Could not bind to group-id\n");
		return -1;
	}
#else 
        if (group->ai_family == AF_INET)
        {
                struct sockaddr_in sin;

                sin.sin_family = group->ai_family;
                sin.sin_port = group->ai_port;
                sin.sin_addr = INADDR_ANY;

                if (bind(socket, (struct sockaddr *) sin, 
                         sizeof(sin)) != 0)
                {
                        mnc_warning("Could not bind to ::\n");
                        return -1;
                }
        }
        else if (group->ai_family == AF_INET6)
        {
                struct sockaddr_in6 sin6;

                sin6.sin6_family = group->ai_family;
                sin6.sin6_port = group->ai_port;
                sin6.sin6_addr = in6addr_any;

                if (bind(socket, (struct sockaddr *) sin6, 
                         sizeof(sin6)) != 0)
                {
                        mnc_warning("Could not bind to ::\n");
                        return -1;
                }
        }
#endif

        /* Set a receive buffer size of 64k */
        rcvbuf = 1 << 15;
        if (setsockopt(socket, SOL_SOCKET, SO_RCVBUF, &rcvbuf, 
                       sizeof(rcvbuf)) < 0) {
                mnc_warning("Could not set receive buffer to 64k\n");
        }

	if (source != NULL)
	{
		if (group->ai_family == AF_INET6)
		{
			/* Use whatever IPv6 API is appropriate */
			return 
			    mnc_join_ipv6_ssm(socket, group, source, iface);
		}
		else if (group->ai_family == AF_INET)
		{
			/* Use the fully portable IPv4 API */
			return 
			    mnc_join_ipv4_ssm(socket, group, source, iface);
		}
		else
		{
			mnc_warning("Only IPv4 and IPv6 are supported\n");
			return -1;
		}
	}
	else
	{
		if (group->ai_family == AF_INET6)
		{
			/* Use the fully portable IPv4 API */
			return 
			    mnc_join_ipv6_asm(socket, group, iface);
		}
		else if (group->ai_family == AF_INET)
		{
			/* Use the fully portable IPv4 API */
			return
			    mnc_join_ipv4_asm(socket, group, iface);
		}
		else
		{
			mnc_warning("Only IPv4 and IPv6 are supported\n");
			return -1;
		}
	}

	/* We should never get here */
	return -1;
}
	

int multicast_setup_send(int socket, struct addrinfo * group, 
                            struct addrinfo * source)
{
	int	ttl	= 255;
	
	if (source != NULL)
	{
		/* bind to the address before anything */
		if (bind(socket, source->ai_addr, source->ai_addrlen) != 0)
		{
			mnc_warning("Could not bind to source-address\n");
			return -1;
		}
	}

	if (group->ai_family == AF_INET)
	{
		if (setsockopt(socket, IPPROTO_IP, IP_MULTICAST_TTL, (char *) 
		               &ttl, sizeof(ttl)) != 0)
		{
			mnc_warning("Could not increase the TTL\n");
			return -1;
		}
	}
	else if (group->ai_family == AF_INET6)
	{
		if (setsockopt(socket, IPPROTO_IPV6, IPV6_MULTICAST_HOPS, 
		               (char *) &ttl, sizeof(ttl)) != 0)
		{
			mnc_warning("Could not increase the hop-count\n");
			return -1;
		}
	}

	return 0;
}
