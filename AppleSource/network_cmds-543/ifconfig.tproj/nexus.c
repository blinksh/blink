/*
 * Copyright (c) 2017 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * The contents of this file constitute Original Code as defined in and
 * are subject to the Apple Public Source License Version 1.1 (the
 * "License").  You may not use this file except in compliance with the
 * License.  Please obtain a copy of the License at
 * http://www.apple.com/publicsource and read it before using this file.
 * 
 * This Original Code and all software distributed under the License are
 * distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE OR NON-INFRINGEMENT.  Please see the
 * License for the specific language governing rights and limitations
 * under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

/*
 * nexus.c
 * - report information about attached nexus
 */

/*
 * Modification History:
 *
 * April 10, 2017	Dieter Siegmund (dieter@apple.com)
 * - created
 */

#include <sys/param.h>
#include <sys/ioctl.h>
#include <sys/socket.h>

#include <stdlib.h>
#include <unistd.h>

#include <net/ethernet.h>
#include <net/if.h>
#include <net/if_var.h>
#include <net/if_fake_var.h>

#include <net/route.h>

#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <err.h>
#include <errno.h>

#include "ifconfig.h"

static void
nexus_status(int s)
{
	struct if_nexusreq	ifnr;
	uuid_string_t		multistack;
	uuid_string_t		netif;

	if (!verbose) {
		return;
	}
	bzero((char *)&ifnr, sizeof(ifnr));
	strlcpy(ifnr.ifnr_name, ifr.ifr_name, sizeof(ifnr.ifnr_name));
	if (ioctl(s, SIOCGIFNEXUS, &ifnr) < 0) {
		return;
	}
	if (uuid_is_null(ifnr.ifnr_netif)) {
		/* technically, this shouldn't happen */
		return;
	}
	uuid_unparse_upper(ifnr.ifnr_netif, netif);
	printf("\tnetif: %s\n", netif);
	if (uuid_is_null(ifnr.ifnr_multistack) == 0) {
		uuid_unparse_upper(ifnr.ifnr_multistack, multistack);
		printf("\tmultistack: %s\n", multistack);
	}
	return;
}

static struct afswtch af_fake = {
	.af_name	= "af_fake",
	.af_af		= AF_UNSPEC,
	.af_other_status = nexus_status,
};

static __constructor void
fake_ctor(void)
{
	af_register(&af_fake);
}

