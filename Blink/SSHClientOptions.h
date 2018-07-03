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
extern const NSString * SSHOptionTCPKeepAlive;
extern const NSString * SSHOptionNumberOfPasswordPrompts; // -o
extern const NSString * SSHOptionServerLiveCountMax; // -o
extern const NSString * SSHOptionServerLiveInterval; // -o

// Non standart
extern const NSString * SSHOptionPassword; //
extern const NSString * SSHOptionPrintConfiguration; // -G
extern const NSString * SSHOptionPrintVersion; // -V

extern const NSString * SSHOptionValueYES;
extern const NSString * SSHOptionValueNO;
extern const NSString * SSHOptionValueAUTO;
extern const NSString * SSHOptionValueANY;
extern const NSString * SSHOptionValueNONE;

extern const NSString * SSHOptionValueINFO;
extern const NSString * SSHOptionValueERROR;
extern const NSString * SSHOptionValueDEBUG;
extern const NSString * SSHOptionValueDEBUG1;
extern const NSString * SSHOptionValueDEBUG2;
extern const NSString * SSHOptionValueDEBUG3;

@interface SSHClientOptions : NSObject

@property (nonatomic) NSString *exitMessage;

- (int)parseArgs:(int) argc argv:(char **) argv;
- (nullable id)objectForKeyedSubscript:(const NSString *)key;
- (int)configureSSHSession:(ssh_session)session;
- (NSString *)configurationAsText;

@end

NS_ASSUME_NONNULL_END
