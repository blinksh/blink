#ifndef USERSPEC_H
# define USERSPEC_H 1

# include <sys/types.h>

const char *
parse_user_spec (const char *spec_arg, uid_t *uid, gid_t *gid,
                 char **username_arg, char **groupname_arg);

#endif
