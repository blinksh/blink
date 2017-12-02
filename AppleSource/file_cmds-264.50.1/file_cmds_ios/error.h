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
    vwarnx(fmt, ap);
    va_end(ap);
    pthread_exit(NULL);
}

static void myerr(int i, const char * fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vwarn(fmt, ap);
    va_end(ap);
    pthread_exit(NULL);
}


static void signal_catcher(int sig) {
    if ((sig == SIGINT) || (sig == SIGQUIT) || (sig == SIGKILL) || (sig == SIGABRT) || (sig == SIGSTOP) || (sig == SIGHUP)) {
        (void)signal(sig, SIG_DFL); // stop using this signal catcher
        pthread_exit(NULL);
    }
}

static void mywarn(const char * fmt, ...) {
    if (stderr == 0) return;
    va_list ap;
    va_start(ap, fmt);
    vwarn(fmt, ap);
    va_end(ap);
}

#define errx myerrx
#define err myerr
#define warn mywarn

#endif /* error_h */
