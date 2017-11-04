//
//  constants.h
//  network_cmds_ios
//
//  Created by Nicolas Holzschuch on 28/10/2017.
//  Copyright © 2017 Nicolas Holzschuch. All rights reserved.
//

#ifndef constants_h
#define constants_h

// constants that are not defined in the iPhoneOS SDK:
#define SO_TRAFFIC_CLASS    0x1086    /* Traffic service class (int) */
#define     SO_TC_BK_SYS    100        /* lowest class */
#define     SO_TC_BK    200
#define  SO_TC_BE    0
#define     SO_TC_RD    300
#define     SO_TC_OAM    400
#define     SO_TC_AV    500
#define     SO_TC_RV    600
#define     SO_TC_VI    700
#define     SO_TC_VO    800
#define     SO_TC_CTL    900        /* highest class */
#define  SO_TC_MAX    10        /* Total # of traffic classes */
#define    SO_RECV_ANYIF    0x1104        /* unrestricted inbound processing */
#define SO_RECV_TRAFFIC_CLASS    0x1087        /* Receive traffic class (bool)*/
/*
 * Recommended DiffServ Code Point values
 */
#define    _DSCP_DF    0    /* RFC 2474 */

#define    _DSCP_CS0    0    /* RFC 2474 */
#define    _DSCP_CS1    8    /* RFC 2474 */
#define    _DSCP_CS2    16    /* RFC 2474 */
#define    _DSCP_CS3    24    /* RFC 2474 */
#define    _DSCP_CS4    32    /* RFC 2474 */
#define    _DSCP_CS5    40    /* RFC 2474 */
#define    _DSCP_CS6    48    /* RFC 2474 */
#define    _DSCP_CS7    56    /* RFC 2474 */

#define    _DSCP_EF    46    /* RFC 2474 */
#define    _DSCP_VA    44    /* RFC 5865 */

#define    _DSCP_AF11    10    /* RFC 2597 */
#define    _DSCP_AF12    12    /* RFC 2597 */
#define    _DSCP_AF13    14    /* RFC 2597 */
#define    _DSCP_AF21    18    /* RFC 2597 */
#define    _DSCP_AF22    20    /* RFC 2597 */
#define    _DSCP_AF23    22    /* RFC 2597 */
#define    _DSCP_AF31    26    /* RFC 2597 */
#define    _DSCP_AF32    28    /* RFC 2597 */
#define    _DSCP_AF33    30    /* RFC 2597 */
#define    _DSCP_AF41    34    /* RFC 2597 */
#define    _DSCP_AF42    36    /* RFC 2597 */
#define    _DSCP_AF43    38    /* RFC 2597 */

#define    _DSCP_52    52    /* Wi-Fi WMM Certification: Sigma */

#define    _MAX_DSCP    63    /* coded on 6 bits */

#define    IP_NO_IFT_CELLULAR    6969 /* for internal use only */
#define MAX_IPOPTLEN    40
// end addition for iPhone / blink

#endif /* constants_h */
