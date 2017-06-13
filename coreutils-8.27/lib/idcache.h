#ifndef IDCACHE_H
# define IDCACHE_H 1

# include <sys/types.h>

extern char *getuser (uid_t uid);
extern char *getgroup (gid_t gid);
extern uid_t *getuidbyname (const char *user);
extern gid_t *getgidbyname (const char *group);

#endif
