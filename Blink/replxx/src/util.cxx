#include <cstdlib>
#include <wctype.h>

#include "util.hxx"
#include "keycodes.hxx"

namespace replxx {

bool isCharacterAlphanumeric(char32_t testChar) {
#ifdef _WIN32
	return (iswalnum((wint_t)testChar) != 0 ? true : false);
#else
	return (iswalnum(testChar) != 0 ? true : false);
#endif
}

/**
 * convert {CTRL + 'A'}, {CTRL + 'a'} and {CTRL + ctrlChar( 'A' )} into
 * ctrlChar( 'A' )
 * leave META alone
 *
 * @param c character to clean up
 * @return cleaned-up character
 */
int cleanupCtrl(int c) {
	if (c & CTRL) {
		int d = c & 0x1FF;
		if (d >= 'a' && d <= 'z') {
			c = (c + ('a' - ctrlChar('A'))) & ~CTRL;
		}
		if (d >= 'A' && d <= 'Z') {
			c = (c + ('A' - ctrlChar('A'))) & ~CTRL;
		}
		if (d >= ctrlChar('A') && d <= ctrlChar('Z')) {
			c = c & ~CTRL;
		}
	}
	return c;
}

/**
 * Recompute widths of all characters in a char32_t buffer
 * @param text					input buffer of Unicode characters
 * @param widths				output buffer of character widths
 * @param charCount		 number of characters in buffer
 */
int mk_wcwidth(char32_t ucs);

void recomputeCharacterWidths(const char32_t* text, char* widths,
																		 int charCount) {
	for (int i = 0; i < charCount; ++i) {
		widths[i] = mk_wcwidth(text[i]);
	}
}

/**
 * Calculate a new screen position given a starting position, screen width and
 * character count
 * @param x						 initial x position (zero-based)
 * @param y						 initial y position (zero-based)
 * @param screenColumns screen column count
 * @param charCount		 character positions to advance
 * @param xOut					returned x position (zero-based)
 * @param yOut					returned y position (zero-based)
 */
void calculateScreenPosition(int x, int y, int screenColumns,
																		int charCount, int& xOut, int& yOut) {
	xOut = x;
	yOut = y;
	int charsRemaining = charCount;
	while (charsRemaining > 0) {
		int charsThisRow = (x + charsRemaining < screenColumns) ? charsRemaining
																														: screenColumns - x;
		xOut = x + charsThisRow;
		yOut = y;
		charsRemaining -= charsThisRow;
		x = 0;
		++y;
	}
	if (xOut == screenColumns) {	// we have to special-case line wrap
		xOut = 0;
		++yOut;
	}
}

/**
 * Calculate a column width using mk_wcswidth()
 * @param buf32	text to calculate
 * @param len		length of text to calculate
 */
int mk_wcswidth(const char32_t* pwcs, size_t n);

int calculateColumnPosition(char32_t* buf32, int len) {
	int width = mk_wcswidth(reinterpret_cast<const char32_t*>(buf32), len);
	if (width == -1)
		return len;
	else
		return width;
}

}

