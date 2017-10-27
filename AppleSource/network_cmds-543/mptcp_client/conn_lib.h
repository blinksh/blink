/*
 * Copyright (c) 2012-2014 Apple Inc. All rights reserved.
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
//  Created by Anumita Biswas on 10/30/12.
//

#ifndef mptcp_client_conn_lib_h
#define mptcp_client_conn_lib_h

typedef struct conninfo {
	__uint32_t			ci_flags;			/* see flags in sys/socket.h (CIF_CONNECTING, etc...) */
	__uint32_t			ci_ifindex;			/* outbound interface */
	struct sockaddr		*ci_src;			/* source address */
	struct sockaddr		*ci_dst;			/* destination address */
	int					ci_error;			/* saved error */
	__uint32_t			ci_aux_type;		/* auxiliary data type */
	void				*ci_aux_data;		/* auxiliary data */
} conninfo_t;

extern int copyassocids(int, sae_associd_t **, uint32_t *);
extern void freeassocids(sae_associd_t *);
extern int copyconnids(int, sae_associd_t, sae_connid_t **, uint32_t *);
extern void freeconnids(sae_connid_t *);
extern int copyconninfo(int, sae_connid_t, conninfo_t **);
extern void freeconninfo(conninfo_t *);

#endif
