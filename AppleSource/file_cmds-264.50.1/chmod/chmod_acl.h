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

#ifdef __APPLE__
#include <pwd.h>
#include <grp.h>
#include <ctype.h>
#include <sys/acl.h>
#include <sys/kauth.h>
#include <uuid/uuid.h>

#define ACL_FLAG (1<<0)
#define ACL_SET_FLAG (1<<1)
#define ACL_DELETE_FLAG (1<<2)
#define ACL_REWRITE_FLAG (1<<3)
#define ACL_ORDER_FLAG (1<<4)
#define ACL_INHERIT_FLAG (1<<5)
#define ACL_FOLLOW_LINK (1<<6)
#define ACL_FROM_STDIN (1<<7)
#define ACL_CHECK_CANONICITY (1<<8)
#define ACL_REMOVE_INHERIT_FLAG (1<<9)
#define ACL_REMOVE_INHERITED_ENTRIES (1<<10)
#define ACL_NO_TRANSLATE (1<<11)
#define ACL_INVOKE_EDITOR (1<<12)
#define ACL_TO_STDOUT (1<<13)
#define ACL_CLEAR_FLAG (1<<14)

#define INHERITANCE_TIER (-5)
#define MINIMUM_TIER (-1000)

#define MATCH_EXACT (2)
#define MATCH_PARTIAL (1)
#define MATCH_NONE (-1)
#define MATCH_SUBSET (-2)
#define MATCH_SUPERSET (-3)

#define MAX_ACL_TEXT_SIZE 4096
#define MAX_INHERITANCE_LEVEL 1024

extern int search_acl_block(char *tok);
extern int parse_entry(char *entrybuf, acl_entry_t newent);
extern acl_t parse_acl_entries(const char *input);
extern int score_acl_entry(acl_entry_t entry);
extern unsigned get_inheritance_level(acl_entry_t entry);
extern int compare_acl_qualifiers(uuid_t *qa, uuid_t *qb);
extern int compare_acl_permsets(acl_permset_t aperms, acl_permset_t bperms);
extern int compare_acl_entries(acl_entry_t a, acl_entry_t b);
extern unsigned is_canonical(acl_t acl);
extern int find_matching_entry (acl_t acl, acl_entry_t modifier, acl_entry_t *rentry, unsigned match_inherited);
extern unsigned find_canonical_position(acl_t acl, acl_entry_t modifier);
extern int subtract_from_entry(acl_entry_t rentry, acl_entry_t modifier, int *valid_perms);
extern int modify_acl(acl_t *oaclp, acl_entry_t modifier, unsigned int optflags, int position, int inheritance_level, unsigned flag_new_acl, const char* path);
extern int modify_file_acl(unsigned int optflags, const char *path, acl_t modifier, int position, int inheritance_level, int follow);
extern uuid_t *name_to_uuid(char *tok, int nametype);
#endif /* __APPLE__*/
