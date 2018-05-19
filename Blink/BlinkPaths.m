//
//  BlinkPaths.m
//  Blink
//
//  Created by Yury Korolev on 5/14/18.
//  Copyright © 2018 Carlos Cabañero Projects SL. All rights reserved.
//

#import "BlinkPaths.h"

@implementation BlinkPaths

+ (NSString *)documents
{
  return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

+ (NSURL *)documentsURL
{
  return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
}

+ (NSString *)blink
{
  return [self documents];
}

+ (NSURL *)blinkURL
{
  return [self documentsURL];
}

+ (NSString *)blinkKeysFile
{
  return [[self blink] stringByAppendingPathComponent:@"keys"];
}

+ (NSString *)historyFile
{
  return [[self documents] stringByAppendingPathComponent:@".blink_history"];
}

+ (NSString *)knownHostsFile
{
  return [[self documents] stringByAppendingPathComponent:@"known_hosts"];
}

+ (NSString *)defaultsFile
{
  return [[self documents] stringByAppendingPathComponent:@"defaults"];
}

@end
