/*
 * Copyright (c) 2004 Apple Computer, Inc. All rights reserved.
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
 * ifbond.c
 * - add and remove interfaces from a bond interface
 */

/*
 * Modification History:
 *
 * July 14, 2004	Dieter Siegmund (dieter@apple.com)
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
#include <net/if_bond_var.h>

#include <net/route.h>

#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <err.h>
#include <errno.h>

#include "ifconfig.h"
extern int bond_details;

#define EA_FORMAT	"%02x:%02x:%02x:%02x:%02x:%02x"
#define EA_CH(e, i)	((u_char)((u_char *)(e))[(i)])
#define EA_LIST(ea)	EA_CH(ea,0),EA_CH(ea,1),EA_CH(ea,2),EA_CH(ea,3),EA_CH(ea,4),EA_CH(ea,5)

static __inline__ const char *
selected_state_string(u_char s)
{
	static const char * names[] = { "unselected", "selected", "standby" };

	if (s <= IF_BOND_STATUS_SELECTED_STATE_STANDBY) {
		return (names[s]);
	}
	return ("<unknown>");
}

static void
bond_print_details(struct if_bond_status * ibs_p, int count)

{
	int				i;
	struct if_bond_status * 	scan_p = ibs_p;

	for (i = 0; i < count; i++, scan_p++) {
		struct if_bond_partner_state *	ps;
		ps = &scan_p->ibs_partner_state;
		printf("\tbond interface: %s priority: 0x%04x "
		       "state: 0x%02x partner system: 0x%04x," 
		       EA_FORMAT " "
		       "key: 0x%04x port: 0x%04x priority: 0x%04x "
		       "state: 0x%02x\n",
		       scan_p->ibs_if_name, scan_p->ibs_port_priority,
		       scan_p->ibs_state, ps->ibps_system_priority,
		       EA_LIST(&ps->ibps_system), ps->ibps_key,
		       ps->ibps_port, ps->ibps_port_priority, 
		       ps->ibps_state);
	}
	return;
}

void
bond_status(int s)
{
	int				i;
	struct if_bond_req		ibr;
	struct if_bond_status *		ibs_p;
	struct if_bond_status_req *	ibsr_p;
	char				mode_buf[16];
	const char *			mode_str;

	bzero((char *)&ibr, sizeof(ibr));
	ibr.ibr_op = IF_BOND_OP_GET_STATUS;
	ibsr_p = &ibr.ibr_ibru.ibru_status;
	ibsr_p->ibsr_version = IF_BOND_STATUS_REQ_VERSION;
	ifr.ifr_data = (caddr_t)&ibr;
    
	/* how many of them are there? */
	if (ioctl(s, SIOCGIFBOND, (caddr_t)&ifr) < 0) {
		return;
	}
	switch (ibsr_p->ibsr_mode) {
	case IF_BOND_MODE_LACP:
		mode_str = "lacp";
		break;
	case IF_BOND_MODE_STATIC:
		mode_str = "static";
		break;
	default:
		snprintf(mode_buf, sizeof(mode_buf), "%d", ibsr_p->ibsr_mode);
		mode_str = mode_buf;
		break;
	}
	if (ibsr_p->ibsr_total == 0) {
		if (bond_details) {
			printf("\tbond mode: %s\n"
			       "\tbond key: 0x%04x interfaces: <none>",
			       mode_str, ibsr_p->ibsr_key);
		}
		else {
			printf("\tbond interfaces: <none>\n");
		}
		return;
	}
	ibsr_p->ibsr_buffer 
		= (char *)malloc(sizeof(struct if_bond_status) 
				 * ibsr_p->ibsr_total);
	ibsr_p->ibsr_count = ibsr_p->ibsr_total;

	/* get the list */
	if (ioctl(s, SIOCGIFBOND, (caddr_t)&ifr) < 0) {
		goto done;
	}
	if (ibsr_p->ibsr_total > 0) {
		if (bond_details) {
			printf("\tbond mode: %s\n"
			       "\tbond key: 0x%04x interfaces:", 
			       mode_str, ibsr_p->ibsr_key);
		}
		else {
			printf("\tbond interfaces:");
		}
		ibs_p = (struct if_bond_status *)ibsr_p->ibsr_buffer;
		for (i = 0; i < ibsr_p->ibsr_total; i++, ibs_p++) {
			printf(" %s", ibs_p->ibs_if_name);
			if (bond_details) {
				u_char s = ibs_p->ibs_selected_state;
				printf(" (%s)", selected_state_string(s));
			}
		}
		printf("\n");
		if (bond_details) {
			bond_print_details((struct if_bond_status *)
					   ibsr_p->ibsr_buffer,
					   ibsr_p->ibsr_total);
		}
	}
	else if (bond_details) {
		printf("\tbond mode: %s\n"
		       "\tbond key: 0x%04x interfaces: <none>\n",
		       mode_str, ibsr_p->ibsr_key);
	}
	else {
		printf("\tbond interfaces: <none>\n");
	}

 done:
	free(ibsr_p->ibsr_buffer);
	return;
}

static
DECL_CMD_FUNC(setbonddev, val, d)
{
	struct if_bond_req		ibr;

	bzero((char *)&ibr, sizeof(ibr));
	if ((unsigned int)snprintf(ibr.ibr_ibru.ibru_if_name, 
				   sizeof(ibr.ibr_ibru.ibru_if_name),
				   "%s", val) >= IFNAMSIZ) {
		errx(1, "interface name too long");
	}
	ibr.ibr_op = IF_BOND_OP_ADD_INTERFACE;
	ifr.ifr_data = (caddr_t)&ibr;
	if (ioctl(s, SIOCSIFBOND, (caddr_t)&ifr) == -1)
		err(1, "SIOCSIFBOND add interface");

	return;
}

static
DECL_CMD_FUNC(unsetbonddev, val, d)
{
	struct if_bond_req		ibr;

	bzero((char *)&ibr, sizeof(ibr));
	if ((unsigned int)snprintf(ibr.ibr_ibru.ibru_if_name, 
				   sizeof(ibr.ibr_ibru.ibru_if_name),
				   "%s", val) >= IFNAMSIZ) {
		errx(1, "interface name too long");
	}
	ibr.ibr_op = IF_BOND_OP_REMOVE_INTERFACE;
	ifr.ifr_data = (caddr_t)&ibr;
	if (ioctl(s, SIOCSIFBOND, (caddr_t)&ifr) == -1)
		err(1, "SIOCSIFBOND remove interface");

	return;
}

static
DECL_CMD_FUNC(setbondmode, val, d)
{
	struct if_bond_req		ibr;
	int				mode;

	if (strcmp(val, "lacp") == 0) {
		mode = IF_BOND_MODE_LACP;
	}
	else if (strcmp(val, "static") == 0) {
		mode = IF_BOND_MODE_STATIC;
	}
	else {
		mode = strtoul(val, NULL, 0);
		if (errno != 0) {
			errx(1, "invalid mode value "
			     "(must be either \"lacp\" or \"static\")");
		}
	}

	bzero((char *)&ibr, sizeof(ibr));
	if ((unsigned int)snprintf(ibr.ibr_ibru.ibru_if_name, 
				   sizeof(ibr.ibr_ibru.ibru_if_name),
				   "%s", val) >= IFNAMSIZ) {
		errx(1, "interface name too long");
	}
	ibr.ibr_op = IF_BOND_OP_SET_MODE;
	ibr.ibr_ibru.ibru_int_val = mode;
	ifr.ifr_data = (caddr_t)&ibr;
	if (ioctl(s, SIOCSIFBOND, (caddr_t)&ifr) == -1)
		err(1, "SIOCSIFBOND set mode");

	return;
}

static struct cmd bond_cmds[] = {
	DEF_CLONE_CMD_ARG("bonddev",		setbonddev),
	DEF_CLONE_CMD_ARG("-bonddev",		unsetbonddev),
	DEF_CMD_ARG("bondmode",				setbondmode),
};
static struct afswtch af_bond = {
	.af_name	= "af_bond",
	.af_af		= AF_UNSPEC,
	.af_other_status = bond_status,
};

static __constructor void
bond_ctor(void)
{
#define	N(a)	(sizeof(a) / sizeof(a[0]))
	int i;
	
	for (i = 0; i < N(bond_cmds);  i++)
		cmd_register(&bond_cmds[i]);
	af_register(&af_bond);
#undef N
}

