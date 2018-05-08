#ifndef REPLXX_IO_HXX_INCLUDED
#define REPLXX_IO_HXX_INCLUDED 1

#ifdef _WIN32
#include <windows.h>
#endif

#include <stdio.h>

namespace replxx {

int write32( int fd, char32_t* text32, int len32 );
void setWinsize(struct winsize *win, FILE *in, FILE *out, FILE *err);
int getScreenColumns(void);
int getScreenRows(void);
void setDisplayAttribute(bool enhancedDisplay, bool);
int enableRawMode(void);
void disableRawMode(void);
char32_t readUnicodeCharacter(void);
void beep();
char32_t read_char(void);
enum class CLEAR_SCREEN {
	WHOLE,
	TO_END
};
void clear_screen( CLEAR_SCREEN );

namespace tty {

extern bool in;
extern bool out;

}

#ifdef _WIN32
extern HANDLE console_out;
#endif

}

#endif

