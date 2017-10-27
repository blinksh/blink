/*
 * $Id: mnc_opts.c,v 1.3 2004/09/22 16:02:26 colmmacc Exp $
 *
 * mnc_opts.c -- Multicast NetCat
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

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#ifndef WINDOWS

/* UNIX-y includes */
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#else

/* WINDOWS-y includes */
#include <winsock2.h>
#include <ws2tcpip.h>
#endif

#include "mnc.h"

/* Display a usage statement */
void usage(void)
{
	fprintf(stderr, 
		"Usage: mnc [-l] [-i interface] [-p port] group-id "
		"[source-address]\n\n"
		"-l :    listen mode\n"
		"-i :    specify interface to listen\n"
		"-p :    specify port to listen/send on\n\n");
	exit(1);
}

struct mnc_configuration * parse_arguments(int argc, char **argv)
{
	/* Utility variables */
	int					optind,
						errorcode;
	struct	addrinfo			hints;

	/* Our persisting configuration */
	static	struct mnc_configuration	config;

	/* Set some defaults */
	config.mode	= SENDER;
	config.port 	= MNC_DEFAULT_PORT;
	config.iface	= NULL;
	config.source	= NULL;

	/* Loop through the arguments */
	for (optind = 1; optind < (argc - 1); optind++)
	{
		if ( (argv[optind][0] == '-') || (argv[optind][0] == '/') )
		{
			switch(argv[optind][1])
			{
				/* Set listening mode */
				case 'l':	config.mode = LISTENER;
						break;

				/* Set port */
				case 'p':	config.port = argv[++optind];
						break;

				/* Set an interface */
				case 'i':	config.iface = argv[++optind];
						break;

				/* Unrecognised option */
				default:	usage();
						break;
			}
		}
		else
		{
			/* assume we've ran out of options */
			break;
		}
	}

	/* There's a chance we were passed one option */
	if (optind >= argc || argv[optind][0] == '-')
	{
		usage();
	}

	/* Now make sure we have either exactly 1 or 2 more arguments */
	if ( (argc - optind) != 1 && (argc - optind) != 2 )
	{
		/* We have not been given the right ammount of 
		   arguments */
		usage();
	}

	/* You can't have an interface without also listening */
	if (config.mode == SENDER && config.iface != NULL)
	{
		mnc_error("You may only specify the interface when in"
				" listening mode\n");
	}

	/* Set some hints for getaddrinfo */
	memset(&hints, 0, sizeof(hints));
	
	/* We want a UDP socket */
	hints.ai_socktype = SOCK_DGRAM;

	/* Don't do any name-lookups */
	hints.ai_flags = AI_NUMERICHOST;
	
	/* Get the group-id information */
	if ( (errorcode =
	      getaddrinfo(argv[optind], config.port, &hints, &config.group)) != 0)
	{
		mnc_error("Error getting group-id address information: %s\n", 
			  gai_strerror(errorcode));
	}

	/* Move on to next argument */
	optind++;
	
	/* Get the source information */
	if ( (argc - optind) == 1)
	{

		if ( (errorcode = 
        	      getaddrinfo(argv[optind], config.port, &hints, &config.source)) 
		    != 0)
		{
			mnc_error("Error getting source-address information: %s\n", 
			          gai_strerror(errorcode));	
		}
	
		/* Confirm that the source and group are in the same Address Family */
		if ( config.source->ai_family != config.group->ai_family )
		{
			mnc_error("Group ID and Source address are not of "
				  "the same type\n");
		}
	}

	return &config;
}
