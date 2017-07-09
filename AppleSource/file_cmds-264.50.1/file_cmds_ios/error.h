//
//  error.h
//  shell_cmds_ios
//
//  Created by Nicolas Holzschuch on 16/06/2017.
//  Copyright © 2017 Nicolas Holzschuch. All rights reserved.
//

#ifndef error_h
#define error_h

#include <stdarg.h>
static void myerrx(int i, const char * fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    warnx(fmt, ap);
    va_end(ap);
}

static void myerr(int i, const char * fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    warn(fmt, ap);
    va_end(ap);
}

static void mywarnx(const char * fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    warnx(fmt, ap);
    va_end(ap);
}

static void mywarn(const char * fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    warn(fmt, ap);
    va_end(ap);
}

#define exit return
#define _exit return


#endif /* error_h */
