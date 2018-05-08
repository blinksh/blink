#include "escape.hxx"
#include "io.hxx"
#include "keycodes.hxx"

namespace replxx {

namespace EscapeSequenceProcessing { // move these out of global namespace

// This chunk of code does parsing of the escape sequences sent by various Linux
// terminals.
//
// It handles arrow keys, Home, End and Delete keys by interpreting the
// sequences sent by
// gnome terminal, xterm, rxvt, konsole, aterm and yakuake including the Alt and
// Ctrl key
// combinations that are understood by replxx.
//
// The parsing uses tables, a bunch of intermediate dispatch routines and a
// doDispatch
// loop that reads the tables and sends control to "deeper" routines to continue
// the
// parsing.	The starting call to doDispatch( c, initialDispatch ) will
// eventually return
// either a character (with optional CTRL and META bits set), or -1 if parsing
// fails, or
// zero if an attempt to read from the keyboard fails.
//
// This is rather sloppy escape sequence processing, since we're not paying
// attention to what the
// actual TERM is set to and are processing all key sequences for all terminals,
// but it works with
// the most common keystrokes on the most common terminals.	It's intricate, but
// the nested 'if'
// statements required to do it directly would be worse.	This way has the
// advantage of allowing
// changes and extensions without having to touch a lot of code.


static char32_t thisKeyMetaCtrl = 0;	// holds pre-set Meta and/or Ctrl modifiers

// This dispatch routine is given a dispatch table and then farms work out to
// routines
// listed in the table based on the character it is called with.	The dispatch
// routines can
// read more input characters to decide what should eventually be returned.
// Eventually,
// a called routine returns either a character or -1 to indicate parsing
// failure.
//
char32_t doDispatch(char32_t c, CharacterDispatch& dispatchTable) {
	for (unsigned int i = 0; i < dispatchTable.len; ++i) {
		if (static_cast<unsigned char>(dispatchTable.chars[i]) == c) {
			return dispatchTable.dispatch[i](c);
		}
	}
	return dispatchTable.dispatch[dispatchTable.len](c);
}

// Final dispatch routines -- return something
//
static char32_t normalKeyRoutine(char32_t c) { return thisKeyMetaCtrl | c; }
static char32_t upArrowKeyRoutine(char32_t) {
	return thisKeyMetaCtrl | UP_ARROW_KEY;
}
static char32_t downArrowKeyRoutine(char32_t) {
	return thisKeyMetaCtrl | DOWN_ARROW_KEY;
}
static char32_t rightArrowKeyRoutine(char32_t) {
	return thisKeyMetaCtrl | RIGHT_ARROW_KEY;
}
static char32_t leftArrowKeyRoutine(char32_t) {
	return thisKeyMetaCtrl | LEFT_ARROW_KEY;
}
static char32_t homeKeyRoutine(char32_t) { return thisKeyMetaCtrl | HOME_KEY; }
static char32_t endKeyRoutine(char32_t) { return thisKeyMetaCtrl | END_KEY; }
static char32_t pageUpKeyRoutine(char32_t) {
	return thisKeyMetaCtrl | PAGE_UP_KEY;
}
static char32_t pageDownKeyRoutine(char32_t) {
	return thisKeyMetaCtrl | PAGE_DOWN_KEY;
}
static char32_t deleteCharRoutine(char32_t) {
	return thisKeyMetaCtrl | ctrlChar('H');
}	// key labeled Backspace
static char32_t deleteKeyRoutine(char32_t) {
	return thisKeyMetaCtrl | DELETE_KEY;
}	// key labeled Delete
static char32_t ctrlUpArrowKeyRoutine(char32_t) {
	return thisKeyMetaCtrl | CTRL | UP_ARROW_KEY;
}
static char32_t ctrlDownArrowKeyRoutine(char32_t) {
	return thisKeyMetaCtrl | CTRL | DOWN_ARROW_KEY;
}
static char32_t ctrlRightArrowKeyRoutine(char32_t) {
	return thisKeyMetaCtrl | CTRL | RIGHT_ARROW_KEY;
}
static char32_t ctrlLeftArrowKeyRoutine(char32_t) {
	return thisKeyMetaCtrl | CTRL | LEFT_ARROW_KEY;
}
static char32_t escFailureRoutine(char32_t) {
	beep();
	return -1;
}

// Handle ESC [ 1 ; 3 (or 5) <more stuff> escape sequences
//
static CharacterDispatchRoutine escLeftBracket1Semicolon3or5Routines[] = {
		upArrowKeyRoutine, downArrowKeyRoutine, rightArrowKeyRoutine,
		leftArrowKeyRoutine, escFailureRoutine};
static CharacterDispatch escLeftBracket1Semicolon3or5Dispatch = {
		4, "ABCD", escLeftBracket1Semicolon3or5Routines};

// Handle ESC [ 1 ; <more stuff> escape sequences
//
static char32_t escLeftBracket1Semicolon3Routine(char32_t c) {
	c = readUnicodeCharacter();
	if (c == 0) return 0;
	thisKeyMetaCtrl |= META;
	return doDispatch(c, escLeftBracket1Semicolon3or5Dispatch);
}
static char32_t escLeftBracket1Semicolon5Routine(char32_t c) {
	c = readUnicodeCharacter();
	if (c == 0) return 0;
	thisKeyMetaCtrl |= CTRL;
	return doDispatch(c, escLeftBracket1Semicolon3or5Dispatch);
}
static CharacterDispatchRoutine escLeftBracket1SemicolonRoutines[] = {
		escLeftBracket1Semicolon3Routine, escLeftBracket1Semicolon5Routine,
		escFailureRoutine};
static CharacterDispatch escLeftBracket1SemicolonDispatch = {
		2, "35", escLeftBracket1SemicolonRoutines};

// Handle ESC [ 1 <more stuff> escape sequences
//
static char32_t escLeftBracket1SemicolonRoutine(char32_t c) {
	c = readUnicodeCharacter();
	if (c == 0) return 0;
	return doDispatch(c, escLeftBracket1SemicolonDispatch);
}
static CharacterDispatchRoutine escLeftBracket1Routines[] = {
		homeKeyRoutine, escLeftBracket1SemicolonRoutine, escFailureRoutine};
static CharacterDispatch escLeftBracket1Dispatch = {2, "~;",
																										escLeftBracket1Routines};

// Handle ESC [ 3 <more stuff> escape sequences
//
static CharacterDispatchRoutine escLeftBracket3Routines[] = {deleteKeyRoutine,
																														 escFailureRoutine};

static CharacterDispatch escLeftBracket3Dispatch = {1, "~",
																										escLeftBracket3Routines};

// Handle ESC [ 4 <more stuff> escape sequences
//
static CharacterDispatchRoutine escLeftBracket4Routines[] = {endKeyRoutine,
																														 escFailureRoutine};
static CharacterDispatch escLeftBracket4Dispatch = {1, "~",
																										escLeftBracket4Routines};

// Handle ESC [ 5 <more stuff> escape sequences
//
static CharacterDispatchRoutine escLeftBracket5Routines[] = {pageUpKeyRoutine,
																														 escFailureRoutine};
static CharacterDispatch escLeftBracket5Dispatch = {1, "~",
																										escLeftBracket5Routines};

// Handle ESC [ 6 <more stuff> escape sequences
//
static CharacterDispatchRoutine escLeftBracket6Routines[] = {pageDownKeyRoutine,
																														 escFailureRoutine};
static CharacterDispatch escLeftBracket6Dispatch = {1, "~",
																										escLeftBracket6Routines};

// Handle ESC [ 7 <more stuff> escape sequences
//
static CharacterDispatchRoutine escLeftBracket7Routines[] = {homeKeyRoutine,
																														 escFailureRoutine};
static CharacterDispatch escLeftBracket7Dispatch = {1, "~",
																										escLeftBracket7Routines};

// Handle ESC [ 8 <more stuff> escape sequences
//
static CharacterDispatchRoutine escLeftBracket8Routines[] = {endKeyRoutine,
																														 escFailureRoutine};
static CharacterDispatch escLeftBracket8Dispatch = {1, "~",
																										escLeftBracket8Routines};

// Handle ESC [ <digit> escape sequences
//
static char32_t escLeftBracket0Routine(char32_t c) {
	return escFailureRoutine(c);
}
static char32_t escLeftBracket1Routine(char32_t c) {
	c = readUnicodeCharacter();
	if (c == 0) return 0;
	return doDispatch(c, escLeftBracket1Dispatch);
}
static char32_t escLeftBracket2Routine(char32_t c) {
	return escFailureRoutine(c);	// Insert key, unused
}
static char32_t escLeftBracket3Routine(char32_t c) {
	c = readUnicodeCharacter();
	if (c == 0) return 0;
	return doDispatch(c, escLeftBracket3Dispatch);
}
static char32_t escLeftBracket4Routine(char32_t c) {
	c = readUnicodeCharacter();
	if (c == 0) return 0;
	return doDispatch(c, escLeftBracket4Dispatch);
}
static char32_t escLeftBracket5Routine(char32_t c) {
	c = readUnicodeCharacter();
	if (c == 0) return 0;
	return doDispatch(c, escLeftBracket5Dispatch);
}
static char32_t escLeftBracket6Routine(char32_t c) {
	c = readUnicodeCharacter();
	if (c == 0) return 0;
	return doDispatch(c, escLeftBracket6Dispatch);
}
static char32_t escLeftBracket7Routine(char32_t c) {
	c = readUnicodeCharacter();
	if (c == 0) return 0;
	return doDispatch(c, escLeftBracket7Dispatch);
}
static char32_t escLeftBracket8Routine(char32_t c) {
	c = readUnicodeCharacter();
	if (c == 0) return 0;
	return doDispatch(c, escLeftBracket8Dispatch);
}
static char32_t escLeftBracket9Routine(char32_t c) {
	return escFailureRoutine(c);
}

// Handle ESC [ <more stuff> escape sequences
//
static CharacterDispatchRoutine escLeftBracketRoutines[] = {
		upArrowKeyRoutine,			downArrowKeyRoutine,		rightArrowKeyRoutine,
		leftArrowKeyRoutine,		homeKeyRoutine,				 endKeyRoutine,
		escLeftBracket0Routine, escLeftBracket1Routine, escLeftBracket2Routine,
		escLeftBracket3Routine, escLeftBracket4Routine, escLeftBracket5Routine,
		escLeftBracket6Routine, escLeftBracket7Routine, escLeftBracket8Routine,
		escLeftBracket9Routine, escFailureRoutine};
static CharacterDispatch escLeftBracketDispatch = {16, "ABCDHF0123456789",
																									 escLeftBracketRoutines};

// Handle ESC O <char> escape sequences
//
static CharacterDispatchRoutine escORoutines[] = {
		upArrowKeyRoutine,			 downArrowKeyRoutine,		 rightArrowKeyRoutine,
		leftArrowKeyRoutine,		 homeKeyRoutine,					endKeyRoutine,
		ctrlUpArrowKeyRoutine,	 ctrlDownArrowKeyRoutine, ctrlRightArrowKeyRoutine,
		ctrlLeftArrowKeyRoutine, escFailureRoutine};
static CharacterDispatch escODispatch = {10, "ABCDHFabcd", escORoutines};

// Initial ESC dispatch -- could be a Meta prefix or the start of an escape
// sequence
//
static char32_t escLeftBracketRoutine(char32_t c) {
	c = readUnicodeCharacter();
	if (c == 0) return 0;
	return doDispatch(c, escLeftBracketDispatch);
}
static char32_t escORoutine(char32_t c) {
	c = readUnicodeCharacter();
	if (c == 0) return 0;
	return doDispatch(c, escODispatch);
}
static char32_t setMetaRoutine(char32_t c);	// need forward reference
static CharacterDispatchRoutine escRoutines[] = {escLeftBracketRoutine,
																								 escORoutine, setMetaRoutine};
static CharacterDispatch escDispatch = {2, "[O", escRoutines};

// Initial dispatch -- we are not in the middle of anything yet
//
static char32_t escRoutine(char32_t c) {
	c = readUnicodeCharacter();
	if (c == 0) return 0;
	return doDispatch(c, escDispatch);
}
static CharacterDispatchRoutine initialRoutines[] = {
		escRoutine, deleteCharRoutine, normalKeyRoutine};
static CharacterDispatch initialDispatch = {2, "\x1B\x7F", initialRoutines};

// Special handling for the ESC key because it does double duty
//
static char32_t setMetaRoutine(char32_t c) {
	thisKeyMetaCtrl = META;
	if (c == 0x1B) {	// another ESC, stay in ESC processing mode
		c = readUnicodeCharacter();
		if (c == 0) return 0;
		return doDispatch(c, escDispatch);
	}
	return doDispatch(c, initialDispatch);
}

char32_t doDispatch(char32_t c) {
	EscapeSequenceProcessing::thisKeyMetaCtrl = 0;	// no modifiers yet at initialDispatch
	return doDispatch(c, initialDispatch);
}

}	// namespace EscapeSequenceProcessing // move these out of global namespace

}

