/*	$NetBSD: mknod.c,v 1.15 1998/09/11 07:22:13 mycroft Exp $	*/

/*-
 * Copyright (c) 1998 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Charles M. Hannum.
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

#include <sys/cdefs.h>
#ifndef lint
__COPYRIGHT("@(#) Copyright (c) 1998 The NetBSD Foundation, Inc.  All rights reserved.\n");
__RCSID("$NetBSD: mknod.c,v 1.15 1998/09/11 07:22:13 mycroft Exp $");
#endif /* not lint */

#include <sys/types.h>
#include <sys/stat.h>

#include <err.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

int main __P((int, char *[]));
static void usage __P((void));
typedef	dev_t pack_t __P((int, u_long []));


pack_t pack_native;

dev_t
pack_native(n, numbers)
	int n;
	u_long numbers[];
{
	dev_t dev=0; /* Quiet -Wall */

	if (n == 2) {
		dev = makedev(numbers[0], numbers[1]);
		if (major(dev) != numbers[0])
			errx(1, "invalid major number");
		if (minor(dev) != numbers[1])
			errx(1, "invalid minor number");
	} else
		errx(1, "too many fields for format");
	return (dev);
}


#define	major_netbsd(x)		((int32_t)((((x) & 0x000fff00) >>  8)))
#define	minor_netbsd(x)		((int32_t)((((x) & 0xfff00000) >> 12) | \
					   (((x) & 0x000000ff) >>  0)))
#define	makedev_netbsd(x,y)	((dev_t)((((x) <<  8) & 0x000fff00) | \
					 (((y) << 12) & 0xfff00000) | \
					 (((y) <<  0) & 0x000000ff)))

pack_t pack_netbsd;

dev_t
pack_netbsd(n, numbers)
	int n;
	u_long numbers[];
{
	dev_t dev=0; /* Quiet -Wall */

	if (n == 2) {
		dev = makedev_netbsd(numbers[0], numbers[1]);
		if (major_netbsd(dev) != numbers[0])
			errx(1, "invalid major number");
		if (minor_netbsd(dev) != numbers[1])
			errx(1, "invalid minor number");
	} else
		errx(1, "too many fields for format");
	return (dev);
}


#define	major_freebsd(x)	((int32_t)(((x) & 0x0000ff00) >> 8))
#define	minor_freebsd(x)	((int32_t)(((x) & 0xffff00ff) >> 0))
#define	makedev_freebsd(x,y)	((dev_t)((((x) << 8) & 0x0000ff00) | \
					 (((y) << 0) & 0xffff00ff)))

pack_t pack_freebsd;

dev_t
pack_freebsd(n, numbers)
	int n;
	u_long numbers[];
{
	dev_t dev=0; /* Quiet -Wall */

	if (n == 2) {
		dev = makedev_freebsd(numbers[0], numbers[1]);
		if (major_freebsd(dev) != numbers[0])
			errx(1, "invalid major number");
		if (minor_freebsd(dev) != numbers[1])
			errx(1, "invalid minor number");
	} else
		errx(1, "too many fields for format");
	return (dev);
}


#define	major_8_8(x)		((int32_t)(((x) & 0x0000ff00) >> 8))
#define	minor_8_8(x)		((int32_t)(((x) & 0x000000ff) >> 0))
#define	makedev_8_8(x,y)	((dev_t)((((x) << 8) & 0x0000ff00) | \
					 (((y) << 0) & 0x000000ff)))

pack_t pack_8_8;

dev_t
pack_8_8(n, numbers)
	int n;
	u_long numbers[];
{
	dev_t dev=0; /* Quiet -Wall */

	if (n == 2) {
		dev = makedev_8_8(numbers[0], numbers[1]);
		if (major_8_8(dev) != numbers[0])
			errx(1, "invalid major number");
		if (minor_8_8(dev) != numbers[1])
			errx(1, "invalid minor number");
	} else
		errx(1, "too many fields for format");
	return (dev);
}


#define	major_12_20(x)		((int32_t)(((x) & 0xfff00000) >> 20))
#define	minor_12_20(x)		((int32_t)(((x) & 0x000fffff) >>  0))
#define	makedev_12_20(x,y)	((dev_t)((((x) << 20) & 0xfff00000) | \
					 (((y) <<  0) & 0x000fffff)))

pack_t pack_12_20;

dev_t
pack_12_20(n, numbers)
	int n;
	u_long numbers[];
{
	dev_t dev=0; /* Quiet -Wall */

	if (n == 2) {
		dev = makedev_12_20(numbers[0], numbers[1]);
		if (major_12_20(dev) != numbers[0])
			errx(1, "invalid major number");
		if (minor_12_20(dev) != numbers[1])
			errx(1, "invalid minor number");
	} else
		errx(1, "too many fields for format");
	return (dev);
}


#define	major_14_18(x)		((int32_t)(((x) & 0xfffc0000) >> 18))
#define	minor_14_18(x)		((int32_t)(((x) & 0x0003ffff) >>  0))
#define	makedev_14_18(x,y)	((dev_t)((((x) << 18) & 0xfffc0000) | \
					 (((y) <<  0) & 0x0003ffff)))

pack_t pack_14_18;

dev_t
pack_14_18(n, numbers)
	int n;
	u_long numbers[];
{
	dev_t dev=0; /* Quiet -Wall */

	if (n == 2) {
		dev = makedev_14_18(numbers[0], numbers[1]);
		if (major_14_18(dev) != numbers[0])
			errx(1, "invalid major number");
		if (minor_14_18(dev) != numbers[1])
			errx(1, "invalid minor number");
	} else
		errx(1, "too many fields for format");
	return (dev);
}


#define	major_8_24(x)		((int32_t)(((x) & 0xff000000) >> 24))
#define	minor_8_24(x)		((int32_t)(((x) & 0x00ffffff) >>  0))
#define	makedev_8_24(x,y)	((dev_t)((((x) << 24) & 0xff000000) | \
					 (((y) <<  0) & 0x00ffffff)))

pack_t pack_8_24;

dev_t
pack_8_24(n, numbers)
	int n;
	u_long numbers[];
{
	dev_t dev=0; /* Quiet -Wall */

	if (n == 2) {
		dev = makedev_8_24(numbers[0], numbers[1]);
		if (major_8_24(dev) != numbers[0])
			errx(1, "invalid major number");
		if (minor_8_24(dev) != numbers[1])
			errx(1, "invalid minor number");
	} else
		errx(1, "too many fields for format");
	return (dev);
}


#define	major_12_12_8(x)	((int32_t)(((x) & 0xfff00000) >> 20))
#define	unit_12_12_8(x)		((int32_t)(((x) & 0x000fff00) >>  8))
#define	subunit_12_12_8(x)	((int32_t)(((x) & 0x000000ff) >>  0))
#define	makedev_12_12_8(x,y,z)	((dev_t)((((x) << 20) & 0xfff00000) | \
					 (((y) <<  8) & 0x000fff00) | \
					 (((z) <<  0) & 0x000000ff)))

pack_t pack_bsdos;

dev_t
pack_bsdos(n, numbers)
	int n;
	u_long numbers[];
{
	dev_t dev=0; /* Quiet -Wall */

	if (n == 2) {
		dev = makedev_12_20(numbers[0], numbers[1]);
		if (major_12_20(dev) != numbers[0])
			errx(1, "invalid major number");
		if (minor_12_20(dev) != numbers[1])
			errx(1, "invalid minor number");
	} else if (n == 3) {
		dev = makedev_12_12_8(numbers[0], numbers[1], numbers[2]);
		if (major_12_12_8(dev) != numbers[0])
			errx(1, "invalid major number");
		if (unit_12_12_8(dev) != numbers[1])
			errx(1, "invalid unit number");
		if (subunit_12_12_8(dev) != numbers[2])
			errx(1, "invalid subunit number");
	} else
		errx(1, "too many fields for format");
	return (dev);
}


struct format {
	char	*name;
	pack_t	*pack;
} formats[] = {
	{"386bsd",  pack_8_8},
	{"4bsd",    pack_8_8},
	{"bsdos",   pack_bsdos},
	{"freebsd", pack_freebsd},
	{"hpux",    pack_8_24},
	{"isc",     pack_8_8},
	{"linux",   pack_8_8},
	{"native",  pack_native},
	{"netbsd",  pack_netbsd},
	{"osf1",    pack_12_20},
	{"sco",     pack_8_8},
	{"solaris", pack_14_18},
	{"sunos",   pack_8_8},
	{"svr3",    pack_8_8},
	{"svr4",    pack_14_18},
	{"ultrix",  pack_8_8},
};

int compare_format __P((const void *, const void *));

int
compare_format(key, element)
	const void *key;
	const void *element;
{
	const char *name;
	const struct format *format;

	name = key;
	format = element;

	return (strcmp(name, format->name));
}


int
main(argc, argv)
	int argc;
	char **argv;
{
	char *name;
	mode_t mode;
	dev_t dev;
	pack_t *pack;
	u_long numbers[8];
	struct format *format;
	char *p;
	int n;
	int ch;

	pack = pack_native;

	while ((ch = getopt(argc, argv, "F:")) != -1) {
		switch (ch) {
		case 'F':
			format = bsearch(optarg, formats,
			    sizeof(formats)/sizeof(formats[0]),
			    sizeof(formats[0]), compare_format);
			if (format == 0)
				errx(1, "invalid format: %s", optarg);
			pack = format->pack;
			break;

		default:
		case '?':
			usage();
		}
	}
	argc -= optind;
	argv += optind;

	if (argc < 2 || argc > 10)
		usage();

	name = *argv;
	argc--;
	argv++;

	mode = S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH|S_IWOTH;
	if (*argv[0] == 'c')
		mode |= S_IFCHR;
	else if (*argv[0] == 'b')
		mode |= S_IFBLK;
	else if (*argv[0] == 'w')
		mode |= S_IFWHT;
	else
		errx(1, "node type must be 'b' or 'c' or 'w'.");
	argc--;
	argv++;

	for (n = 0; n < argc; n++) {
		if (S_ISWHT(mode)) {
			errx(1, "whiteout nodes have no device numbers.");
		}
		numbers[n] = strtoul(argv[n], &p, 0);
		if ((p && *p != '\0') || (numbers[n] == ULONG_MAX && errno == ERANGE))
			errx(1, "invalid number: %s", argv[n]);
	}

	if (S_ISWHT(mode))
		dev = 0;
	else if (argc == 1)
		dev = (dev_t)numbers[0];
	else
		dev = (*pack)(argc, numbers);

#if 0
	printf("name: %s\nmode: %05o\ndev:  %08x\n", name, mode, dev);
#else
	if (mknod(name, mode, dev) < 0)
		err(1, "%s", name);
#endif

	exit(0);
}

void
usage()
{

	fprintf(stderr, "usage: mknod [-F format] name [b | c] major minor\n");
	fprintf(stderr, "       mknod [-F format] name [b | c] major unit subunit\n");
	fprintf(stderr, "       mknod name [b | c] number\n");
	fprintf(stderr, "       mknod name w\n");
	exit(1);
}
