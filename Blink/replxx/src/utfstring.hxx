#ifndef REPLXX_UTFSTRING_HXX_INCLUDED
#define REPLXX_UTFSTRING_HXX_INCLUDED

#include <cstring>

#include "conversion.hxx"

namespace replxx {

class Utf32String {
public:
	Utf32String()
		: _length( 0 )
		, _data( nullptr ) {
		_data = new char32_t[1]();
	}

	explicit Utf32String(const char* src)
		: _length( 0 )
		, _data( nullptr ) {
		size_t len = strlen(src);
		_data = new char32_t[len + 1]();
		copyString8to32(_data, len + 1, _length, src);
	}

	explicit Utf32String(const char8_t* src)
		: _length( 0 )
		, _data( nullptr ) {
		size_t len = strlen(reinterpret_cast<const char*>(src));
		_data = new char32_t[len + 1]();
		copyString8to32(_data, len + 1, _length, src);
	}

	explicit Utf32String(const char32_t* src)
		: _length( 0 )
		, _data( nullptr ) {
		for (_length = 0; src[_length] != 0; ++_length) {
		}
		_data = new char32_t[_length + 1]();
		memcpy(_data, src, _length * sizeof(char32_t));
	}

	explicit Utf32String(const char32_t* src, int len)
		: _length( len )
		, _data( nullptr ) {
		_data = new char32_t[len + 1]();
		memcpy(_data, src, len * sizeof(char32_t));
	}

	explicit Utf32String(int len)
		: _length( 0 )
		, _data( nullptr ) {
		_data = new char32_t[len]();
	}

	explicit Utf32String(const Utf32String& that)
		: _length( 0 )
		, _data( nullptr ) {
		_data = new char32_t[that._length + 1]();
		_length = that._length;
		memcpy(_data, that._data, sizeof(char32_t) * _length);
	}

	Utf32String& operator=(const Utf32String& that) {
		if (this != &that) {
			delete[] _data;
			_data = new char32_t[that._length]();
			_length = that._length;
			memcpy(_data, that._data, sizeof(char32_t) * _length);
		}

		return *this;
	}

	~Utf32String() { delete[] _data; }

public:
	char32_t* get() const { return _data; }

	size_t length() const { return _length; }

	size_t chars() const { return _length; }

	void initFromBuffer() {
		for (_length = 0; _data[_length] != 0; ++_length) {
		}
	}

	const char32_t& operator[](size_t pos) const { return _data[pos]; }

	char32_t& operator[](size_t pos) { return _data[pos]; }

 private:
	size_t _length;
	char32_t* _data;
};

class Utf8String {
	Utf8String(const Utf8String&) = delete;
	Utf8String& operator=(const Utf8String&) = delete;

public:
	explicit Utf8String(const Utf32String& src) {
		size_t len = src.length() * 4 + 1;
		_data = new char[len];
		copyString32to8(_data, len, src.get());
	}

	~Utf8String() { delete[] _data; }

public:
	char* get() const { return _data; }

private:
	char* _data;
};

}

#endif

