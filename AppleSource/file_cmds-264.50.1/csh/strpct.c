/*	$NetBSD: strpct.c,v 1.2 1998/05/08 18:43:54 fair Exp $	*/

/*-
 * Copyright (c) 1998 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Erik E. Fair
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *        This product includes software developed by the NetBSD
 *        Foundation, Inc. and its contributors.
 * 4. Neither the name of The NetBSD Foundation nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * Calculate a percentage without resorting to floating point
 * and return a pointer to a string
 *
 * "digits" is the number of digits past the decimal place you want
 * (zero being the straight percentage with no decimals)
 *
 * Erik E. Fair <fair@clock.org>, May 8, 1997
 */

#include <sys/types.h>
#include <machine/limits.h>

#include <stdio.h>

char * strpct __P((u_long, u_long, u_int));

char *
strpct(numerator, denominator, digits)
	u_long  numerator, denominator;
	u_int   digits;
{
        int i;
        u_long result, factor;
        static char     percent[32];

        /* I should check for digit overflow here, too XXX */
	factor = 100L;
        for(i = 0; i < digits; i++) {
                factor *= 10;
        }

        /* watch out for overflow! */
        if (numerator < (ULONG_MAX / factor)) {
                numerator *= factor;
        } else {
                /* toss some of the bits of lesser significance */
                denominator /= factor;
        }

        if (denominator == 0L)
                denominator = 1L;

        result = numerator / denominator;

        if (digits == 0) {
                (void) snprintf(percent, sizeof(percent), "%lu%%", result);
        } else {
                char    fmt[32];

                /* indirection to produce the right output format */
                (void) snprintf(fmt, sizeof(fmt), "%%lu.%%0%ulu%%%%", digits);

                factor /= 100L;         /* undo initialization */

                (void) snprintf(percent, sizeof(percent),
                        fmt, result / factor, result % factor);
        }       

        return(percent);
}
