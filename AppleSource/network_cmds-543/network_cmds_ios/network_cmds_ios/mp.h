//
//  mp.h
//  network_cmds_ios
//
//  Created by Nicolas Holzschuch on 28/10/2017.
//  Copyright © 2017 Nicolas Holzschuch. All rights reserved.
//

#ifndef mp_h
#define mp_h

#define MINT struct mint
MINT
{   int len;
    short *val;
};
#define FREE(x) {if(x.len!=0) {free((char *)x.val); x.len=0;}}
#ifndef DBG
#define shfree(u) free((char *)u)
#else
#include "stdio.h"
#define shfree(u) { if(dbg) fprintf(stderr, "free %o\n", u); free((char *)u);}
extern int dbg;
#endif
struct half
{   short high;
   short low;
};
extern MINT *itom();
extern short *xalloc();

#ifdef lint
extern xv_oid;
#define VOID xv_oid =
#else
#define VOID
#endif

#endif /* mp_h */
