//
//  file_cmds_ios.h
//  file_cmds_ios
//
//  Created by Nicolas Holzschuch on 14/06/2017.
//  Copyright © 2017 Nicolas Holzschuch. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for file_cmds_ios.
FOUNDATION_EXPORT double file_cmds_iosVersionNumber;

//! Project version string for file_cmds_ios.
FOUNDATION_EXPORT const unsigned char file_cmds_iosVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <file_cmds_ios/PublicHeader.h>

// Most useful file utilities
extern int ls_main(int argc, char *argv[]);
extern int touch_main(int argc, char *argv[]);
extern int rm_main(int argc, char *argv[]);
extern int cp_main(int argc, char *argv[]);
extern int ln_main(int argc, char *argv[]);
extern int mv_main(int argc, char *argv[]);
extern int mkdir_main(int argc, char *argv[]);
extern int rmdir_main(int argc, char *argv[]);

// Might be useful
extern int du_main(int argc, char *argv[]);
extern int chksum_main(int argc, char *argv[]);

// Most likely useless in a sandboxed environment, but provided nevertheless
extern int chmod_main(int argc, char *argv[]);
extern int chflags_main(int argc, char *argv[]);
extern int chown_main(int argc, char *argv[]);
extern int stat_main(int argc, char *argv[]);

// ??? Really useless in a sandboxed environment ???
// ipcrm, ipcs, mkfifo, mknod, pathchk,
// rmt (remote magtape protocol)
// But feasible on request (please provide scenario and explanations)
