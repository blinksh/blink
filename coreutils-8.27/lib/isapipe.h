/* Whether pipes are FIFOs; -1 if not known.  */
#ifndef HAVE_FIFO_PIPES
# define HAVE_FIFO_PIPES (-1)
#endif

int isapipe (int fd);
