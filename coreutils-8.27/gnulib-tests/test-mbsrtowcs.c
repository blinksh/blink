/* Test of conversion of string to wide string.
   Copyright (C) 2008-2017 Free Software Foundation, Inc.

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

/* Written by Bruno Haible <bruno@clisp.org>, 2008.  */

#include <config.h>

#include <wchar.h>

#include "signature.h"
SIGNATURE_CHECK (mbsrtowcs, size_t, (wchar_t *, char const **, size_t,
                                     mbstate_t *));

#include <locale.h>
#include <stdio.h>
#include <string.h>

#include "macros.h"

int
main (int argc, char *argv[])
{
  mbstate_t state;
  wchar_t wc;
  size_t ret;

  /* configure should already have checked that the locale is supported.  */
  if (setlocale (LC_ALL, "") == NULL)
    return 1;

  /* Test NUL byte input.  */
  {
    const char *src;

    memset (&state, '\0', sizeof (mbstate_t));

    src = "";
    ret = mbsrtowcs (NULL, &src, 0, &state);
    ASSERT (ret == 0);
    ASSERT (mbsinit (&state));

    src = "";
    ret = mbsrtowcs (NULL, &src, 1, &state);
    ASSERT (ret == 0);
    ASSERT (mbsinit (&state));

    wc = (wchar_t) 0xBADFACE;
    src = "";
    ret = mbsrtowcs (&wc, &src, 0, &state);
    ASSERT (ret == 0);
    ASSERT (wc == (wchar_t) 0xBADFACE);
    ASSERT (mbsinit (&state));

    wc = (wchar_t) 0xBADFACE;
    src = "";
    ret = mbsrtowcs (&wc, &src, 1, &state);
    ASSERT (ret == 0);
    ASSERT (wc == 0);
    ASSERT (mbsinit (&state));
  }

  if (argc > 1)
    {
      int unlimited;

      for (unlimited = 0; unlimited < 2; unlimited++)
        {
          #define BUFSIZE 10
          wchar_t buf[BUFSIZE];
          const char *src;
          mbstate_t temp_state;

          {
            size_t i;
            for (i = 0; i < BUFSIZE; i++)
              buf[i] = (wchar_t) 0xBADFACE;
          }

          switch (argv[1][0])
            {
            case '1':
              /* Locale encoding is ISO-8859-1 or ISO-8859-15.  */
              {
                char input[] = "B\374\337er"; /* "Büßer" */
                memset (&state, '\0', sizeof (mbstate_t));

                wc = (wchar_t) 0xBADFACE;
                ret = mbrtowc (&wc, input, 1, &state);
                ASSERT (ret == 1);
                ASSERT (wc == 'B');
                ASSERT (mbsinit (&state));
                input[0] = '\0';

                wc = (wchar_t) 0xBADFACE;
                ret = mbrtowc (&wc, input + 1, 1, &state);
                ASSERT (ret == 1);
                ASSERT (wctob (wc) == (unsigned char) '\374');
                ASSERT (mbsinit (&state));
                input[1] = '\0';

                src = input + 2;
                temp_state = state;
                ret = mbsrtowcs (NULL, &src, unlimited ? BUFSIZE : 1, &temp_state);
                ASSERT (ret == 3);
                ASSERT (src == input + 2);
                ASSERT (mbsinit (&state));

                src = input + 2;
                ret = mbsrtowcs (buf, &src, unlimited ? BUFSIZE : 1, &state);
                ASSERT (ret == (unlimited ? 3 : 1));
                ASSERT (src == (unlimited ? NULL : input + 3));
                ASSERT (wctob (buf[0]) == (unsigned char) '\337');
                if (unlimited)
                  {
                    ASSERT (buf[1] == 'e');
                    ASSERT (buf[2] == 'r');
                    ASSERT (buf[3] == 0);
                    ASSERT (buf[4] == (wchar_t) 0xBADFACE);
                  }
                else
                  ASSERT (buf[1] == (wchar_t) 0xBADFACE);
                ASSERT (mbsinit (&state));
              }
              break;

            case '2':
              /* Locale encoding is UTF-8.  */
              {
                char input[] = "B\303\274\303\237er"; /* "Büßer" */
                memset (&state, '\0', sizeof (mbstate_t));

                wc = (wchar_t) 0xBADFACE;
                ret = mbrtowc (&wc, input, 1, &state);
                ASSERT (ret == 1);
                ASSERT (wc == 'B');
                ASSERT (mbsinit (&state));
                input[0] = '\0';

                wc = (wchar_t) 0xBADFACE;
                ret = mbrtowc (&wc, input + 1, 1, &state);
                ASSERT (ret == (size_t)(-2));
                ASSERT (wc == (wchar_t) 0xBADFACE);
                ASSERT (!mbsinit (&state));
                input[1] = '\0';

                src = input + 2;
                temp_state = state;
                ret = mbsrtowcs (NULL, &src, unlimited ? BUFSIZE : 2, &temp_state);
                ASSERT (ret == 4);
                ASSERT (src == input + 2);
                ASSERT (!mbsinit (&state));

                src = input + 2;
                ret = mbsrtowcs (buf, &src, unlimited ? BUFSIZE : 2, &state);
                ASSERT (ret == (unlimited ? 4 : 2));
                ASSERT (src == (unlimited ? NULL : input + 5));
                ASSERT (wctob (buf[0]) == EOF);
                ASSERT (wctob (buf[1]) == EOF);
                if (unlimited)
                  {
                    ASSERT (buf[2] == 'e');
                    ASSERT (buf[3] == 'r');
                    ASSERT (buf[4] == 0);
                    ASSERT (buf[5] == (wchar_t) 0xBADFACE);
                  }
                else
                  ASSERT (buf[2] == (wchar_t) 0xBADFACE);
                ASSERT (mbsinit (&state));
              }
              break;

            case '3':
              /* Locale encoding is EUC-JP.  */
              {
                char input[] = "<\306\374\313\334\270\354>"; /* "<日本語>" */
                memset (&state, '\0', sizeof (mbstate_t));

                wc = (wchar_t) 0xBADFACE;
                ret = mbrtowc (&wc, input, 1, &state);
                ASSERT (ret == 1);
                ASSERT (wc == '<');
                ASSERT (mbsinit (&state));
                input[0] = '\0';

                wc = (wchar_t) 0xBADFACE;
                ret = mbrtowc (&wc, input + 1, 2, &state);
                ASSERT (ret == 2);
                ASSERT (wctob (wc) == EOF);
                ASSERT (mbsinit (&state));
                input[1] = '\0';
                input[2] = '\0';

                wc = (wchar_t) 0xBADFACE;
                ret = mbrtowc (&wc, input + 3, 1, &state);
                ASSERT (ret == (size_t)(-2));
                ASSERT (wc == (wchar_t) 0xBADFACE);
                ASSERT (!mbsinit (&state));
                input[3] = '\0';

                src = input + 4;
                temp_state = state;
                ret = mbsrtowcs (NULL, &src, unlimited ? BUFSIZE : 2, &temp_state);
                ASSERT (ret == 3);
                ASSERT (src == input + 4);
                ASSERT (!mbsinit (&state));

                src = input + 4;
                ret = mbsrtowcs (buf, &src, unlimited ? BUFSIZE : 2, &state);
                ASSERT (ret == (unlimited ? 3 : 2));
                ASSERT (src == (unlimited ? NULL : input + 7));
                ASSERT (wctob (buf[0]) == EOF);
                ASSERT (wctob (buf[1]) == EOF);
                if (unlimited)
                  {
                    ASSERT (buf[2] == '>');
                    ASSERT (buf[3] == 0);
                    ASSERT (buf[4] == (wchar_t) 0xBADFACE);
                  }
                else
                  ASSERT (buf[2] == (wchar_t) 0xBADFACE);
                ASSERT (mbsinit (&state));
              }
              break;

            case '4':
              /* Locale encoding is GB18030.  */
              {
                char input[] = "B\250\271\201\060\211\070er"; /* "Büßer" */
                memset (&state, '\0', sizeof (mbstate_t));

                wc = (wchar_t) 0xBADFACE;
                ret = mbrtowc (&wc, input, 1, &state);
                ASSERT (ret == 1);
                ASSERT (wc == 'B');
                ASSERT (mbsinit (&state));
                input[0] = '\0';

                wc = (wchar_t) 0xBADFACE;
                ret = mbrtowc (&wc, input + 1, 1, &state);
                ASSERT (ret == (size_t)(-2));
                ASSERT (wc == (wchar_t) 0xBADFACE);
                ASSERT (!mbsinit (&state));
                input[1] = '\0';

                src = input + 2;
                temp_state = state;
                ret = mbsrtowcs (NULL, &src, unlimited ? BUFSIZE : 2, &temp_state);
                ASSERT (ret == 4);
                ASSERT (src == input + 2);
                ASSERT (!mbsinit (&state));

                src = input + 2;
                ret = mbsrtowcs (buf, &src, unlimited ? BUFSIZE : 2, &state);
                ASSERT (ret == (unlimited ? 4 : 2));
                ASSERT (src == (unlimited ? NULL : input + 7));
                ASSERT (wctob (buf[0]) == EOF);
                ASSERT (wctob (buf[1]) == EOF);
                if (unlimited)
                  {
                    ASSERT (buf[2] == 'e');
                    ASSERT (buf[3] == 'r');
                    ASSERT (buf[4] == 0);
                    ASSERT (buf[5] == (wchar_t) 0xBADFACE);
                  }
                else
                  ASSERT (buf[2] == (wchar_t) 0xBADFACE);
                ASSERT (mbsinit (&state));
              }
              break;

            default:
              return 1;
            }
        }

      return 0;
    }

  return 1;
}
