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

#ifndef HAVE_REPLXX_REPLXX_IMPL_HXX_INCLUDED
#define HAVE_REPLXX_REPLXX_IMPL_HXX_INCLUDED 1

#include <vector>
#include <memory>
#include <string>

#include "replxx.hxx"
#include "history.hxx"
#include "killring.hxx"
#include "utfstring.hxx"

namespace replxx {

class Replxx::ReplxxImpl {
public:
	typedef std::vector<Utf32String> completions_t;
	typedef std::vector<Utf32String> hints_t;
	typedef std::unique_ptr<char[]> input_buffer_t;
private:
	int _maxLineLength;
	input_buffer_t _inputBuffer;
	History _history;
	KillRing _killRing;
	int _maxHintRows;
	char const* _breakChars;
	char const* _specialPrefixes;
	int _completionCountCutoff;
	bool _doubleTabCompletion;
	bool _completeOnEmpty;
	bool _beepOnAmbiguousCompletion;
	bool _noColor;
	Replxx::completion_callback_t _completionCallback;
	Replxx::highlighter_callback_t _highlighterCallback;
	Replxx::hint_callback_t _hintCallback;
	void* _completionUserdata;
	void* _highlighterUserdata;
	void* _hintUserdata;
	std::string _preloadedBuffer; // used with set_preload_buffer
	std::string _errorMessage;
public:
	ReplxxImpl( FILE*, FILE*, FILE* );
	void set_completion_callback( Replxx::completion_callback_t const& fn, void* userData );
	void set_highlighter_callback( Replxx::highlighter_callback_t const& fn, void* userData );
	void set_hint_callback( Replxx::hint_callback_t const& fn, void* userData );
	char const* input( std::string const& prompt );
  char const* blink_input( std::string const& prompt, struct winsize *size);
	void history_add( std::string const& line );
	int history_save( std::string const& filename );
	int history_load( std::string const& filename );
	std::string const& history_line( int index );
	int history_size( void ) const;
	void set_preload_buffer(std::string const& preloadText);
	void set_word_break_characters( char const* wordBreakers );
	void set_special_prefixes( char const* specialPrefixes );
	void set_max_line_size( int len );
	void set_max_hint_rows( int count );
	void set_double_tab_completion( bool val );
	void set_complete_on_empty( bool val );
	void set_beep_on_ambiguous_completion( bool val );
	void set_no_color( bool val );
	void set_max_history_size( int len );
	void clear_screen( void );
	int install_window_change_handler( void );
	completions_t call_completer( std::string const& input, int breakPos ) const;
	hints_t call_hinter( std::string const& input, int breakPos, Replxx::Color& color ) const;
	void call_highlighter( std::string const& input, Replxx::colors_t& colors ) const;
	History& history( void ) {
		return ( _history );
	}
	KillRing& kill_ring( void ) {
		return ( _killRing );
	}
	bool has_hinter( void ) const {
		return ( !! _hintCallback );
	}
	bool has_completer( void ) const {
		return ( !! _completionCallback );
	}
	bool has_highlighter( void ) const {
		return ( !! _highlighterCallback );
	}
	bool no_color( void ) const {
		return ( _noColor );
	}
	int max_hint_rows( void ) const {
		return ( _maxHintRows );
	}
	char const* break_chars( void ) const {
		return ( _breakChars );
	}
	char const* special_prefixes( void ) const {
		return ( _specialPrefixes );
	}
	bool beep_on_ambiguous_completion( void ) const {
		return ( _beepOnAmbiguousCompletion );
	}
	bool complete_on_empty( void ) const {
		return ( _completeOnEmpty );
	}
	bool double_tab_completion( void ) const {
		return ( _doubleTabCompletion );
	}
	int completion_count_cutoff( void ) const {
		return ( _completionCountCutoff );
	}
	int print( char const* , int );
private:
	ReplxxImpl( ReplxxImpl const& ) = delete;
	ReplxxImpl& operator = ( ReplxxImpl const& ) = delete;
};

}

#endif

