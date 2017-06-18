//
//  text_cmds_ios.h
//  text_cmds_ios
//
//  Created by Nicolas Holzschuch on 18/06/2017.
//  Copyright © 2017 Nicolas Holzschuch. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for text_cmds_ios.
FOUNDATION_EXPORT double text_cmds_iosVersionNumber;

//! Project version string for text_cmds_ios.
FOUNDATION_EXPORT const unsigned char text_cmds_iosVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <text_cmds_ios/PublicHeader.h>

// Most useful text commands
extern int cat_main(int argc, char *argv[]);
extern int grep_main(int argc, char *argv[]);    
extern int sort_main(int argc, char *argv[]);
extern int wc_main(int argc, char *argv[]);
extern int md5_main(int argc, char *argv[]); // ??? if it works



// Useless or meaningless in a sandboxed environment
// banner, col, colrm, column, comm, csplit, cut, ed, ee, expand, fmt, fold, head, join, lam, look, md5, nl, paste, pr, rev, rs, sed, split, tail, tr, ul, unexpand, uniq, unvis, vis
// md5: requires CommonCrypto
