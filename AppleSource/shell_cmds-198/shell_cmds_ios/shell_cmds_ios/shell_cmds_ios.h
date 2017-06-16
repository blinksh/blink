//
//  shell_cmds_ios.h
//  shell_cmds_ios
//
//  Created by Nicolas Holzschuch on 16/06/2017.
//  Copyright © 2017 Nicolas Holzschuch. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for shell_cmds_ios.
FOUNDATION_EXPORT double shell_cmds_iosVersionNumber;

//! Project version string for shell_cmds_ios.
FOUNDATION_EXPORT const unsigned char shell_cmds_iosVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <shell_cmds_ios/PublicHeader.h>


// Most useful shell commands
extern int date_main(int argc, char *argv[]);
extern int env_main(int argc, char *argv[]);     // does the same as printenv
extern int hostname_main(int argc, char *argv[]);
extern int id_main(int argc, char *argv[]); // also groups, whoami
extern int printenv_main(int argc, char *argv[]);
extern int pwd_main(int argc, char *argv[]);
extern int uname_main(int argc, char *argv[]);
extern int w_main(int argc, char *argv[]); // also uptime

// Useless or meaningless in a sandboxed environment
// alias, apply, basename, chroot, dirname, echo, expr, false, getopt, hexdump, jot, kill, killall, lastcomm, locate, logname, mktemp, nice, nohup, path_helper, printf, renice, script, seq, sh, shlock, sleep, su, systime, tee, test, time, true, users, what, whereis, who, which, xargs, yes
// find: not re-entrant
