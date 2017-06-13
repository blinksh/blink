#ifndef DEV_INO_H
# define DEV_INO_H 1

# include <sys/types.h>
# include <sys/stat.h>

struct dev_ino
{
  ino_t st_ino;
  dev_t st_dev;
};

#endif
