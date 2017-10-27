/*
 * $Id: mnc_main.c,v 1.12 2004/09/22 19:14:23 colmmacc Exp $
 *
 * mnc_main.c -- Multicast NetCat
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

#ifndef WINDOWS

/* Non-windows includes */

#include <sys/types.h>
#include <sys/socket.h>
#include <unistd.h>
#include <stdio.h>

#else 

/* Windows-specific includes */

#include <winsock2.h>
#include <ws2tcpip.h>
#include <stdlib.h>
#include <stdio.h>

#endif /* WINDOWS */

#include "mnc.h"

int main(int argc, char **argv)
{
	/* Utility variables */
	int				sock,
					len;
	char				buffer[1024];

	/* Our main configuration */
	struct mnc_configuration *	config;

#ifdef WINDOWS
	WSADATA 			wsaData;
 
	if (WSAStartup(MAKEWORD(2,2), &wsaData) != 0)
	{
		mnc_error("This operating system is not supported\n");
	}
#endif
	
	/* Parse the command line */
	config = parse_arguments(argc, argv);
	
	/* Create a socket */
	if ((sock = socket(config->group->ai_family, config->group->ai_socktype, 
 	    config->group->ai_protocol)) < 0)
	{
		mnc_error("Could not create socket\n");
	}

	/* Are we supposed to listen? */
	if (config->mode == LISTENER)
	{
		/* Set up the socket for listening */
		if (multicast_setup_listen(sock, config->group, config->source, 
		                 config->iface) < 0)
		{
			mnc_error("Can not listen for multicast packets.\n");
		}

		/* Recieve the packets */
		while ((len = recvfrom(sock, buffer, sizeof(buffer), 
		                       0, NULL, NULL)) >= 0)
		{	
			write(STDOUT_FILENO, buffer, len);
		}
	}
	else /* Assume MODE == SENDER */
	{
		/* Set up the socket for sending */
		if (multicast_setup_send(sock, config->group, config->source) 
		    < 0)
		{
			mnc_error("Can not send multicast packets\n");
		}
		
		/* Send the packets */
		while((len = read(STDIN_FILENO, buffer, sizeof(buffer))) > 0)
		{
			sendto(sock, buffer, len, 0, config->group->ai_addr, 
			       config->group->ai_addrlen);
		}
	}
	
	/* Close the socket */
	close(sock);

	return 0;
}
