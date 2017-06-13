//
//  coreutils.h
//  coreutils
//
//  Created by Nicolas Holzschuch on 11/06/2017.
//  Copyright © 2017 Nicolas Holzschuch. All rights reserved.
//

#ifndef coreutils_h
#define coreutils_h

extern int ls_main (int argc, char** argv);
extern int touch_main (int argc, char** argv);
extern int rm_main (int argc, char** argv);
extern int cp_main (int argc, char** argv);
extern int id_main (int argc, char** argv);
extern int groups_main (int argc, char **argv);
extern int ln_main (int argc, char **argv);
extern int realpath_main (int argc, char **argv);
extern int mv_main (int argc, char **argv);
extern int mkdir_main (int argc, char **argv);
extern int rmdir_main (int argc, char **argv);
extern int uname_main (int argc, char **argv);
extern int pwd_main (int argc, char **argv);
extern int env_main (int argc, char **argv);
extern int printenv_main (int argc, char **argv);
extern int whoami_main (int argc, char **argv);

#endif /* coreutils_h */
