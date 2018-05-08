#ifndef REPLXX_INPUTBUFFER_HXX_INCLUDED
#define REPLXX_INPUTBUFFER_HXX_INCLUDED 1

#include <vector>
#include <memory>

#include "replxx.hxx"
#include "replxx_impl.hxx"
#include "prompt.hxx"

namespace replxx {

struct PromptBase;

class InputBuffer {
public:
	typedef std::unique_ptr<char32_t[]> input_buffer_t;
	typedef std::unique_ptr<char[]> char_widths_t;
	typedef std::vector<char32_t> display_t;
	enum class HINT_ACTION {
		REGENERATE,
		REPAINT,
		SKIP
	};
private:
	Replxx::ReplxxImpl& _replxx;
	input_buffer_t _buf32;      // input buffer
	char_widths_t  _charWidths; // character widths from mk_wcwidth()
	display_t      _display;
	Utf32String    _hint;
	int _buflen; // buffer size in characters
	int _len;    // length of text in input buffer
	int _pos;    // character position in buffer ( 0 <= _pos <= _len )
	int _prefix; // prefix length used in common prefix search
	int _hintSelection; // Currently selected hint.
	History& _history;
	KillRing& _killRing;

	void clearScreen(PromptBase& pi);
	int incrementalHistorySearch(PromptBase& pi, int startChar);
	void commonPrefixSearch(PromptBase& pi, int startChar);
	int completeLine(PromptBase& pi);
	void refreshLine(PromptBase& pi, HINT_ACTION = HINT_ACTION::REGENERATE);
	void highlight( int, bool );
	int handle_hints( PromptBase&, HINT_ACTION );
	void setColor( Replxx::Color );
	int start_index( void );

 public:
	InputBuffer( Replxx::ReplxxImpl& replxx_, int bufferLen )
		: _replxx( replxx_ )
		, _buf32(new char32_t[bufferLen])
		, _charWidths(new char[bufferLen])
		, _display()
		, _hint()
		, _buflen(bufferLen - 1)
		, _len(0)
		, _pos(0)
		, _prefix( 0 )
		, _hintSelection( -1 )
		, _history( replxx_.history() )
		, _killRing( replxx_.kill_ring() ) {
		_buf32[0] = 0;
	}
	void preloadBuffer( char const* preloadText );
	int getInputLine(PromptBase& pi);
	int length(void) const { return _len; }
	char32_t* buf() {
		return ( _buf32.get() );
	}
};

}

#endif

