/*-
 * Copyright (c) 1991, 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * Cimarron D. Taylor of the University of California, Berkeley.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 4. Neither the name of the University nor the names of its contributors
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
static char sccsid[] = "@(#)find.c	8.5 (Berkeley) 8/5/94";
#else
#endif
#endif /* not lint */

#include <sys/cdefs.h>
__FBSDID("$FreeBSD: src/usr.bin/find/find.c,v 1.23 2010/12/11 08:32:16 joel Exp $");

#include <sys/types.h>
#include <sys/stat.h>

#include <err.h>
#include <errno.h>
#include <fts.h>
#include <regex.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __APPLE__
#include <get_compat.h>
#include <unistd.h>
#else
#define COMPAT_MODE(func, mode) 1
#endif

#include "find.h"

#ifdef __APPLE__
static int find_compare(const FTSENT **s1, const FTSENT **s2);
#else /* !__APPLE__ */
static int find_compare(const FTSENT * const *s1, const FTSENT * const *s2);
#endif /* __APPLE__ */

/*
 * find_compare --
 *	tell fts_open() how to order the traversal of the hierarchy. 
 *	This variant gives lexicographical order, i.e., alphabetical
 *	order within each directory.
 */
static int
#ifdef __APPLE__
find_compare(const FTSENT **s1, const FTSENT **s2)
#else /* !__APPLE__ */
find_compare(const FTSENT * const *s1, const FTSENT * const *s2)
#endif /* __APPLE__ */
{

	return (strcoll((*s1)->fts_name, (*s2)->fts_name));
}

/*
 * find_formplan --
 *	process the command line and create a "plan" corresponding to the
 *	command arguments.
 */
PLAN *
find_formplan(char *argv[])
{
	PLAN *plan, *tail, *new;

	/*
	 * for each argument in the command line, determine what kind of node
	 * it is, create the appropriate node type and add the new plan node
	 * to the end of the existing plan.  The resulting plan is a linked
	 * list of plan nodes.  For example, the string:
	 *
	 *	% find . -name foo -newer bar -print
	 *
	 * results in the plan:
	 *
	 *	[-name foo]--> [-newer bar]--> [-print]
	 *
	 * in this diagram, `[-name foo]' represents the plan node generated
	 * by c_name() with an argument of foo and `-->' represents the
	 * plan->next pointer.
	 */
	for (plan = tail = NULL; *argv;) {
		if (!(new = find_create(&argv)))
			continue;
		if (plan == NULL)
			tail = plan = new;
		else {
			tail->next = new;
			tail = new;
		}
	}

	/*
	 * if the user didn't specify one of -print, -ok or -exec, then -print
	 * is assumed so we bracket the current expression with parens, if
	 * necessary, and add a -print node on the end.
	 */
	if (!isoutput) {
		OPTION *p;
		char **argv1 = 0;

		if (plan == NULL) {
			p = lookup_option("-print");
			new = (p->create)(p, &argv1);
			tail = plan = new;
		} else {
			p = lookup_option("(");
			new = (p->create)(p, &argv1);
			new->next = plan;
			plan = new;
			p = lookup_option(")");
			new = (p->create)(p, &argv1);
			tail->next = new;
			tail = new;
			p = lookup_option("-print");
			new = (p->create)(p, &argv1);
			tail->next = new;
			tail = new;
		}
	}

	/*
	 * the command line has been completely processed into a search plan
	 * except for the (, ), !, and -o operators.  Rearrange the plan so
	 * that the portions of the plan which are affected by the operators
	 * are moved into operator nodes themselves.  For example:
	 *
	 *	[!]--> [-name foo]--> [-print]
	 *
	 * becomes
	 *
	 *	[! [-name foo] ]--> [-print]
	 *
	 * and
	 *
	 *	[(]--> [-depth]--> [-name foo]--> [)]--> [-print]
	 *
	 * becomes
	 *
	 *	[expr [-depth]-->[-name foo] ]--> [-print]
	 *
	 * operators are handled in order of precedence.
	 */

	plan = paren_squish(plan);		/* ()'s */
	plan = not_squish(plan);		/* !'s */
	plan = or_squish(plan);			/* -o's */
	return (plan);
}

/* addPath - helper function used to build a list of paths that were
 * specified on the command line that we are allowed to search.
 */
static char **addPath(char **array, char *newPath)
{
	static int pathCounter = 0;
	
	if (newPath == NULL) {	/* initialize array */
		if ((array = malloc(sizeof(char *))) == NULL)
			err(2, "out of memory");
		array[0] = NULL;
	}
	else {
		array = realloc(array, (++pathCounter + 1) * sizeof(char *));
		if (array == NULL)
			err(2, "out of memory");
		else {
			array[pathCounter - 1] = newPath;
			array[pathCounter] = NULL;	/* ensure array is null terminated */
		}
	}
	return (array);
}

FTS *tree;			/* pointer to top of FTS hierarchy */

/*
 * find_execute --
 *	take a search plan and an array of search paths and executes the plan
 *	over all FTSENT's returned for the given search paths.
 */
int
find_execute(PLAN *plan, char *paths[])
{
	FTSENT *entry;
	PLAN *p;
	int rval;
	char **myPaths;
	int nonSearchableDirFound = 0;
	int pathIndex;
	struct stat statInfo;

	/* special-case directories specified on command line - explicitly examine
	 * mode bits, to ensure failure if the directory cannot be searched
	 * (whether or not it's empty). UNIX conformance... <sigh>
	 */
		
	int strict_symlinks = (ftsoptions & (FTS_COMFOLLOW|FTS_LOGICAL))
	  && COMPAT_MODE("bin/find", "unix2003");

	myPaths = addPath(NULL, NULL);
	for (pathIndex = 0; paths[pathIndex] != NULL; ++pathIndex) {
		int stat_ret = stat(paths[pathIndex], &statInfo);
		int stat_errno = errno;
		if (strict_symlinks && stat_ret < 0) {
		    if (stat_errno == ELOOP) {
			errx(1, "Symlink loop resolving %s", paths[pathIndex]);
		    }
		}

		/* retrieve mode bits, and examine "searchable" bit of 
		  directories, exempt root from POSIX conformance */
		if (COMPAT_MODE("bin/find", "unix2003") && getuid() 
		  && stat_ret == 0 
		  && ((statInfo.st_mode & S_IFMT) == S_IFDIR)) {
			if (access(paths[pathIndex], X_OK) == 0) {
				myPaths = addPath(myPaths, paths[pathIndex]);
			} else {
				if (stat_errno != ENAMETOOLONG) {	/* if name is too long, just let existing logic handle it */
					warnx("%s: Permission denied", paths[pathIndex]);
					nonSearchableDirFound = 1;
				}
			}
		} else {
			/* not a directory, so add path to array */
			myPaths = addPath(myPaths, paths[pathIndex]);
		}
	}
	if (myPaths[0] == NULL) {	/* were any directories searchable? */
		free(myPaths);
		return(nonSearchableDirFound);	/* no... */
	}

	tree = fts_open(myPaths, ftsoptions, (issort ? find_compare : NULL));
	if (tree == NULL)
		err(1, "ftsopen");

	for (rval = nonSearchableDirFound; (entry = fts_read(tree)) != NULL;) {
		if (maxdepth != -1 && entry->fts_level >= maxdepth) {
			if (fts_set(tree, entry, FTS_SKIP))
				err(1, "%s", entry->fts_path);
		}

		switch (entry->fts_info) {
		case FTS_D:
			if (isdepth)
				continue;
			break;
		case FTS_DP:
			if (!isdepth)
				continue;
			break;
		case FTS_DNR:
		case FTS_ERR:
		case FTS_NS:
			(void)fflush(stdout);
			warnx("%s: %s",
			    entry->fts_path, strerror(entry->fts_errno));
			rval = 1;
			continue;
#ifdef FTS_W
		case FTS_W:
			continue;
#endif /* FTS_W */
		}
#define	BADCH	" \t\n\\'\""
		if (isxargs && strpbrk(entry->fts_path, BADCH)) {
			(void)fflush(stdout);
			warnx("%s: illegal path", entry->fts_path);
			rval = 1;
			continue;
		}

		if (mindepth != -1 && entry->fts_level < mindepth)
			continue;

		/*
		 * Call all the functions in the execution plan until one is
		 * false or all have been executed.  This is where we do all
		 * the work specified by the user on the command line.
		 */
		for (p = plan; p && (p->execute)(p, entry); p = p->next);
	}
	free (myPaths);
	finish_execplus();
	if (execplus_error) {
		exit(execplus_error);
	}
	if (errno)
		err(1, "fts_read");
	fts_close(tree);
	return (rval);
}
