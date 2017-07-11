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
#include <pthread.h>

static void myerrx(int i, const char * fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    warnx(fmt, ap);
    va_end(ap);
    pthread_exit(NULL);
}

static void myerr(int i, const char * fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    warn(fmt, ap);
    va_end(ap);
    pthread_exit(NULL);
}

#define errx myerrx
#define err myerr


#endif /* error_h */
