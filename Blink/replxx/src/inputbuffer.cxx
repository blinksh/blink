#include <algorithm>
#include <memory>
#include <cerrno>

#import <stdio.h>
#ifdef _WIN32

#include <conio.h>
#include <windows.h>
#include <io.h>
#if _MSC_VER < 1900
#define snprintf _snprintf	// Microsoft headers use underscores in some names
#endif
#define strcasecmp _stricmp
#define strdup _strdup
#define write _write
#define STDIN_FILENO 0

#else /* _WIN32 */

#include <unistd.h>
#include <signal.h>

#endif /* _WIN32 */

#include "inputbuffer.hxx"
#include "prompt.hxx"
#include "util.hxx"
#include "io.hxx"
#include "keycodes.hxx"
#include "history.hxx"
#include "replxx.hxx"

using namespace std;

int printf (const char *format, ...) {
  va_list arg;
  int done;
  
  va_start (arg, format);
  done = vfprintf (thread_stdout, format, arg);
  va_end (arg);
  
  return done;
}


namespace replxx {
  

struct PromptBase;

void dynamicRefresh(PromptBase& pi, char32_t* buf32, int len, int pos);

#ifndef _WIN32
extern bool gotResize;
#endif

void InputBuffer::preloadBuffer(const char* preloadText) {
	size_t ucharCount = 0;
	copyString8to32(_buf32.get(), _buflen + 1, ucharCount, preloadText);
	recomputeCharacterWidths(_buf32.get(), _charWidths.get(), static_cast<int>(ucharCount));
	_len = static_cast<int>(ucharCount);
	_prefix = _pos = static_cast<int>(ucharCount);
}

char const* ansi_color( Replxx::Color color_ ) {
	static char const reset[] = "\033[0m";
	static char const black[] = "\033[0;22;30m";
	static char const red[] = "\033[0;22;31m";
	static char const green[] = "\033[0;22;32m";
	static char const brown[] = "\033[0;22;33m";
	static char const blue[] = "\033[0;22;34m";
	static char const magenta[] = "\033[0;22;35m";
	static char const cyan[] = "\033[0;22;36m";
	static char const lightgray[] = "\033[0;22;37m";
  static char const hint[] = "\033[2;33m";

	static char const* TERM( getenv( "TERM" ) );
	static bool const has256color( TERM ? ( strstr( TERM, "256" ) != nullptr ) : false );
	static char const* gray = has256color ? "\033[0;1;90m" : "\033[0;1;30m";
	static char const* brightred = has256color ? "\033[0;1;91m" : "\033[0;1;31m";
	static char const* brightgreen = has256color ? "\033[0;1;92m" : "\033[0;1;32m";
	static char const* yellow = has256color ? "\033[0;1;93m" : "\033[0;1;33m";
	static char const* brightblue = has256color ? "\033[0;1;94m" : "\033[0;1;34m";
	static char const* brightmagenta = has256color ? "\033[0;1;95m" : "\033[0;1;35m";
	static char const* brightcyan = has256color ? "\033[0;1;96m" : "\033[0;1;36m";
	static char const* white = has256color ? "\033[0;1;97m" : "\033[0;1;37m";
	static char const error[] = "\033[101;1;33m";

	char const* code( reset );
	switch ( color_ ) {
		case Replxx::Color::BLACK:         code = black;         break;
		case Replxx::Color::RED:           code = red;           break;
		case Replxx::Color::GREEN:         code = green;         break;
		case Replxx::Color::BROWN:         code = brown;         break;
		case Replxx::Color::BLUE:          code = blue;          break;
		case Replxx::Color::MAGENTA:       code = magenta;       break;
		case Replxx::Color::CYAN:          code = cyan;          break;
		case Replxx::Color::LIGHTGRAY:     code = lightgray;     break;
		case Replxx::Color::GRAY:          code = gray;          break;
		case Replxx::Color::BRIGHTRED:     code = brightred;     break;
		case Replxx::Color::BRIGHTGREEN:   code = brightgreen;   break;
		case Replxx::Color::YELLOW:        code = yellow;        break;
		case Replxx::Color::BRIGHTBLUE:    code = brightblue;    break;
		case Replxx::Color::BRIGHTMAGENTA: code = brightmagenta; break;
		case Replxx::Color::BRIGHTCYAN:    code = brightcyan;    break;
		case Replxx::Color::WHITE:         code = white;         break;
    case Replxx::Color::HINT:          code = hint;          break;
		case Replxx::Color::ERROR:         code = error;         break;
		case Replxx::Color::DEFAULT:       code = reset;         break;
	}
	return ( code );
}

void InputBuffer::setColor( Replxx::Color color_ ) {
	char const* code( ansi_color( color_ ) );
	while ( *code ) {
		_display.push_back( *code );
		++ code;
	}
}

void InputBuffer::highlight( int highlightIdx, bool error_ ) {
	Replxx::colors_t colors( _len, Replxx::Color::DEFAULT );
	Utf32String unicodeCopy( _buf32.get(), _len );
	Utf8String parseItem( unicodeCopy );
	_replxx.call_highlighter( parseItem.get(), colors );
	if ( highlightIdx != -1 ) {
		colors[highlightIdx] = error_ ? Replxx::Color::ERROR : Replxx::Color::BRIGHTRED;
	}
	_display.clear();
	Replxx::Color c( Replxx::Color::DEFAULT );
	for ( int i( 0 ); i < _len; ++ i ) {
		if ( colors[i] != c ) {
			c = colors[i];
			setColor( c );
		}
		_display.push_back( _buf32[i] );
	}
	setColor( Replxx::Color::DEFAULT );
}

int InputBuffer::handle_hints( PromptBase& pi, HINT_ACTION hintAction_ ) {
	_hint = Utf32String();
	int len( 0 );
	if ( !_replxx.no_color() && ( hintAction_ != HINT_ACTION::SKIP ) && _replxx.has_hinter() && ( _pos == _len ) ) {
		if ( hintAction_ == HINT_ACTION::REGENERATE ) {
			_hintSelection = -1;
		}
    Replxx::Color c( Replxx::Color::HINT );
		Utf32String unicodeCopy( _buf32.get(), _pos );
		Utf8String parseItem(unicodeCopy);
		int startIndex( start_index() );
		Replxx::ReplxxImpl::hints_t hints( _replxx.call_hinter( parseItem.get(), startIndex, c ) );
		int hintCount( hints.size() );
		if ( hintCount == 1 ) {
			setColor( c );
			_hint = hints.front();
			len = _hint.length();
			for ( int i( 0 ); i < len; ++ i ) {
				_display.push_back( _hint[i] );
			}
			setColor( Replxx::Color::DEFAULT );
		} else if ( _replxx.max_hint_rows() > 0 ) {
//      if (_hintSelection == -1) {
//        _hintSelection = 0;
//      }
			int startCol( pi.promptIndentation + startIndex );
			int maxCol( pi.promptScreenColumns );
#ifdef _WIN32
			-- maxCol;
#endif
			if ( _hintSelection < -1 ) {
				_hintSelection = hintCount - 1;
			} else if ( _hintSelection >= hintCount ) {
				_hintSelection = -1;
			}
			setColor( c );
			if ( _hintSelection != -1 ) {
				_hint = hints[_hintSelection];
				len = min<int>( _hint.length(), maxCol - startCol - _len );
				for ( int i( 0 ); i < len; ++ i ) {
					_display.push_back( _hint[i] );
				}
			}
			setColor( Replxx::Color::DEFAULT );
			for ( int hintRow( 0 ); hintRow < min( hintCount, _replxx.max_hint_rows() ); ++ hintRow ) {
#ifdef _WIN32
				_display.push_back( '\r' );
#endif
				_display.push_back( '\n' );
				int col( 0 );
				for ( int i( 0 ); ( i < startCol ) && ( col < maxCol ); ++ i, ++ col ) {
					_display.push_back( ' ' );
				}
				setColor( c );
				for ( int i( startIndex ); ( i < _pos ) && ( col < maxCol ); ++ i, ++ col ) {
					_display.push_back( _buf32[i] );
				}
				int hintNo( hintRow + _hintSelection + 1 );
				if ( hintNo == hintCount ) {
					continue;
				} else if ( hintNo > hintCount ) {
					-- hintNo;
				}
				Utf32String const& h( hints[hintNo % hintCount] );
				for ( size_t i( 0 ); ( i < h.length() ) && ( col < maxCol ); ++ i, ++ col ) {
					_display.push_back( h[i] );
				}
				setColor( Replxx::Color::DEFAULT );
			}
		}
	}
	return ( len );
}

/**
 * Refresh the user's input line: the prompt is already onscreen and is not
 * redrawn here
 * @param pi	 PromptBase struct holding information about the prompt and our
 * screen position
 */
void InputBuffer::refreshLine(PromptBase& pi, HINT_ACTION hintAction_) {
	// check for a matching brace/bracket/paren, remember its position if found
	int highlightIdx = -1;
	bool indicateError = false;
	if (_pos < _len) {
		/* this scans for a brace matching _buf32[_pos] to highlight */
		unsigned char part1, part2;
		int scanDirection = 0;
		if (strchr("}])", _buf32[_pos])) {
			scanDirection = -1; /* backwards */
			if (_buf32[_pos] == '}') {
				part1 = '}'; part2 = '{';
			} else if (_buf32[_pos] == ']') {
				part1 = ']'; part2 = '[';
			} else {
				part1 = ')'; part2 = '(';
			}
		} else if (strchr("{[(", _buf32[_pos])) {
			scanDirection = 1; /* forwards */
			if (_buf32[_pos] == '{') {
				//part1 = '{'; part2 = '}';
				part1 = '}'; part2 = '{';
			} else if (_buf32[_pos] == '[') {
				//part1 = '['; part2 = ']';
				part1 = ']'; part2 = '[';
			} else {
				//part1 = '('; part2 = ')';
				part1 = ')'; part2 = '(';
			}
		}

		if (scanDirection) {
			int unmatched = scanDirection;
			int unmatchedOther = 0;
			for (int i = _pos + scanDirection; i >= 0 && i < _len; i += scanDirection) {
				/* TODO: the right thing when inside a string */
				if (strchr("}])", _buf32[i])) {
					if (_buf32[i] == part1) {
						--unmatched;
					} else {
						--unmatchedOther;
					}
				} else if (strchr("{[(", _buf32[i])) {
					if (_buf32[i] == part2) {
						++unmatched;
					} else {
						++unmatchedOther;
					}
				}

				if (unmatched == 0) {
					highlightIdx = i;
					indicateError = (unmatchedOther != 0);
					break;
				}
			}
		}
	}

	highlight( highlightIdx, indicateError );
	int hintLen( handle_hints( pi, hintAction_ ) );
	// calculate the position of the end of the input line
	int xEndOfInput( 0 ), yEndOfInput( 0 );
	calculateScreenPosition(
		pi.promptIndentation, 0, pi.promptScreenColumns,
		calculateColumnPosition( _buf32.get(), _len ) + hintLen,
		xEndOfInput, yEndOfInput
	);
	yEndOfInput += count( _display.begin(), _display.end(), '\n' );

	// calculate the desired position of the cursor
	int xCursorPos( 0 ), yCursorPos( 0 );
	calculateScreenPosition(
		pi.promptIndentation, 0, pi.promptScreenColumns,
		calculateColumnPosition(_buf32.get(), _pos),
		xCursorPos,
		yCursorPos
	);

#ifdef _WIN32
	// position at the end of the prompt, clear to end of previous input
	CONSOLE_SCREEN_BUFFER_INFO inf;
	GetConsoleScreenBufferInfo(console_out, &inf);
	inf.dwCursorPosition.X = pi.promptIndentation;	// 0-based on Win32
	inf.dwCursorPosition.Y -= pi.promptCursorRowOffset - pi.promptExtraLines;
	SetConsoleCursorPosition(console_out, inf.dwCursorPosition);
	clear_screen( CLEAR_SCREEN::TO_END );
	pi.promptPreviousInputLen = _len;

	// display the input line
	if ( !_replxx.no_color() ) {
		if (write32(1, _display.data(), _display.size()) == -1) return;
	} else {
		if (write32(1, _buf32.get(), _len) == -1) return;
	}

	// position the cursor
	GetConsoleScreenBufferInfo(console_out, &inf);
	inf.dwCursorPosition.X = xCursorPos;	// 0-based on Win32
	inf.dwCursorPosition.Y -= ( yEndOfInput - yCursorPos );
	SetConsoleCursorPosition(console_out, inf.dwCursorPosition);
#else	// _WIN32
	char seq[64];
	int cursorRowMovement = pi.promptCursorRowOffset - pi.promptExtraLines;
	if (cursorRowMovement > 0) {	// move the cursor up as required
		snprintf(seq, sizeof seq, "\x1b[%dA", cursorRowMovement);
		if (fwrite(seq, 1, strlen(seq), thread_stdout) == -1) return;
	}
	// position at the end of the prompt, clear to end of screen
	snprintf(
		seq, sizeof seq, "\x1b[%dG\x1b[%c",
		pi.promptIndentation + 1, /* 1-based on VT100 */
		'J'
	);
	if (fwrite(seq, 1, strlen(seq), thread_stdout) == -1) return;

	if ( !_replxx.no_color() ) {
		if (write32(1, _display.data(), _display.size()) == -1) return;
	} else {	// highlightIdx the matching brace/bracket/parenthesis
		if (write32(1, _buf32.get(), _len) == -1) return;
	}

	// we have to generate our own newline on line wrap
	if (xEndOfInput == 0 && yEndOfInput > 0)
		if (fwrite("\n", 1, 1, thread_stdout) == -1) return;

	// position the cursor
	cursorRowMovement = yEndOfInput - yCursorPos;
	if (cursorRowMovement > 0) {	// move the cursor up as required
		snprintf(seq, sizeof seq, "\x1b[%dA", cursorRowMovement);
		if (fwrite(seq, 1, strlen(seq), thread_stdout) == -1) return;
	}
	// position the cursor within the line
	snprintf(seq, sizeof seq, "\x1b[%dG", xCursorPos + 1);	// 1-based on VT100
	if (fwrite(seq, 1, strlen(seq), thread_stdout) == -1) return;
#endif

	pi.promptCursorRowOffset =
			pi.promptExtraLines + yCursorPos;	// remember row for next pass
}

int InputBuffer::start_index() {
	int startIndex = _pos;
	while (--startIndex >= 0) {
		if ( strchr(_replxx.break_chars(), _buf32[startIndex]) ) {
			break;
		}
	}
	if ( ( startIndex < 0 ) || ! strchr( _replxx.special_prefixes(), _buf32[startIndex] ) ) {
		++ startIndex;
	}
	while ( ( startIndex > 0 ) && ( strchr( _replxx.special_prefixes(), _buf32[startIndex - 1] ) != nullptr ) ) {
		-- startIndex;
	}
	return ( startIndex );
}

/**
 * Handle command completion, using a completionCallback() routine to provide
 * possible substitutions
 * This routine handles the mechanics of updating the user's input buffer with
 * possible replacement
 * of text as the user selects a proposed completion string, or cancels the
 * completion attempt.
 * @param pi		 PromptBase struct holding information about the prompt and our
 * screen position
 */
int InputBuffer::completeLine(PromptBase& pi) {
	char32_t c = 0;

	// completionCallback() expects a parsable entity, so find the previous break
	// character and
	// extract a copy to parse.	we also handle the case where tab is hit while
	// not at end-of-line.
	int startIndex( start_index() );
	int itemLength( _pos - startIndex );

	Utf32String unicodeCopy(_buf32.get(), _pos);
	Utf8String parseItem(unicodeCopy);
	// get a list of completions
	Replxx::ReplxxImpl::completions_t completions( _replxx.call_completer( parseItem.get(), startIndex ) );

	// if no completions, we are done
	if (completions.size() == 0) {
		beep();
		return 0;
	}

	// at least one completion
	int longestCommonPrefix = 0;
	int displayLength = 0;
	int completionsCount = static_cast<int>(completions.size());
	int selectedCompletion( 0 );
	if ( _hintSelection != -1 ) {
		selectedCompletion = _hintSelection;
		completionsCount = 1;
	}
	if ( completionsCount == 1) {
		longestCommonPrefix = static_cast<int>(completions[selectedCompletion].length());
	} else {
		bool keepGoing = true;
		while (keepGoing) {
			for (int j = 0; j < completionsCount - 1; ++j) {
				char32_t c1 = completions[j][longestCommonPrefix];
				char32_t c2 = completions[j + 1][longestCommonPrefix];
				if ((0 == c1) || (0 == c2) || (c1 != c2)) {
					keepGoing = false;
					break;
				}
			}
			if (keepGoing) {
				++longestCommonPrefix;
			}
		}
	}
//  if ( _replxx.beep_on_ambiguous_completion() && ( completionsCount != 1 ) ) {  // beep if ambiguous
//    beep();
//  }
  
  if ( (longestCommonPrefix <= itemLength) && _pos > 0) {
    if (completionsCount == 1) {
      Utf32String unicodeCopy2(_buf32.get(), _pos - itemLength);
      Utf8String parseItem2(unicodeCopy2);
      // get new list of completions
      completions = _replxx.call_completer( parseItem2.get(), startIndex );
      completionsCount = static_cast<int>(completions.size());
      
      int bp = static_cast<int>(unicodeCopy.length()) - itemLength;
      
      selectedCompletion = -1;
      for (int i = 0; i != completionsCount; i++) {
        if (completions[i].length() == itemLength && memcmp(&completions[i][0], &unicodeCopy[bp], sizeof(char32_t) * itemLength) == 0) {
          selectedCompletion = i;
        }
      }
      if (selectedCompletion != -1) {
        selectedCompletion ++;
      } else {
        selectedCompletion = 0;
      }
      if (selectedCompletion >= completionsCount) {
        selectedCompletion = 0;
      }
    } else {
      if (completions[selectedCompletion].length() == itemLength && memcmp(&completions[selectedCompletion][0], &unicodeCopy[0], sizeof(char32_t) * itemLength) == 0) {
        selectedCompletion++;
      }
      if (selectedCompletion >= completionsCount) {
        selectedCompletion = 0;
      }
    }
  
    longestCommonPrefix = static_cast<int>(completions[selectedCompletion].length());
    displayLength = _len + longestCommonPrefix - itemLength;
    if (displayLength > _buflen) {
      longestCommonPrefix -= displayLength - _buflen; // don't overflow buffer
      displayLength = _buflen;                        // truncate the insertion
      beep();                                         // and make a noise
    }
    Utf32String displayText(displayLength + 1);
    memcpy(displayText.get(), _buf32.get(), sizeof(char32_t) * startIndex);
    memcpy(&displayText[startIndex], &completions[selectedCompletion][0],
           sizeof(char32_t) * longestCommonPrefix);
    int tailIndex = startIndex + longestCommonPrefix;
    memcpy(&displayText[tailIndex], &_buf32[_pos],
           sizeof(char32_t) * (displayLength - tailIndex + 1));
    copyString32(_buf32.get(), displayText.get(), displayLength);
    _prefix = _pos = startIndex + longestCommonPrefix;
    _len = displayLength;
    refreshLine(pi);
    return 0;
  }

	// if we can extend the item, extend it and return to main loop
	if ( ( longestCommonPrefix > itemLength ) || ( completionsCount == 1 ) ) {
		displayLength = _len + longestCommonPrefix - itemLength;
		if (displayLength > _buflen) {
			longestCommonPrefix -= displayLength - _buflen; // don't overflow buffer
			displayLength = _buflen;                        // truncate the insertion
			beep();                                         // and make a noise
		}
		Utf32String displayText(displayLength + 1);
		memcpy(displayText.get(), _buf32.get(), sizeof(char32_t) * startIndex);
		memcpy(&displayText[startIndex], &completions[selectedCompletion][0],
					 sizeof(char32_t) * longestCommonPrefix);
		int tailIndex = startIndex + longestCommonPrefix;
		memcpy(&displayText[tailIndex], &_buf32[_pos],
					 sizeof(char32_t) * (displayLength - tailIndex + 1));
		copyString32(_buf32.get(), displayText.get(), displayLength);
		_prefix = _pos = startIndex + longestCommonPrefix;
		_len = displayLength;
		refreshLine(pi);
		return 0;
	}

	if ( _replxx.double_tab_completion() ) {
		// we can't complete any further, wait for second tab
		do {
			c = read_char();
			c = cleanupCtrl(c);
		} while (c == static_cast<char32_t>(-1));

		// if any character other than tab, pass it to the main loop
		if (c != ctrlChar('I')) {
			return c;
		}
	}

	// we got a second tab, maybe show list of possible completions
	bool showCompletions = true;
	bool onNewLine = false;
	if (static_cast<int>( completions.size() ) > _replxx.completion_count_cutoff()) {
		int savePos =
				_pos;	// move cursor to EOL to avoid overwriting the command line
		_pos = _len;
		refreshLine(pi);
		_pos = savePos;
		printf("\nDisplay all %u possibilities? (y or n)",
					 static_cast<unsigned int>(completions.size()));
		fflush(stdout);
		onNewLine = true;
		while (c != 'y' && c != 'Y' && c != 'n' && c != 'N' && c != ctrlChar('C')) {
			do {
				c = read_char();
				c = cleanupCtrl(c);
			} while (c == static_cast<char32_t>(-1));
		}
		switch (c) {
			case 'n':
			case 'N':
				showCompletions = false;
				break;
			case ctrlChar('C'):
				showCompletions = false;
				if (write(1, "^C", 2) == -1) return -1;	// Display the ^C we got
				c = 0;
				break;
		}
	}

	// if showing the list, do it the way readline does it
	bool stopList = false;
	if (showCompletions) {
		int longestCompletion = 0;
		for (size_t j = 0; j < completions.size(); ++j) {
			itemLength = static_cast<int>(completions[j].length());
			if (itemLength > longestCompletion) {
				longestCompletion = itemLength;
			}
		}
		longestCompletion += 2;
		int columnCount = pi.promptScreenColumns / longestCompletion;
		if (columnCount < 1) {
			columnCount = 1;
		}
		if (!onNewLine) { // skip this if we showed "Display all %d possibilities?"
			int savePos = _pos; // move cursor to EOL to avoid overwriting the command line
			_pos = _len;
			refreshLine( pi, HINT_ACTION::SKIP );
			_pos = savePos;
		} else {
			clear_screen( CLEAR_SCREEN::TO_END );
		}
		size_t pauseRow = getScreenRows() - 1;
		size_t rowCount =
				(completions.size() + columnCount - 1) / columnCount;
		for (size_t row = 0; row < rowCount; ++row) {
			if (row == pauseRow) {
				printf("\n--More--");
				fflush(stdout);
				c = 0;
				bool doBeep = false;
				while (c != ' ' && c != '\r' && c != '\n' && c != 'y' && c != 'Y' &&
							 c != 'n' && c != 'N' && c != 'q' && c != 'Q' &&
							 c != ctrlChar('C')) {
					if (doBeep) {
						beep();
					}
					doBeep = true;
					do {
						c = read_char();
						c = cleanupCtrl(c);
					} while (c == static_cast<char32_t>(-1));
				}
				switch (c) {
					case ' ':
					case 'y':
					case 'Y':
						printf("\r				\r");
						pauseRow += getScreenRows() - 1;
						break;
					case '\r':
					case '\n':
						printf("\r				\r");
						++pauseRow;
						break;
					case 'n':
					case 'N':
					case 'q':
					case 'Q':
						printf("\r				\r");
						stopList = true;
						break;
					case ctrlChar('C'):
						if (fwrite("^C", 1, 2, thread_stdout) == -1) return -1;	// Display the ^C we got
						stopList = true;
						break;
				}
			} else {
				printf("\n");
			}
			if (stopList) {
				break;
			}
			for (int column = 0; column < columnCount; ++column) {
				size_t index = (column * rowCount) + row;
				if (index < completions.size()) {
					itemLength = static_cast<int>(completions[index].length());
					fflush(stdout);

					static Utf32String const col( ansi_color( Replxx::Color::BRIGHTMAGENTA ) );
					if ( !_replxx.no_color() && ( write32( 1, col.get(), col.length() ) == -1 ) )
						return -1;
					if (write32(1, completions[index].get(), longestCommonPrefix) == -1)
						return -1;
					static Utf32String const res( ansi_color( Replxx::Color::DEFAULT ) );
					if ( !_replxx.no_color() && ( write32( 1, res.get(), res.length() ) == -1 ) )
						return -1;

					if (write32(1, completions[index].get() + longestCommonPrefix, itemLength - longestCommonPrefix) == -1)
						return -1;

					if (((column + 1) * rowCount) + row < completions.size()) {
						for (int k = itemLength; k < longestCompletion; ++k) {
							printf(" ");
						}
					}
				}
			}
		}
		fflush(thread_stdout);
	}

	// display the prompt on a new line, then redisplay the input buffer
	if (!stopList || c == ctrlChar('C')) {
		if (fwrite("\n", 1, 1, thread_stdout) == -1) return 0;
	}
	if (!pi.write()) return 0;
#ifndef _WIN32
	// we have to generate our own newline on line wrap on Linux
	if (pi.promptIndentation == 0 && pi.promptExtraLines > 0)
		if (fwrite("\n", 1, 1, thread_stdout) == -1) return 0;
#endif
	pi.promptCursorRowOffset = pi.promptExtraLines;
	refreshLine(pi);
	return 0;
}

int InputBuffer::getInputLine(PromptBase& pi) {
	// The latest history entry is always our current buffer
	if (_len > 0) {
		size_t bufferSize = sizeof(char32_t) * _len + 1;
		unique_ptr<char[]> tempBuffer(new char[bufferSize]);
		copyString32to8(tempBuffer.get(), bufferSize, _buf32.get());
		_replxx.history_add(tempBuffer.get());
	} else {
		_replxx.history_add("");
	}
	_history.reset_pos();

	// display the prompt
	if (!pi.write()) return -1;

#ifndef _WIN32
	// we have to generate our own newline on line wrap on Linux
	if (pi.promptIndentation == 0 && pi.promptExtraLines > 0)
		if (fwrite("\n", 1, 1, thread_stdout) == -1) return -1;
#endif

	// the cursor starts out at the end of the prompt
	pi.promptCursorRowOffset = pi.promptExtraLines;

	// kill and yank start in "other" mode
	_killRing.lastAction = KillRing::actionOther;

	// when history search returns control to us, we execute its terminating
	// keystroke
	int terminatingKeystroke = -1;

	// if there is already text in the buffer, display it first
	if (_len > 0) {
		refreshLine(pi);
	}

	// loop collecting characters, respond to line editing characters
	while (true) {
		int c;
		if (terminatingKeystroke == -1) {
			c = read_char();	// get a new keystroke

#ifndef _WIN32
			if (c == 0 && gotResize) {
				// caught a window resize event
				// now redraw the prompt and line
				gotResize = false;
				pi.promptScreenColumns = getScreenColumns();
				dynamicRefresh(pi, _buf32.get(), _len,
											 _pos);	// redraw the original prompt with current input
				continue;
			}
#endif
		} else {
			c = terminatingKeystroke;	 // use the terminating keystroke from search
			terminatingKeystroke = -1;	// clear it once we've used it
		}

		c = cleanupCtrl(c);	// convert CTRL + <char> into normal ctrl

		if (c == 0) {
			return _len;
		}

		if (c == -1) {
			refreshLine(pi);
			continue;
		}

		if (c == -2) {
			if (!pi.write()) return -1;
			refreshLine(pi);
			continue;
		}

		// ctrl-I/tab, command completion, needs to be before switch statement
		if (c == ctrlChar('I') && _replxx.has_completer()) {
			if ( ( _pos == 0 ) && ! _replxx.complete_on_empty() ) {
				// SERVER-4967 -- in earlier versions, you could paste
				// previous output
				continue;	//	back into the shell ... this output may have leading tabs.
			}
			// This hack (i.e. what the old code did) prevents command completion
			//	on an empty line but lets users paste text with leading tabs.

			_killRing.lastAction = KillRing::actionOther;
			_history.reset_recall_most_recent();

			// completeLine does the actual completion and replacement
			c = completeLine(pi);

			if (c < 0)	// return on error
				return _len;

			if (c == 0)	// read next character when 0
				continue;

			// deliberate fall-through here, so we use the terminating character
		}

		bool updatePrefix( true );
		switch (c) {
			case ctrlChar('A'):	// ctrl-A, move cursor to start of line
			case HOME_KEY:
				_killRing.lastAction = KillRing::actionOther;
				_pos = 0;
				refreshLine(pi);
				break;

			case ctrlChar('B'):	// ctrl-B, move cursor left by one character
			case LEFT_ARROW_KEY:
				_killRing.lastAction = KillRing::actionOther;
				if (_pos > 0) {
					--_pos;
					refreshLine(pi);
				}
				break;

			case META + 'b':	// meta-B, move cursor left by one word
			case META + 'B':
			case CTRL + LEFT_ARROW_KEY:
			case META + LEFT_ARROW_KEY:	// Emacs allows Meta, bash & readline don't
				_killRing.lastAction = KillRing::actionOther;
				if (_pos > 0) {
					while (_pos > 0 && !isCharacterAlphanumeric(_buf32[_pos - 1])) {
						--_pos;
					}
					while (_pos > 0 && isCharacterAlphanumeric(_buf32[_pos - 1])) {
						--_pos;
					}
					refreshLine(pi);
				}
				break;

			case ctrlChar('C'):	// ctrl-C, abort this line
				_killRing.lastAction = KillRing::actionOther;
				_history.reset_recall_most_recent();
				errno = EAGAIN;
				_history.drop_last();
				// we need one last refresh with the cursor at the end of the line
				// so we don't display the next prompt over the previous input line
				_pos = _len;	// pass _len as _pos for EOL
				refreshLine(pi, HINT_ACTION::SKIP);
				if (fwrite("^C\r\n", 1, 4, thread_stdout) == -1) return -1;	// Display the ^C we got
				return -1;

			case META + 'c':	// meta-C, give word initial Cap
			case META + 'C':
				_killRing.lastAction = KillRing::actionOther;
				_history.reset_recall_most_recent();
				if (_pos < _len) {
					while (_pos < _len && !isCharacterAlphanumeric(_buf32[_pos])) {
						++_pos;
					}
					if (_pos < _len && isCharacterAlphanumeric(_buf32[_pos])) {
						if (_buf32[_pos] >= 'a' && _buf32[_pos] <= 'z') {
							_buf32[_pos] += 'A' - 'a';
						}
						++_pos;
					}
					while (_pos < _len && isCharacterAlphanumeric(_buf32[_pos])) {
						if (_buf32[_pos] >= 'A' && _buf32[_pos] <= 'Z') {
							_buf32[_pos] += 'a' - 'A';
						}
						++_pos;
					}
					refreshLine(pi);
				}
				break;

			// ctrl-D, delete the character under the cursor
			// on an empty line, exit the shell
			case ctrlChar('D'):
				_killRing.lastAction = KillRing::actionOther;
				if (_len > 0 && _pos < _len) {
					_history.reset_recall_most_recent();
					memmove(_buf32.get() + _pos, _buf32.get() + _pos + 1, sizeof(char32_t) * (_len - _pos));
					--_len;
					refreshLine(pi);
				} else if (_len == 0) {
					_history.drop_last();
					return -1;
				}
				break;

			case META + 'd':	// meta-D, kill word to right of cursor
			case META + 'D':
				if (_pos < _len) {
					_history.reset_recall_most_recent();
					int endingPos = _pos;
					while (endingPos < _len &&
								 !isCharacterAlphanumeric(_buf32[endingPos])) {
						++endingPos;
					}
					while (endingPos < _len && isCharacterAlphanumeric(_buf32[endingPos])) {
						++endingPos;
					}
					_killRing.kill(&_buf32[_pos], endingPos - _pos, true);
					memmove(_buf32.get() + _pos, _buf32.get() + endingPos,
									sizeof(char32_t) * (_len - endingPos + 1));
					_len -= endingPos - _pos;
					refreshLine(pi);
				}
				_killRing.lastAction = KillRing::actionKill;
				break;

			case ctrlChar('E'):	// ctrl-E, move cursor to end of line
			case END_KEY:
				_killRing.lastAction = KillRing::actionOther;
				_pos = _len;
				refreshLine(pi);
				break;

			case ctrlChar('F'):	// ctrl-F, move cursor right by one character
			case RIGHT_ARROW_KEY:
				_killRing.lastAction = KillRing::actionOther;
				if (_pos < _len) {
					++_pos;
					refreshLine(pi);
				}
				break;

			case META + 'f':	// meta-F, move cursor right by one word
			case META + 'F':
			case CTRL + RIGHT_ARROW_KEY:
			case META + RIGHT_ARROW_KEY:	// Emacs allows Meta, bash & readline don't
				_killRing.lastAction = KillRing::actionOther;
				if (_pos < _len) {
					while (_pos < _len && !isCharacterAlphanumeric(_buf32[_pos])) {
						++_pos;
					}
					while (_pos < _len && isCharacterAlphanumeric(_buf32[_pos])) {
						++_pos;
					}
					refreshLine(pi);
				}
				break;

			case ctrlChar('H'):	// backspace/ctrl-H, delete char to left of cursor
				_killRing.lastAction = KillRing::actionOther;
				if (_pos > 0) {
					_history.reset_recall_most_recent();
					memmove(_buf32.get() + _pos - 1, _buf32.get() + _pos,
									sizeof(char32_t) * (1 + _len - _pos));
					--_pos;
					--_len;
					refreshLine(pi);
				}
				break;

			// meta-Backspace, kill word to left of cursor
			case META + ctrlChar('H'):
				if (_pos > 0) {
					_history.reset_recall_most_recent();
					int startingPos = _pos;
					while (_pos > 0 && !isCharacterAlphanumeric(_buf32[_pos - 1])) {
						--_pos;
					}
					while (_pos > 0 && isCharacterAlphanumeric(_buf32[_pos - 1])) {
						--_pos;
					}
					_killRing.kill(&_buf32[_pos], startingPos - _pos, false);
					memmove(_buf32.get() + _pos, _buf32.get() + startingPos,
									sizeof(char32_t) * (_len - startingPos + 1));
					_len -= startingPos - _pos;
					refreshLine(pi);
				}
				_killRing.lastAction = KillRing::actionKill;
				break;

			case ctrlChar('J'): // ctrl-J/linefeed/newline, accept line
			case ctrlChar('M'): // ctrl-M/return/enter
				_killRing.lastAction = KillRing::actionOther;
				// we need one last refresh with the cursor at the end of the line
				// so we don't display the next prompt over the previous input line
				_pos = _len; // pass _len as _pos for EOL
				refreshLine(pi, HINT_ACTION::SKIP);
				_history.commit_index();
				_history.drop_last();
				return _len;

			case ctrlChar('K'):	// ctrl-K, kill from cursor to end of line
				_killRing.kill(&_buf32[_pos], _len - _pos, true);
				_buf32[_pos] = '\0';
				_len = _pos;
				refreshLine(pi);
				_killRing.lastAction = KillRing::actionKill;
				_history.reset_recall_most_recent();
				break;

			case ctrlChar('L'):	// ctrl-L, clear screen and redisplay line
				clearScreen(pi);
				break;

			case META + 'l':	// meta-L, lowercase word
			case META + 'L':
				_killRing.lastAction = KillRing::actionOther;
				if (_pos < _len) {
					_history.reset_recall_most_recent();
					while (_pos < _len && !isCharacterAlphanumeric(_buf32[_pos])) {
						++_pos;
					}
					while (_pos < _len && isCharacterAlphanumeric(_buf32[_pos])) {
						if (_buf32[_pos] >= 'A' && _buf32[_pos] <= 'Z') {
							_buf32[_pos] += 'a' - 'A';
						}
						++_pos;
					}
					refreshLine(pi);
				}
				break;

			case ctrlChar('N'):	// ctrl-N, recall next line in history
			case ctrlChar('P'):	// ctrl-P, recall previous line in history
			case DOWN_ARROW_KEY:
			case UP_ARROW_KEY:
				_killRing.lastAction = KillRing::actionOther;
				// if not already recalling, add the current line to the history list so
				// we don't
				// have to special case it
				if ( _history.is_last() ) {
					size_t tempBufferSize = sizeof(char32_t) * _len + 1;
					unique_ptr<char[]> tempBuffer(new char[tempBufferSize]);
					copyString32to8(tempBuffer.get(), tempBufferSize, _buf32.get());
					_history.update_last( tempBuffer.get() );
				}
				if ( ! _history.is_empty() ) {
					if (c == UP_ARROW_KEY) {
						c = ctrlChar('P');
					}
					if ( ! _history.move( c == ctrlChar('P') ) ) {
						break;
					}
					size_t ucharCount = 0;
					copyString8to32(_buf32.get(), _buflen, ucharCount, _history.current().c_str());
					_len = _pos = static_cast<int>(ucharCount);
					refreshLine(pi);
				}
				break;
			case CTRL + UP_ARROW_KEY:
				if ( ! _replxx.no_color() ) {
					_killRing.lastAction = KillRing::actionOther;
					-- _hintSelection;
					refreshLine(pi, HINT_ACTION::REPAINT);
				}
				break;
			case CTRL + DOWN_ARROW_KEY:
				if ( ! _replxx.no_color() ) {
					_killRing.lastAction = KillRing::actionOther;
					++ _hintSelection;
					refreshLine(pi, HINT_ACTION::REPAINT);
				}
				break;

			case META + 'p': // Alt-P, reverse history search for prefix
			case META + 'P': // Alt-P, reverse history search for prefix
			case META + 'n': // Alt-N, forward history search for prefix
			case META + 'N': // Alt-N, forward history search for prefix
				commonPrefixSearch( pi, c );
				updatePrefix = false;
				break;
			case ctrlChar('R'): // ctrl-R, reverse history search
			case ctrlChar('S'): // ctrl-S, forward history search
				terminatingKeystroke = incrementalHistorySearch(pi, c);
				break;

			case ctrlChar('T'): // ctrl-T, transpose characters
				_killRing.lastAction = KillRing::actionOther;
				if (_pos > 0 && _len > 1) {
					_history.reset_recall_most_recent();
					size_t leftCharPos = (_pos == _len) ? _pos - 2 : _pos - 1;
					char32_t aux = _buf32[leftCharPos];
					_buf32[leftCharPos] = _buf32[leftCharPos + 1];
					_buf32[leftCharPos + 1] = aux;
					if (_pos != _len) ++_pos;
					refreshLine(pi);
				}
				break;

			case ctrlChar('U'): // ctrl-U, kill all characters to the left of the cursor
				if (_pos > 0) {
					_history.reset_recall_most_recent();
					_killRing.kill(&_buf32[0], _pos, false);
					_len -= _pos;
					memmove(_buf32.get(), _buf32.get() + _pos, sizeof(char32_t) * (_len + 1));
					_pos = 0;
					refreshLine(pi);
				}
				_killRing.lastAction = KillRing::actionKill;
				break;

			case META + 'u':	// meta-U, uppercase word
			case META + 'U':
				_killRing.lastAction = KillRing::actionOther;
				if (_pos < _len) {
					_history.reset_recall_most_recent();
					while (_pos < _len && !isCharacterAlphanumeric(_buf32[_pos])) {
						++_pos;
					}
					while (_pos < _len && isCharacterAlphanumeric(_buf32[_pos])) {
						if (_buf32[_pos] >= 'a' && _buf32[_pos] <= 'z') {
							_buf32[_pos] += 'A' - 'a';
						}
						++_pos;
					}
					refreshLine(pi);
				}
				break;

			// ctrl-W, kill to whitespace (not word) to left of cursor
			case ctrlChar('W'):
				if (_pos > 0) {
					_history.reset_recall_most_recent();
					int startingPos = _pos;
					while (_pos > 0 && _buf32[_pos - 1] == ' ') {
						--_pos;
					}
					while (_pos > 0 && _buf32[_pos - 1] != ' ') {
						--_pos;
					}
					_killRing.kill(&_buf32[_pos], startingPos - _pos, false);
					memmove(_buf32.get() + _pos, _buf32.get() + startingPos,
									sizeof(char32_t) * (_len - startingPos + 1));
					_len -= startingPos - _pos;
					refreshLine(pi);
				}
				_killRing.lastAction = KillRing::actionKill;
				break;

			case ctrlChar('Y'):	// ctrl-Y, yank killed text
				_history.reset_recall_most_recent();
				{
					Utf32String* restoredText = _killRing.yank();
					if (restoredText) {
						bool truncated = false;
						size_t ucharCount = restoredText->length();
						if (ucharCount > static_cast<size_t>(_buflen - _len)) {
							ucharCount = _buflen - _len;
							truncated = true;
						}
						memmove(_buf32.get() + _pos + ucharCount, _buf32.get() + _pos,
										sizeof(char32_t) * (_len - _pos + 1));
						memmove(_buf32.get() + _pos, restoredText->get(),
										sizeof(char32_t) * ucharCount);
						_pos += static_cast<int>(ucharCount);
						_len += static_cast<int>(ucharCount);
						refreshLine(pi);
						_killRing.lastAction = KillRing::actionYank;
						_killRing.lastYankSize = ucharCount;
						if (truncated) {
							beep();
						}
					} else {
						beep();
					}
				}
				break;

			case META + 'y':	// meta-Y, "yank-pop", rotate popped text
			case META + 'Y':
				if (_killRing.lastAction == KillRing::actionYank) {
					_history.reset_recall_most_recent();
					Utf32String* restoredText = _killRing.yankPop();
					if (restoredText) {
						bool truncated = false;
						size_t ucharCount = restoredText->length();
						if (ucharCount >
								static_cast<size_t>(_killRing.lastYankSize + _buflen - _len)) {
							ucharCount = _killRing.lastYankSize + _buflen - _len;
							truncated = true;
						}
						if (ucharCount > _killRing.lastYankSize) {
							memmove(_buf32.get() + _pos + ucharCount - _killRing.lastYankSize,
											_buf32.get() + _pos, sizeof(char32_t) * (_len - _pos + 1));
							memmove(_buf32.get() + _pos - _killRing.lastYankSize, restoredText->get(),
											sizeof(char32_t) * ucharCount);
						} else {
							memmove(_buf32.get() + _pos - _killRing.lastYankSize, restoredText->get(),
											sizeof(char32_t) * ucharCount);
							memmove(_buf32.get() + _pos + ucharCount - _killRing.lastYankSize,
											_buf32.get() + _pos, sizeof(char32_t) * (_len - _pos + 1));
						}
						_pos += static_cast<int>(ucharCount - _killRing.lastYankSize);
						_len += static_cast<int>(ucharCount - _killRing.lastYankSize);
						_killRing.lastYankSize = ucharCount;
						refreshLine(pi);
						if (truncated) {
							beep();
						}
						break;
					}
				}
				beep();
				break;

#ifndef _WIN32
			case ctrlChar('Z'):	// ctrl-Z, job control
				disableRawMode();	// Returning to Linux (whatever) shell, leave raw
													 // mode
//        raise(SIGSTOP);    // Break out in mid-line
				enableRawMode();	 // Back from Linux shell, re-enter raw mode
				if (!pi.write()) break;	// Redraw prompt
				refreshLine(pi);				 // Refresh the line
				break;
#endif

			// DEL, delete the character under the cursor
			case 127:
			case DELETE_KEY:
				_killRing.lastAction = KillRing::actionOther;
				if (_len > 0 && _pos < _len) {
					_history.reset_recall_most_recent();
					memmove(_buf32.get() + _pos, _buf32.get() + _pos + 1, sizeof(char32_t) * (_len - _pos));
					--_len;
					refreshLine(pi);
				}
				break;

			case META + '<':		 // meta-<, beginning of history
			case PAGE_UP_KEY:		// Page Up, beginning of history
			case META + '>':		 // meta->, end of history
			case PAGE_DOWN_KEY:	// Page Down, end of history
				_killRing.lastAction = KillRing::actionOther;
				// if not already recalling, add the current line to the history list so
				// we don't
				// have to special case it
				if ( _history.is_last() ) {
					size_t tempBufferSize = sizeof(char32_t) * _len + 1;
					unique_ptr<char[]> tempBuffer(new char[tempBufferSize]);
					copyString32to8(tempBuffer.get(), tempBufferSize, _buf32.get());
					_history.update_last( tempBuffer.get() );
				}
				if ( ! _history.is_empty() ) {
					_history.jump( (c == META + '<' || c == PAGE_UP_KEY) );
					size_t ucharCount = 0;
					copyString8to32(_buf32.get(), _buflen, ucharCount, _history.current().c_str());
					_len = _pos = static_cast<int>(ucharCount);
					refreshLine(pi);
				}
				break;

			// not one of our special characters, maybe insert it in the buffer
			default:
				_killRing.lastAction = KillRing::actionOther;
				_history.reset_recall_most_recent();
				if (c & (META | CTRL)) {	// beep on unknown Ctrl and/or Meta keys
					beep();
					break;
				}
				if (_len < _buflen) {
					if (isControlChar(c)) {	// don't insert control characters
						beep();
						break;
					}
					if (_len == _pos) {	// at end of buffer
						_buf32[_pos] = c;
						++_pos;
						++_len;
						_buf32[_len] = '\0';
						int inputLen = calculateColumnPosition(_buf32.get(), _len);
						if ( _replxx.no_color()
							|| ( ! ( _replxx.has_highlighter() || _replxx.has_hinter() )
								&& ( pi.promptIndentation + inputLen < pi.promptScreenColumns )
							)
						) {
							if (inputLen > pi.promptPreviousInputLen)
								pi.promptPreviousInputLen = inputLen;
							/* Avoid a full update of the line in the
							 * trivial case. */
							if (write32(1, reinterpret_cast<char32_t*>(&c), 1) == -1)
								return -1;
						} else {
							refreshLine(pi);
						}
					} else {	// not at end of buffer, have to move characters to our
										// right
						memmove(_buf32.get() + _pos + 1, _buf32.get() + _pos,
										sizeof(char32_t) * (_len - _pos));
						_buf32[_pos] = c;
						++_len;
						++_pos;
						_buf32[_len] = '\0';
						refreshLine(pi);
					}
				} else {
					beep();	// buffer is full, beep on new characters
				}
				break;
		}
		if ( updatePrefix ) {
			_prefix = _pos;
		}
	}
	return _len;
}

void InputBuffer::commonPrefixSearch(PromptBase& pi, int startChar) {
	_killRing.lastAction = KillRing::actionOther;
	size_t bufferSize = sizeof(char32_t) * length() + 1;
	unique_ptr<char[]> buf8(new char[bufferSize]);
	copyString32to8(buf8.get(), bufferSize, buf());
	int prefixSize( calculateColumnPosition( _buf32.get(), _prefix ) );
	if (
		_history.common_prefix_search(
			buf8.get(), prefixSize, ( startChar == ( META + 'p' ) ) || ( startChar == ( META + 'P' ) )
		)
	) {
		size_t ucharCount = 0;
		copyString8to32( buf(), _buflen, ucharCount, _history.current().c_str() );
		_len = _pos = static_cast<int>(ucharCount);
		refreshLine(pi);
	}
}

/**
 * Incremental history search -- take over the prompt and keyboard as the user
 * types a search
 * string, deletes characters from it, changes direction, and either accepts the
 * found line (for
 * execution orediting) or cancels.
 * @param pi				PromptBase struct holding information about the (old,
 * static) prompt and our
 *									screen position
 * @param startChar the character that began the search, used to set the initial
 * direction
 */
int InputBuffer::incrementalHistorySearch(PromptBase& pi, int startChar) {
	size_t bufferSize;
	size_t ucharCount = 0;

	// if not already recalling, add the current line to the history list so we
	// don't have to
	// special case it
	if ( _history.is_last() ) {
		bufferSize = sizeof(char32_t) * _len + 1;
		unique_ptr<char[]> tempBuffer(new char[bufferSize]);
		copyString32to8(tempBuffer.get(), bufferSize, _buf32.get());
		_history.update_last( tempBuffer.get() );
	}
	int historyLineLength = _len;
	int historyLinePosition = _pos;
	InputBuffer empty( _replxx, 1 );
	empty.refreshLine(pi); // erase the old input first
	DynamicPrompt dp(pi, (startChar == ctrlChar('R')) ? -1 : 1);

	dp.promptPreviousLen = pi.promptPreviousLen;
	dp.promptPreviousInputLen = pi.promptPreviousInputLen;
	dynamicRefresh(dp, _buf32.get(), historyLineLength,
								 historyLinePosition);	// draw user's text with our prompt

	// loop until we get an exit character
	int c = 0;
	bool keepLooping = true;
	bool useSearchedLine = true;
	bool searchAgain = false;
	char32_t* activeHistoryLine = 0;
	while (keepLooping) {
		c = read_char();
		c = cleanupCtrl(c);	// convert CTRL + <char> into normal ctrl

		switch (c) {
			// these characters keep the selected text but do not execute it
			case ctrlChar('A'):	// ctrl-A, move cursor to start of line
			case HOME_KEY:
			case ctrlChar('B'):	// ctrl-B, move cursor left by one character
			case LEFT_ARROW_KEY:
			case META + 'b':	// meta-B, move cursor left by one word
			case META + 'B':
			case CTRL + LEFT_ARROW_KEY:
			case META + LEFT_ARROW_KEY:	// Emacs allows Meta, bash & readline don't
			case ctrlChar('D'):
			case META + 'd':	// meta-D, kill word to right of cursor
			case META + 'D':
			case ctrlChar('E'):	// ctrl-E, move cursor to end of line
			case END_KEY:
			case ctrlChar('F'):	// ctrl-F, move cursor right by one character
			case RIGHT_ARROW_KEY:
			case META + 'f':	// meta-F, move cursor right by one word
			case META + 'F':
			case CTRL + RIGHT_ARROW_KEY:
			case META + RIGHT_ARROW_KEY:	// Emacs allows Meta, bash & readline don't
			case META + ctrlChar('H'):
			case ctrlChar('J'):
			case ctrlChar('K'):	// ctrl-K, kill from cursor to end of line
			case ctrlChar('M'):
			case ctrlChar('N'):	// ctrl-N, recall next line in history
			case ctrlChar('P'):	// ctrl-P, recall previous line in history
			case DOWN_ARROW_KEY:
			case UP_ARROW_KEY:
			case ctrlChar('T'):	// ctrl-T, transpose characters
			case ctrlChar(
					'U'):	// ctrl-U, kill all characters to the left of the cursor
			case ctrlChar('W'):
			case META + 'y':	// meta-Y, "yank-pop", rotate popped text
			case META + 'Y':
			case 127:
			case DELETE_KEY:
			case META + '<':	// start of history
			case PAGE_UP_KEY:
			case META + '>':	// end of history
			case PAGE_DOWN_KEY:
				keepLooping = false;
				break;

			// these characters revert the input line to its previous state
			case ctrlChar('C'):	// ctrl-C, abort this line
			case ctrlChar('G'):
			case ctrlChar('L'):	// ctrl-L, clear screen and redisplay line
				keepLooping = false;
				useSearchedLine = false;
				if (c != ctrlChar('L')) {
					c = -1;	// ctrl-C and ctrl-G just abort the search and do nothing
									 // else
				}
				break;

			// these characters stay in search mode and update the display
			case ctrlChar('S'):
			case ctrlChar('R'):
				if (dp.searchTextLen ==
						0) {	// if no current search text, recall previous text
					if (previousSearchText.length()) {
						dp.updateSearchText(previousSearchText.get());
					}
				}
				if ((dp.direction == 1 && c == ctrlChar('R')) ||
						(dp.direction == -1 && c == ctrlChar('S'))) {
					dp.direction = 0 - dp.direction;	// reverse direction
					dp.updateSearchPrompt();					// change the prompt
				} else {
					searchAgain = true;	// same direction, search again
				}
				break;

// job control is its own thing
#ifndef _WIN32
			case ctrlChar('Z'):	// ctrl-Z, job control
				disableRawMode();	// Returning to Linux (whatever) shell, leave raw
													 // mode
				raise(SIGSTOP);		// Break out in mid-line
				enableRawMode();	 // Back from Linux shell, re-enter raw mode
				{
					bufferSize = historyLineLength + 1;
					unique_ptr<char32_t[]> tempUnicode(new char32_t[bufferSize]);
					copyString8to32(tempUnicode.get(), bufferSize, ucharCount,
													_history.current().c_str());
					dynamicRefresh(dp, tempUnicode.get(), historyLineLength,
												 historyLinePosition);
				}
				continue;
				break;
#endif

			// these characters update the search string, and hence the selected input
			// line
			case ctrlChar('H'):	// backspace/ctrl-H, delete char to left of cursor
				if (dp.searchTextLen > 0) {
					unique_ptr<char32_t[]> tempUnicode(new char32_t[dp.searchTextLen]);
					--dp.searchTextLen;
					dp.searchText[dp.searchTextLen] = 0;
					copyString32(tempUnicode.get(), dp.searchText.get(),
											 dp.searchTextLen);
					dp.updateSearchText(tempUnicode.get());
				} else {
					beep();
				}
				break;

			case ctrlChar('Y'):	// ctrl-Y, yank killed text
				break;

			default:
				if (!isControlChar(c) && c <= 0x0010FFFF) {	// not an action character
					unique_ptr<char32_t[]> tempUnicode(
							new char32_t[dp.searchTextLen + 2]);
					copyString32(tempUnicode.get(), dp.searchText.get(),
											 dp.searchTextLen);
					tempUnicode[dp.searchTextLen] = c;
					tempUnicode[dp.searchTextLen + 1] = 0;
					dp.updateSearchText(tempUnicode.get());
				} else {
					beep();
				}
		}	// switch

		// if we are staying in search mode, search now
		if (keepLooping) {
			bufferSize = historyLineLength + 1;
			if (activeHistoryLine) {
				delete[] activeHistoryLine;
				activeHistoryLine = nullptr;
			}
			activeHistoryLine = new char32_t[bufferSize];
			copyString8to32(activeHistoryLine, bufferSize, ucharCount,
											_history.current().c_str());
			if (dp.searchTextLen > 0) {
				bool found = false;
				int historySearchIndex = _history.current_pos();
				int lineLength = static_cast<int>(ucharCount);
				int lineSearchPos = historyLinePosition;
				if (searchAgain) {
					lineSearchPos += dp.direction;
				}
				searchAgain = false;
				while (true) {
					while ((dp.direction > 0) ? (lineSearchPos < lineLength)
																		: (lineSearchPos >= 0)) {
						if (strncmp32(dp.searchText.get(),
													&activeHistoryLine[lineSearchPos],
													dp.searchTextLen) == 0) {
							found = true;
							break;
						}
						lineSearchPos += dp.direction;
					}
					if (found) {
						_history.reset_pos( historySearchIndex );
						historyLineLength = lineLength;
						historyLinePosition = lineSearchPos;
						break;
					} else if ((dp.direction > 0) ? (historySearchIndex < _history.size())
																				: (historySearchIndex > 0)) {
						historySearchIndex += dp.direction;
						bufferSize = _history[historySearchIndex].length() + 1;
						delete[] activeHistoryLine;
						activeHistoryLine = nullptr;
						activeHistoryLine = new char32_t[bufferSize];
						copyString8to32(activeHistoryLine, bufferSize, ucharCount,
														_history[historySearchIndex].c_str());
						lineLength = static_cast<int>(ucharCount);
						lineSearchPos =
								(dp.direction > 0) ? 0 : (lineLength - dp.searchTextLen);
					} else {
						beep();
						break;
					}
				};	// while
			}
			if (activeHistoryLine) {
				delete[] activeHistoryLine;
				activeHistoryLine = nullptr;
			}
			bufferSize = historyLineLength + 1;
			activeHistoryLine = new char32_t[bufferSize];
			copyString8to32(activeHistoryLine, bufferSize, ucharCount,
											_history.current().c_str());
			dynamicRefresh(dp, activeHistoryLine, historyLineLength,
										 historyLinePosition); // draw user's text with our prompt
		}
	}	// while

	// leaving history search, restore previous prompt, maybe make searched line
	// current
	PromptBase pb;
	pb.promptChars = pi.promptIndentation;
	pb.promptBytes = pi.promptBytes;
	Utf32String tempUnicode(pb.promptBytes + 1);

	copyString32(tempUnicode.get(), &pi.promptText[pi.promptLastLinePosition],
							 pb.promptBytes - pi.promptLastLinePosition);
	tempUnicode.initFromBuffer();
	pb.promptText = tempUnicode;
	pb.promptExtraLines = 0;
	pb.promptIndentation = pi.promptIndentation;
	pb.promptLastLinePosition = 0;
	pb.promptPreviousInputLen = historyLineLength;
	pb.promptCursorRowOffset = dp.promptCursorRowOffset;
	pb.promptScreenColumns = pi.promptScreenColumns;
	pb.promptPreviousLen = dp.promptChars;
	if (useSearchedLine && activeHistoryLine) {
		_history.set_recall_most_recent();
		copyString32(_buf32.get(), activeHistoryLine, _buflen + 1);
		_len = historyLineLength;
		_prefix = _pos = historyLinePosition;
	}
	if (activeHistoryLine) {
		delete[] activeHistoryLine;
		activeHistoryLine = nullptr;
	}
	dynamicRefresh(pb, _buf32.get(), _len, _pos);	// redraw the original prompt with current input
	pi.promptPreviousInputLen = _len;
	pi.promptCursorRowOffset = pi.promptExtraLines + pb.promptCursorRowOffset;
	previousSearchText =
			dp.searchText;	// save search text for possible reuse on ctrl-R ctrl-R
	return c;					 // pass a character or -1 back to main loop
}

void InputBuffer::clearScreen(PromptBase& pi) {
	_replxx.clear_screen();
	if (!pi.write()) return;
#ifndef _WIN32
	// we have to generate our own newline on line wrap on Linux
	if (pi.promptIndentation == 0 && pi.promptExtraLines > 0)
		if (fwrite("\n", 1, 1, thread_stdout) == -1) return;
#endif
	pi.promptCursorRowOffset = pi.promptExtraLines;
	refreshLine(pi);
}

/**
 * Display the dynamic incremental search prompt and the current user input
 * line.
 * @param pi	 PromptBase struct holding information about the prompt and our
 * screen position
 * @param buf32	input buffer to be displayed
 * @param len	count of characters in the buffer
 * @param pos	current cursor position within the buffer (0 <= pos <= len)
 */
void dynamicRefresh(PromptBase& pi, char32_t* buf32, int len, int pos) {
	// calculate the position of the end of the prompt
	int xEndOfPrompt, yEndOfPrompt;
	calculateScreenPosition(0, 0, pi.promptScreenColumns, pi.promptChars,
													xEndOfPrompt, yEndOfPrompt);
	pi.promptIndentation = xEndOfPrompt;

	// calculate the position of the end of the input line
	int xEndOfInput, yEndOfInput;
	calculateScreenPosition(xEndOfPrompt, yEndOfPrompt, pi.promptScreenColumns,
													calculateColumnPosition(buf32, len), xEndOfInput,
													yEndOfInput);

	// calculate the desired position of the cursor
	int xCursorPos, yCursorPos;
	calculateScreenPosition(xEndOfPrompt, yEndOfPrompt, pi.promptScreenColumns,
													calculateColumnPosition(buf32, pos), xCursorPos,
													yCursorPos);

#ifdef _WIN32
	// position at the start of the prompt, clear to end of previous input
	CONSOLE_SCREEN_BUFFER_INFO inf;
	GetConsoleScreenBufferInfo(console_out, &inf);
	inf.dwCursorPosition.X = 0;
	inf.dwCursorPosition.Y -= pi.promptCursorRowOffset /*- pi.promptExtraLines*/;
	SetConsoleCursorPosition(console_out, inf.dwCursorPosition);
	DWORD count;
	FillConsoleOutputCharacterA(console_out, ' ',
															pi.promptPreviousLen + pi.promptPreviousInputLen,
															inf.dwCursorPosition, &count);
	pi.promptPreviousLen = pi.promptIndentation;
	pi.promptPreviousInputLen = len;

	// display the prompt
	if (!pi.write()) return;

	// display the input line
	if (write32(1, buf32, len) == -1) return;

	// position the cursor
	GetConsoleScreenBufferInfo(console_out, &inf);
	inf.dwCursorPosition.X = xCursorPos;	// 0-based on Win32
	inf.dwCursorPosition.Y -= yEndOfInput - yCursorPos;
	SetConsoleCursorPosition(console_out, inf.dwCursorPosition);
#else	// _WIN32
	char seq[64];
	int cursorRowMovement = pi.promptCursorRowOffset - pi.promptExtraLines;
	if (cursorRowMovement > 0) {	// move the cursor up as required
		snprintf(seq, sizeof seq, "\x1b[%dA", cursorRowMovement);
		if (fwrite(seq, 1, strlen(seq), thread_stdout) == -1) return;
	}
	// position at the start of the prompt, clear to end of screen
	snprintf(seq, sizeof seq, "\x1b[1G\x1b[J");	// 1-based on VT100
	if (fwrite(seq, 1, strlen(seq), thread_stdout) == -1) return;

	// display the prompt
	if (!pi.write()) return;

	// display the input line
	if (write32(1, buf32, len) == -1) return;

	// we have to generate our own newline on line wrap
	if (xEndOfInput == 0 && yEndOfInput > 0)
		if (fwrite("\n", 1, 1, thread_stdout) == -1) return;

	// position the cursor
	cursorRowMovement = yEndOfInput - yCursorPos;
	if (cursorRowMovement > 0) {	// move the cursor up as required
		snprintf(seq, sizeof seq, "\x1b[%dA", cursorRowMovement);
		if (fwrite(seq, 1, strlen(seq), thread_stdout) == -1) return;
	}
	// position the cursor within the line
	snprintf(seq, sizeof seq, "\x1b[%dG", xCursorPos + 1);	// 1-based on VT100
	if (fwrite(seq, 1, strlen(seq), thread_stdout) == -1) return;
#endif

	pi.promptCursorRowOffset =
			pi.promptExtraLines + yCursorPos;	// remember row for next pass
}

}

