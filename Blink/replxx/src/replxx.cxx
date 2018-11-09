/*
 * Copyright (c) 2017-2018, Marcin Konarski (amok at codestation.org)
 * Copyright (c) 2010, Salvatore Sanfilippo <antirez at gmail dot com>
 * Copyright (c) 2010, Pieter Noordhuis <pcnoordhuis at gmail dot com>
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *	 * Redistributions of source code must retain the above copyright notice,
 *		 this list of conditions and the following disclaimer.
 *	 * Redistributions in binary form must reproduce the above copyright
 *		 notice, this list of conditions and the following disclaimer in the
 *		 documentation and/or other materials provided with the distribution.
 *	 * Neither the name of Redis nor the names of its contributors may be used
 *		 to endorse or promote products derived from this software without
 *		 specific prior written permission.
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
 *
 * line editing lib needs to be 20,000 lines of C code.
 *
 * You can find the latest source code at:
 *
 *	 http://github.com/antirez/linenoise
 *
 * Does a number of crazy assumptions that happen to be true in 99.9999% of
 * the 2010 UNIX computers around.
 *
 * References:
 * - http://invisible-island.net/xterm/ctlseqs/ctlseqs.html
 * - http://www.3waylabs.com/nw/WWW/products/wizcon/vt220.html
 *
 * Todo list:
 * - Switch to gets() if $TERM is something we can't support.
 * - Filter bogus Ctrl+<char> combinations.
 * - Win32 support
 *
 * Bloat:
 * - Completion?
 * - History search like Ctrl+r in readline?
 *
 * List of escape sequences used by this program, we do everything just
 * with three sequences. In order to be so cheap we may have some
 * flickering effect with some slow terminal, but the lesser sequences
 * the more compatible.
 *
 * CHA (Cursor Horizontal Absolute)
 *		Sequence: ESC [ n G
 *		Effect: moves cursor to column n (1 based)
 *
 * EL (Erase Line)
 *		Sequence: ESC [ n K
 *		Effect: if n is 0 or missing, clear from cursor to end of line
 *		Effect: if n is 1, clear from beginning of line to cursor
 *		Effect: if n is 2, clear entire line
 *
 * CUF (Cursor Forward)
 *		Sequence: ESC [ n C
 *		Effect: moves cursor forward of n chars
 *
 * The following are used to clear the screen: ESC [ H ESC [ 2 J
 * This is actually composed of two sequences:
 *
 * cursorhome
 *		Sequence: ESC [ H
 *		Effect: moves the cursor to upper left corner
 *
 * ED2 (Clear entire screen)
 *		Sequence: ESC [ 2 J
 *		Effect: clear the whole screen
 *
 */

#include <string>
#include <vector>
#include <algorithm>
#include <memory>
#include <cerrno>
#include <cstdarg>
#include <cassert>

#ifdef _WIN32

#include <conio.h>
#include <windows.h>
#include <io.h>
#if _MSC_VER < 1900
#define snprintf _snprintf	// Microsoft headers use underscores in some names
#endif
#define strcasecmp _stricmp
#define write _write
#define STDIN_FILENO 0

#else /* _WIN32 */

#include <signal.h>
#include <unistd.h>
#include <sys/stat.h>

#endif /* _WIN32 */

#include "replxx.h"
#include "replxx.hxx"
#include "conversion.hxx"

#ifdef _WIN32
#include "windows.hxx"
#endif

#include "replxx_impl.hxx"
#include "prompt.hxx"
#include "io.hxx"
#include "util.hxx"
#include "inputbuffer.hxx"
#include "keycodes.hxx"
#include "escape.hxx"
#include "history.hxx"

using namespace std;
using namespace std::placeholders;
using namespace replxx;


namespace replxx {
  
  int printf (const char *format, ...) {
    va_list arg;
    int done;
    
    va_start (arg, format);
    done = vfprintf (thread_stdout, format, arg);
    va_end (arg);
    
    return done;
  }

#ifndef _WIN32

__thread bool gotResize = false;

#endif

namespace {

static int const REPLXX_MAX_LINE( 4096 );
static int const REPLXX_MAX_HINT_ROWS( 4 );
//char const defaultBreakChars[] = " =+-/\\*?\"'`&<>;|@{([])}";
char const defaultBreakChars[] = " =+\\*?\"'`&<>;|@{([])}";

#ifndef _WIN32

static void WindowSizeChanged(int) {
	// do nothing here but setting this flag
	gotResize = true;
}

#endif

static const char* unsupported_term[] = {"dumb", "cons25", "emacs", NULL};

static bool isUnsupportedTerm(void) {
	char* term = getenv("TERM");
	if (term == NULL) {
		return false;
	}
	for (int j = 0; unsupported_term[j]; ++j) {
		if (!strcasecmp(term, unsupported_term[j])) {
			return true;
		}
	}
	return false;
}

}

Replxx::ReplxxImpl::ReplxxImpl( FILE*, FILE*, FILE* )
	: _maxLineLength( REPLXX_MAX_LINE )
	, _inputBuffer( new char[_maxLineLength * sizeof ( char32_t ) + 1] )
	, _history()
	, _killRing()
	, _maxHintRows( REPLXX_MAX_HINT_ROWS )
	, _breakChars( defaultBreakChars )
	, _specialPrefixes( "" )
	, _completionCountCutoff( 100 )
	, _doubleTabCompletion( false )
	, _completeOnEmpty( true )
	, _beepOnAmbiguousCompletion( false )
	, _noColor( false )
	, _completionCallback( nullptr )
	, _highlighterCallback( nullptr )
	, _hintCallback( nullptr )
	, _completionUserdata( nullptr )
	, _highlighterUserdata( nullptr )
	, _hintUserdata( nullptr )
	, _preloadedBuffer()
	, _errorMessage() {
}

void Replxx::ReplxxImpl::history_add( std::string const& line ) {
	_history.add( line );
}

int Replxx::ReplxxImpl::history_save( std::string const& filename ) {
	return ( _history.save( filename ) );
}

int Replxx::ReplxxImpl::history_load( std::string const& filename ) {
	return ( _history.load( filename ) );
}

int Replxx::ReplxxImpl::history_size( void ) const {
	return ( _history.size() );
}

Replxx::ReplxxImpl::completions_t Replxx::ReplxxImpl::call_completer( std::string const& input, int breakPos ) const {
	Replxx::completions_t completionsIntermediary(
		!! _completionCallback
			? _completionCallback( input, breakPos, _completionUserdata )
			: Replxx::completions_t()
	);
	completions_t completions;
	completions.reserve( completionsIntermediary.size() );
	for ( std::string const& c : completionsIntermediary ) {
		completions.emplace_back( c.c_str() );
	}
	return ( completions );
}

Replxx::ReplxxImpl::hints_t Replxx::ReplxxImpl::call_hinter( std::string const& input, int breakPos, Replxx::Color& color ) const {
	Replxx::hints_t hintsIntermediary(
		!! _hintCallback
			? _hintCallback( input, breakPos, color, _hintUserdata )
			: Replxx::hints_t()
	);
	hints_t hints;
	hints.reserve( hintsIntermediary.size() );
	for ( std::string const& h : hintsIntermediary ) {
		hints.emplace_back( h.c_str() );
	}
	return ( hints );
}

void Replxx::ReplxxImpl::call_highlighter( std::string const& input, Replxx::colors_t& colors ) const {
	if ( !! _highlighterCallback ) {
		_highlighterCallback( input, colors, _highlighterUserdata );
	}
}

void Replxx::ReplxxImpl::set_preload_buffer( std::string const& preloadText ) {
	_preloadedBuffer = preloadText;
	// remove characters that won't display correctly
	bool controlsStripped = false;
	int whitespaceSeen( 0 );
	for ( std::string::iterator it( _preloadedBuffer.begin() ); it != _preloadedBuffer.end(); ) {
		unsigned char c = *it;
		if ( '\r' == c ) { // silently skip CR
			_preloadedBuffer.erase( it, it + 1 );
			continue;
		}
		if ( '\n' == c || '\t' == c ) { // note newline or tab
			++ whitespaceSeen;
			++ it;
			continue;
		}
		if ( whitespaceSeen > 0 ) {
			it -= whitespaceSeen;
			*it = ' ';
			_preloadedBuffer.erase( it + 1, it + whitespaceSeen - 1 );
		}
		if ( isControlChar( c ) ) { // remove other control characters, flag for message
			controlsStripped = true;
			if ( whitespaceSeen > 0 ) {
				_preloadedBuffer.erase( it, it + 1 );
				-- it;
			} else {
				*it = ' ';
			}
		}
		whitespaceSeen = 0;
		++ it;
	}
	bool lineTruncated = false;
	int processedLength( static_cast<int>( _preloadedBuffer.length() ) );
	if ( processedLength > ( _maxLineLength - 1 ) ) {
		lineTruncated = true;
		_preloadedBuffer.erase( _maxLineLength );
	}
	_errorMessage.clear();
	if ( controlsStripped ) {
		_errorMessage.assign( " [Edited line: control characters were converted to spaces]\n" );
	}
	if (lineTruncated) {
		_errorMessage
			.append( " [Edited line: the line length was reduced from " )
			.append( to_string( processedLength ) )
			.append( " to " )
			.append( to_string( _preloadedBuffer.length() ) )
			.append( "]\n" );
	}
}
  
void Replxx::ReplxxImpl::blink_replace_streams(FILE * in, FILE * out, FILE *err, struct winsize *win) {
  setWinsize(win, in, out, err);
  
  thread_stdin = in;
  thread_stdout = out;
  thread_stderr = err;
}
  


char const* Replxx::ReplxxImpl::input( std::string const& prompt ) {
#ifndef _WIN32
	gotResize = false;
#endif
	errno = 0;
	if ( tty::in ) {	// input is from a terminal
		if (!_errorMessage.empty()) {
			fprintf(thread_stdout, "%s", _errorMessage.c_str());
			fflush(thread_stdout);
			_errorMessage.clear();
		}
		PromptInfo pi(prompt, getScreenColumns());
		if (isUnsupportedTerm()) {
			if (!pi.write()) return 0;
			fflush(thread_stdout);
			if (_preloadedBuffer.empty()) {
				if (fgets(_inputBuffer.get(), _maxLineLength, thread_stdin) == NULL) {
					return NULL;
				}
				size_t len = strlen(_inputBuffer.get());
				while (len && (_inputBuffer[len - 1] == '\n' || _inputBuffer[len - 1] == '\r')) {
					--len;
					_inputBuffer[len] = '\0';
				}
				return ( _inputBuffer.get() );
			} else {
				strncpy( _inputBuffer.get(), _preloadedBuffer.c_str(), _maxLineLength );
				_preloadedBuffer.clear();
				return ( _inputBuffer.get() );
			}
		} else {
			if (enableRawMode() == -1) {
				return NULL;
			}
			InputBuffer ib(*this, _maxLineLength);
			if (!_preloadedBuffer.empty()) {
				ib.preloadBuffer(_preloadedBuffer.c_str());
				_preloadedBuffer.clear();
			}
			int count = ib.getInputLine(pi);
      disableRawMode();
			if (count == -1) {
				return NULL;
			}
      
			assert( ib.length() < _maxLineLength );
			printf("\n");
      size_t bufferSize = sizeof(char32_t) * ib.length() + 1;
      copyString32to8(_inputBuffer.get(), bufferSize, ib.buf());
			return ( _inputBuffer.get() );
		}
	} else { // input not from a terminal, we should work with piped input, i.e. redirected stdin
		if (fgets(_inputBuffer.get(), _maxLineLength, thread_stdout) == NULL) {
			return NULL;
		}

		// if fgets() gave us the newline, remove it
		int count = static_cast<int>( strlen( _inputBuffer.get() ) );
		if (count > 0 && _inputBuffer[count - 1] == '\n') {
			--count;
			_inputBuffer[count] = '\0';
		}
		return ( _inputBuffer.get() );
	}
}

void Replxx::ReplxxImpl::clear_screen( void ) {
	replxx::clear_screen( CLEAR_SCREEN::WHOLE );
}
  
void Replxx::ReplxxImpl::clear_screen_to_end( void ) {
  replxx::clear_screen( CLEAR_SCREEN::TO_END );
}


int Replxx::ReplxxImpl::install_window_change_handler( void ) {
#ifndef _WIN32
	struct sigaction sa;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = 0;
	sa.sa_handler = &WindowSizeChanged;

	if (sigaction(SIGWINCH, &sa, nullptr) == -1) {
		return errno;
	}
#endif
	return 0;
}
  
int Replxx::ReplxxImpl::window_changed( void ) {
  WindowSizeChanged(0);
  return 0;
}

std::string const& Replxx::ReplxxImpl::history_line( int index ) {
	return ( _history[index] );
}

void Replxx::ReplxxImpl::set_completion_callback( Replxx::completion_callback_t const& fn, void* userData ) {
	_completionCallback = fn;
	_completionUserdata = userData;
}

void Replxx::ReplxxImpl::set_highlighter_callback( Replxx::highlighter_callback_t const& fn, void* userData ) {
	_highlighterCallback = fn;
	_highlighterUserdata = userData;
}

void Replxx::ReplxxImpl::set_hint_callback( Replxx::hint_callback_t const& fn, void* userData ) {
	_hintCallback = fn;
	_hintUserdata = userData;
}

void Replxx::ReplxxImpl::set_max_history_size( int len ) {
	_history.set_max_size( len );
}

void Replxx::ReplxxImpl::set_max_line_size( int len ) {
	if ( len > _maxLineLength ) {
		_inputBuffer.reset( new char[len * sizeof ( char32_t ) + 1] );
	}
	_maxLineLength = len;
}

void Replxx::ReplxxImpl::set_max_hint_rows( int count ) {
	_maxHintRows = count;
}

void Replxx::ReplxxImpl::set_word_break_characters( char const* wordBreakers ) {
	_breakChars = wordBreakers;
}

void Replxx::ReplxxImpl::set_special_prefixes( char const* specialPrefixes ) {
	_specialPrefixes = specialPrefixes;
}

void Replxx::ReplxxImpl::set_double_tab_completion( bool val ) {
	_doubleTabCompletion = val;
}

void Replxx::ReplxxImpl::set_complete_on_empty( bool val ) {
	_completeOnEmpty = val;
}

void Replxx::ReplxxImpl::set_beep_on_ambiguous_completion( bool val ) {
	_beepOnAmbiguousCompletion = val;
}

void Replxx::ReplxxImpl::set_no_color( bool val ) {
	_noColor = val;
}

int Replxx::ReplxxImpl::print( char const* str_, int size_ ) {
#ifdef _WIN32
	int count( win_write( str_, size_ ) );
#else
	int count( fwrite(str_, 1, size_, thread_stdout ) );
#endif
	return ( count );
}

namespace {
void delete_ReplxxImpl( Replxx::ReplxxImpl* impl_ ) {
	delete impl_;
}
}

Replxx::Replxx( void )
	: _impl( new Replxx::ReplxxImpl( nullptr, nullptr, nullptr ), delete_ReplxxImpl ) {
}

void Replxx::set_completion_callback( completion_callback_t const& fn, void* userData ) {
	_impl->set_completion_callback( fn, userData );
}

#if 0
int Replxx::print( char const* fmt, ... );
#endif

void Replxx::set_highlighter_callback( highlighter_callback_t const& fn, void* userData ) {
	_impl->set_highlighter_callback( fn, userData );
}

void Replxx::set_hint_callback( hint_callback_t const& fn, void* userData ) {
	_impl->set_hint_callback( fn, userData );
}

char const* Replxx::input( std::string const& prompt ) {
	return ( _impl->input( prompt ) );
}

void Replxx::history_add( std::string const& line ) {
	_impl->history_add( line );
}

int Replxx::history_save( std::string const& filename ) {
	return ( _impl->history_save( filename ) );
}

int Replxx::history_load( std::string const& filename ) {
	return ( _impl->history_load( filename ) );
}

int Replxx::history_size( void ) const {
	return ( _impl->history_size() );
}

std::string const& Replxx::history_line( int index ) {
	return ( _impl->history_line( index ) );
}

void Replxx::set_preload_buffer( std::string const& preloadText ) {
	_impl->set_preload_buffer( preloadText );
}

void Replxx::set_word_break_characters( char const* wordBreakers ) {
	_impl->set_word_break_characters( wordBreakers );
}

void Replxx::set_special_prefixes( char const* specialPrefixes ) {
	_impl->set_special_prefixes( specialPrefixes );
}

void Replxx::set_max_line_size( int len ) {
	_impl->set_max_line_size( len );
}

void Replxx::set_max_hint_rows( int count ) {
	_impl->set_max_hint_rows( count );
}

void Replxx::set_double_tab_completion( bool val ) {
	_impl->set_double_tab_completion( val );
}

void Replxx::set_complete_on_empty( bool val ) {
	_impl->set_complete_on_empty( val );
}

void Replxx::set_beep_on_ambiguous_completion( bool val ) {
	_impl->set_beep_on_ambiguous_completion( val );
}

void Replxx::set_no_color( bool val ) {
	_impl->set_no_color( val );
}

void Replxx::set_max_history_size( int len ) {
	_impl->set_max_history_size( len );
}

void Replxx::clear_screen( void ) {
	_impl->clear_screen();
}

int Replxx::install_window_change_handler( void ) {
	return ( _impl->install_window_change_handler() );
}
  
int Replxx::window_changed( void ) {
  return ( _impl->window_changed() );
}


int Replxx::print( char const* format_, ... ) {
	::std::va_list ap;
	va_start( ap, format_ );
	int size = static_cast<int>( vsnprintf( nullptr, 0, format_, ap ) );
	va_end( ap );
	va_start( ap, format_ );
	unique_ptr<char[]> buf( new char[size + 1] );
	vsnprintf( buf.get(), static_cast<size_t>( size + 1 ), format_, ap );
	va_end( ap );
	return ( _impl->print( buf.get(), size ) );
}

}

::Replxx* replxx_init() {
	return ( reinterpret_cast<::Replxx*>( new replxx::Replxx::ReplxxImpl( nullptr, nullptr, nullptr ) ) );
}

void replxx_end( ::Replxx* replxx_ ) {
	delete reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ );
}

void replxx_clear_screen( ::Replxx* replxx_ ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	return ( replxx->clear_screen() );
}

void replxx_clear_screen_to_end( ::Replxx* replxx_ ) {
  replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
  return ( replxx->clear_screen_to_end() );
}

/**
 * replxx_set_preload_buffer provides text to be inserted into the command buffer
 *
 * the provided text will be processed to be usable and will be used to preload
 * the input buffer on the next call to replxx_input()
 *
 * @param preloadText text to begin with on the next call to replxx_input()
 */
void replxx_set_preload_buffer(::Replxx* replxx_, const char* preloadText) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->set_preload_buffer( preloadText ? preloadText : "" );
}

/**
 * replxx_input is a readline replacement.
 *
 * call it with a prompt to display and it will return a line of input from the
 * user
 *
 * @param prompt text of prompt to display to the user
 * @return the returned string belongs to the caller on return and must be
 * freed to prevent memory leaks
 */
void blink_replxx_replace_streams( ::Replxx* replxx_, FILE *in, FILE *out, FILE *err, struct winsize *win) {
  replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
  replxx->blink_replace_streams(in, out, err, win);
}

char const* replxx_input( ::Replxx* replxx_, const char* prompt ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	return ( replxx->input( prompt ) );
}

int replxx_print( ::Replxx* replxx_, char const* format_, ... ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	::std::va_list ap;
	va_start( ap, format_ );
	int size = static_cast<int>( vsnprintf( nullptr, 0, format_, ap ) );
	va_end( ap );
	va_start( ap, format_ );
	unique_ptr<char[]> buf( new char[size + 1] );
	vsnprintf( buf.get(), static_cast<size_t>( size + 1 ), format_, ap );
	va_end( ap );
	return ( replxx->print( buf.get(), size ) );
}

struct replxx_completions {
	replxx::Replxx::completions_t data;
};

struct replxx_hints {
	replxx::Replxx::hints_t data;
};

replxx::Replxx::completions_t completions_fwd( replxx_completion_callback_t fn, std::string const& input_, int breakPos_, void* userData ) {
	replxx_completions completions;
	fn( input_.c_str(), breakPos_, &completions, userData );
	return ( completions.data );
}

/* Register a callback function to be called for tab-completion. */
void replxx_set_completion_callback(::Replxx* replxx_, replxx_completion_callback_t* fn, void* userData) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->set_completion_callback( std::bind( &completions_fwd, fn, _1, _2, _3 ), userData );
}

void highlighter_fwd( replxx_highlighter_callback_t fn, std::string const& input, replxx::Replxx::colors_t& colors, void* userData ) {
	std::vector<ReplxxColor> colorsTmp( colors.size() );
	std::transform(
		colors.begin(),
		colors.end(),
		colorsTmp.begin(),
		[]( replxx::Replxx::Color c ) {
			return ( static_cast<ReplxxColor>( c ) );
		}
	);
	fn( input.c_str(), colorsTmp.data(), colors.size(), userData );
	std::transform(
		colorsTmp.begin(),
		colorsTmp.end(),
		colors.begin(),
		[]( ReplxxColor c ) {
			return ( static_cast<replxx::Replxx::Color>( c ) );
		}
	);
}

void replxx_set_highlighter_callback( ::Replxx* replxx_, replxx_highlighter_callback_t* fn, void* userData ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->set_highlighter_callback( std::bind( &highlighter_fwd, fn, _1, _2, _3 ), userData );
}

replxx::Replxx::hints_t hints_fwd( replxx_hint_callback_t fn, std::string const& input_, int breakPos_, replxx::Replxx::Color& color_, void* userData ) {
	replxx_hints hints;
	ReplxxColor c( static_cast<ReplxxColor>( color_ ) );
	fn( input_.c_str(), breakPos_, &hints, &c, userData );
	return ( hints.data );
}

void replxx_set_hint_callback( ::Replxx* replxx_, replxx_hint_callback_t* fn, void* userData ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->set_hint_callback( std::bind( &hints_fwd, fn, _1, _2, _3, _4 ), userData );
}

void replxx_add_hint(replxx_hints* lh, const char* str) {
	lh->data.emplace_back(str);
}

void replxx_add_completion(replxx_completions* lc, const char* str) {
	lc->data.emplace_back(str);
}

void replxx_history_add( ::Replxx* replxx_, const char* line ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->history_add( line );
}

void replxx_set_max_history_size( ::Replxx* replxx_, int len ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->set_max_history_size( len );
}

void replxx_set_max_line_size( ::Replxx* replxx_, int len ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->set_max_line_size( len );
}

void replxx_set_max_hint_rows( ::Replxx* replxx_, int count ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->set_max_hint_rows( count );
}

void replxx_set_word_break_characters( ::Replxx* replxx_, char const* breakChars_ ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->set_word_break_characters( breakChars_ );
}

void replxx_set_special_prefixes( ::Replxx* replxx_, char const* specialPrefixes_ ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->set_special_prefixes( specialPrefixes_ );
}

void replxx_set_double_tab_completion( ::Replxx* replxx_, int val ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->set_double_tab_completion( val ? true : false );
}

void replxx_set_complete_on_empty( ::Replxx* replxx_, int val ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->set_complete_on_empty( val ? true : false );
}

void replxx_set_no_color( ::Replxx* replxx_, int val ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->set_no_color( val ? true : false );
}

void replxx_set_beep_on_ambiguous_completion( ::Replxx* replxx_, int val ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	replxx->set_beep_on_ambiguous_completion( val ? true : false );
}

/* Fetch a line of the history by (zero-based) index.	If the requested
 * line does not exist, NULL is returned.	The return value is a heap-allocated
 * copy of the line. */
char const* replxx_history_line( ::Replxx* replxx_, int index ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	return ( replxx->history_line( index ).c_str() );
}

/* Save the history in the specified file. On success 0 is returned
 * otherwise -1 is returned. */
int replxx_history_save( ::Replxx* replxx_, const char* filename ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	return ( replxx->history_save( filename ) );
}

/* Load the history from the specified file. If the file does not exist
 * zero is returned and no operation is performed.
 *
 * If the file exists and the operation succeeded 0 is returned, otherwise
 * on error -1 is returned. */
int replxx_history_load( ::Replxx* replxx_, const char* filename ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	return ( replxx->history_load( filename ) );
}

int replxx_history_size( ::Replxx* replxx_ ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	return ( replxx->history_size() );
}

/* This special mode is used by replxx in order to print scan codes
 * on screen for debugging / development purposes. It is implemented
 * by the replxx-c-api-example program using the --keycodes option. */
void replxx_debug_dump_print_codes(void) {
  fprintf(thread_stdout,
      "Press any keys - Ctrl-D will terminate this program.\r\n");
  if (enableRawMode() == -1) {
    return;
  }

  char ch;
  while (1) {
    ssize_t n = read(fileno(thread_stdin), &ch, 1);
    if (n <= 0) {
      break;
    }
    
    if (ch == '\n')
      fprintf(thread_stdout, "\\n");
    else if (ch == '\t')
      fprintf(thread_stdout, "\\t");
    else if (ch < ' ')
      fprintf(thread_stdout, "^%c", ch+64);
    else
      fprintf(thread_stdout, "%c",ch);
    
    fprintf(thread_stdout, "\t%3d 0%03o 0x%02x\n\r", ch,
           ch, ch);
    fflush(thread_stdout);
    if (ch == 4) { // Ctrl-D
      break;
    }
  }
  disableRawMode();
}

int replxx_install_window_change_handler( ::Replxx* replxx_ ) {
	replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
	return ( replxx->install_window_change_handler() );
}

int replxx_window_changed( ::Replxx* replxx_ ) {
  replxx::Replxx::ReplxxImpl* replxx( reinterpret_cast<replxx::Replxx::ReplxxImpl*>( replxx_ ) );
  return ( replxx->window_changed() );
}


