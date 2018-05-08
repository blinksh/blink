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

#endif /* _WIN32 */

#include "prompt.hxx"
#include "util.hxx"
#include "io.hxx"

namespace replxx {

bool PromptBase::write() {
	if (write32(1, promptText.get(), promptBytes) == -1) return false;

	return true;
}

PromptInfo::PromptInfo(std::string const& text_, int columns) {
	promptExtraLines = 0;
	promptLastLinePosition = 0;
	promptPreviousLen = 0;
	promptScreenColumns = columns;
	Utf32String tempUnicode(text_.c_str());

	// strip control characters from the prompt -- we do allow newline
	char32_t* pIn = tempUnicode.get();
	char32_t* pOut = pIn;

	int len = 0;
	int x = 0;

	bool const strip = !tty::out;

	while (*pIn) {
		char32_t c = *pIn;
		if ('\n' == c || !isControlChar(c)) {
			*pOut = c;
			++pOut;
			++pIn;
			++len;
			if ('\n' == c || ++x >= promptScreenColumns) {
				x = 0;
				++promptExtraLines;
				promptLastLinePosition = len;
			}
		} else if (c == '\x1b') {
			if (strip) {
				// jump over control chars
				++pIn;
				if (*pIn == '[') {
					++pIn;
					while (*pIn && ((*pIn == ';') || ((*pIn >= '0' && *pIn <= '9')))) {
						++pIn;
					}
					if (*pIn == 'm') {
						++pIn;
					}
				}
			} else {
				// copy control chars
				*pOut = *pIn;
				++pOut;
				++pIn;
				if (*pIn == '[') {
					*pOut = *pIn;
					++pOut;
					++pIn;
					while (*pIn && ((*pIn == ';') || ((*pIn >= '0' && *pIn <= '9')))) {
						*pOut = *pIn;
						++pOut;
						++pIn;
					}
					if (*pIn == 'm') {
						*pOut = *pIn;
						++pOut;
						++pIn;
					}
				}
			}
		} else {
			++pIn;
		}
	}
	*pOut = 0;
	promptChars = len;
	promptBytes = static_cast<int>(pOut - tempUnicode.get());
	promptText = tempUnicode;

	promptIndentation = len - promptLastLinePosition;
	promptCursorRowOffset = promptExtraLines;
}

// Used with DynamicPrompt (history search)
//
const Utf32String forwardSearchBasePrompt("(i-search)`");
const Utf32String reverseSearchBasePrompt("(reverse-i-search)`");
const Utf32String endSearchBasePrompt("': ");
Utf32String previousSearchText;	// remembered across invocations of replxx_input()

DynamicPrompt::DynamicPrompt(PromptBase& pi, int initialDirection)
		: searchTextLen(0), direction(initialDirection) {
	promptScreenColumns = pi.promptScreenColumns;
	promptCursorRowOffset = 0;
	Utf32String emptyString(1);
	searchText = emptyString;
	const Utf32String* basePrompt =
			(direction > 0) ? &forwardSearchBasePrompt : &reverseSearchBasePrompt;
	size_t promptStartLength = basePrompt->length();
	promptChars =
			static_cast<int>(promptStartLength + endSearchBasePrompt.length());
	promptBytes = promptChars;
	promptLastLinePosition = promptChars;	// TODO fix this, we are asssuming
																				 // that the history prompt won't wrap
																				 // (!)
	promptPreviousLen = promptChars;
	Utf32String tempUnicode(promptChars + 1);
	memcpy(tempUnicode.get(), basePrompt->get(),
				 sizeof(char32_t) * promptStartLength);
	memcpy(&tempUnicode[promptStartLength], endSearchBasePrompt.get(),
				 sizeof(char32_t) * (endSearchBasePrompt.length() + 1));
	tempUnicode.initFromBuffer();
	promptText = tempUnicode;
	calculateScreenPosition(0, 0, pi.promptScreenColumns, promptChars,
													promptIndentation, promptExtraLines);
}

void DynamicPrompt::updateSearchPrompt(void) {
	const Utf32String* basePrompt =
			(direction > 0) ? &forwardSearchBasePrompt : &reverseSearchBasePrompt;
	size_t promptStartLength = basePrompt->length();
	promptChars = static_cast<int>(promptStartLength + searchTextLen +
																 endSearchBasePrompt.length());
	promptBytes = promptChars;
	Utf32String tempUnicode(promptChars + 1);
	memcpy(tempUnicode.get(), basePrompt->get(),
				 sizeof(char32_t) * promptStartLength);
	memcpy(&tempUnicode[promptStartLength], searchText.get(),
				 sizeof(char32_t) * searchTextLen);
	size_t endIndex = promptStartLength + searchTextLen;
	memcpy(&tempUnicode[endIndex], endSearchBasePrompt.get(),
				 sizeof(char32_t) * (endSearchBasePrompt.length() + 1));
	tempUnicode.initFromBuffer();
	promptText = tempUnicode;
}

void DynamicPrompt::updateSearchText(const char32_t* text_) {
	Utf32String tempUnicode(text_);
	searchTextLen = static_cast<int>(tempUnicode.chars());
	searchText = tempUnicode;
	updateSearchPrompt();
}

}

