/*
 * Copyright (c) 1989, 1993, 1994
 *	The Regents of the University of California.  All rights reserved.
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
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
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
#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>

#include <membership.h>
#include "chmod_acl.h"

extern void chmod_usage(void);

#ifdef __APPLE__
static struct {
	acl_perm_t	perm;
	char		*name;
	int		flags;
#define ACL_PERM_DIR	(1<<0)
#define ACL_PERM_FILE	(1<<1)
} acl_perms[] = {
	{ACL_READ_DATA,		"read",		ACL_PERM_FILE},
	{ACL_LIST_DIRECTORY,	"list",		ACL_PERM_DIR},
	{ACL_WRITE_DATA,	"write",	ACL_PERM_FILE},
	{ACL_ADD_FILE,		"add_file",	ACL_PERM_DIR},
	{ACL_EXECUTE,		"execute",	ACL_PERM_FILE},
	{ACL_SEARCH,		"search",	ACL_PERM_DIR},
	{ACL_DELETE,		"delete",	ACL_PERM_FILE | ACL_PERM_DIR},
	{ACL_APPEND_DATA,	"append",	ACL_PERM_FILE},
	{ACL_ADD_SUBDIRECTORY,	"add_subdirectory", ACL_PERM_DIR},
	{ACL_DELETE_CHILD,	"delete_child",	ACL_PERM_DIR},
	{ACL_READ_ATTRIBUTES,	"readattr",	ACL_PERM_FILE | ACL_PERM_DIR},
	{ACL_WRITE_ATTRIBUTES,	"writeattr",	ACL_PERM_FILE | ACL_PERM_DIR},
	{ACL_READ_EXTATTRIBUTES, "readextattr",	ACL_PERM_FILE | ACL_PERM_DIR},
	{ACL_WRITE_EXTATTRIBUTES, "writeextattr", ACL_PERM_FILE | ACL_PERM_DIR},
	{ACL_READ_SECURITY,	"readsecurity",	ACL_PERM_FILE | ACL_PERM_DIR},
	{ACL_WRITE_SECURITY,	"writesecurity", ACL_PERM_FILE | ACL_PERM_DIR},
	{ACL_CHANGE_OWNER,	"chown",	ACL_PERM_FILE | ACL_PERM_DIR},
	{0, NULL, 0}
};

static struct {
	acl_flag_t	flag;
	char		*name;
	int		flags;
} acl_flags[] = {
	{ACL_ENTRY_INHERITED,		"inherited",		ACL_PERM_FILE | ACL_PERM_DIR},
	{ACL_ENTRY_FILE_INHERIT, 	"file_inherit",		ACL_PERM_DIR},
	{ACL_ENTRY_DIRECTORY_INHERIT,	"directory_inherit",	ACL_PERM_DIR},
	{ACL_ENTRY_LIMIT_INHERIT,	"limit_inherit",	ACL_PERM_FILE | ACL_PERM_DIR},
	{ACL_ENTRY_ONLY_INHERIT,	"only_inherit",		ACL_PERM_DIR},
	{0, NULL, 0}
};

/* TBD - Many of these routines could potentially be considered for
 * inclusion in a library. If that is done, either avoid use of "err"
 * and implement a better fall-through strategy in case of errors, 
 * or use err_set_exit() and make various structures globals.
 */

#define NAME_USER   (1)
#define NAME_GROUP  (2)
#define NAME_EITHER (NAME_USER | NAME_GROUP)

/* Perform a name to uuid mapping - calls through to memberd */

uuid_t *
name_to_uuid(char *tok, int nametype) {
	uuid_t *entryg = NULL;
	size_t len = strlen(tok);

	if ((entryg = (uuid_t *) calloc(1, sizeof(uuid_t))) == NULL) {
		warnx("Unable to allocate a uuid");
        return 0;
	}

	if ((nametype & NAME_USER) && mbr_identifier_to_uuid(ID_TYPE_USERNAME, tok, len, *entryg) == 0) {
		return entryg;
	}
	
	if ((nametype & NAME_GROUP) && mbr_identifier_to_uuid(ID_TYPE_GROUPNAME, tok, len, *entryg) == 0) {
		return entryg;
	}
	
	warnx("Unable to translate '%s' to a UUID", tok);
    return 0;
}

/* Convert an acl entry in string form to an acl_entry_t */
int
parse_entry(char *entrybuf, acl_entry_t newent) {
	char *tok;
	char *pebuf;
	uuid_t *entryg;

	acl_tag_t	tag;
	acl_permset_t	perms;
	acl_flagset_t	flags;
	unsigned permcount = 0;
	unsigned pindex = 0;
	char *delimiter = " ";
	int nametype = NAME_EITHER;

	acl_get_permset(newent, &perms);
	acl_get_flagset_np(newent, &flags);

	pebuf = entrybuf;

	if (0 == strncmp(entrybuf, "user:", 5)) {
		nametype = NAME_USER;
		pebuf += 5;
	} else if (0 == strncmp(entrybuf, "group:", 6)) {
		nametype = NAME_GROUP;
		pebuf += 6;
	}

	if (strchr(pebuf, ':')) /* User/Group names can have spaces */
		delimiter = ":";
	tok = strsep(&pebuf, delimiter);
	
	if ((tok == NULL) || *tok == '\0') {
		warnx("Invalid entry format -- expected user or group name");
        return 0;
	}

	/* parse the name into a qualifier */
	entryg = name_to_uuid(tok, nametype);

	tok = strsep(&pebuf, ": "); /* Stick with delimiter? */
	if ((tok == NULL) || *tok == '\0') {
		warnx("Invalid entry format -- expected allow or deny");
        return 0;
	}

	/* is the verb 'allow' or 'deny'? */
	if (!strcmp(tok, "allow")) {
		tag = ACL_EXTENDED_ALLOW;
	} else if (!strcmp(tok, "deny")) {
		tag = ACL_EXTENDED_DENY;
	} else {
		warnx("Unknown tag type '%s'", tok);
        return 0;
	}

	/* parse permissions */
	for (; (tok = strsep(&pebuf, ",")) != NULL;) {
		if (*tok != '\0') {
			/* is it a permission? */
			for (pindex = 0; acl_perms[pindex].name != NULL; pindex++) {
				if (!strcmp(acl_perms[pindex].name, tok)) {
					/* got one */
					acl_add_perm(perms, acl_perms[pindex].perm);
					permcount++;
					goto found;
				}
			}
			/* is it a flag? */
			for (pindex = 0; acl_flags[pindex].name != NULL; pindex++) {
				if (!strcmp(acl_flags[pindex].name, tok)) {
					/* got one */
					acl_add_flag_np(flags, acl_flags[pindex].flag);
					permcount++;
					goto found;
				}
			}
			warnx("Invalid permission type '%s'", tok);
            return 0;
		found:
			continue;
		}
	}
	if (0 == permcount) {
		warnx("No permissions specified");
        return 0;
    }
	acl_set_tag_type(newent, tag);
	acl_set_qualifier(newent, entryg);
	acl_set_permset(newent, perms);
	acl_set_flagset_np(newent, flags);
	free(entryg);

	return(0);
}

/* Convert one or more acl entries in string form to an acl_t */
acl_t
parse_acl_entries(const char *input) {
	acl_t acl_input;
	acl_entry_t newent;
	char *inbuf;
	char *oinbuf;

	char **bufp, *entryv[ACL_MAX_ENTRIES];
#if 0
/* XXX acl_from_text(), when implemented, will presumably use the canonical 
 * text representation format, which is what chmod should be using 
 * We may need to add an entry number to the input
 */
	/* Translate the user supplied ACL entry */
	/* acl_input = acl_from_text(input); */
#else
	inbuf = malloc(MAX_ACL_TEXT_SIZE);
	
    if (inbuf == NULL) {
		warn("malloc() failed");
        return 0;
    }
	strncpy(inbuf, input, MAX_ACL_TEXT_SIZE);
	inbuf[MAX_ACL_TEXT_SIZE - 1] = '\0';

    if ((acl_input = acl_init(1)) == NULL) {
		warn("acl_init() failed");
        return 0;
    }

	oinbuf = inbuf;

	for (bufp = entryv; (*bufp = strsep(&oinbuf, "\n")) != NULL;)
		if (**bufp != '\0') {
            if (0 != acl_create_entry(&acl_input, &newent)) {
				warn("acl_create_entry() failed");
                return 0;
            }
			if (0 != parse_entry(*bufp, newent)) {
				warnx("Failed parsing entry '%s'", *bufp);
                return 0;
			}
			if (++bufp >= &entryv[ACL_MAX_ENTRIES - 1]) {
				warnx("Too many entries");
                return 0;
			}
		}
	
	free(inbuf);
	return acl_input;
#endif	/* #if 0 */
}

/* XXX No Libc support for inherited entries and generation determination yet */
unsigned
get_inheritance_level(acl_entry_t entry) {
/* XXX to be implemented */
	return 1;
}

/* Determine a "score" for an acl entry. The entry scores higher if it's
 * tagged ACL_EXTENDED_DENY, and non-inherited entries are ranked higher
 * than inherited entries.
 */

int
score_acl_entry(acl_entry_t entry) {

	acl_tag_t	tag;
	acl_flagset_t	flags;
	acl_permset_t	perms;
	
	int score = 0;

	if (entry == NULL)
		return (MINIMUM_TIER);

	if (acl_get_tag_type(entry, &tag) != 0) {
		warn("Malformed ACL entry, no tag present");
        return 0;
	}
	if (acl_get_flagset_np(entry, &flags) != 0){
		warn("Unable to obtain flagset");
        return 0;
	}
    if (acl_get_permset(entry, &perms) != 0) {
		warn("Malformed ACL entry, no permset present");
        return 0;
    }
	switch(tag) {
	case ACL_EXTENDED_ALLOW:
		break;
	case ACL_EXTENDED_DENY:
		score++;
		break;
	default:
		warnx("Unknown tag type %d present in ACL entry", tag);
        return 0;
	        /* NOTREACHED */
	}

	if (acl_get_flag_np(flags, ACL_ENTRY_INHERITED))
		score += get_inheritance_level(entry) * INHERITANCE_TIER;

	return score;
}

int
compare_acl_qualifiers(uuid_t *qa, uuid_t *qb) {
	return bcmp(qa, qb, sizeof(uuid_t));
}

/* Compare two ACL permsets. 
 *  Returns :
 *  MATCH_SUBSET if bperms is a subset of aperms
 *  MATCH_SUPERSET if bperms is a superset of aperms
 *  MATCH_PARTIAL if the two permsets have a common subset
 *  MATCH_EXACT if the two permsets are identical
 *  MATCH_NONE if they are disjoint
 */

int
compare_acl_permsets(acl_permset_t aperms, acl_permset_t bperms)
{
	int i;
/* TBD Implement other match levels as needed */
	for (i = 0; acl_perms[i].name != NULL; i++) {
		if (acl_get_perm_np(aperms, acl_perms[i].perm) != 
		    acl_get_perm_np(bperms, acl_perms[i].perm))
			return MATCH_NONE;
	}
	return MATCH_EXACT;
}

static int
compare_acl_flagsets(acl_flagset_t aflags, acl_flagset_t bflags)
{
	int i;
/* TBD Implement other match levels as needed */
	for (i = 0; acl_flags[i].name != NULL; i++) {
		if (acl_get_flag_np(aflags, acl_flags[i].flag) != 
		    acl_get_flag_np(bflags, acl_flags[i].flag))
			return MATCH_NONE;
	}
	return MATCH_EXACT;
}

/* Compares two ACL entries for equality */
int
compare_acl_entries(acl_entry_t a, acl_entry_t b)
{
	acl_tag_t atag, btag;
	acl_permset_t aperms, bperms;
	acl_flagset_t aflags, bflags;
	int pcmp = 0, fcmp = 0;
	void *aqual, *bqual;

	aqual = acl_get_qualifier(a);
	bqual = acl_get_qualifier(b);

	int compare = compare_acl_qualifiers(aqual, bqual);
	acl_free(aqual);
	acl_free(bqual);

	if (compare != 0)
		return MATCH_NONE;

    if (0 != acl_get_tag_type(a, &atag)) {
		warn("No tag type present in entry");
        return 0;
    }
    if (0!= acl_get_tag_type(b, &btag)) {
		warn("No tag type present in entry");
        return 0;
    }
	if (atag != btag)
		return MATCH_NONE;

	if ((acl_get_permset(a, &aperms) != 0) ||
	    (acl_get_flagset_np(a, &aflags) != 0) ||
	    (acl_get_permset(b, &bperms) != 0) ||
        (acl_get_flagset_np(b, &bflags) != 0)) {
		warn("error fetching permissions");
        return 0;
    }

	pcmp = compare_acl_permsets(aperms, bperms);
	fcmp = compare_acl_flagsets(aflags, bflags);

	if ((pcmp == MATCH_NONE) || (fcmp == MATCH_NONE))
		return(MATCH_PARTIAL);
	else
		return(MATCH_EXACT);
}

/* Verify that an ACL is in canonical order. Currently, the canonical
 * form is:
 * local deny
 * local allow
 * inherited deny (parent)
 * inherited allow (parent)
 * inherited deny (grandparent)
 * inherited allow (grandparent)
 * ...
 */
unsigned int
is_canonical(acl_t acl) {
	
	unsigned aindex;
	acl_entry_t entry;
	int score = 0, next_score = 0;

/* XXX - is a zero entry ACL in canonical form? */	
	if (0 != acl_get_entry(acl, ACL_FIRST_ENTRY, &entry))
		return 1;

	score = score_acl_entry(entry);
	
	for (aindex = 0; acl_get_entry(acl, ACL_NEXT_ENTRY, &entry) == 0;
	     aindex++)	{
		if (score < (next_score = score_acl_entry(entry)))
			return 0;
		score = next_score;
	}
	return 1;
}


/* Iterate through an ACL, and find the canonical position for the
 * specified entry 
 */
unsigned int
find_canonical_position(acl_t acl, acl_entry_t modifier) {

	acl_entry_t entry;
	int mscore = 0;
	unsigned mpos = 0;

	/* Check if there's an entry with the same qualifier
	 * and tag type; if not, find the appropriate slot
	 * for the score.
	 */

	if (0 != acl_get_entry(acl, ACL_FIRST_ENTRY, &entry))
		return 0;

	mscore = score_acl_entry(modifier);

	while (mscore < score_acl_entry(entry)) {

		mpos++;

	       if (0 != acl_get_entry(acl, ACL_NEXT_ENTRY, &entry))
		       break;

	       }
	return mpos;
}

int canonicalize_acl_entries(acl_t acl);

/* For a given acl_entry_t "modifier", find the first exact or 
 * partially matching entry from the specified acl_t acl
 */

int
find_matching_entry (acl_t acl, acl_entry_t modifier, acl_entry_t *rentryp,
		     unsigned match_inherited) {

	acl_entry_t entry = NULL;

	unsigned aindex;
	int cmp, fcmp = MATCH_NONE;
	
	for (aindex = 0; 
	     acl_get_entry(acl, entry == NULL ? ACL_FIRST_ENTRY : 
			   ACL_NEXT_ENTRY, &entry) == 0;
	     aindex++)	{
		cmp = compare_acl_entries(entry, modifier);
		if ((cmp == MATCH_EXACT) || (cmp == MATCH_PARTIAL)) {
			if (match_inherited) {
				acl_flagset_t eflags, mflags;

                if (0 != acl_get_flagset_np(modifier, &mflags)) {
					warn("Unable to get flagset");
                    return 0;
                }
                if (0 != acl_get_flagset_np(entry, &eflags)) {
					warn("Unable to get flagset");
                    return 0;
                }
				if (compare_acl_flagsets(mflags, eflags) == MATCH_EXACT) {
					*rentryp = entry;
					fcmp = cmp;
				}
			}
			else {
				*rentryp = entry;
				fcmp = cmp;
			}
		}
		if (fcmp == MATCH_EXACT)
			break;
	}
	return fcmp;
}

/* Remove all perms specified in modifier from rentry*/
int
subtract_from_entry(acl_entry_t rentry, acl_entry_t  modifier, int* valid_perms)
{
	acl_permset_t rperms, mperms;
	acl_flagset_t rflags, mflags;
	if (valid_perms)
		*valid_perms = 0;
	int i;

	if ((acl_get_permset(rentry, &rperms) != 0) ||
	    (acl_get_flagset_np(rentry, &rflags) != 0) ||
	    (acl_get_permset(modifier, &mperms) != 0) ||
        (acl_get_flagset_np(modifier, &mflags) != 0)) {
		warn("error computing ACL modification");
        return 0;
    }

	for (i = 0; acl_perms[i].name != NULL; i++) {
		if (acl_get_perm_np(mperms, acl_perms[i].perm))
			acl_delete_perm(rperms, acl_perms[i].perm);
		else if (valid_perms && acl_get_perm_np(rperms, acl_perms[i].perm)) 
			(*valid_perms)++;
	}
	for (i = 0; acl_flags[i].name != NULL; i++) {
		if (acl_get_flag_np(mflags, acl_flags[i].flag))
			acl_delete_flag_np(rflags, acl_flags[i].flag);
	}
	acl_set_permset(rentry, rperms);
	acl_set_flagset_np(rentry, rflags);
	return 0;
}
/* Add the perms specified in modifier to rentry */
static int
merge_entry_perms(acl_entry_t rentry, acl_entry_t  modifier)
{
	acl_permset_t rperms, mperms;
	acl_flagset_t rflags, mflags;
	int i;

	if ((acl_get_permset(rentry, &rperms) != 0) ||
	    (acl_get_flagset_np(rentry, &rflags) != 0) ||
	    (acl_get_permset(modifier, &mperms) != 0) ||
        (acl_get_flagset_np(modifier, &mflags) != 0)) {
		warn("error computing ACL modification");
        return 0;
    }

	for (i = 0; acl_perms[i].name != NULL; i++) {
		if (acl_get_perm_np(mperms, acl_perms[i].perm))
			acl_add_perm(rperms, acl_perms[i].perm);
	}
	for (i = 0; acl_flags[i].name != NULL; i++) {
		if (acl_get_flag_np(mflags, acl_flags[i].flag))
			acl_add_flag_np(rflags, acl_flags[i].flag);
	}
	acl_set_permset(rentry, rperms);
	acl_set_flagset_np(rentry, rflags);
	return 0;
}

int
modify_acl(acl_t *oaclp, acl_entry_t modifier, unsigned int optflags,
	   int position, int inheritance_level, 
	   unsigned flag_new_acl, const char* path) {

	unsigned cpos = 0;
	acl_entry_t newent = NULL;
	int dmatch = 0;
	acl_entry_t rentry = NULL;
	unsigned retval = 0;
	acl_t oacl = *oaclp;
	
/* Add the inherited flag if requested by the user*/
	if (modifier && (optflags & ACL_INHERIT_FLAG)) {
		acl_flagset_t mflags;

		acl_get_flagset_np(modifier, &mflags);
		acl_add_flag_np(mflags, ACL_ENTRY_INHERITED);
		acl_set_flagset_np(modifier, mflags);
	}

	if (optflags & ACL_SET_FLAG) {
		if (position != -1) {
            if (0 != acl_create_entry_np(&oacl, &newent, position)) {
				warn("acl_create_entry() failed");
                return 0;
            }
			acl_copy_entry(newent, modifier);
		} else {
/* If an entry exists, add the new permissions to it, else add an
 * entry in the canonical position.
 */

/* First, check for a matching entry - if one exists, merge flags */
			dmatch = find_matching_entry(oacl, modifier, &rentry, 1);

			if (dmatch != MATCH_NONE) {
				if (dmatch == MATCH_EXACT)
/* Nothing to be done */
					goto ma_exit; 
				
				if (dmatch == MATCH_PARTIAL) {
					merge_entry_perms(rentry, modifier);
					goto ma_exit;
				}
			}
/* Insert the entry in canonical order */
			cpos = find_canonical_position(oacl, modifier);
            if (0!= acl_create_entry_np(&oacl, &newent, cpos)) {
				warn("acl_create_entry() failed");
                return 0;
            }
			acl_copy_entry(newent, modifier);
		}
	} else if (optflags & ACL_DELETE_FLAG) {
		if (flag_new_acl) {
			warnx("No ACL present '%s'", path);
			retval = 1;
		} else if (position != -1 ) {
			if (0 != acl_get_entry(oacl, position, &rentry)) {
				warnx("Invalid entry number '%s'", path);
				retval = 1;
			} else {
				acl_delete_entry(oacl, rentry);
			}
		} else {
			unsigned match_found = 0, aindex;
			for (aindex = 0; 
			     acl_get_entry(oacl, rentry == NULL ? 
					   ACL_FIRST_ENTRY : 
					   ACL_NEXT_ENTRY, &rentry) == 0;
			     aindex++)	{
				unsigned cmp;
				cmp = compare_acl_entries(rentry, modifier);
				if ((cmp == MATCH_EXACT) || 
				    (cmp == MATCH_PARTIAL)) {
					match_found++;
					if (cmp == MATCH_EXACT)
						acl_delete_entry(oacl, rentry);
					else {
						int valid_perms;
/* In the event of a partial match, remove the specified perms from the 
 * entry */
						subtract_from_entry(rentry, modifier, &valid_perms);
						/* if no perms survived then delete the entry */
						if (valid_perms == 0)
							acl_delete_entry(oacl, rentry);
					}
				}
			}
			if (0 == match_found) {
				warnx("Entry not found when attempting delete '%s'",path);
				retval = 1;
			}
		}
	} else if (optflags & ACL_REWRITE_FLAG) {
		acl_entry_t rentry;
		
		if (-1 == position) {
			chmod_usage();
            return 0;
		}
		if (0 == flag_new_acl) {
			if (0 != acl_get_entry(oacl, position,
                                   &rentry)) {
				warn("Invalid entry number '%s'", path);
                return 0;
            }
            if (0 != acl_delete_entry(oacl, rentry)) {
				warn("Unable to delete entry '%s'", path);
                return 0;
            }
        }
        if (0!= acl_create_entry_np(&oacl, &newent, position)) {
			warn("acl_create_entry() failed");
            return 0;
        }
		acl_copy_entry(newent, modifier);
	}
ma_exit:
	*oaclp = oacl;
	return retval;
}

int
modify_file_acl(unsigned int optflags, const char *path, acl_t modifier, int position, int inheritance_level, int follow) {
	
	acl_t oacl = NULL;
	unsigned aindex  = 0, flag_new_acl = 0;
	acl_entry_t newent = NULL;
	acl_entry_t entry = NULL;
	unsigned retval = 0;

	extern int fflag;

/* XXX acl_get_file() returns a zero entry ACL if an ACL was previously
 * associated with the file, and has had its entries removed.
 * However, POSIX 1003.1e states that a zero entry ACL should be 
 * returned if the caller asks for ACL_TYPE_DEFAULT, and no ACL is 
 * associated with the path; it
 * does not specifically state that a request for ACL_TYPE_EXTENDED
 * should not return a zero entry ACL, however.
 */

/* Determine if we've been given a zero entry ACL, or create an ACL if 
 * none exists. There are some issues to consider here: Should we create
 * a zero-entry ACL for a delete or check canonicity operation?
 */

    if (path == NULL) {
		chmod_usage();
        return 0;
    }

	if (optflags & ACL_CLEAR_FLAG) {
		filesec_t fsec = filesec_init();
		if (fsec == NULL) {
			warn("filesec_init() failed");
            return 0;
		}
		if (filesec_set_property(fsec, FILESEC_ACL, _FILESEC_REMOVE_ACL) != 0) {
			warn("filesec_set_property() failed");
            return 0;
                }
		if (follow) {
			if (chmodx_np(path, fsec) != 0) {
                                if (!fflag) {
					warn("Failed to clear ACL on file %s", path);
				}
				retval = 1;
			}
		} else {
			int fd = open(path, O_SYMLINK);
			if (fd != -1) {
				if (fchmodx_np(fd, fsec) != 0) {
					if (!fflag) {
						warn("Failed to clear ACL on file %s", path);
					}
					retval = 1;
				}
				close(fd);
			} else {
				if (!fflag) {
					warn("Failed to open file %s", path);
                }
				retval = 1;
			}
		}
		filesec_free(fsec);
		return (retval);
	}

	if (optflags & ACL_FROM_STDIN) {
		oacl = acl_dup(modifier);
	} else {
		if (follow) {
			oacl = acl_get_file(path, ACL_TYPE_EXTENDED);
		} else {
			int fd = open(path, O_SYMLINK);
			if (fd != -1) {
				oacl = acl_get_fd_np(fd, ACL_TYPE_EXTENDED);
				close(fd);
			}
		}
		if ((oacl == NULL) ||
		    (acl_get_entry(oacl,ACL_FIRST_ENTRY, &newent) != 0)) {
            if ((oacl = acl_init(1)) == NULL) {
				warn("acl_init() failed");
                return 0;
            }
			flag_new_acl = 1;
			position = 0;
		}
	
		if ((0 == flag_new_acl) && (optflags & (ACL_REMOVE_INHERIT_FLAG | 
							ACL_REMOVE_INHERITED_ENTRIES))) {
			acl_t facl = NULL;
            if ((facl = acl_init(1)) == NULL) {
				warn("acl_init() failed");
                return 0;
            }
            for (aindex = 0;
			     acl_get_entry(oacl, 
					   (entry == NULL ? ACL_FIRST_ENTRY : 
					    ACL_NEXT_ENTRY), &entry) == 0; 
			     aindex++) {
				acl_flagset_t eflags;
				acl_entry_t fent = NULL;
				if (acl_get_flagset_np(entry, &eflags) != 0) {
					warn("Unable to obtain flagset");
                    return 0;
				}
				
				if (acl_get_flag_np(eflags, ACL_ENTRY_INHERITED)) {
					if (optflags & ACL_REMOVE_INHERIT_FLAG) {
						acl_delete_flag_np(eflags, ACL_ENTRY_INHERITED);
						acl_set_flagset_np(entry, eflags);
						acl_create_entry(&facl, &fent);
						acl_copy_entry(fent, entry);
					}
				}
				else {
					acl_create_entry(&facl, &fent);
					acl_copy_entry(fent, entry);
				}
			}
			if (oacl)
				acl_free(oacl);
			oacl = facl;
		} else if (optflags & ACL_TO_STDOUT) {
			ssize_t len; /* need to get printacl() from ls(1) */
			char *text = acl_to_text(oacl, &len);
			puts(text);
			acl_free(text);
		} else if (optflags & ACL_CHECK_CANONICITY) {
			if (flag_new_acl) {
				warnx("No ACL currently associated with file '%s'", path);
			}
			retval = is_canonical(oacl);
		} else if ((optflags & ACL_SET_FLAG) && (position == -1) && 
		    (!is_canonical(oacl))) {
			warnx("The specified file '%s' does not have an ACL in canonical order, please specify a position with +a# ", path);
			retval = 1;
		} else if (((optflags & ACL_DELETE_FLAG) && (position != -1))
		    || (optflags & ACL_CHECK_CANONICITY)) {
			retval = modify_acl(&oacl, NULL, optflags, position, 
					    inheritance_level, flag_new_acl, path);
		} else if ((optflags & (ACL_REMOVE_INHERIT_FLAG|ACL_REMOVE_INHERITED_ENTRIES)) && flag_new_acl) {
			warnx("No ACL currently associated with file '%s'", path);
			retval = 1;
		} else {
			if (!modifier) { /* avoid bus error in acl_get_entry */
				warnx("Internal error: modifier should not be NULL");
                return 0;
			}
			for (aindex = 0; 
			     acl_get_entry(modifier, 
					   (entry == NULL ? ACL_FIRST_ENTRY : 
					    ACL_NEXT_ENTRY), &entry) == 0; 
			     aindex++) {

				retval += modify_acl(&oacl, entry, optflags, 
						     position, inheritance_level, 
						     flag_new_acl, path);
			}
		}
	}

/* XXX Potential race here, since someone else could've modified or
 * read the ACL on this file (with the intention of modifying it) in
 * the interval from acl_get_file() to acl_set_file(); we can
 * minimize one aspect of this  window by comparing the original acl
 * to a fresh one from acl_get_file() but we could consider a
 * "changeset" mechanism, common locking  strategy, or kernel
 * supplied reservation mechanism to prevent this race.
 */
	if (!(optflags & (ACL_TO_STDOUT|ACL_CHECK_CANONICITY))) {
		int status = -1;
		if (follow) {
	    		status = acl_set_file(path, ACL_TYPE_EXTENDED, oacl);
		} else {
			int fd = open(path, O_SYMLINK);
			if (fd != -1) {
				status = acl_set_fd_np(fd, oacl,
							ACL_TYPE_EXTENDED);
				close(fd);
			}
		}
		if (status != 0) {
            if (!fflag) {
				warn("Failed to set ACL on file '%s'", path);
            }
			retval = 1;
		}
	}
	
	if (oacl)
		acl_free(oacl);
	
	return retval;
}

#endif /*__APPLE__*/
