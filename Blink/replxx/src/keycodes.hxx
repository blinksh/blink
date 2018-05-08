#ifndef REPLXX_KEYCODES_HXX_INCLUDED
#define REPLXX_KEYCODES_HXX_INCLUDED 1

// make control-characters more readable
#define ctrlChar(upperCaseASCII) (upperCaseASCII - 0x40)

// Special codes for keyboard input:
//
// Between Windows and the various Linux "terminal" programs, there is some
// pretty diverse behavior in the "scan codes" and escape sequences we are
// presented with.	So ... we'll translate them all into our own pidgin
// pseudocode, trying to stay out of the way of UTF-8 and international
// characters.	Here's the general plan.
//
// "User input keystrokes" (key chords, whatever) will be encoded as a single
// value.
// The low 21 bits are reserved for Unicode characters.	Popular function-type
// keys
// get their own codes in the range 0x10200000 to (if needed) 0x1FE00000,
// currently
// just arrow keys, Home, End and Delete.	Keypresses with Ctrl get ORed with
// 0x20000000, with Alt get ORed with 0x40000000.	So, Ctrl+Alt+Home is encoded
// as 0x20000000 + 0x40000000 + 0x10A00000 == 0x70A00000.	To keep things
// complicated,
// the Alt key is equivalent to prefixing the keystroke with ESC, so ESC
// followed by
// D is treated the same as Alt + D ... we'll just use Emacs terminology and
// call
// this "Meta".	So, we will encode both ESC followed by D and Alt held down
// while D
// is pressed the same, as Meta-D, encoded as 0x40000064.
//
// Here are the definitions of our component constants:
//
// Maximum unsigned 32-bit value		= 0xFFFFFFFF;	 // For reference, max 32-bit
// value
// Highest allocated Unicode char	 = 0x001FFFFF;	 // For reference, max
// Unicode value
static const int META = 0x40000000;	// Meta key combination
static const int CTRL = 0x20000000;	// Ctrl key combination
// static const int SPECIAL_KEY = 0x10000000;	 // Common bit for all special
// keys
static const int UP_ARROW_KEY = 0x10200000;	// Special keys
static const int DOWN_ARROW_KEY = 0x10400000;
static const int RIGHT_ARROW_KEY = 0x10600000;
static const int LEFT_ARROW_KEY = 0x10800000;
static const int HOME_KEY = 0x10A00000;
static const int END_KEY = 0x10C00000;
static const int DELETE_KEY = 0x10E00000;
static const int PAGE_UP_KEY = 0x11000000;
static const int PAGE_DOWN_KEY = 0x11200000;

#endif

