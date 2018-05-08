/*
 * Copyright (c) 2017-2018, Marcin Konarski (amok at codestation.org)
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

#ifndef HAVE_REPLXX_HXX_INCLUDED
#define HAVE_REPLXX_HXX_INCLUDED 1

#include <memory>
#include <vector>
#include <string>
#include <functional>

namespace replxx {

class Replxx {
public:
	enum class Color {
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
	};
	typedef std::vector<Color> colors_t;
	typedef std::vector<std::string> completions_t;
	typedef std::vector<std::string> hints_t;
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
	 * \param userData - pointer to opaque user data block.
	 * \return A list of user completions.
	 */
	typedef std::function<completions_t ( std::string const& input, int breakPos, void* userData)> completion_callback_t;

	/*! \brief Highlighter callback type definition.
	 *
	 * If user want to have colorful input she must simply install highlighter callback.
	 * The callback would be invoked by the library after each change to the input done by
	 * the user. After callback returns library uses data from colors buffer to colorize
	 * displayed user input.
	 *
	 * Size of \e colors buffer is equal to number of code points in user \e input
	 * which will be different from simple `input.lenght()`!
	 *
	 * \param input - an UTF-8 encoded input entered by the user so far.
	 * \param colors - output buffer for color information.
	 * \param userData - pointer to opaque user data block.
	 */
	typedef std::function<void ( std::string const& input, colors_t& colors, void* userData )> highlighter_callback_t;

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
	 * \param color - a color used for displaying hints.
	 * \param userData - pointer to opaque user data block.
	 * \return A list of possible hints.
	 */
	typedef std::function<hints_t ( std::string const& input, int breakPos, Color& color, void* userData )> hint_callback_t;

	class ReplxxImpl;
private:
	typedef std::unique_ptr<ReplxxImpl, void (*)( ReplxxImpl* )> impl_t;
	impl_t _impl;

public:
	Replxx( void );
	Replxx( Replxx&& ) = default;
	Replxx& operator = ( Replxx&& ) = default;

	/*! \brief Register completion callback.
	 *
	 * \param fn - user defined callback function.
	 * \param userData - pointer to opaque user data block to be passed into each invocation of the callback.
	 */
	void set_completion_callback( completion_callback_t const& fn, void* userData );

	/*! \brief Register highlighter callback.
	 *
	 * \param fn - user defined callback function.
	 * \param userData - pointer to opaque user data block to be passed into each invocation of the callback.
	 */
	void set_highlighter_callback( highlighter_callback_t const& fn, void* userData );

	/*! \brief Register hints callback.
	 *
	 * \param fn - user defined callback function.
	 * \param userData - pointer to opaque user data block to be passed into each invocation of the callback.
	 */
	void set_hint_callback( hint_callback_t const& fn, void* userData );

	/*! \brief Read line of user input.
	 *
	 * \param prompt - prompt to be displayed before getting user input.
	 * \return An UTF-8 encoded input given by the user (or nullptr on EOF).
	 */
	char const* input( std::string const& prompt );

	/*! \brief Print formatted string to standard output.
	 *
	 * This function ensures proper handling of ANSI escape sequences
	 * contained in printed data, which is especially useful on Windows
	 * since Unixes handle them correctly out of the box.
	 *
	 * \param fmt - printf style format.
	 */
	int print( char const* fmt, ... );

	void history_add( std::string const& line );
	int history_save( std::string const& filename );
	int history_load( std::string const& filename );
	int history_size( void ) const;
	std::string const& history_line( int index );

	void set_preload_buffer( std::string const& preloadText );

	/*! \brief Set set of word break characters.
	 *
	 * This setting influences \e breakPos in completion and hints callbacks
	 * and how completions are printed.
	 *
	 * \param wordBreakers - 7-bit ASCII set of word breaking characters.
	 */
	void set_word_break_characters( char const* wordBreakers );

	/*! \brief Set special prefixes.
	 *
	 * Special prefixes are word breaking characters
	 * that do not affect \e breakPos in completion and hints callbacks.
	 *
	 * \param specialPrefixes - 7-bit ASCII set of special prefixes.
	 */
	void set_special_prefixes( char const* specialPrefixes );

	/*! \brief Set maximum allowed length of user input.
	 */
	void set_max_line_size( int len );

	/*! \brief Set maximum number of displayed hint rows.
	 */
	void set_max_hint_rows( int count );

	/*! \brief Set tab completion behavior.
	 *
	 * \param val - use double tab to invoke completions.
	 */
	void set_double_tab_completion( bool val );

	/*! \brief Set tab completion behavior.
	 *
	 * \param val - invoke completion even if user input is empty.
	 */
	void set_complete_on_empty( bool val );

	/*! \brief Set tab completion behavior.
	 *
	 * \param val - beep if completion is ambiguous.
	 */
	void set_beep_on_ambiguous_completion( bool val );

	/*! \brief Disable output coloring.
	 *
	 * \param val - if set to non-zero disable output colors.
	 */
	void set_no_color( bool val );

	/*! \brief Set maximum number of entries in history list.
	 */
	void set_max_history_size( int len );
	void clear_screen( void );
	int install_window_change_handler( void );

private:
	Replxx( Replxx const& ) = delete;
	Replxx& operator = ( Replxx const& ) = delete;
};

}

#endif /* HAVE_REPLXX_HXX_INCLUDED */

