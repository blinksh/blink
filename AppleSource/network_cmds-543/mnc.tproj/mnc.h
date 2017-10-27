/*
 * $Id: mnc.h,v 1.4 2004/09/22 14:07:10 colmmacc Exp $
 *
 * mnc.h -- Multicast NetCat
 *
 * Colm MacCarthaigh, <colm@apache.org>
 *
 * Copyright (c) 2007, Colm MacCarthaigh.
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

#ifndef _MNC_H_
#define _MNC_H_

#ifndef WINDOWS

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

#else

#include <winsock2.h>
#include <ws2tcpip.h>

#endif

/* The UDP port MNC will use by default */
#define MNC_DEFAULT_PORT    	"1234"

struct mnc_configuration
{
	/* Are we sending or recieving ? */
	enum {SENDER, LISTENER}	mode;

	/* What UDP port are we using ? */
	char	*		port;
	
	/* The group-id */
	struct addrinfo	*	group;

	/* The source */
	struct addrinfo *	source;
	
	/* An interface index for listening */
	char	*		iface;
};


/* Functions in mnc_opts.c */
void 				usage(void);
struct mnc_configuration * 	parse_arguments(int argc, char **argv);

/* Functions in mnc_multicast.c */
int multicast_setup_listen(int, struct addrinfo *, struct addrinfo *, char *);
int multicast_setup_send(int, struct addrinfo *, struct addrinfo *);

/* Functions in mnc_error.c */
void mnc_warning(char * string, ...);
void mnc_error(char * string, ...);

#endif /* _MNC_H_ */
