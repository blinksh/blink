#include <memory>
#include <cerrno>
#include <cstdlib>
#include <stdio.h>

#ifdef _WIN32

#include <conio.h>
#include <windows.h>
#include <io.h>
#define isatty _isatty
#define strcasecmp _stricmp
#define strdup _strdup
#define write _write
#define STDIN_FILENO 0

#include "windows.hxx"

#else /* _WIN32 */

#include <unistd.h>
#include <termios.h>
#include <sys/ioctl.h>

#endif /* _WIN32 */

#include "io.hxx"
#include "conversion.hxx"
#include "escape.hxx"
#include "keycodes.hxx"


using namespace std;

__thread static winsize *__win = NULL;
__thread static FILE* __thread_stdin;
__thread static FILE* __thread_stdout;
__thread static FILE* __thread_stderr;

namespace replxx {

#ifdef _WIN32
HANDLE console_out;
static HANDLE console_in;
static DWORD oldMode;
static WORD oldDisplayAttribute;
static UINT const inputCodePage( GetConsoleCP() );
static UINT const outputCodePage( GetConsoleOutputCP() );
#else
__thread static struct termios orig_termios; /* in order to restore at exit */
#endif

__thread static int rawmode = 0; /* for atexit() function to check if restore is needed*/
__thread static int atexit_registered = 0; /* register atexit just 1 time */
// At exit we'll try to fix the terminal to the initial conditions
static void repl_at_exit(void) { disableRawMode(); }

namespace tty {

bool is_a_tty( int fd_ ) {
	bool aTTY( isatty( fd_ ) != 0 );
#ifdef _WIN32
	do {
		if ( aTTY ) {
			break;
		}
		HANDLE h( (HANDLE)_get_osfhandle( fd_ ) );
		if ( h == INVALID_HANDLE_VALUE ) {
			break;
		}
		DWORD st( 0 );
		if ( ! GetConsoleMode( h, &st ) ) {
			break;
		}
		aTTY = true;
	} while ( false );
#endif
	return ( aTTY );
}

bool in( true /*is_a_tty( 0 )*/ );
bool out( is_a_tty( 1 ) );

}

int write32( int fd, char32_t* text32, int len32 ) {
	size_t len8 = 4 * len32 + 1;
	unique_ptr<char[]> text8(new char[len8]);
	size_t count8 = 0;

	copyString32to8(text8.get(), len8, &count8, text32, len32);
#ifdef _WIN32
	return win_write(text8.get(), count8);
#else
//  return fwritef(fd, text8.get(), count8);
//  fwrite(const void * __restrict __ptr, size_t __size, size_t __nitems, FILE * __restrict __stream)
  return ::fwrite(text8.get(), 1, count8, __thread_stdout);
#endif
}
  
void setWinsize(struct winsize *win, FILE *in, FILE *out, FILE *err)
{
  __win = win;
  __thread_stdin = in;
  __thread_stdout = out;
  __thread_stderr = err;
}

int getScreenColumns(void) {
	int cols;
#ifdef _WIN32
	CONSOLE_SCREEN_BUFFER_INFO inf;
	GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &inf);
	cols = inf.dwSize.X;
#else
  cols = __win->ws_col;
//  struct winsize ws;
//  cols = (ioctl(1, TIOCGWINSZ, &ws) == -1) ? 80 : ws.ws_col;
#endif
	// cols is 0 in certain circumstances like inside debugger, which creates
	// further issues
	return (cols > 0) ? cols : 80;
}

int getScreenRows(void) {
	int rows;
#ifdef _WIN32
	CONSOLE_SCREEN_BUFFER_INFO inf;
	GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &inf);
	rows = 1 + inf.srWindow.Bottom - inf.srWindow.Top;
#else
  rows = __win->ws_row;
//  struct winsize ws;
//  rows = (ioctl(1, TIOCGWINSZ, &ws) == -1) ? 24 : ws.ws_row;
#endif
	return (rows > 0) ? rows : 24;
}

void setDisplayAttribute(bool enhancedDisplay, bool error) {
#ifdef _WIN32
	if (enhancedDisplay) {
		CONSOLE_SCREEN_BUFFER_INFO inf;
		GetConsoleScreenBufferInfo(console_out, &inf);
		oldDisplayAttribute = inf.wAttributes;
		BYTE oldLowByte = oldDisplayAttribute & 0xFF;
		BYTE newLowByte;
		switch (oldLowByte) {
			case 0x07:
				// newLowByte = FOREGROUND_BLUE | FOREGROUND_INTENSITY;	// too dim
				// newLowByte = FOREGROUND_BLUE;												 // even dimmer
				newLowByte = FOREGROUND_BLUE |
										 FOREGROUND_GREEN;	// most similar to xterm appearance
				break;
			case 0x70:
				newLowByte = BACKGROUND_BLUE | BACKGROUND_INTENSITY;
				break;
			default:
				newLowByte = oldLowByte ^ 0xFF;	// default to inverse video
				break;
		}
		inf.wAttributes = (inf.wAttributes & 0xFF00) | newLowByte;
		SetConsoleTextAttribute(console_out, inf.wAttributes);
	} else {
		SetConsoleTextAttribute(console_out, oldDisplayAttribute);
	}
#else
	if (enhancedDisplay) {
		char const* p = (error ? "\x1b[1;31m" : "\x1b[1;34m");
		if (fwrite(p, 1, 7, __thread_stdout) == -1) {
			return; /* bright blue (visible with both B&W bg) */
		}
	} else {
		if (fwrite("\x1b[0m", 1, 4, __thread_stdout) == -1) return; /* reset */
	}
#endif
}

int enableRawMode(void) {
#ifdef _WIN32
	if ( ! console_in ) {
		console_in = GetStdHandle( STD_INPUT_HANDLE );
		console_out = GetStdHandle( STD_OUTPUT_HANDLE );
		SetConsoleCP( 65001 );
		SetConsoleOutputCP( 65001 );
		GetConsoleMode( console_in, &oldMode );
		SetConsoleMode(
			console_in,
			oldMode & ~( ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT | ENABLE_PROCESSED_INPUT )
		);
	}
	return 0;
#else
//  fprintf(__thread_stdout, "\x1b]1337;BlinkAutoCR=0\x07");
  rawmode = 1;
  return 0;
  
	struct termios raw;

	if ( ! tty::in ) {
		goto fatal;
	}
	if (!atexit_registered) {
		atexit(repl_at_exit);
		atexit_registered = 1;
	}
//  if (tcgetattr(0, &orig_termios) == -1) goto fatal;

	raw = orig_termios; /* modify the original mode */
	/* input modes: no break, no CR to NL, no parity check, no strip char,
	 * no start/stop output control. */
	raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
	/* output modes - disable post processing */
	// this is wrong, we don't want raw output, it turns newlines into straight
	// linefeeds
	// raw.c_oflag &= ~(OPOST);
	/* control modes - set 8 bit chars */
	raw.c_cflag |= (CS8);
	/* local modes - echoing off, canonical off, no extended functions,
	 * no signal chars (^Z,^C) */
	raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
	/* control chars - set return condition: min number of bytes and timer.
	 * We want read to return every single byte, without timeout. */
	raw.c_cc[VMIN] = 1;
	raw.c_cc[VTIME] = 0; /* 1 byte, no timer */

	/* put terminal in raw mode after flushing */
	if (tcsetattr(0, TCSADRAIN, &raw) < 0) goto fatal;
	rawmode = 1;
	return 0;

fatal:
	errno = ENOTTY;
	return -1;
#endif
}

void disableRawMode(void) {
#ifdef _WIN32
	SetConsoleMode(console_in, oldMode);
	SetConsoleCP( inputCodePage );
	SetConsoleOutputCP( outputCodePage );
	console_in = 0;
	console_out = 0;
#else
	if ( rawmode /*&& tcsetattr(0, TCSADRAIN, &orig_termios ) != -1 */) {
		rawmode = 0;
//    fprintf(__thread_stdout, "\x1b]1337;BlinkAutoCR=1\x07");
	}
#endif
}

#ifndef _WIN32

/**
 * Read a UTF-8 sequence from the non-Windows keyboard and return the Unicode
 * (char32_t) character it
 * encodes
 *
 * @return	char32_t Unicode character
 */
char32_t readUnicodeCharacter(void) {
	__thread static char8_t utf8String[5];
	__thread static size_t utf8Count = 0;
	while (true) {
		char8_t c;

		/* Continue reading if interrupted by signal. */
		ssize_t nread;
		do {
			nread = read(fileno(__thread_stdin), &c, 1);
		} while ((nread == -1) && (errno == EINTR));

		if (nread <= 0) return 0;
		if (c <= 0x7F || locale::is8BitEncoding) {	// short circuit ASCII
			utf8Count = 0;
			return c;
		} else if (utf8Count < sizeof(utf8String) - 1) {
			utf8String[utf8Count++] = c;
			utf8String[utf8Count] = 0;
			char32_t unicodeChar[2];
			size_t ucharCount;
			ConversionResult res =
					copyString8to32(unicodeChar, 2, ucharCount, utf8String);
			if (res == conversionOK && ucharCount) {
				utf8Count = 0;
				return unicodeChar[0];
			}
		} else {
			utf8Count =
					0;	// this shouldn't happen: got four bytes but no UTF-8 character
		}
	}
}

#endif	// #ifndef _WIN32

void beep() {
	fprintf(__thread_stderr, "\x7");	// ctrl-G == bell/beep
	fflush(__thread_stderr);
}

// replxx_read_char -- read a keystroke or keychord from the keyboard, and
// translate it
// into an encoded "keystroke".	When convenient, extended keys are translated
// into their
// simpler Emacs keystrokes, so an unmodified "left arrow" becomes Ctrl-B.
//
// A return value of zero means "no input available", and a return value of -1
// means "invalid key".
//
char32_t read_char(void) {
#ifdef _WIN32

	INPUT_RECORD rec;
	DWORD count;
	int modifierKeys = 0;
	bool escSeen = false;
	while (true) {
		ReadConsoleInputW(console_in, &rec, 1, &count);
#if 0	// helper for debugging keystrokes, display info in the debug "Output"
			 // window in the debugger
				{
						if ( rec.EventType == KEY_EVENT ) {
								//if ( rec.Event.KeyEvent.uChar.UnicodeChar ) {
										char buf[1024];
										sprintf(
														buf,
														"Unicode character 0x%04X, repeat count %d, virtual keycode 0x%04X, "
														"virtual scancode 0x%04X, key %s%s%s%s%s\n",
														rec.Event.KeyEvent.uChar.UnicodeChar,
														rec.Event.KeyEvent.wRepeatCount,
														rec.Event.KeyEvent.wVirtualKeyCode,
														rec.Event.KeyEvent.wVirtualScanCode,
														rec.Event.KeyEvent.bKeyDown ? "down" : "up",
																(rec.Event.KeyEvent.dwControlKeyState & LEFT_CTRL_PRESSED)	?
																		" L-Ctrl" : "",
																(rec.Event.KeyEvent.dwControlKeyState & RIGHT_CTRL_PRESSED) ?
																		" R-Ctrl" : "",
																(rec.Event.KeyEvent.dwControlKeyState & LEFT_ALT_PRESSED)	 ?
																		" L-Alt"	: "",
																(rec.Event.KeyEvent.dwControlKeyState & RIGHT_ALT_PRESSED)	?
																		" R-Alt"	: ""
													 );
										OutputDebugStringA( buf );
								//}
						}
				}
#endif
		if (rec.EventType != KEY_EVENT) {
			continue;
		}
		// Windows provides for entry of characters that are not on your keyboard by
		// sending the
		// Unicode characters as a "key up" with virtual keycode 0x12 (VK_MENU ==
		// Alt key) ...
		// accept these characters, otherwise only process characters on "key down"
		if (!rec.Event.KeyEvent.bKeyDown &&
				rec.Event.KeyEvent.wVirtualKeyCode != VK_MENU) {
			continue;
		}
		modifierKeys = 0;
		// AltGr is encoded as ( LEFT_CTRL_PRESSED | RIGHT_ALT_PRESSED ), so don't
		// treat this
		// combination as either CTRL or META we just turn off those two bits, so it
		// is still
		// possible to combine CTRL and/or META with an AltGr key by using
		// right-Ctrl and/or
		// left-Alt
		if ((rec.Event.KeyEvent.dwControlKeyState &
				 (LEFT_CTRL_PRESSED | RIGHT_ALT_PRESSED)) ==
				(LEFT_CTRL_PRESSED | RIGHT_ALT_PRESSED)) {
			rec.Event.KeyEvent.dwControlKeyState &=
					~(LEFT_CTRL_PRESSED | RIGHT_ALT_PRESSED);
		}
		if (rec.Event.KeyEvent.dwControlKeyState &
				(RIGHT_CTRL_PRESSED | LEFT_CTRL_PRESSED)) {
			modifierKeys |= CTRL;
		}
		if (rec.Event.KeyEvent.dwControlKeyState &
				(RIGHT_ALT_PRESSED | LEFT_ALT_PRESSED)) {
			modifierKeys |= META;
		}
		if (escSeen) {
			modifierKeys |= META;
		}
		if (rec.Event.KeyEvent.uChar.UnicodeChar == 0) {
			switch (rec.Event.KeyEvent.wVirtualKeyCode) {
				case VK_LEFT:
					return modifierKeys | LEFT_ARROW_KEY;
				case VK_RIGHT:
					return modifierKeys | RIGHT_ARROW_KEY;
				case VK_UP:
					return modifierKeys | UP_ARROW_KEY;
				case VK_DOWN:
					return modifierKeys | DOWN_ARROW_KEY;
				case VK_DELETE:
					return modifierKeys | DELETE_KEY;
				case VK_HOME:
					return modifierKeys | HOME_KEY;
				case VK_END:
					return modifierKeys | END_KEY;
				case VK_PRIOR:
					return modifierKeys | PAGE_UP_KEY;
				case VK_NEXT:
					return modifierKeys | PAGE_DOWN_KEY;
				default:
					continue;	// in raw mode, ReadConsoleInput shows shift, ctrl ...
			}							//	... ignore them
		} else if (rec.Event.KeyEvent.uChar.UnicodeChar ==
							 ctrlChar('[')) {	// ESC, set flag for later
			escSeen = true;
			continue;
		} else {
			// we got a real character, return it
			return modifierKeys | rec.Event.KeyEvent.uChar.UnicodeChar;
		}
	}

#else
	char32_t c;
	c = readUnicodeCharacter();
	if (c == 0) return 0;

// If _DEBUG_LINUX_KEYBOARD is set, then ctrl-^ puts us into a keyboard
// debugging mode
// where we print out decimal and decoded values for whatever the "terminal"
// program
// gives us on different keystrokes.	Hit ctrl-C to exit this mode.
//
#define _DEBUG_LINUX_KEYBOARD
#if defined(_DEBUG_LINUX_KEYBOARD)
	if (c == ctrlChar('^')) {	// ctrl-^, special debug mode, prints all keys hit,
														 // ctrl-C to get out
		printf(
				"\nEntering keyboard debugging mode (on ctrl-^), press ctrl-C to exit "
				"this mode\n");
		while (true) {
			unsigned char keys[10];
			int ret = read(0, keys, 10);

			if (ret <= 0) {
				printf("\nret: %d\n", ret);
			}
			for (int i = 0; i < ret; ++i) {
				char32_t key = static_cast<char32_t>(keys[i]);
				char* friendlyTextPtr;
				char friendlyTextBuf[10];
				const char* prefixText = (key < 0x80) ? "" : "0x80+";
				char32_t keyCopy = (key < 0x80) ? key : key - 0x80;
				if (keyCopy >= '!' && keyCopy <= '~') {	// printable
					friendlyTextBuf[0] = '\'';
					friendlyTextBuf[1] = keyCopy;
					friendlyTextBuf[2] = '\'';
					friendlyTextBuf[3] = 0;
					friendlyTextPtr = friendlyTextBuf;
				} else if (keyCopy == ' ') {
					friendlyTextPtr = const_cast<char*>("space");
				} else if (keyCopy == 27) {
					friendlyTextPtr = const_cast<char*>("ESC");
				} else if (keyCopy == 0) {
					friendlyTextPtr = const_cast<char*>("NUL");
				} else if (keyCopy == 127) {
					friendlyTextPtr = const_cast<char*>("DEL");
				} else {
					friendlyTextBuf[0] = '^';
					friendlyTextBuf[1] = keyCopy + 0x40;
					friendlyTextBuf[2] = 0;
					friendlyTextPtr = friendlyTextBuf;
				}
				printf("%d x%02X (%s%s)	", key, key, prefixText, friendlyTextPtr);
			}
			printf("\x1b[1G\n");	// go to first column of new line

			// drop out of this loop on ctrl-C
			if (keys[0] == ctrlChar('C')) {
				printf("Leaving keyboard debugging mode (on ctrl-C)\n");
				fflush(__thread_stdout);
				return -2;
			}
		}
	}
#endif	// _DEBUG_LINUX_KEYBOARD

	return EscapeSequenceProcessing::doDispatch(c);
#endif	// #_WIN32
}

/**
 * Clear the screen ONLY (no redisplay of anything)
 */
void clear_screen( CLEAR_SCREEN clearScreen_ ) {
#ifdef _WIN32
	COORD coord = {0, 0};
	CONSOLE_SCREEN_BUFFER_INFO inf;
	HANDLE screenHandle = GetStdHandle( STD_OUTPUT_HANDLE );
	bool toEnd( clearScreen_ == CLEAR_SCREEN::TO_END );
	GetConsoleScreenBufferInfo( screenHandle, &inf );
	if ( ! toEnd ) {
		SetConsoleCursorPosition( screenHandle, coord );
	}
	DWORD count;
	FillConsoleOutputCharacterA(
		screenHandle, ' ',
		( inf.dwSize.Y - ( toEnd ? inf.dwCursorPosition.Y : 0 ) ) * inf.dwSize.X,
		( toEnd ? inf.dwCursorPosition : coord ),
		&count
	);
#else
	if ( clearScreen_ == CLEAR_SCREEN::WHOLE ) {
		char const clearCode[] = "\033c\033[H\033[2J\033[0m";
		static_cast<void>( fwrite(clearCode, 1, sizeof ( clearCode ) - 1, __thread_stdout) >= 0);
	} else {
		char const clearCode[] = "\033[J";
		static_cast<void>( fwrite(clearCode, 1, sizeof ( clearCode ) - 1, __thread_stdout) >= 0 );
	}
#endif
}

}

