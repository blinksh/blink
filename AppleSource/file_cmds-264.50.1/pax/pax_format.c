/*-
 * Copyright (c) 1992 Keith Muller.
 * Copyright (c) 1992, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Keith Muller of the University of California, San Diego.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef lint
#if 0
static const char sccsid[] = "@(#)tar.c	8.2 (Berkeley) 4/18/94";
#else
static const char rcsid[] __attribute__((__unused__)) = "$OpenBSD: tar.c,v 1.34 2004/10/23 19:34:14 otto Exp $";
#endif
#endif /* not lint */

#include <sys/types.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include "pax.h"
#include "extern.h"
#include "tar.h"
#include <fnmatch.h>
#include <regex.h>
#include "pat_rep.h"
#include <errno.h>

/* 
 * This file implements the -x pax format support; it is incomplete.
 * Known missing features include:
 *	many -o options for "copy" mode are not implemented (only path=)
 *	many format specifiers for -o listopt are not implemented
 *	-o listopt option should work for all archive formats, not just -x pax
 * This file was originally derived from the file tar.c. You should
 * 'diff' it to that file to see how much of the -x pax format has been implemented.
 */

char pax_eh_datablk[4*1024];
int pax_read_or_list_mode = 0;
int want_a_m_time_headers = 0;
int want_linkdata = 0;

int pax_invalid_action = 0;
char *	pax_invalid_action_write_path = NULL;
char *	pax_invalid_action_write_cwd = NULL;

char
	*path_g,	*path_x,	*path_g_current,	*path_x_current,
	*uname_g,	*uname_x,	*uname_g_current,	*uname_x_current,
	*gname_g,	*gname_x,	*gname_g_current,	*gname_x_current,
	*comment_g,	*comment_x,	*comment_g_current,	*comment_x_current,
	*charset_g,	*charset_x,	*charset_g_current,	*charset_x_current,
	*atime_g,	*atime_x,	*atime_g_current,	*atime_x_current,
	*gid_g,		*gid_x,		*gid_g_current,		*gid_x_current,
	*linkpath_g,	*linkpath_x,	*linkpath_g_current,	*linkpath_x_current,
	*mtime_g,	*mtime_x,	*mtime_g_current,	*mtime_x_current,
	*size_g,	*size_x,	*size_g_current,	*size_x_current,
	*uid_g,		*uid_x,		*uid_g_current,		*uid_x_current;

char	*header_name_g_requested = NULL,
	*header_name_x_requested = NULL;

char	*header_name_g = "/tmp/GlobalHead.%p.%n",
	*header_name_x = "%d/PaxHeaders.%p/%f";

int	nglobal_headers = 0;
char	*pax_list_opt_format;

#define O_OPTION_ACTION_NOTIMPL		0
#define O_OPTION_ACTION_INVALID		1
#define O_OPTION_ACTION_DELETE		2
#define O_OPTION_ACTION_STORE_HEADER	3
#define O_OPTION_ACTION_TIMES		4
#define O_OPTION_ACTION_HEADER_NAME	5
#define O_OPTION_ACTION_LISTOPT		6
#define O_OPTION_ACTION_LINKDATA	7

#define O_OPTION_ACTION_IGNORE		8
#define O_OPTION_ACTION_ERROR		9
#define O_OPTION_ACTION_STORE_HEADER2	10

#define ATTRSRC_FROM_NOWHERE		0
#define ATTRSRC_FROM_X_O_OPTION		1
#define ATTRSRC_FROM_G_O_OPTION		2
#define ATTRSRC_FROM_X_HEADER		3
#define ATTRSRC_FROM_G_HEADER		4

#define KW_PATH_CASE	0
#define KW_SKIP_CASE	-1
#define KW_ATIME_CASE	-2

typedef struct {
	char *	name;
	int	len;
	int	active;			/* 1 means active, 0 means deleted via -o delete=		*/
	int	cmdline_action;
	int	header_action;
	/* next 2 entries only used by store_header actions						*/
	char **	g_value;		/* -o keyword= value						*/
	char **	x_value;		/* -o keyword:= value						*/
	char **	g_value_current;	/* keyword= value found in Global extended header		*/
	char **	x_value_current;	/* keyword= value found in extended header			*/
	int	header_inx;		/* starting index of header field this keyword represents	*/
	int	header_len;		/* length of header field this keyword represents		*/
					/* If negative, special cases line path=			*/
} O_OPTION_TYPE;

O_OPTION_TYPE o_option_table[] = {
	{ "atime",	5,	1,	O_OPTION_ACTION_STORE_HEADER, O_OPTION_ACTION_STORE_HEADER,
	&atime_g,	&atime_x,	&atime_g_current,	&atime_x_current,	0,	KW_ATIME_CASE	},
	{ "charset",	7,	1,	O_OPTION_ACTION_STORE_HEADER, O_OPTION_ACTION_IGNORE,
	&charset_g,	&charset_x,	&charset_g_current,	&charset_x_current,	0,	KW_SKIP_CASE	},
	{ "comment",	7,	1,	O_OPTION_ACTION_STORE_HEADER, O_OPTION_ACTION_IGNORE,
	&comment_g,	&comment_x,	&comment_g_current,	&comment_x_current,	0,	KW_SKIP_CASE	},
	{ "gid",	3,	1,	O_OPTION_ACTION_STORE_HEADER2, O_OPTION_ACTION_STORE_HEADER2,
	&gid_g,		&gid_x,		&gid_g_current,		&gid_x_current	,	116,	8		},
	{ "gname",	5,	1,	O_OPTION_ACTION_STORE_HEADER2, O_OPTION_ACTION_STORE_HEADER2,
	&gname_g,	&gname_x,	&gname_g_current,	&gname_x_current,	297,	32		},
	{ "linkpath",	8,	1,	O_OPTION_ACTION_STORE_HEADER, O_OPTION_ACTION_STORE_HEADER,
	&linkpath_g,	&linkpath_x,	&linkpath_g_current,	&linkpath_x_current,	0,	KW_SKIP_CASE	},
	{ "mtime",	5,	1,	O_OPTION_ACTION_STORE_HEADER, O_OPTION_ACTION_STORE_HEADER,
	&mtime_g,	&mtime_x,	&mtime_g_current,	&mtime_x_current,	136,	KW_SKIP_CASE	},
	{ "path",	4,	1,	O_OPTION_ACTION_STORE_HEADER, O_OPTION_ACTION_STORE_HEADER,
	&path_g,	&path_x,	&path_g_current,	&path_x_current,	0,	KW_PATH_CASE	},
	{ "size",	4,	1,	O_OPTION_ACTION_STORE_HEADER, O_OPTION_ACTION_STORE_HEADER,
	&size_g,	&size_x,	&size_g_current,	&size_x_current,	124,	KW_SKIP_CASE	},
	{ "uid",	3,	1,	O_OPTION_ACTION_STORE_HEADER2, O_OPTION_ACTION_STORE_HEADER2,
	&uid_g,		&uid_x,		&uid_g_current,		&uid_x_current,		108,	8		},
	{ "uname",	5,	1,	O_OPTION_ACTION_STORE_HEADER2, O_OPTION_ACTION_STORE_HEADER2,
	&uname_g,	&uname_x,	&uname_g_current,	&uname_x_current,	265,	32		},

	{ "exthdr.name",  11,	1,	O_OPTION_ACTION_HEADER_NAME,	O_OPTION_ACTION_ERROR,
	&header_name_x, &header_name_x_requested,	NULL,	NULL,	0,	KW_SKIP_CASE	},
	{ "globexthdr.name", 15, 1,	O_OPTION_ACTION_HEADER_NAME,	O_OPTION_ACTION_ERROR,
	&header_name_g, &header_name_g_requested,	NULL,	NULL,	0,	KW_SKIP_CASE	},

	{ "delete",	6,	1,	O_OPTION_ACTION_DELETE,	 O_OPTION_ACTION_ERROR,	
	NULL,		NULL,		NULL,			NULL,	0,	KW_SKIP_CASE	},
	{ "invalid",	7,	1,	O_OPTION_ACTION_INVALID,	 O_OPTION_ACTION_ERROR,	
	NULL,		NULL,		NULL,			NULL,	0,	KW_SKIP_CASE	},
	{ "linkdata",	8,	1,	O_OPTION_ACTION_LINKDATA,	 O_OPTION_ACTION_ERROR,
	NULL,		NULL,		NULL,			NULL,	0,	KW_SKIP_CASE	}, /* Test 241 */
	{ "listopt",	7,	1,	O_OPTION_ACTION_LISTOPT,	 O_OPTION_ACTION_ERROR,
	&pax_list_opt_format, NULL,	NULL,			NULL,	0,	KW_SKIP_CASE	}, /* Test 242 */
		/* Note: listopt is supposed to apply for all formats, not just -x pax only	*/
	{ "times",	5,	1,	O_OPTION_ACTION_TIMES,	 O_OPTION_ACTION_ERROR,
	NULL,		NULL,		NULL,			NULL,	0,	KW_SKIP_CASE	},
};

int ext_header_inx,
    global_ext_header_inx;

/* Make these tables big enough to handle lots of -o options, not just one per table entry */
int ext_header_entry       [4*sizeof(o_option_table)/sizeof(O_OPTION_TYPE)],
    global_ext_header_entry[4*sizeof(o_option_table)/sizeof(O_OPTION_TYPE)];

/*
 * Routines for reading, writing and header identify of various versions of pax
 */

static size_t expandname(char *, size_t, char **, const char *, size_t);
static u_long pax_chksm(char *, int);
static char *name_split(char *, int);
static int ul_oct(u_long, char *, int, int);
#ifndef LONG_OFF_T
static int uqd_oct(u_quad_t, char *, int, int);
#endif

static uid_t uid_nobody;
static uid_t uid_warn;
static gid_t gid_nobody;
static gid_t gid_warn;

/*
 * Routines common to all versions of pax
 */

/*
 * ul_oct()
 *	convert an unsigned long to an octal string. many oddball field
 *	termination characters are used by the various versions of tar in the
 *	different fields. term selects which kind to use. str is '0' padded
 *	at the front to len. we are unable to use only one format as many old
 *	tar readers are very cranky about this.
 * Return:
 *	0 if the number fit into the string, -1 otherwise
 */

static int
ul_oct(u_long val, char *str, int len, int term)
{
	char *pt;

	/*
	 * term selects the appropriate character(s) for the end of the string
	 */
	pt = str + len - 1;
	switch (term) {
	case 3:
		*pt-- = '\0';
		break;
	case 2:
		*pt-- = ' ';
		*pt-- = '\0';
		break;
	case 1:
		*pt-- = ' ';
		break;
	case 0:
	default:
		*pt-- = '\0';
		*pt-- = ' ';
		break;
	}

	/*
	 * convert and blank pad if there is space
	 */
	while (pt >= str) {
		*pt-- = '0' + (char)(val & 0x7);
		if ((val = val >> 3) == (u_long)0)
			break;
	}

	while (pt >= str)
		*pt-- = '0';
	if (val != (u_long)0)
		return(-1);
	return(0);
}

#ifndef LONG_OFF_T
/*
 * uqd_oct()
 *	convert an u_quad_t to an octal string. one of many oddball field
 *	termination characters are used by the various versions of tar in the
 *	different fields. term selects which kind to use. str is '0' padded
 *	at the front to len. we are unable to use only one format as many old
 *	tar readers are very cranky about this.
 * Return:
 *	0 if the number fit into the string, -1 otherwise
 */

static int
uqd_oct(u_quad_t val, char *str, int len, int term)
{
	char *pt;

	/*
	 * term selects the appropriate character(s) for the end of the string
	 */
	pt = str + len - 1;
	switch (term) {
	case 3:
		*pt-- = '\0';
		break;
	case 2:
		*pt-- = ' ';
		*pt-- = '\0';
		break;
	case 1:
		*pt-- = ' ';
		break;
	case 0:
	default:
		*pt-- = '\0';
		*pt-- = ' ';
		break;
	}

	/*
	 * convert and blank pad if there is space
	 */
	while (pt >= str) {
		*pt-- = '0' + (char)(val & 0x7);
		if ((val = val >> 3) == 0)
			break;
	}

	while (pt >= str)
		*pt-- = '0';
	if (val != (u_quad_t)0)
		return(-1);
	return(0);
}
#endif

/*
 * pax_chksm()
 *	calculate the checksum for a pax block counting the checksum field as
 *	all blanks (BLNKSUM is that value pre-calculated, the sum of 8 blanks).
 *	NOTE: we use len to short circuit summing 0's on write since we ALWAYS
 *	pad headers with 0.
 * Return:
 *	unsigned long checksum
 */

static u_long
pax_chksm(char *blk, int len)
{
	char *stop;
	char *pt;
	u_long chksm = BLNKSUM;	/* initial value is checksum field sum */

	/*
	 * add the part of the block before the checksum field
	 */
	pt = blk;
	stop = blk + CHK_OFFSET;
	while (pt < stop)
		chksm += (u_long)(*pt++ & 0xff);
	/*
	 * move past the checksum field and keep going, spec counts the
	 * checksum field as the sum of 8 blanks (which is pre-computed as
	 * BLNKSUM).
	 * ASSUMED: len is greater than CHK_OFFSET. (len is where our 0 padding
	 * starts, no point in summing zero's)
	 */
	pt += CHK_LEN;
	stop = blk + len;
	while (pt < stop)
		chksm += (u_long)(*pt++ & 0xff);
	return(chksm);
}

void
pax_format_list_output(ARCHD *arcn, time_t now, FILE *fp, int term)
{
	/* parse specified listopt format */
	char *nextpercent, *nextchar;
	char buf[4*1024];
	int pos, cpylen;
	char *fname;

	nextpercent = strchr(pax_list_opt_format,'%');
	if (nextpercent==NULL) {
		/* Strange case: no specifiers? */
	 	safe_print(pax_list_opt_format, fp);
		(void)putc(term, fp);
		(void)fflush(fp);
		return;
	}
	pos = nextpercent-pax_list_opt_format;
	memcpy(buf,pax_list_opt_format, pos);
	while (nextpercent++) {
		switch (*nextpercent) {
		case 'F':
			fname = arcn->name;
			cpylen = strlen(fname);
			memcpy(&buf[pos],fname,cpylen);
			pos+= cpylen;
			break;
		case 'D':
		case 'T':
		case 'M':
		case 'L':
		default:
			paxwarn(1, "Unimplemented listopt format: %c",*nextpercent);
			break;
		}
		nextpercent++;
		if (*nextpercent=='\0') {
			break;
		}
		nextchar = nextpercent;
		nextpercent = strchr(nextpercent,'%');
		if (nextpercent==NULL) {
			cpylen = strlen(nextchar);
		} else {
			cpylen = nextpercent - nextchar;
		}
		memcpy(&buf[pos],nextchar, cpylen);
		pos += cpylen;
	}
	buf[pos]='\0';
 	safe_print(&buf[0], fp);
	(void)putc(term, fp);
	(void)fflush(fp);
	return;
}

void
cleanup_pax_invalid_action()
{
	switch (pax_invalid_action) {
	case PAX_INVALID_ACTION_BYPASS:
	case PAX_INVALID_ACTION_RENAME:
		break;
	case PAX_INVALID_ACTION_WRITE:
		pax_invalid_action_write_path = NULL;
		if (pax_invalid_action_write_cwd) {
			free(pax_invalid_action_write_cwd);
			pax_invalid_action_write_cwd = NULL;
		}
		break;
	case PAX_INVALID_ACTION_UTF8:
	default:
		paxwarn(1, "pax_invalid_action not implemented:%d", pax_invalid_action);
	}
}

void
record_pax_invalid_action_results(ARCHD * arcn, char * fixed_path)
{
	switch (pax_invalid_action) {
	case PAX_INVALID_ACTION_BYPASS:
	case PAX_INVALID_ACTION_RENAME:
		break;
	case PAX_INVALID_ACTION_WRITE:
		pax_invalid_action_write_path = fixed_path;
		pax_invalid_action_write_cwd  = strdup(arcn->name);
		pax_invalid_action_write_cwd[fixed_path-arcn->name-1] = '\0';
		break;
	case PAX_INVALID_ACTION_UTF8:
	default:
		paxwarn(1, "pax_invalid_action not implemented:%d", pax_invalid_action);
	}
}

int
perform_pax_invalid_action(ARCHD * arcn, int err)
{
	int rc = 0;
	switch (pax_invalid_action) {
	case PAX_INVALID_ACTION_BYPASS:
		rc = -1;
		break;
	case PAX_INVALID_ACTION_RENAME:
		rc = tty_rename(arcn);
		break;
	case PAX_INVALID_ACTION_WRITE:
		pax_invalid_action_write_path = NULL;
		pax_invalid_action_write_cwd = NULL;
		rc = 2;
		break;
	case PAX_INVALID_ACTION_UTF8:
	default:
		paxwarn(1, "pax_invalid_action not implemented:%d", pax_invalid_action);
		rc = -1;	/* do nothing? */
	}
	return rc;
}

static void
delete_keywords(char * pattern)
{
	int i;
	/* loop over all keywords, marking any matched as deleted */
	for (i = 0; i < sizeof(o_option_table)/sizeof(O_OPTION_TYPE); i++) {
		if (fnmatch(pattern, o_option_table[i].name, 0) == 0) {
			/* Found option: mark deleted */
			o_option_table[i].active = 0;
		}
	}
}

/*
 * pax_opt()
 *	handle pax format specific -o options
 * Return:
 *	0 if ok -1 otherwise
 */

int
pax_opt(void)
{
	OPLIST *opt;
	int got_option = 0;

	while ((opt = opt_next()) != NULL) {
		int i;
		got_option = -1;
		pax_invalid_action = PAX_INVALID_ACTION_BYPASS; /* Default for pax format */
		/* look up opt->name */
		for (i = 0; i < sizeof(o_option_table)/sizeof(O_OPTION_TYPE); i++) {
			if (strncasecmp(opt->name, o_option_table[i].name, o_option_table[i].len) == 0) {
				/* Found option: see if already set */
				/* Save it away */
				got_option = 1;
				switch (o_option_table[i].cmdline_action) {
				case O_OPTION_ACTION_INVALID:
					if (opt->separator != SEP_EQ) {
						paxwarn(1,"-o %s= option requires '=' separator: option ignored",
								opt->name);
						break;
					}
					if (opt->value) {
						if (strncasecmp(opt->value,"bypass",6) == 0) {
							pax_invalid_action = PAX_INVALID_ACTION_BYPASS;
						} else if (strncasecmp(opt->value,"rename",6) == 0) {
							pax_invalid_action = PAX_INVALID_ACTION_RENAME;
						} else if (strncasecmp(opt->value,"UTF-8",5) == 0) {
							pax_invalid_action = PAX_INVALID_ACTION_UTF8;
						} else if (strncasecmp(opt->value,"write",5) == 0) {
							pax_invalid_action = PAX_INVALID_ACTION_WRITE;
						} else {
							paxwarn(1,"Invalid action %s not recognized: option ignored",
								opt->value);
						}
					} else {
						paxwarn(1,"Invalid action RHS not specified: option ignored");
					}
					break;
				case O_OPTION_ACTION_DELETE:
					if (opt->separator != SEP_EQ) {
						paxwarn(1,"-o %s= option requires '=' separator: option ignored",
								opt->name);
						break;
					}
					/* Mark all matches as deleted */
					/* can have multiple -o delete= patterns */
					delete_keywords(opt->value);
					break;
				case O_OPTION_ACTION_STORE_HEADER2:
					if(pax_read_or_list_mode) pids = 1;	/* Force -p o for these options */
				case O_OPTION_ACTION_STORE_HEADER:
					if (o_option_table[i].g_value == NULL || 
					    o_option_table[i].x_value == NULL ) {
						paxwarn(1,"-o option not implemented: %s=%s",
								opt->name, opt->value);
					} else {
						if (opt->separator == SEP_EQ) {
							*(o_option_table[i].g_value) = opt->value;
							global_ext_header_entry[global_ext_header_inx++] = i;
                				} else if (opt->separator == SEP_COLONEQ ) { 
							*(o_option_table[i].x_value) = opt->value;
							ext_header_entry       [ext_header_inx++] = i;
				                } else {        /* SEP_NONE */
							paxwarn(1,"-o %s option is missing value", opt->name);
				                }
					}
					break;
				case O_OPTION_ACTION_TIMES:
					if (opt->separator != SEP_NONE) {
						paxwarn(1,"-o %s option takes no value: option ignored", opt->name);
						break;
					}
					want_a_m_time_headers = 1;
					break;
				case O_OPTION_ACTION_LINKDATA:
					if (opt->separator != SEP_NONE) {
						paxwarn(1,"-o %s option takes no value: option ignored", opt->name);
						break;
					}
					want_linkdata = 1;
					break;
				case O_OPTION_ACTION_HEADER_NAME:
					if (opt->separator != SEP_EQ) {
						paxwarn(1,"-o %s= option requires '=' separator: option ignored",
								opt->name);
						break;
					}
					*(o_option_table[i].g_value) = opt->value;
					*(o_option_table[i].x_value) = "YES";
					break;
				case O_OPTION_ACTION_LISTOPT:
					if (opt->separator != SEP_EQ) {
						paxwarn(1,"-o %s= option requires '=' separator: option ignored",
								opt->name);
						break;
					}
					*(o_option_table[i].g_value) = opt->value;
					break;
				case O_OPTION_ACTION_NOTIMPL:
				default:
					paxwarn(1,"pax format -o option not yet implemented: %s=%s",
						    opt->name, opt->value);
					break;
				}
				break;
			}
		}
		if (got_option == -1) {
			paxwarn(1,"pax format -o option not recognized: %s=%s",
			    opt->name, opt->value);
		}
	}
	return(0);
}

static int
expand_extended_headers(ARCHD *arcn, HD_USTAR *hd)
{
	char mybuf[BLKMULT];
	HD_USTAR *myhd;
	char * current_value;
	int path_replaced = 0;
	int i, len;

	myhd = hd;
	while (myhd->typeflag == PAXGTYPE ||  myhd->typeflag == PAXXTYPE) {
		char *name, *str;
		int size, nbytes, inx;
		size = asc_ul(myhd->size, sizeof(myhd->size), OCT);
		if (size > sizeof(mybuf)) {
			paxwarn(1,"extended header buffer overflow");
			exit(1);
		}
		nbytes = rd_wrbuf(mybuf, size);
		if (nbytes != size) {
			paxwarn(1,"extended header data read failure: nbytes=%d, size=%d\n",
				nbytes, size);
			exit(1);
		}
		/*
		printf("Read 1 extended header: type=%c, size=%d\n",
				myhd->typeflag, size);
		*/
		inx=0;
		/* loop over buffer collecting attributes  */
		while (nbytes > 0) {
			int got_option = -1;
			int nentries = sscanf(&mybuf[inx],"%d ", &len);
			if (nentries != 1) {
				paxwarn(1,"Extended header failure: length");
				exit(1);
			}
			if (len < 0 || (inx+len-1 >= sizeof(mybuf))) {
				paxwarn(1, "Extended header failure: invalid length (%d)", len);
				exit(1);
			}
			if (mybuf[inx+len-1] != '\n') {
				paxwarn(1,"Extended header failure: missed newline");
				exit(1);
			} else
				mybuf[inx+len-1] = '\0';
			name = strchr(&mybuf[inx],' ');
			if (name) name++;
			else {
				paxwarn(1,"Extended header failure: missing space");
				exit(1);
			}
			str = strchr(name,'=');
			if (str) {
				*str++='\0'; /* end of name */
			} else {
				paxwarn(1,"Extended header failure: missing RHS string");
				exit(1);
			}
			for (i = 0; i < sizeof(o_option_table)/sizeof(O_OPTION_TYPE); i++) {
				if (strncasecmp(name, o_option_table[i].name, o_option_table[i].len) == 0) {
					/* Found option: see if already set TBD */
					/* Save it away */
					got_option = i;
					break;
				}
			}
			if (got_option == -1) {
				paxwarn(1,"Unrecognized header keyword: %s",name);
			} else {
				/* Determine precedence of -o and header attributes */
				int found_value = ATTRSRC_FROM_NOWHERE;
				current_value = NULL;
				if (myhd->typeflag == PAXXTYPE) {
					if (*o_option_table[got_option].x_value) {
						current_value = *o_option_table[got_option].x_value;
						found_value = ATTRSRC_FROM_X_O_OPTION;
					} else {
						current_value = str;    
						found_value = ATTRSRC_FROM_X_HEADER;
					}
				} else if (myhd->typeflag == PAXGTYPE) {
					if (*o_option_table[got_option].g_value) {
						current_value = *o_option_table[got_option].g_value;
						found_value = ATTRSRC_FROM_G_O_OPTION;
					} else {
						current_value = str;    
						found_value = ATTRSRC_FROM_G_HEADER;
					}
				} else {
					paxwarn(1,"Unsupported header type:%c",myhd->typeflag);
				}
				if (current_value) {
					/* Save this attribute value for use later */
					switch (o_option_table[got_option].header_action) {
					case O_OPTION_ACTION_IGNORE:
						paxwarn(1,"ignoring header keyword: %s",name);
						break;
					case O_OPTION_ACTION_STORE_HEADER2:
					case O_OPTION_ACTION_STORE_HEADER:
						switch (found_value) {
						case ATTRSRC_FROM_NOWHERE: /* shouldn't happen */
							paxwarn(1, "internal error: value from nowhere");
							break;
						case ATTRSRC_FROM_X_O_OPTION:
						case ATTRSRC_FROM_G_O_OPTION:
							break;
						case ATTRSRC_FROM_X_HEADER:
							current_value = strdup(current_value);
							if(*o_option_table[got_option].x_value_current)
								free(*o_option_table[got_option].x_value_current);
							*o_option_table[got_option].x_value_current = current_value;
							break;
						case ATTRSRC_FROM_G_HEADER:
							current_value = strdup(current_value);
							if(*o_option_table[got_option].g_value_current)
								free(*o_option_table[got_option].g_value_current);
							*o_option_table[got_option].g_value_current = current_value;
							break;
						}
						break;
					case O_OPTION_ACTION_ERROR:
					default:
						paxwarn(1,"Unsupported extended header attribute: %s=%s",
							name, str);
					}
				}
			}
			inx+=len;
			nbytes -= len;
		}

		/* position file at next header */
		(void)rd_skip(TAR_PAD(size));

		/* read next header */
		nbytes = rd_wrbuf(mybuf, frmt->hsz);
		if (nbytes != frmt->hsz) {
			paxwarn(1,"extended header read failure: nbytes=%d, size=%d\n",
				nbytes, frmt->hsz);
		}
		myhd = ((HD_USTAR *)mybuf);
		/* repeat until no more extended headers */
	}

	/* The header about to be returned must now be updated using all the extended
	   header values collected and any command line options */
	/* Acceleration: check during command option processing. If there are no -o
	   options, and no changes from any header, do not need to run through this loop. */
	   
	for (i = 0; i < sizeof(o_option_table)/sizeof(O_OPTION_TYPE); i++) {
		int header_len, free_it;
		if (!o_option_table[i].active) {
			continue; /* deleted keywords */
		}
		header_len = o_option_table[i].header_len;
		if (header_len == KW_SKIP_CASE) {
			continue;
		}
		free_it = 0;
		/* Calculate values for all non-skip keywords */
		current_value = NULL;
		if (o_option_table[i].x_value) {
			current_value = *o_option_table[i].x_value;
		}
		if (!current_value) {	/* No -o := */
			if (o_option_table[i].x_value_current) {
				current_value = *o_option_table[i].x_value_current;
			}
			if (current_value) {
				/* Must remove it: x header values not valid beyond this header */
				*o_option_table[i].x_value_current = NULL;
				free_it = 1;
			} else {	/* No x values, try globals */
				current_value = *o_option_table[i].g_value;
				if (!current_value) {
					current_value = *o_option_table[i].g_value_current;
				}
			}
		}
		if (current_value) {
			/* Update current header with this value */
			/*
				printf ("Found current_value:%s for %s,  pids=%d\n",
			 current_value, o_option_table[i].name, pids);
				*/
			len = strlen(current_value);
			if (header_len == KW_ATIME_CASE) {
				time_t asecs = strtoul(current_value, NULL, 10);
				arcn->sb.st_atimespec.tv_sec = asecs;
			} else if (header_len == KW_PATH_CASE) {	/* Special case for path keyword */
				path_replaced = 1;
				arcn->nlen = len;
				strlcpy(arcn->name,current_value,sizeof(arcn->name));
			} else if (header_len >= 0) { // Skip negative values
				if (len > header_len) {
					paxwarn(1," length of string from extended header bigger than header field:"
						" THAT won't work!\n");
				} else {
					char * p = (char *) myhd;
					memcpy(&p[o_option_table[i].header_inx],
					       current_value, len);
					if (len != header_len) {
						/* pad with ? */
						p[o_option_table[i].header_inx+len] = '\0';
					}
				}
			}
			if (free_it) {
				free(current_value);
			}
		}
	}

	if (myhd==hd) return(path_replaced);

	/* must put new header into memory of original */
	memcpy(hd, myhd, sizeof(HD_USTAR));

	return(path_replaced);
}

/*
 * pax_id()
 *	determine if a block given to us is a valid pax header. We have to
 *	be on the lookout for those pesky blocks of all zero's
 * Return:
 *	0 if a ustar header, -1 otherwise
 */

int
pax_id(char *blk, int size)
{
	HD_USTAR *hd;

	if (size < BLKMULT)
		return(-1);
	hd = (HD_USTAR *)blk;

	/*
	 * check for block of zero's first, a simple and fast test then check
	 * ustar magic cookie. We should use TMAGLEN, but some USTAR archive
	 * programs are fouled up and create archives missing the \0. Last we
	 * check the checksum. If ok we have to assume it is a valid header.
	 */
	if (hd->name[0] == '\0')
		return(-1);
	if (strncmp(hd->magic, TMAGIC, TMAGLEN - 1) != 0)
		return(-1);
	if (asc_ul(hd->chksum,sizeof(hd->chksum),OCT) != pax_chksm(blk,BLKMULT))
		return(-1);
	if ((hd->typeflag != PAXXTYPE) && (hd->typeflag != PAXGTYPE)) {
		/* Not explicitly pax format, but at least ustar */
		if (act==LIST || act==EXTRACT) {
			/* Although insufficient evidence, call it pax format */
			return(0);
		}
		return(-1);
	}
	pax_invalid_action = PAX_INVALID_ACTION_BYPASS; /* Default for pax format */
	return(0);
}

/*
 * pax_rd()
 *	extract the values out of block already determined to be a pax header.
 *	store the values in the ARCHD parameter.
 * Return:
 *	0
 */

int
pax_rd(ARCHD *arcn, char *buf)
{
	HD_USTAR *hd;
	int cnt = 0;
	int check_path;
	dev_t devmajor;
	dev_t devminor;

	/*
	 * we only get proper sized buffers
	 */
	if (pax_id(buf, BLKMULT) < 0)
		return(-1);

	memset(arcn, 0, sizeof(*arcn));
	arcn->org_name = arcn->name;
	arcn->sb.st_nlink = 1;
	hd = (HD_USTAR *)buf;

	check_path = expand_extended_headers(arcn, hd);

	if (check_path) {
		/* 
		 * pathname derived from extended head or -o option;
		 * full name is in one string, but length may exceed
		 * max path so be careful.
		 */
		if (arcn->nlen > sizeof(arcn->name)) {
			paxwarn(1,"pathname from extended header info  doesn't fit! (len=%d)\n",
				arcn->nlen);
		}
	} else {
		/*
		 * see if the filename is split into two parts. if so, join the parts.
		 * we copy the prefix first and add a / between the prefix and name.
		 */
		char *dest = arcn->name;
		if (*(hd->prefix) != '\0') {
			cnt = strlcpy(dest, hd->prefix, sizeof(arcn->name) - 1);
			dest += cnt;
			*dest++ = '/';
			cnt++;
		} else {
			cnt = 0;
		}
	
		if (hd->typeflag != LONGLINKTYPE && hd->typeflag != LONGNAMETYPE) {
			arcn->nlen = cnt + expandname(dest, sizeof(arcn->name) - cnt,
			    &gnu_name_string, hd->name, sizeof(hd->name));
			arcn->ln_nlen = expandname(arcn->ln_name, sizeof(arcn->ln_name),
			    &gnu_link_string, hd->linkname, sizeof(hd->linkname));
		}
	}

	/*
	 * follow the spec to the letter. we should only have mode bits, strip
	 * off all other crud we may be passed.
	 */
	arcn->sb.st_mode = (mode_t)(asc_ul(hd->mode, sizeof(hd->mode), OCT) &
	    0xfff);
#ifdef LONG_OFF_T
	arcn->sb.st_size = (off_t)asc_ul(hd->size, sizeof(hd->size), OCT);
#else
	arcn->sb.st_size = (off_t)asc_uqd(hd->size, sizeof(hd->size), OCT);
#endif
	arcn->sb.st_mtime = (time_t)asc_ul(hd->mtime, sizeof(hd->mtime), OCT);
	if (arcn->sb.st_atimespec.tv_sec == 0) { // Can be set from header
		arcn->sb.st_atime = arcn->sb.st_mtime;
	}
	arcn->sb.st_ctime = arcn->sb.st_mtime;

	/*
	 * If we can find the ascii names for gname and uname in the password
	 * and group files we will use the uid's and gid they bind. Otherwise
	 * we use the uid and gid values stored in the header. (This is what
	 * the posix spec wants).
	 */
	hd->gname[sizeof(hd->gname) - 1] = '\0';
	if (gid_name(hd->gname, &(arcn->sb.st_gid)) < 0)
		arcn->sb.st_gid = (gid_t)asc_ul(hd->gid, sizeof(hd->gid), OCT);
	hd->uname[sizeof(hd->uname) - 1] = '\0';
	if (uid_name(hd->uname, &(arcn->sb.st_uid)) < 0)
		arcn->sb.st_uid = (uid_t)asc_ul(hd->uid, sizeof(hd->uid), OCT);

	/*
	 * set the defaults, these may be changed depending on the file type
	 */
	arcn->pad = 0;
	arcn->skip = 0;
	arcn->sb.st_rdev = (dev_t)0;

	/*
	 * set the mode and PAX type according to the typeflag in the header
	 */
	switch (hd->typeflag) {
	case FIFOTYPE:
		arcn->type = PAX_FIF;
		arcn->sb.st_mode |= S_IFIFO;
		break;
	case DIRTYPE:
		arcn->type = PAX_DIR;
		arcn->sb.st_mode |= S_IFDIR;
		arcn->sb.st_nlink = 2;

		/*
		 * Some programs that create pax archives append a '/'
		 * to the pathname for directories. This clearly violates
		 * pax specs, but we will silently strip it off anyway.
		 */
		if (arcn->name[arcn->nlen - 1] == '/')
			arcn->name[--arcn->nlen] = '\0';
		break;
	case BLKTYPE:
	case CHRTYPE:
		/*
		 * this type requires the rdev field to be set.
		 */
		if (hd->typeflag == BLKTYPE) {
			arcn->type = PAX_BLK;
			arcn->sb.st_mode |= S_IFBLK;
		} else {
			arcn->type = PAX_CHR;
			arcn->sb.st_mode |= S_IFCHR;
		}
		devmajor = (dev_t)asc_ul(hd->devmajor,sizeof(hd->devmajor),OCT);
		devminor = (dev_t)asc_ul(hd->devminor,sizeof(hd->devminor),OCT);
		arcn->sb.st_rdev = TODEV(devmajor, devminor);
		break;
	case SYMTYPE:
	case LNKTYPE:
		if (hd->typeflag == SYMTYPE) {
			arcn->type = PAX_SLK;
			arcn->sb.st_mode |= S_IFLNK;
		} else {
			arcn->type = PAX_HLK;
			/*
			 * so printing looks better
			 */
			arcn->sb.st_mode |= S_IFREG;
			arcn->sb.st_nlink = 2;
		}
		break;
	case LONGLINKTYPE:
	case LONGNAMETYPE:
		/*
		 * GNU long link/file; we tag these here and let the
		 * pax internals deal with it -- too ugly otherwise.
		 */
		arcn->type =
		    hd->typeflag == LONGLINKTYPE ? PAX_GLL : PAX_GLF;
		arcn->pad = TAR_PAD(arcn->sb.st_size);
		arcn->skip = arcn->sb.st_size;
		break;
	case CONTTYPE:
	case AREGTYPE:
	case REGTYPE:
	default:
		/*
		 * these types have file data that follows. Set the skip and
		 * pad fields.
		 */
		arcn->type = PAX_REG;
		arcn->pad = TAR_PAD(arcn->sb.st_size);
		arcn->skip = arcn->sb.st_size;
		arcn->sb.st_mode |= S_IFREG;
		break;
	}
	return(0);
}

void
adjust_copy_for_pax_options(ARCHD * arcn)
{
	/* Because ext_header options take precedence over global_header options, apply
	   global options first, then override with any extended header options 	*/
	int i;
	if (global_ext_header_inx) {
		for (i=0; i < global_ext_header_inx; i++) {
			if (!o_option_table[global_ext_header_entry[i]].active) continue; /* deleted keywords */
			if (strcmp(o_option_table[global_ext_header_entry[i]].name, "path")==0) {
				strlcpy(arcn->name,*(o_option_table[global_ext_header_entry[i]].g_value),
						sizeof(arcn->name));
				arcn->nlen = strlen(*(o_option_table[global_ext_header_entry[i]].g_value));
			} else {	/* only handle path for now: others TBD */
				paxwarn(1, "adjust arcn for global extended header options not implemented:%d", i);
			}
		}
	}
	if (ext_header_inx) {
		for (i=0; i < ext_header_inx; i++) {
			if (!o_option_table[ext_header_entry[i]].active) continue; /* deleted keywords */
			if (strcmp(o_option_table[ext_header_entry[i]].name, "path")==0) {
				strlcpy(arcn->name,*(o_option_table[ext_header_entry[i]].x_value),
						sizeof(arcn->name));
				arcn->nlen = strlen(*(o_option_table[ext_header_entry[i]].x_value));
			} else {	/* only handle path for now: others TBD */
				paxwarn(1, "adjust arcn for extended header options not implemented:%d", i);
			}
		}
	}
	if (want_a_m_time_headers) {
		/* TBD */
	}
}

static int
emit_extended_header_record(int len, int total_len, int head_type,
				char * name, char * value)
{
	if (total_len + len > sizeof(pax_eh_datablk)) {
		paxwarn(1,"extended header buffer overflow for header type '%c': %d", 
				head_type, total_len+len);
	} else {
		sprintf(&pax_eh_datablk[total_len],"%d %s=%s\n", len, name, value);
		total_len += len;
	}
	return (total_len);
}

__attribute__((__malloc__))
static char *
substitute_percent(char * header, char * filename)
{
	char *nextpercent, *nextchar;
	char buf[4*1024];
	int pos, cpylen;
	char *dname, *fname;

	nextpercent = strchr(header,'%');
	if (nextpercent==NULL) return strdup(header);
	pos = nextpercent-header;
	memcpy(buf,header, pos);
	while (nextpercent++) {
		switch (*nextpercent) {
		case '%':
			buf[pos++]='%';	/* just skip it */
			break;
		case 'd':
			dname = strrchr(filename,'/');
			if (dname==NULL) {
				cpylen = 1;
				dname = ".";
			} else {
				cpylen = dname-filename;
				dname = filename;
			}
			memcpy(&buf[pos],dname,cpylen);
			pos+= cpylen;
			break;
		case 'f':
			fname = strrchr(filename,'/');
			if (fname==NULL) {
				fname = filename;
			} else {
				fname++;
			}
			cpylen = strlen(fname);
			memcpy(&buf[pos],fname,cpylen);
			pos+= cpylen;
			break;
		case 'n':
			pos += sprintf (&buf[pos],"%d",nglobal_headers);
			break;
		case 'p':
			pos += sprintf (&buf[pos],"%d",getpid());
			break;
		default:
			paxwarn(1,"header format substitution failed: '%c'", *nextpercent);
			return strdup(header);
		}
		nextpercent++;
		if (*nextpercent=='\0') {
			break;
		}
		nextchar = nextpercent;
		nextpercent = strchr(nextpercent,'%');
		if (nextpercent==NULL) {
			cpylen = strlen(nextchar);
		} else {
			cpylen = nextpercent - nextchar;
		}
		memcpy(&buf[pos],nextchar, cpylen);
		pos += cpylen;
	}
	buf[pos]='\0';
	return (strdup(&buf[0]));
}

static int
generate_pax_ext_header_and_data(ARCHD *arcn, int nfields, int *table, 
				char header_type, char * header_name, char * header_name_requested)
{
	HD_USTAR *hd;
	char hdblk[sizeof(HD_USTAR)];
	u_long	records_size;
	int term_char, i, len, total_len;
	char * str, *name;

	if (nfields == 0 && (header_name_requested == NULL)) {
		if (header_type==PAXXTYPE) {
			if (!want_a_m_time_headers) return (0);
		} else
			return (0);
	}

	/* There might be no fields but a header with a specific name or
	   times might be wanted */

	term_char = 1;
	memset(hdblk, 0, sizeof(hdblk));
	hd = (HD_USTAR *)hdblk;
	memset(pax_eh_datablk, 0, sizeof(pax_eh_datablk));

	/* generate header */
	hd->typeflag = header_type;

	/* These fields appear to be necessary to be able to treat extended headers 
	   like files in older versions of pax */
	ul_oct((u_long)0444, hd->mode, sizeof(hd->mode), term_char);
	strncpy(hd->magic, TMAGIC, TMAGLEN);
	strncpy(hd->version, TVERSION, TVERSLEN);
	ul_oct((u_long)arcn->sb.st_mtime,hd->mtime,sizeof(hd->mtime),term_char);

	/* compute size of data */
	total_len = 0;
	for (i=0; i < nfields; i++) {
		if (!o_option_table[table[i]].active) continue; /* deleted keywords */
		name = o_option_table[table[i]].name;
		if (header_type == PAXXTYPE) {
			str = *(o_option_table[table[i]].x_value);
		} else {
			str = *(o_option_table[table[i]].g_value);
		}
		if (str==NULL) {
			paxwarn(1,"Missing option value for %s", name);
			continue;
		}
		len = strlen(str) + o_option_table[table[i]].len + 3;
		if (len < 9) len++;
		else if (len < 98)	len = len + 2;
		else if (len < 997)	len = len + 3;
		else if (len < 9996)	len = len + 4;
		else {
			paxwarn(1,"extended header data too long for header type '%c': %d", 
					header_type, len);
		}
		total_len = emit_extended_header_record(len, total_len, 
					header_type, name, str);
	}

	if ((header_type == PAXXTYPE) && want_a_m_time_headers) {
		char time_buffer[12];
		memset(time_buffer,0,sizeof(time_buffer));
		sprintf(&time_buffer[0],"%d",(int)arcn->sb.st_atime);
		/* 3 chars + strlen("atime") + time + # chars in len */
		len = 3 + 5 + strlen(&time_buffer[0]) + 2;
		total_len = emit_extended_header_record(len, total_len, 
				header_type, "atime", &time_buffer[0]);
		memset(time_buffer,0,sizeof(time_buffer));
		sprintf(&time_buffer[0],"%d",(int)arcn->sb.st_mtime);
		/* 3 chars + strlen("mtime") + time + # chars in len */
		len = 3 + 5 + strlen(&time_buffer[0]) + 2;
		total_len = emit_extended_header_record(len, total_len, 
				header_type, "mtime", &time_buffer[0]);
	}

	/* Check if all fields were deleted: might not need to generate anything */
	if ((total_len==0) && (header_name_requested == NULL)) return (0);

	if (header_type == PAXGTYPE) nglobal_headers++;
	/* substitution of fields in header_name */
	header_name = substitute_percent(header_name, arcn->name);
	if (strlen(header_name) == sizeof(hd->name)) {	/* must account for name just fits in buffer */
		strncpy(hd->name, header_name, sizeof(hd->name));
	} else {
		strlcpy(hd->name, header_name, sizeof(hd->name));
	}

	free(header_name);
	header_name = NULL;
	records_size = (u_long)total_len;
	if (ul_oct(records_size, hd->size, sizeof(hd->size), term_char)) {
		paxwarn(1,"extended header data too long for header type '%c'", header_type);
		return(1);
	}

	if (ul_oct(pax_chksm(hdblk, sizeof(HD_USTAR)), hd->chksum, sizeof(hd->chksum), term_char)) {
		paxwarn(1,"extended header data checksum failed: header type '%c'", header_type);
		return(1);
	}

	/* write out header */
	if (wr_rdbuf(hdblk, sizeof(HD_USTAR)) < 0)
		return(-1);
	if (wr_skip((off_t)(BLKMULT - sizeof(HD_USTAR))) < 0)
		return(-1);
	/* write out header data */
	if (total_len > 0) {
		if (wr_rdbuf(pax_eh_datablk, total_len) < 0)
			return(-1);
		if (wr_skip((off_t)(BLKMULT - total_len)) < 0)
			return(-1);
		/*
		printf("data written:\n%s",&pax_eh_datablk[0]);
		*/
	}

	/*
	paxwarn(0,"extended header and data written: header type '%c', #items: %d, %d characters",
				header_type, nfields, records_size);
	*/
	return (0);
}

/*
 * pax_wr()
 *	write a pax header for the file specified in the ARCHD to the archive
 *	Have to check for file types that cannot be stored and file names that
 *	are too long. Be careful of the term (last arg) to ul_oct, we only use
 *	'\0' for the termination character (this is different than picky tar)
 *	ASSUMED: space after header in header block is zero filled
 * Return:
 *	0 if file has data to be written after the header, 1 if file has NO
 *	data to write after the header, -1 if archive write failed
 */

int
pax_wr(ARCHD *arcn)
{
	HD_USTAR *hd;
	char *pt;
	char hdblk[sizeof(HD_USTAR)];
	mode_t mode12only;
	int term_char=3;	/* orignal setting */
	term_char=1;		/* To pass conformance tests 274, 301 */

	/*
	 * check for those file system types pax cannot store
	 */
	if (arcn->type == PAX_SCK) {
		paxwarn(1, "Pax cannot archive a socket %s", arcn->org_name);
		return(1);
	}

	/*
	 * check the length of the linkname
	 */
	if (((arcn->type == PAX_SLK) || (arcn->type == PAX_HLK) ||
	    (arcn->type == PAX_HRG)) && (arcn->ln_nlen > sizeof(hd->linkname))){
		paxwarn(1, "Link name too long for pax %s", arcn->ln_name);
		/*
		 * Conformance: test pax:285 wants error code to be non-zero, and
		 * test tar:12 wants error code from pax to be 0
		 */
		return(1);
	}

	/*
	 * split the path name into prefix and name fields (if needed). if
	 * pt != arcn->name, the name has to be split
	 */
	if ((pt = name_split(arcn->name, arcn->nlen)) == NULL) {
		paxwarn(1, "File name too long for pax %s", arcn->name);
		return(1);
	}

	generate_pax_ext_header_and_data(arcn, global_ext_header_inx, &global_ext_header_entry[0],
					PAXGTYPE, header_name_g, header_name_g_requested);
	generate_pax_ext_header_and_data(arcn, ext_header_inx, &ext_header_entry[0],
					PAXXTYPE, header_name_x, header_name_x_requested);

	/*
	 * zero out the header so we don't have to worry about zero fill below
	 */
	memset(hdblk, 0, sizeof(hdblk));
	hd = (HD_USTAR *)hdblk;
	arcn->pad = 0L;
	/* To pass conformance tests 274/301, always set these fields to "zero" */
	ul_oct(0, hd->devmajor, sizeof(hd->devmajor), term_char);
	ul_oct(0, hd->devminor, sizeof(hd->devminor), term_char);

	/*
	 * split the name, or zero out the prefix
	 */
	if (pt != arcn->name) {
		/*
		 * name was split, pt points at the / where the split is to
		 * occur, we remove the / and copy the first part to the prefix
		 */
		*pt = '\0';
		strlcpy(hd->prefix, arcn->name, sizeof(hd->prefix));
		*pt++ = '/';
	}

	/*
	 * copy the name part. this may be the whole path or the part after
	 * the prefix
	 */
	if (strlen(pt) == sizeof(hd->name)) {	/* must account for name just fits in buffer */
		strncpy(hd->name, pt, sizeof(hd->name));
	} else {
		strlcpy(hd->name, pt, sizeof(hd->name));
	}

	/*
	 * set the fields in the header that are type dependent
	 */
	switch (arcn->type) {
	case PAX_DIR:
		hd->typeflag = DIRTYPE;
		if (ul_oct((u_long)0L, hd->size, sizeof(hd->size), term_char))
			goto out;
		break;
	case PAX_CHR:
	case PAX_BLK:
		if (arcn->type == PAX_CHR)
			hd->typeflag = CHRTYPE;
		else
			hd->typeflag = BLKTYPE;
		if (ul_oct((u_long)MAJOR(arcn->sb.st_rdev), hd->devmajor,
		   sizeof(hd->devmajor), term_char) ||
		   ul_oct((u_long)MINOR(arcn->sb.st_rdev), hd->devminor,
		   sizeof(hd->devminor), term_char) ||
		   ul_oct((u_long)0L, hd->size, sizeof(hd->size), term_char))
			goto out;
		break;
	case PAX_FIF:
		hd->typeflag = FIFOTYPE;
		if (ul_oct((u_long)0L, hd->size, sizeof(hd->size), term_char))
			goto out;
		break;
	case PAX_SLK:
	case PAX_HLK:
	case PAX_HRG:
		if (arcn->type == PAX_SLK)
			hd->typeflag = SYMTYPE;
		else
			hd->typeflag = LNKTYPE;
		if (strlen(arcn->ln_name) == sizeof(hd->linkname)) {	/* must account for name just fits in buffer */
			strncpy(hd->linkname, arcn->ln_name, sizeof(hd->linkname));
		} else {
			strlcpy(hd->linkname, arcn->ln_name, sizeof(hd->linkname));
		}
		if (ul_oct((u_long)0L, hd->size, sizeof(hd->size), term_char))
			goto out;
		break;
	case PAX_REG:
	case PAX_CTG:
	default:
		/*
		 * file data with this type, set the padding
		 */
		if (arcn->type == PAX_CTG)
			hd->typeflag = CONTTYPE;
		else
			hd->typeflag = REGTYPE;
		arcn->pad = TAR_PAD(arcn->sb.st_size);
#		ifdef LONG_OFF_T
		if (ul_oct((u_long)arcn->sb.st_size, hd->size,
		    sizeof(hd->size), term_char)) {
#		else
		if (uqd_oct((u_quad_t)arcn->sb.st_size, hd->size,
		    sizeof(hd->size), term_char)) {
#		endif
			paxwarn(1,"File is too long for pax %s",arcn->org_name);
			return(1);
		}
		break;
	}

	strncpy(hd->magic, TMAGIC, TMAGLEN);
	strncpy(hd->version, TVERSION, TVERSLEN);

	/*
	 * set the remaining fields. Some versions want all 16 bits of mode
	 * we better humor them (they really do not meet spec though)....
	 */
	if (ul_oct((u_long)arcn->sb.st_uid, hd->uid, sizeof(hd->uid), term_char)) {
		if (uid_nobody == 0) {
			if (uid_name("nobody", &uid_nobody) == -1)
				goto out;
		}
		if (uid_warn != arcn->sb.st_uid) {
			uid_warn = arcn->sb.st_uid;
			paxwarn(1,
			    "Pax header field is too small for uid %lu, "
			    "using nobody", (u_long)arcn->sb.st_uid);
		}
		if (ul_oct((u_long)uid_nobody, hd->uid, sizeof(hd->uid), term_char))
			goto out;
	}
	if (ul_oct((u_long)arcn->sb.st_gid, hd->gid, sizeof(hd->gid), term_char)) {
		if (gid_nobody == 0) {
			if (gid_name("nobody", &gid_nobody) == -1)
				goto out;
		}
		if (gid_warn != arcn->sb.st_gid) {
			gid_warn = arcn->sb.st_gid;
			paxwarn(1,
			    "Pax header field is too small for gid %lu, "
			    "using nobody", (u_long)arcn->sb.st_gid);
		}
		if (ul_oct((u_long)gid_nobody, hd->gid, sizeof(hd->gid), term_char))
			goto out;
	}
	/* However, Unix conformance tests do not like MORE than 12 mode bits:
	   remove all beyond (see definition of stat.st_mode structure)		*/
	mode12only = ((u_long)arcn->sb.st_mode) & 0x00000fff;
	if (ul_oct((u_long)mode12only, hd->mode, sizeof(hd->mode), term_char) ||
	    ul_oct((u_long)arcn->sb.st_mtime,hd->mtime,sizeof(hd->mtime),term_char))
		goto out;
	strncpy(hd->uname, name_uid(arcn->sb.st_uid, 0), sizeof(hd->uname));
	strncpy(hd->gname, name_gid(arcn->sb.st_gid, 0), sizeof(hd->gname));

	/*
	 * calculate and store the checksum write the header to the archive
	 * return 0 tells the caller to now write the file data, 1 says no data
	 * needs to be written
	 */
	if (ul_oct(pax_chksm(hdblk, sizeof(HD_USTAR)), hd->chksum,
	   sizeof(hd->chksum), term_char))
		goto out;
	if (wr_rdbuf(hdblk, sizeof(HD_USTAR)) < 0)
		return(-1);
	if (wr_skip((off_t)(BLKMULT - sizeof(HD_USTAR))) < 0)
		return(-1);
	if ((arcn->type == PAX_CTG) || (arcn->type == PAX_REG))
		return(0);
	return(1);

    out:
	/*
	 * header field is out of range
	 */
	paxwarn(1, "Pax header field is too small for %s", arcn->org_name);
	return(1);
}

/*
 * name_split()
 *	see if the name has to be split for storage in a ustar header. We try
 *	to fit the entire name in the name field without splitting if we can.
 *	The split point is always at a /
 * Return
 *	character pointer to split point (always the / that is to be removed
 *	if the split is not needed, the points is set to the start of the file
 *	name (it would violate the spec to split there). A NULL is returned if
 *	the file name is too long
 */

static char *
name_split(char *name, int len)
{
	char *start;

	/*
	 * check to see if the file name is small enough to fit in the name
	 * field. if so just return a pointer to the name.
	 */
	if (len <= TNMSZ)
		return(name);
	if (len > (TPFSZ + TNMSZ))
		return(NULL);

	/*
	 * we start looking at the biggest sized piece that fits in the name
	 * field. We walk forward looking for a slash to split at. The idea is
	 * to find the biggest piece to fit in the name field (or the smallest
	 * prefix we can find)
	 */
	start = name + len - TNMSZ -1;
	if ((*start == '/') && (start == name))
		++start;	/* 101 byte paths with leading '/' are dinged otherwise */
	while ((*start != '\0') && (*start != '/'))
		++start;

	/*
	 * if we hit the end of the string, this name cannot be split, so we
	 * cannot store this file.
	 */
	if (*start == '\0')
		return(NULL);
	len = start - name;

	/*
	 * NOTE: /str where the length of str == TNMSZ can not be stored under
	 * the p1003.1-1990 spec for ustar. We could force a prefix of / and
	 * the file would then expand on extract to //str. The len == 0 below
	 * makes this special case follow the spec to the letter.
	 */
	if ((len >= TPFSZ) || (len == 0))
		return(NULL);

	/*
	 * ok have a split point, return it to the caller
	 */
	return(start);
}

static size_t
expandname(char *buf, size_t len, char **gnu_name, const char *name, size_t name_len)
{
	size_t nlen;

	if (*gnu_name) {
		if ((nlen = strlcpy(buf, *gnu_name, len)) >= len)
			nlen = len - 1;
		free(*gnu_name);
		*gnu_name = NULL;
	} else {
		if (name_len < len) {
			/* name may not be null terminated: it might be as big as the
			   field,  so copy is limited to the max size of the header field */
			if ((nlen = strlcpy(buf, name, name_len+1)) >= name_len+1)
				nlen = name_len;
		} else {
			if ((nlen = strlcpy(buf, name, len)) >= len)
				nlen = len - 1;
		}
	}
	return(nlen);
}
