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
 * iffake.c
 * - manage fake interfaces that pretend to be e.g. ethernet
 */

/*
 * Modification History:
 *
 * January 17, 2017	Dieter Siegmund (dieter@apple.com)
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
fake_status(int s)
{
	struct ifdrv			ifd;
	struct if_fake_request		iffr;

	bzero((char *)&ifd, sizeof(ifd));
	bzero((char *)&iffr, sizeof(iffr));
	strlcpy(ifd.ifd_name, ifr.ifr_name, sizeof(ifd.ifd_name));
	ifd.ifd_cmd = IF_FAKE_G_CMD_GET_PEER;
	ifd.ifd_len = sizeof(iffr);
	ifd.ifd_data = &iffr;
	if (ioctl(s, SIOCGDRVSPEC, &ifd) < 0) {
		return;
	}
	if (iffr.iffr_peer_name[0] == '\0') {
		printf("\tpeer: <none>\n");
	} else {
		printf("\tpeer: %s\n", iffr.iffr_peer_name);
	}
	return;
}

static void
set_peer(int s, const char * operation, const char * val)
{
	struct ifdrv			ifd;
	struct if_fake_request		iffr;

	bzero((char *)&ifd, sizeof(ifd));
	bzero((char *)&iffr, sizeof(iffr));
	strlcpy(ifd.ifd_name, ifr.ifr_name, sizeof(ifd.ifd_name));
	ifd.ifd_cmd = IF_FAKE_S_CMD_SET_PEER;
	ifd.ifd_len = sizeof(iffr);
	ifd.ifd_data = &iffr;
	if (val != NULL) {
		strlcpy(iffr.iffr_peer_name, val, sizeof(iffr.iffr_peer_name));
	}
	if (ioctl(s, SIOCSDRVSPEC, &ifd) < 0) {
		err(1, "SIOCDRVSPEC %s peer", operation);
	}
	return;
}

static
DECL_CMD_FUNC(setpeer, val, d)
{
	set_peer(s, "set", val);
	return;
}

static
DECL_CMD_FUNC(unsetpeer, val, d)
{
	set_peer(s, "unset", NULL);
	return;
}

static struct cmd fake_cmds[] = {
	DEF_CLONE_CMD_ARG("peer",		setpeer),
	DEF_CMD_OPTARG("-peer",			unsetpeer),
};
static struct afswtch af_fake = {
	.af_name	= "af_fake",
	.af_af		= AF_UNSPEC,
	.af_other_status = fake_status,
};

static __constructor void
fake_ctor(void)
{
#define	N(a)	(sizeof(a) / sizeof(a[0]))
	int i;
	
	for (i = 0; i < N(fake_cmds);  i++)
		cmd_register(&fake_cmds[i]);
	af_register(&af_fake);
#undef N
}

