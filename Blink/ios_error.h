//
//  error.h
//  shell_cmds_ios
//
//  Created by Nicolas Holzschuch on 16/06/2017.
//  Copyright © 2017 Nicolas Holzschuch. All rights reserved.
//

#ifndef ios_error_h
#define ios_error_h

#ifdef __cplusplus
extern "C" {
#endif
  
#include <stdarg.h>
#include <stdio.h>
#include <pthread.h>
  
  /* #define errx compileError
   #define err compileError
   #define warn compileError
   #define warnx compileError
   #ifndef printf
   #define printf(...) fprintf (thread_stdout, ##__VA_ARGS__)
   #endif */
  
#define putchar(a) fputc(a, thread_stdout)
#define getchar() fgetc(thread_stdin)
#define getwchar() fgetwc(thread_stdin)
  // iswprint depends on the given locale, and setlocale() fails on iOS:
#define iswprint(a) 1
#define write ios_write
#define fwrite ios_fwrite
#define puts ios_puts
#define fputs ios_fputs
#define fputc ios_fputc
#define putw ios_putw
#define fflush ios_fflush
  
  
  // Thread-local input and output streams
  extern __thread FILE* thread_stdin;
  extern __thread FILE* thread_stdout;
  extern __thread FILE* thread_stderr;
  
#define exit ios_exit
#define abort() ios_exit(1)
#define _exit ios_exit
#define popen ios_popen
#define pclose fclose
#define system ios_system
#define execv ios_execv
#define execvp ios_execv
#define execve ios_execve
#define dup2 ios_dup2
  
  extern int ios_executable(const char* cmd); // is this command part of the "shell" commands?
  extern int ios_system(const char* inputCmd); // execute this command (executable file or builtin command)
  extern FILE *ios_popen(const char *command, const char *type); // Execute this command and pipe the result
  extern int ios_kill(void); // kill the current running command
  
  extern void ios_exit(int errorCode) __dead2; // set error code and exits from the thread.
  extern int ios_execv(const char *path, char* const argv[]);
  extern int ios_execve(const char *path, char* const argv[], char** envlist);
  extern int ios_dup2(int fd1, int fd2);
  extern int ios_isatty(int fd);
//  extern pthread_t ios_getLastThreadId(void);
  extern int ios_getCommandStatus(void);
  extern const char* ios_progname(void);
  
  extern ssize_t ios_write(int fildes, const void *buf, size_t nbyte);
  extern size_t ios_fwrite(const void *ptr, size_t size, size_t nitems, FILE *stream);
  extern int ios_puts(const char *s);
  extern int ios_fputs(const char* s, FILE *stream);
  extern    int ios_fputc(int c, FILE *stream);
  extern int ios_putw(int w, FILE *stream);
  extern int ios_fflush(FILE *stream);
  
#ifdef __cplusplus
}
#endif
#endif /* ios_error_h */
