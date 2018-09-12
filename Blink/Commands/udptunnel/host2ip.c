#include <sys/types.h>
#include <sys/socket.h>      /* struct sockaddr */
#include <stdlib.h>
#include <netdb.h>           /* gethostbyname() */
#include <netinet/in.h>      /* sockaddr_in */
#include <arpa/inet.h>       /* inet_addr() */
//#include <rpcsvc/ypclnt.h>   /* YP */
#include <ctype.h>           /* isspace() */

#include "host2ip.h"

static char rcsid[]  = "$Id: host2ip.c,v 1.1 1996/09/20 12:49:19 sho Exp $";
/*
* Return IP address given host name 'host'. Returns INADDR_ANY if not valid.
* NOTE: always include the correct function prototype,
*    extern int host2ip(char *host);
* is not correct and will cause memory problems.
*/
struct in_addr host2ip(char *host)
{
  struct in_addr in, tmp;
  struct hostent *hep;

  /* Strip leading white space. */
  if (host) {
    while (*host && isspace((int)*host)) host++;  
  }

  /* Check whether this is a dotted decimal. */
  if (!host) {
    in.s_addr = INADDR_ANY;
  }
  else if ((tmp.s_addr = inet_addr(host)) != -1) {
    in = tmp;
  }
  /* Attempt to resolve host name via DNS. */
  else if ((hep = gethostbyname(host))) {
    in = *(struct in_addr *)(hep->h_addr_list[0]);
  }
  /* As a last resort, try YP. */
//  else {
//    static char *domain = 0;  /* YP domain */
//    char *value;              /* key value */
//    int value_len;            /* length of returned value */
//
//    if (!domain) yp_get_default_domain(&domain);
//    if (yp_match(domain, "hosts.byname", host, strlen(host), &value, &value_len) == 0) {
//      in.s_addr = inet_addr(value);
//    } else {
//      /* Everything failed */
//      in.s_addr = INADDR_ANY;
//    }
//  }
  return in;
} /* host2ip */
