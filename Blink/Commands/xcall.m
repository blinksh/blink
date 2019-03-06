////////////////////////////////////////////////////////////////////////////////
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

#include <stdio.h>
#include "ios_system/ios_system.h"
#include "ios_error.h"
#include "bk_getopts.h"
#include "xcall.h"


@implementation BlinkXCall {
  dispatch_semaphore_t _sema;
}

+ (NSMutableDictionary<NSString *, BlinkXCall *> *)registry {
  static NSMutableDictionary *registry = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    registry = [[NSMutableDictionary alloc] init];
  });
  return registry;
}


- (instancetype)init
{
  self = [super init];
  if (self) {
    _callID = NSProcessInfo.processInfo.globallyUniqueString;
    
    _parseOutputParams = [[NSMutableArray alloc] init];
    _encodeInputParams = [[NSMutableArray alloc] init];
    
    _xSuccessURL = [NSURL URLWithString: [NSString stringWithFormat:@"blinkshell://x-success/%@", _callID]];
    _xErrorURL = [NSURL URLWithString: [NSString stringWithFormat:@"blinkshell://x-error/%@", _callID]];
    _xCancelURL = [NSURL URLWithString: [NSString stringWithFormat:@"blinkshell://x-cancel/%@", _callID]];
  }
  return self;
}

- (int)run {

  if (!_xURL) {
    return 0;
  }

  NSURLComponents * components = [NSURLComponents componentsWithURL:_xURL resolvingAgainstBaseURL:YES];
  NSArray<NSURLQueryItem *> *originalQueryItems = [components queryItems] ?: @[];
  NSMutableArray<NSURLQueryItem *> *originalItemsWithParams = [originalQueryItems mutableCopy];
  
  for (NSArray *pair in _encodeInputParams) {
    NSURLQueryItem *item = [NSURLQueryItem queryItemWithName:pair.firstObject value:pair.lastObject];
    [originalItemsWithParams addObject:item];
  }
  
  NSMutableArray<NSURLQueryItem *> *newQueryItems = [[NSMutableArray alloc] init];
  for (NSURLQueryItem *item in originalItemsWithParams) {
    BOOL xParam = false;
    if ([@"x-success" isEqual:item.name]) {
      xParam = true;
      _xOriginalSuccessURL = [NSURL URLWithString:item.value];
    } else if ([@"x-error" isEqual:item.name]) {
      xParam = true;
      _xOriginalErrorURL = [NSURL URLWithString:item.value];
    } else if ([@"x-cancel" isEqual:item.name]) {
      xParam = true;
      _xOriginalCancelURL = [NSURL URLWithString:item.value];
    }
    if (_async) {
      [newQueryItems addObject:item];
    } else if (!xParam) {
      [newQueryItems addObject:item];
    }
  }
  
  if (!_async) {
    [newQueryItems addObject:[NSURLQueryItem queryItemWithName:@"x-success" value:_xSuccessURL.absoluteString]];
    [newQueryItems addObject:[NSURLQueryItem queryItemWithName:@"x-error" value:_xErrorURL.absoluteString]];
    [newQueryItems addObject:[NSURLQueryItem queryItemWithName:@"x-cancel" value:_xCancelURL.absoluteString]];
  }
  
  [components setQueryItems:newQueryItems];
  
  NSURL * url = [components URL];

  puts(url.absoluteString.UTF8String);
  _sema = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_main_queue(), ^{
    NSMutableDictionary *registry = [BlinkXCall registry];
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL success) {
      if (success) {
        [registry setObject:self forKey:_callID];
      }
    }];
  });
  
  dispatch_semaphore_wait(_sema, DISPATCH_TIME_FOREVER);
  
  puts(_xCallbackURL.absoluteString.UTF8String);
  
  NSURLComponents *comps = [NSURLComponents componentsWithURL:_xCallbackURL resolvingAgainstBaseURL:YES];
  NSArray<NSURLQueryItem *> *queryItems = [comps queryItems];
  for (NSURLQueryItem *item in queryItems) {
    for (NSArray * decode in _parseOutputParams) {
      NSString *param = decode.firstObject;
      if (![param isEqual:item.name]) {
        continue;
      }
      
      NSString *decoder = decode.lastObject;
      puts(item.value.UTF8String);
      
    }
  }
  
  return 0;
}

- (void)onCallback: (NSURL *)url {
  _xCallbackURL = url;
  dispatch_semaphore_signal(_sema);
}

@end

void blink_handle_url(NSURL *url) {
  if ([@"x-success" isEqual:url.host] || [@"x-error" isEqual:url.host] || [@"x-cancel" isEqual:url.host]) {
    NSString *callID = [url.pathComponents lastObject];
    NSMutableDictionary *registry = [BlinkXCall registry];
    BlinkXCall *call = registry[callID];
    [registry removeObjectForKey:callID];
    [call onCallback:url];
  }
}

int blink_xcall_main(int argc, char *argv[]) {
  thread_optind = 1;
  
  NSString *usage = @"Usage: xcall [ap:j:b:i:s:] url";
  
  BlinkXCall *call = [[BlinkXCall alloc] init];
  
  for (;;) {
    int c = thread_getopt(argc, argv, "ap:j:b:i:s:x");
    
    if (c == -1) {
      break;
    }
    switch (c) {
      case 'a':
        call.async = YES;
        break;
      case 'p': {
        NSMutableArray * parts = [[@(thread_optarg) componentsSeparatedByString:@"="] mutableCopy];
        NSString *name = parts.firstObject;
        [parts removeObjectAtIndex:0];
        NSString *value = [parts componentsJoinedByString:@"="];
        [call.encodeInputParams addObject:@[name, value]];
        break;
      }
      case 'j': {
        [call.parseOutputParams addObject:@[@(thread_optarg), @"json"]];
        break;
      }
      case 'b': {
        [call.parseOutputParams addObject:@[@(thread_optarg), @"base64"]];
        break;
      }
      case 's': {
        [call.parseOutputParams addObject:@[@(thread_optarg), @"string"]];
        break;
      }
      case 'i': {
        call.stdInParameterName = @(thread_optarg);
        break;
      }
      default:
        printf("%s\n", usage.UTF8String);
        return -1;
    }
        
        
  }
  
  NSString * urlStr = nil;
  if (thread_optind < argc) {
    NSMutableArray<NSString *> *parts = [[NSMutableArray alloc] init];
    for (int i = thread_optind; i < argc; i++) {
      [parts addObject:@(argv[i])];
    }
    urlStr = [parts componentsJoinedByString:@" "];
    
  } else {
    printf("%s\n", usage.UTF8String);
    return -1;
  }
  
  urlStr = [urlStr stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSURL *xUrl = [NSURL URLWithString:urlStr];
  if (!xUrl) {
    puts("invalid url");
    return -1;
  }
  
  call.xURL = xUrl;
  
  BOOL isatty = ios_isatty(fileno(thread_stdin));

  if (!isatty) {
    if (call.stdInParameterName) {
      const int bufsize = 1024;
      char buffer[bufsize];
      NSMutableData* data = [[NSMutableData alloc] init];
      ssize_t count = 0;
      while ((count = read(fileno(thread_stdin), buffer, bufsize-1))) {
        [data appendBytes:buffer length:count];
      }
      
      NSString *value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
      [call.encodeInputParams addObject:@[call.stdInParameterName, value]];
    }
  }
  
  [call run];
  
  
  return 0;
}

