/* Convert string to wide string.
   Copyright (C) 2008-2017 Free Software Foundation, Inc.
   Written by Bruno Haible <bruno@clisp.org>, 2008.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

size_t
mbsrtowcs (wchar_t *dest, const char **srcp, size_t len, mbstate_t *ps)
{
  if (ps == NULL)
    ps = &_gl_mbsrtowcs_state;
  {
    const char *src = *srcp;

    if (dest != NULL)
      {
        wchar_t *destptr = dest;

        for (; len > 0; destptr++, len--)
          {
            size_t src_avail;
            size_t ret;

            /* An optimized variant of
               src_avail = strnlen1 (src, MB_LEN_MAX);  */
            if (src[0] == '\0')
              src_avail = 1;
            else if (src[1] == '\0')
              src_avail = 2;
            else if (src[2] == '\0')
              src_avail = 3;
            else if (MB_LEN_MAX <= 4 || src[3] == '\0')
              src_avail = 4;
            else
              src_avail = 4 + strnlen1 (src + 4, MB_LEN_MAX - 4);

            /* Parse the next multibyte character.  */
            ret = mbrtowc (destptr, src, src_avail, ps);

            if (ret == (size_t)(-2))
              /* Encountered a multibyte character that extends past a '\0' byte
                 or that is longer than MB_LEN_MAX bytes.  Cannot happen.  */
              abort ();

            if (ret == (size_t)(-1))
              goto bad_input;
            if (ret == 0)
              {
                src = NULL;
                /* Here mbsinit (ps).  */
                break;
              }
            src += ret;
          }

        *srcp = src;
        return destptr - dest;
      }
    else
      {
        /* Ignore dest and len, don't store *srcp at the end, and
           don't clobber *ps.  */
        mbstate_t state = *ps;
        size_t totalcount = 0;

        for (;; totalcount++)
          {
            size_t src_avail;
            size_t ret;

            /* An optimized variant of
               src_avail = strnlen1 (src, MB_LEN_MAX);  */
            if (src[0] == '\0')
              src_avail = 1;
            else if (src[1] == '\0')
              src_avail = 2;
            else if (src[2] == '\0')
              src_avail = 3;
            else if (MB_LEN_MAX <= 4 || src[3] == '\0')
              src_avail = 4;
            else
              src_avail = 4 + strnlen1 (src + 4, MB_LEN_MAX - 4);

            /* Parse the next multibyte character.  */
            ret = mbrtowc (NULL, src, src_avail, &state);

            if (ret == (size_t)(-2))
              /* Encountered a multibyte character that extends past a '\0' byte
                 or that is longer than MB_LEN_MAX bytes.  Cannot happen.  */
              abort ();

            if (ret == (size_t)(-1))
              goto bad_input2;
            if (ret == 0)
              {
                /* Here mbsinit (&state).  */
                break;
              }
            src += ret;
          }

        return totalcount;
      }

   bad_input:
    *srcp = src;
   bad_input2:
    errno = EILSEQ;
    return (size_t)(-1);
  }
}
