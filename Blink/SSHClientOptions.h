//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2018 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////


#import <Foundation/Foundation.h>
#include <libssh/libssh.h>


NS_ASSUME_NONNULL_BEGIN

extern const NSString * SSHOptionStrictHostKeyChecking;
extern const NSString * SSHOptionHostName;
extern const NSString * SSHOptionPort; // -p
extern const NSString * SSHOptionLogLevel; // -v
extern const NSString * SSHOptionIdentityFile; // -i
extern const NSString * SSHOptionRequestTTY; // -tT
extern const NSString * SSHOptionUser; // -l
extern const NSString * SSHOptionProxyCommand; // ?
extern const NSString * SSHOptionConfigFile; // -F
extern const NSString * SSHOptionRemoteCommand;
extern const NSString * SSHOptionConnectTimeout; // -o
extern const NSString * SSHOptionConnectionAttempts; // -o
extern const NSString * SSHOptionCompression; //-C -o
extern const NSString * SSHOptionCompressionLevel; // -o
extern const NSString * SSHOptionTCPKeepAlive;
extern const NSString * SSHOptionNumberOfPasswordPrompts; // -o
extern const NSString * SSHOptionServerLiveCountMax; // -o
extern const NSString * SSHOptionServerLiveInterval; // -o
extern const NSString * SSHOptionLocalForward; // -L
extern const NSString * SSHOptionRemoteForward; // -R

extern const NSString * SSHOptionForwardAgent; // -a -A
extern const NSString * SSHOptionForwardX11; // -x -X
extern const NSString * SSHOptionExitOnForwardFailure; // -o

// Auth

extern NSString * SSHOptionKbdInteractiveAuthentication; // -o
extern NSString * SSHOptionPubkeyAuthentication; // -o
extern NSString * SSHOptionPasswordAuthentication; // -o


// Non standart
extern const NSString * SSHOptionPassword; //
extern const NSString * SSHOptionPrintConfiguration; // -G
extern const NSString * SSHOptionPrintVersion; // -V

// Possibale values
extern const NSString * SSHOptionValueYES;
extern const NSString * SSHOptionValueNO;
extern const NSString * SSHOptionValueASK;
extern const NSString * SSHOptionValueAUTO;
extern const NSString * SSHOptionValueANY;
extern const NSString * SSHOptionValueNONE;

// QUIET, FATAL, ERROR, INFO, VERBOSE, DEBUG, DEBUG1, DEBUG2, and DEBUG3.
// Client log level
extern const NSString * SSHOptionValueQUIET; // -q                  ; SSH_LOG_NOLOG
extern const NSString * SSHOptionValueFATAL; // -v -q -v            ; SSH_LOG_NOLOG
extern const NSString * SSHOptionValueERROR; // -v -q -vv           ; SSH_LOG_NOLOG
extern const NSString * SSHOptionValueINFO;  // no -v or -v -q -vvv ; SSH_LOG_NOLOG
extern const NSString * SSHOptionValueVERBOSE; // -v -q -vvvv       ; SSH_LOG_NOLOG

// libssh log level
extern const NSString * SSHOptionValueDEBUG;  // -v   ; SSH_LOG_WARNING
extern const NSString * SSHOptionValueDEBUG1; // same as DEBUG
extern const NSString * SSHOptionValueDEBUG2; // -vv  ; SSH_LOG_PROTOCOL
extern const NSString * SSHOptionValueDEBUG3; // -vvv ; SSH_LOG_PACKET

@interface SSHClientOptions : NSObject

@property (nonatomic) NSString *exitMessage;

- (int)parseArgs:(int) argc argv:(char **) argv;
- (nullable id)objectForKeyedSubscript:(const NSString *)key;
- (int)configureSSHSession:(ssh_session)session;
- (NSString *)configurationAsText;

@end

NS_ASSUME_NONNULL_END
