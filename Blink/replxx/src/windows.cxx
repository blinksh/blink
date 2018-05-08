#ifdef _WIN32

#include <iostream>

#include "windows.hxx"
#include "conversion.hxx"
#include "io.hxx"

#ifndef ENABLE_VIRTUAL_TERMINAL_PROCESSING
static DWORD const ENABLE_VIRTUAL_TERMINAL_PROCESSING = 4;
#endif

using namespace std;

namespace replxx {

WinAttributes WIN_ATTR;

template<typename T>
T* HandleEsc(T* p, T* end) {
	if (*p == '[') {
		int code = 0;

		int thisBackground( WIN_ATTR._defaultBackground );
		for (++p; p < end; ++p) {
			char32_t c = *p;

			if ('0' <= c && c <= '9') {
				code = code * 10 + (c - '0');
			} else if (c == 'm' || c == ';') {
				switch (code) {
					case 0:
						WIN_ATTR._consoleAttribute = WIN_ATTR._defaultAttribute;
						WIN_ATTR._consoleColor = WIN_ATTR._defaultColor | thisBackground;
						break;
					case 1:	// BOLD
					case 5:	// BLINK
						WIN_ATTR._consoleAttribute = (WIN_ATTR._defaultAttribute ^ FOREGROUND_INTENSITY) & INTENSITY;
						break;
					case 22:
						WIN_ATTR._consoleAttribute = WIN_ATTR._defaultAttribute;
						break;
					case 30:
					case 90:
						WIN_ATTR._consoleColor = thisBackground;
						break;
					case 31:
					case 91:
						WIN_ATTR._consoleColor = FOREGROUND_RED | thisBackground;
						break;
					case 32:
					case 92:
						WIN_ATTR._consoleColor = FOREGROUND_GREEN | thisBackground;
						break;
					case 33:
					case 93:
						WIN_ATTR._consoleColor = FOREGROUND_RED | FOREGROUND_GREEN | thisBackground;
						break;
					case 34:
					case 94:
						WIN_ATTR._consoleColor = FOREGROUND_BLUE | thisBackground;
						break;
					case 35:
					case 95:
						WIN_ATTR._consoleColor = FOREGROUND_BLUE | FOREGROUND_RED | thisBackground;
						break;
					case 36:
					case 96:
						WIN_ATTR._consoleColor = FOREGROUND_BLUE | FOREGROUND_GREEN | thisBackground;
						break;
					case 37:
					case 97:
						WIN_ATTR._consoleColor = FOREGROUND_GREEN | FOREGROUND_RED | FOREGROUND_BLUE | thisBackground;
						break;
					case 101:
						thisBackground = BACKGROUND_RED;
						break;
				}

				if ( ( code >= 90 ) && ( code <= 97 ) ) {
					WIN_ATTR._consoleAttribute = (WIN_ATTR._defaultAttribute ^ FOREGROUND_INTENSITY) & INTENSITY;
				}

				code = 0;
			}

			if (*p == 'm') {
				++p;
				break;
			}
		}
	} else {
		++p;
	}

	auto handle = GetStdHandle(STD_OUTPUT_HANDLE);
	SetConsoleTextAttribute(handle,
													WIN_ATTR._consoleAttribute | WIN_ATTR._consoleColor);

	return p;
}

int win_write( char const* str_, int size_ ) {
	int count( 0 );
	DWORD currentMode( 0 );
	HANDLE consoleOut( GetStdHandle( STD_OUTPUT_HANDLE ) );
	if ( tty::out && GetConsoleMode( consoleOut, &currentMode ) ) {
		UINT inputCodePage( GetConsoleCP() );
		UINT outputCodePage( GetConsoleOutputCP() );
		SetConsoleCP( 65001 );
		SetConsoleOutputCP( 65001 );
		if ( SetConsoleMode( consoleOut, currentMode | ENABLE_VIRTUAL_TERMINAL_PROCESSING ) ) {
			WriteConsole( consoleOut, str_, size_, nullptr, nullptr );
			count = size_;
			SetConsoleMode( consoleOut, currentMode );
		} else {
			char const* s( str_ );
			char const* e( str_ + size_ );
			while ( str_ < e ) {
				if ( *str_ == 27 ) {
					if ( s < str_ ) {
						WriteConsole( consoleOut, s, static_cast<DWORD>( str_ - s ), nullptr, nullptr );
						count += ( str_ - s );
					}
					str_ = s = HandleEsc( str_ + 1, e );
				} else {
					++ str_;
				}
			}

			if ( s < str_ ) {
				WriteConsole( consoleOut, s, static_cast<DWORD>( str_ - s ), nullptr, nullptr );
				count += ( str_ - s );
			}
		}
		SetConsoleCP( inputCodePage );
		SetConsoleOutputCP( outputCodePage );
	} else {
		_write( 1, str_, size_ );
		count = size_;
	}
	return ( count );
}

}

#endif

