/* linenoise.h -- guerrilla line editing library against the idea that a
 * line editing lib needs to be 20,000 lines of C code.
 *
 * See linenoise.c for more information.
 *
 * Copyright (c) 2010, Salvatore Sanfilippo <antirez at gmail dot com>
 * Copyright (c) 2010, Pieter Noordhuis <pcnoordhuis at gmail dot com>
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   * Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *   * Neither the name of Redis nor the names of its contributors may be used
 *     to endorse or promote products derived from this software without
 *     specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef __REPLXX_H
#define __REPLXX_H

#define REPLXX_VERSION "0.0.1"
#define REPLXX_VERSION_MAJOR 0
#define REPLXX_VERSION_MINOR 0

#ifdef __cplusplus
extern "C" {
#endif

/*! \brief Color definitions to use in highlighter callbacks.
 */
typedef enum {
	BLACK         = 0,
	RED           = 1,
	GREEN         = 2,
	BROWN         = 3,
	BLUE          = 4,
	MAGENTA       = 5,
	CYAN          = 6,
	LIGHTGRAY     = 7,
	GRAY          = 8,
	BRIGHTRED     = 9,
	BRIGHTGREEN   = 10,
	YELLOW        = 11,
	BRIGHTBLUE    = 12,
	BRIGHTMAGENTA = 13,
	BRIGHTCYAN    = 14,
	WHITE         = 15,
	NORMAL        = LIGHTGRAY,
	DEFAULT       = -1,
#undef ERROR
	ERROR         = -2
} ReplxxColor;

typedef struct Replxx Replxx;

/*! \brief Create Replxx library resouce holder.
 *
 * Use replxx_end() to free resoiurce acquired with this function.
 *
 * \param in - opened input file stream.
 * \param out - opened output file stream.
 * \param err - opened error file stream.
 * \return Replxx library resouce holder.
 */
Replxx* replxx_init( void );

/*! \brief Cleanup resources used by Replxx library.
 *
 * \param replxx - a Replxx library resource holder.
 */
void replxx_end( Replxx* replxx );

/*! \brief Highlighter callback type definition.
 *
 * If user want to have colorful input she must simply install highlighter callback.
 * The callback would be invoked by the library after each change to the input done by
 * the user. After callback returns library uses data from colors buffer to colorize
 * displayed user input.
 *
 * \e size of \e colors buffer is equal to number of code points in user \e input
 * which will be different from simple `strlen( input )`!
 *
 * \param input - an UTF-8 encoded input entered by the user so far.
 * \param colors - output buffer for color information.
 * \param size - size of output buffer for color information.
 * \param userData - pointer to opaque user data block.
 */
typedef void (replxx_highlighter_callback_t)(char const* input, ReplxxColor* colors, int size, void* userData);

/*! \brief Register highlighter callback.
 *
 * \param fn - user defined callback function.
 * \param userData - pointer to opaque user data block to be passed into each invocation of the callback.
 */
void replxx_set_highlighter_callback( Replxx*, replxx_highlighter_callback_t* fn, void* userData );

typedef struct replxx_completions replxx_completions;

/*! \brief Completions callback type definition.
 *
 * \e breakPos is counted in Unicode code points (not in bytes!).
 *
 * For user input:
 * if ( obj.me
 *
 * input == "if ( obj.me"
 * breakPos == 4 or breakPos == 8 (depending on \e replxx_set_word_break_characters())
 *
 * \param input - the whole UTF-8 encoded input entered by the user so far.
 * \param breakPos - index of last break character before cursor.
 * \param completions - pointer to opaque list of user completions.
 * \param userData - pointer to opaque user data block.
 */
typedef void(replxx_completion_callback_t)(const char* input, int breakPos, replxx_completions* completions, void* userData);

/*! \brief Register completion callback.
 *
 * \param fn - user defined callback function.
 * \param userData - pointer to opaque user data block to be passed into each invocation of the callback.
 */
void replxx_set_completion_callback( Replxx*, replxx_completion_callback_t* fn, void* userData );

/*! \brief Add another possible completion for current user input.
 *
 * \param completions - pointer to opaque list of user completions.
 * \param str - UTF-8 encoded completion string.
 */
void replxx_add_completion( replxx_completions* completions, const char* str );

typedef struct replxx_hints replxx_hints;

/*! \brief Hints callback type definition.
 *
 * \e breakPos is counted in Unicode code points (not in bytes!).
 *
 * For user input:
 * if ( obj.me
 *
 * input == "if ( obj.me"
 * breakPos == 4 or breakPos == 8 (depending on replxx_set_word_break_characters())
 *
 * \param input - the whole UTF-8 encoded input entered by the user so far.
 * \param breakPos - index of last break character before cursor.
 * \param hints - pointer to opaque list of possible hints.
 * \param color - a color used for displaying hints.
 * \param userData - pointer to opaque user data block.
 */
typedef void(replxx_hint_callback_t)(const char* input, int breakPos, replxx_hints* hints, ReplxxColor* color, void* userData);

/*! \brief Register hints callback.
 *
 * \param fn - user defined callback function.
 * \param userData - pointer to opaque user data block to be passed into each invocation of the callback.
 */
void replxx_set_hint_callback( Replxx*, replxx_hint_callback_t* fn, void* userData );

/*! \brief Add another possible hint for current user input.
 *
 * \param hints - pointer to opaque list of hints.
 * \param str - UTF-8 encoded hint string.
 */
void replxx_add_hint( replxx_hints* hints, const char* str );

/*! \brief Read line of user input.
 *
 * \param prompt - prompt to be displayed before getting user input.
 * \return An UTF-8 encoded input given by the user (or nullptr on EOF).
 */
void blink_replxx_replace_streams( Replxx*, FILE *, FILE *, FILE *, struct winsize *);
char const* replxx_input( Replxx*, const char* prompt );


/*! \brief Print formatted string to standard output.
 *
 * This function ensures proper handling of ANSI escape sequences
 * contained in printed data, which is especially useful on Windows
 * since Unixes handle them correctly out of the box.
 *
 * \param fmt - printf style format.
 */
int replxx_print( Replxx*, char const* fmt, ... );

void replxx_set_preload_buffer( Replxx*, const char* preloadText );

void replxx_history_add( Replxx*, const char* line );
int replxx_history_size( Replxx* );

/*! \brief Set set of word break characters.
 *
 * This setting influences \e breakPos in completion and hints callbacks
 * and how completions are printed.
 *
 * \param wordBreakers - 7-bit ASCII set of word breaking characters.
 */
void replxx_set_word_break_characters( Replxx*, char const* wordBreakers );

/*! \brief Set special prefixes.
 *
 * Special prefixes are word breaking characters
 * that do not affect \e breakPos in completion and hints callbacks.
 *
 * \param specialPrefixes - 7-bit ASCII set of special prefixes.
 */
void replxx_set_special_prefixes( Replxx*, char const* specialPrefixes );

/*! \brief Set maximum allowed length of user input.
 */
void replxx_set_max_line_size( Replxx*, int len );

/*! \brief Set maximum number of displayed hint rows.
 */
void replxx_set_max_hint_rows( Replxx*, int count );

/*! \brief Set tab completion behavior.
 *
 * \param val - use double tab to invoke completions (if != 0).
 */
void replxx_set_double_tab_completion( Replxx*, int val );

/*! \brief Set tab completion behavior.
 *
 * \param val - invoke completion even if user input is empty (if != 0).
 */
void replxx_set_complete_on_empty( Replxx*, int val );

/*! \brief Set tab completion behavior.
 *
 * \param val - beep if completion is ambiguous (if != 0).
 */
void replxx_set_beep_on_ambiguous_completion( Replxx*, int val );

/*! \brief Disable output coloring.
 *
 * \param val - if set to non-zero disable output colors.
 */
void replxx_set_no_color( Replxx*, int val );

/*! \brief Set maximum number of entries in history list.
 */
void replxx_set_max_history_size( Replxx*, int len );
char const* replxx_history_line( Replxx*, int index );
int replxx_history_save( Replxx*, const char* filename );
int replxx_history_load( Replxx*, const char* filename );
void replxx_clear_screen( Replxx* );
void replxx_clear_screen_to_end( Replxx* );
void replxx_debug_dump_print_codes(void);
/* the following is extension to the original linenoise API */
int replxx_install_window_change_handler( Replxx* );
int replxx_window_changed( Replxx* );

#ifdef __cplusplus
}
#endif

#endif /* __REPLXX_H */

