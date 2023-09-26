//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
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


#ifndef Blink_bridge_h
#define Blink_bridge_h

#include <stdio.h>
#include <pthread.h>

// Thread-local input and output streams
// Note we could not import ios_system
extern __thread FILE* thread_stdin;
extern __thread FILE* thread_stdout;
extern __thread FILE* thread_stderr;
extern __thread void* thread_context;

typedef int socket_t;
extern void __thread_ssh_execute_command(const char *command, socket_t in, socket_t out);
extern int ios_dup2(int fd1, int fd2);
extern void ios_exit(int errorCode) __dead2; // set error code and exits from the thread.

typedef void (*mosh_state_callback) (const void *context, const void *buffer, size_t size);

#import "BLKDefaults.h"
#import "UIDevice+DeviceName.h"
#import "BKHosts.h"
#import "BlinkPaths.h"
#import "DeviceInfo.h"
#import "LayoutManager.h"
#import "BKUserConfigurationManager.h"
#import "Session.h"
#import "MCPSession.h"
#import "TermDevice.h"
#import "KBWebViewBase.h"
#import "openurl.h"
#import "BKPubKey.h"
#import "BKHosts.h"
#import "UICKeyChainStore.h"
#import "BKiCloudSyncHandler.h"
#import "UIApplication+Version.h"
#import "AppDelegate.h"
#import "BKLinkActions.h"
#import "TokioSignals.h"
#import "BlinkMenu.h"
#import "GeoManager.h"
#import "mosh/moshiosbridge.h"


#endif /* Blink_bridge_h */
