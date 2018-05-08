#ifndef REPLXX_KILLRING_HXX_INCLUDED
#define REPLXX_KILLRING_HXX_INCLUDED 1

#include <vector>

#include "utfstring.hxx"

namespace replxx {

class KillRing {
	static const int capacity = 10;
	int size;
	int index;
	char indexToSlot[10];
	std::vector<Utf32String> theRing;

public:
	enum action { actionOther, actionKill, actionYank };
	action lastAction;
	size_t lastYankSize;

	KillRing() : size(0), index(0), lastAction(actionOther) {
		theRing.reserve(capacity);
	}

	void kill(const char32_t* text, int textLen, bool forward) {
		if (textLen == 0) {
			return;
		}
		Utf32String killedText(text, textLen);
		if (lastAction == actionKill && size > 0) {
			int slot = indexToSlot[0];
			int currentLen = static_cast<int>(theRing[slot].length());
			int resultLen = currentLen + textLen;
			Utf32String temp(resultLen + 1);
			if (forward) {
				memcpy(temp.get(), theRing[slot].get(), currentLen * sizeof(char32_t));
				memcpy(&temp[currentLen], killedText.get(), textLen * sizeof(char32_t));
			} else {
				memcpy(temp.get(), killedText.get(), textLen * sizeof(char32_t));
				memcpy(&temp[textLen], theRing[slot].get(),
							 currentLen * sizeof(char32_t));
			}
			temp[resultLen] = 0;
			temp.initFromBuffer();
			theRing[slot] = temp;
		} else {
			if (size < capacity) {
				if (size > 0) {
					memmove(&indexToSlot[1], &indexToSlot[0], size);
				}
				indexToSlot[0] = size;
				size++;
				theRing.push_back(killedText);
			} else {
				int slot = indexToSlot[capacity - 1];
				theRing[slot] = killedText;
				memmove(&indexToSlot[1], &indexToSlot[0], capacity - 1);
				indexToSlot[0] = slot;
			}
			index = 0;
		}
	}

	Utf32String* yank() { return (size > 0) ? &theRing[indexToSlot[index]] : 0; }

	Utf32String* yankPop() {
		if (size == 0) {
			return 0;
		}
		++index;
		if (index == size) {
			index = 0;
		}
		return &theRing[indexToSlot[index]];
	}
};

}

#endif

