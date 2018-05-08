#include <fstream>
#include <cstring>

#ifndef _WIN32

#include <unistd.h>
#include <sys/stat.h>

#endif /* _WIN32 */

#include "history.hxx"

using namespace std;

namespace replxx {

static int const REPLXX_DEFAULT_HISTORY_MAX_LEN( 1000 );

History::History( void )
	: _data()
	, _maxSize( REPLXX_DEFAULT_HISTORY_MAX_LEN )
	, _index( 0 )
	, _previousIndex( -2 )
	, _recallMostRecent( false ) {
}

void History::add( std::string const& line ) {
	if ( ( _maxSize > 0 ) && ( _data.empty() || ( line != _data.back() ) ) ) {
		if ( size() == _maxSize ) {
			_data.erase( _data.begin() );
			if ( -- _previousIndex < -1 ) {
				_previousIndex = -2;
			}
		}
		_data.push_back( line );
	}
}

int History::save( std::string const& filename ) {
#ifndef _WIN32
	mode_t old_umask = umask( S_IXUSR | S_IRWXG| S_IRWXO );
#endif
	ofstream histFile( filename );
	if ( ! histFile ) {
		return ( -1 );
	}
#ifndef _WIN32
	umask( old_umask );
	chmod( filename.c_str(), S_IRUSR | S_IWUSR );
#endif
	for ( string const& h : _data ) {
		if ( ! h.empty() ) {
			histFile << h << endl;
		}
	}
	return ( 0 );
}

int History::load( std::string const& filename ) {
	ifstream histFile( filename );
	if ( ! histFile ) {
		return ( -1 );
	}
	string line;
	while ( getline( histFile, line ).good() ) {
		string::size_type eol( line.find_first_of( "\r\n" ) );
		if ( eol != string::npos ) {
			line.erase( eol );
		}
		if ( ! line.empty() ) {
			add( line );
		}
	}
	return 0;
}

void History::set_max_size( int size_ ) {
	if ( size_ >= 0 ) {
		_maxSize = size_;
		int curSize( size() );
		if ( _maxSize < curSize ) {
			_data.erase( _data.begin(), _data.begin() + ( curSize - _maxSize ) );
		}
	}
}

void History::reset_pos( int pos_ ) {
	if ( pos_ == -1 ) {
		_index = size() - 1;
		_recallMostRecent = false;
	} else {
		_index = pos_;
	}
}

bool History::move( bool up_ ) {
	if (_previousIndex != -2 && ! up_ ) {
		_index = 1 + _previousIndex;	// emulate Windows down-arrow
	} else {
		_index += up_ ? -1 : 1;
	}
	_previousIndex = -2;
	if (_index < 0) {
		_index = 0;
		return ( false );
	} else if ( _index >= size() ) {
		_index = size() - 1;
		return ( false );
	}
	_recallMostRecent = true;
	return ( true );
}

void History::jump( bool start_ ) {
	_index = start_ ? 0 : size() - 1;
	_previousIndex = -2;
	_recallMostRecent = true;
}

bool History::common_prefix_search( std::string const& prefix_, int prefixSize_, bool back_ ) {
	int direct( size() + ( back_ ? -1 : 1 ) );
	int i( ( _index + direct ) % _data.size() );
	while ( i != _index ) {
		if ( ( strncmp( prefix_.c_str(), _data[i].c_str(), prefixSize_ ) == 0 )
			&& ( strcmp( prefix_.c_str(), _data[i].c_str() ) != 0 ) ) {
			_index = i;
			_previousIndex = -2;
			_recallMostRecent = true;
			return ( true );
		}
		i += direct;
		i %= _data.size();
	}
	return ( false );
}

std::string const& History::operator[] ( int idx_ ) const {
	return ( _data[ idx_ ] );
}

}

