////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016 Blink Mobile Shell Project
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

#import "StateManager.h"
#import "MCPSessionParameters.h"

NSString * const StatesKey = @"StatesKey";

@implementation StateManager {
  NSMutableDictionary *_states;
}

- (instancetype)init {
  if (self = [super init]) {
    _states = [[NSMutableDictionary alloc] init];
  }
  
  return self;
}

- (NSMutableDictionary *)_loadStates
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSURL *fileURL = [self _filePath];
  
  if ([fileManager fileExistsAtPath:[fileURL absoluteString]]) {
    return [[NSMutableDictionary alloc] init];
  }
  
  @try {
    NSData *data = [NSData dataWithContentsOfFile:[fileURL path]];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    [unarchiver setRequiresSecureCoding:YES];
    
    NSSet *classes = [[NSSet alloc] initWithObjects:[NSDictionary class], [NSString class], [MCPSessionParameters class], nil];
    NSDictionary *dict = [unarchiver decodeObjectOfClasses:classes forKey:StatesKey];
    if (dict) {
      return [dict mutableCopy];
    } else {
      return [[NSMutableDictionary alloc] init];
    }
  }
  @catch (NSException *exception){
    NSLog(@"Exception: %@", exception);
    
    return [[NSMutableDictionary alloc] init];
  }
}

- (NSURL *)_filePath {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSError *error = nil;
  NSURL *url = [fileManager URLForDirectory:NSApplicationSupportDirectory
                                   inDomain:NSUserDomainMask
                          appropriateForURL:nil
                                     create:YES
                                      error:&error];
  if (error) {
    NSLog(@"Error: %@", error);
  }
  return [url URLByAppendingPathComponent:@"states"] ;
}

- (void)load
{
  _states = [self _loadStates];
}

- (void)reset
{
  _states = [[NSMutableDictionary alloc] init];
}

- (void)save
{
  NSDictionary *copy = [[NSDictionary alloc] initWithDictionary:_states];
  
  NSMutableData *data = [[NSMutableData alloc] init];
  NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [archiver setRequiresSecureCoding:YES];
  [archiver encodeObject:copy forKey:StatesKey];
  [archiver finishEncoding];
  
  NSString *filePath = [[self _filePath] path];
  NSDataWritingOptions options = NSDataWritingAtomic | NSDataWritingFileProtectionComplete;
  
  NSError *error = nil;
  if ([data writeToFile:filePath options:options error:&error]) {
    NSLog(@"States are saved");
  } else {
    NSLog(@"Error: %@", error);
  }
}

- (void)snapshotState:(id<SecureRestoration>)object
{
  _states[object.sessionStateKey] = object.sessionParameters;
}

- (void)restoreState:(id<SecureRestoration>)object {
  if (object.sessionParameters == nil) {
    object.sessionParameters = _states[object.sessionStateKey];
  }
}

@end
