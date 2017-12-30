//
//  StateManager.m
//  Blink
//
//  Created by Yury Korolev on 12/30/17.
//  Copyright © 2017 Carlos Cabañero Projects SL. All rights reserved.
//

#import "StateManager.h"

@implementation StateManager {
  NSMutableDictionary *_states;
}

+ (StateManager *)shared {
  static StateManager *manager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    manager = [[self alloc] init];
  });
  return manager;
}

-(instancetype)init {
  if (self = [super init]) {
    NSDictionary *states = [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePath]];
    if (states == nil) {
      states = [[NSDictionary alloc] init];
    }
    _states = [states mutableCopy];
  }
  
  return self;
}

- (NSString *)filePath{
  NSURL *url = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
  return [[url URLByAppendingPathComponent:@"state2"] path];
}

- (void)save
{
  [NSKeyedArchiver archiveRootObject:_states toFile:[self filePath]];
}


- (void)storeSessionParams:(NSString *)sessionKey params:(NSObject *)params
{
  _states[sessionKey] = params;
  [self save];
}

-(NSObject *)restoreSessionParamsForKey:(NSString *)sessionKey {
  return _states[sessionKey];
}

- (void)removeSession:(NSString *)sessionKey
{
  [_states removeObjectForKey:sessionKey];
  [self save];
}


@end
