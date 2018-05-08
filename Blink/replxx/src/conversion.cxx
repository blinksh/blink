#include <algorithm>
#include <string>
#include <cstring>
#include <cctype>
#include <locale.h>

#include "conversion.hxx"

#ifdef _WIN32
#define strdup _strdup
#endif

using namespace std;

namespace replxx {

namespace locale {

void to_lower( std::string& s_ ) {
	transform( s_.begin(), s_.end(), s_.begin(), static_cast<int(*)(int)>( &tolower ) );
}

bool is_8bit_encoding( void ) {
  return true;
//  bool is8BitEncoding( false );
//  string origLC( setlocale( LC_CTYPE, nullptr ) );
//  string lc( origLC );
//  to_lower( lc );
//  if ( lc == "c" ) {
//    setlocale( LC_CTYPE, "" );
//  }
//  lc = setlocale( LC_CTYPE, nullptr );
//  setlocale( LC_CTYPE, origLC.c_str() );
//  to_lower( lc );
//  if ( lc.find( "8859" ) != std::string::npos ) {
//    is8BitEncoding = true;
//  }
//  return ( is8BitEncoding );
}

bool is8BitEncoding( is_8bit_encoding() );

}

ConversionResult copyString8to32(char32_t* dst, size_t dstSize,
																				size_t& dstCount, const char* src) {
	ConversionResult res = ConversionResult::conversionOK;
	if ( ! locale::is8BitEncoding ) {
		const UTF8* sourceStart = reinterpret_cast<const UTF8*>(src);
		const UTF8* sourceEnd = sourceStart + strlen(src);
		UTF32* targetStart = reinterpret_cast<UTF32*>(dst);
		UTF32* targetEnd = targetStart + dstSize;

		res = ConvertUTF8toUTF32(
				&sourceStart, sourceEnd, &targetStart, targetEnd, lenientConversion);

		if (res == conversionOK) {
			dstCount = targetStart - reinterpret_cast<UTF32*>(dst);

			if (dstCount < dstSize) {
				*targetStart = 0;
			}
		}
	} else {
		for ( dstCount = 0; ( dstCount < dstSize ) && src[dstCount]; ++ dstCount ) {
			dst[dstCount] = src[dstCount];
		}
		if ( dstCount < dstSize ) {
			dst[dstCount] = 0;
		}
	}
	return res;
}

ConversionResult copyString8to32(char32_t* dst, size_t dstSize,
																				size_t& dstCount, const char8_t* src) {
	return copyString8to32(dst, dstSize, dstCount,
												 reinterpret_cast<const char*>(src));
}

size_t strlen32(const char32_t* str) {
	const char32_t* ptr = str;

	while (*ptr) {
		++ptr;
	}

	return ptr - str;
}

size_t strlen8(const char8_t* str) {
	return strlen(reinterpret_cast<const char*>(str));
}

char8_t* strdup8(const char* src) {
	return reinterpret_cast<char8_t*>(strdup(src));
}


void copyString32to16(char16_t* dst, size_t dstSize, size_t* dstCount,
														 const char32_t* src, size_t srcSize) {
	const UTF32* sourceStart = reinterpret_cast<const UTF32*>(src);
	const UTF32* sourceEnd = sourceStart + srcSize;
	char16_t* targetStart = reinterpret_cast<char16_t*>(dst);
	char16_t* targetEnd = targetStart + dstSize;

	ConversionResult res = ConvertUTF32toUTF16(
			&sourceStart, sourceEnd, &targetStart, targetEnd, lenientConversion);

	if (res == conversionOK) {
		*dstCount = targetStart - reinterpret_cast<char16_t*>(dst);

		if (*dstCount < dstSize) {
			*targetStart = 0;
		}
	}
}

void copyString32to8(char* dst, size_t dstSize, size_t* dstCount,
														const char32_t* src, size_t srcSize) {
	if ( ! locale::is8BitEncoding ) {
		const UTF32* sourceStart = reinterpret_cast<const UTF32*>(src);
		const UTF32* sourceEnd = sourceStart + srcSize;
		UTF8* targetStart = reinterpret_cast<UTF8*>(dst);
		UTF8* targetEnd = targetStart + dstSize;

		ConversionResult res = ConvertUTF32toUTF8(
				&sourceStart, sourceEnd, &targetStart, targetEnd, lenientConversion);

		if (res == conversionOK) {
			*dstCount = targetStart - reinterpret_cast<UTF8*>(dst);

			if (*dstCount < dstSize) {
				*targetStart = 0;
			}
		}
	} else {
		size_t i( 0 );
		for ( i = 0; ( i < dstSize ) && ( i < srcSize ) && src[i]; ++ i ) {
			dst[i] = static_cast<char>( src[i] );
		}
		if ( dstCount ) {
			*dstCount = i;
		}
		if ( i < dstSize ) {
			dst[i] = 0;
		}
	}
}

void copyString32to8(char* dst, size_t dstLen, const char32_t* src) {
	size_t dstCount = 0;
	copyString32to8(dst, dstLen, &dstCount, src, strlen32(src));
}

void copyString32(char32_t* dst, const char32_t* src, size_t len) {
	while (0 < len && *src) {
		*dst++ = *src++;
		--len;
	}

	*dst = 0;
}

int strncmp32(const char32_t* left, const char32_t* right, size_t len) {
	while (0 < len && *left) {
		if (*left != *right) {
			return *left - *right;
		}

		++left;
		++right;
		--len;
	}

	return 0;
}

}
