/* expand-common - common functionality for expand/unexapnd

   Copyright (C) 1989-2017 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* If true, convert blanks even after nonblank characters have been
   read on the line.  */
extern bool convert_entire_line;

/* The maximum distance between tab stops.  */
extern size_t max_column_width;

/* Null-terminated array of input filenames.  */
//extern char **file_list;

/* Default for 'file_list' if no files are given on the command line.  */
//extern char *stdin_argv[];

/* True if we have ever read standard input.  */
//extern bool have_read_stdin;

/* The desired exit status.  */
extern int exit_status;

/* Add tab stop TABVAL to the end of 'tab_list'.  */
extern void
add_tab_stop (uintmax_t tabval);

/* Add the comma or blank separated list of tab stops STOPS
   to the list of tab stops.  */
extern void
parse_tab_stops (char const *stops);

/* TODO: Document */
extern uintmax_t
get_next_tab_column (const uintmax_t column, size_t* tab_index,
                     bool* last_tab);

/* Called after all command-line options have been parsed,
   sets the final tab-stops values */
extern void
finalize_tab_stops (void);




/* Sets new file-list */
extern void
set_file_list (char **file_list);

/* Close the old stream pointer FP if it is non-NULL,
   and return a new one opened to read the next input file.
   Open a filename of '-' as the standard input.
   Return NULL if there are no more input files.  */
extern FILE *
next_file (FILE *fp);

/* */
extern void
cleanup_file_list_stdin (void);
