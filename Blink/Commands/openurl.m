////////////////////////////////////////////////////////////////////////////////
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

#include <stdio.h>
#import <UIKit/UIKit.h>
#include "ios_system/ios_system.h"
#include "ios_error.h"
#include "openurl.h"

NSArray<NSString *> *__blink_known_browsers(void) {
  return @[
           @"brave",
           @"firefox",
           @"googlechrome",
           @"opera",
           @"safari",
           @"yandexbrowser",
           ];
}

NSURL *__blink_browser_app_url(NSURL *srcURL) {
  if (!srcURL) {
    return nil;
  }
  
  NSString *scheme = srcURL.scheme;
  BOOL isWebLink = [scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"];
  if (!isWebLink) {
    return nil;
  }
  
  char *browserEnvVar = getenv("BROWSER");
  if (!browserEnvVar) {
    return nil;
  }

  NSString *browser = [@(browserEnvVar) lowercaseString];
  if (![__blink_known_browsers() containsObject:browser]) {
    return nil;
  }
  
  if ([browser isEqualToString:@"safari"]) {
    return nil;
  }
  
  NSString *absSrcURLStr = [srcURL absoluteString];
  
  // browsers with the open-url scheme:
  if (([browser isEqualToString:@"firefox"]) ||
      ([browser isEqualToString:@"brave"]) ||
      ([browser isEqualToString:@"opera"])) {
    NSString *url = [absSrcURLStr
                     stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSString *openUrl = [@"://open-url?url=" stringByAppendingString:url];
    url = [browser stringByAppendingString:openUrl];
    return [NSURL URLWithString:url];
  }
  
  if ([browser isEqualToString:@"yandexbrowser"]) {
    NSString *url = [absSrcURLStr
                     stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    url = [@"yandexbrowser-open-url://" stringByAppendingString:url];
    return [NSURL URLWithString:url];
  }
  
  NSString *browserAppUrlStr = [absSrcURLStr stringByReplacingCharactersInRange:NSMakeRange(0, 4) withString:browser];
  return [NSURL URLWithString:browserAppUrlStr];
}

void blink_openurl(NSURL *url) {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSURL *browserAppURL = __blink_browser_app_url(url);
    [[UIApplication sharedApplication] openURL:browserAppURL ?: url
                                       options:@{}
                             completionHandler:nil];
  });
}

__attribute__ ((visibility("default")))
int blink_openurl_main(int argc, char *argv[]) {
  NSString *usage = [@[@"Usage: openurl url",
                       @"you can change default browser with BROWSER env var:",
                       [NSString stringWithFormat: @"  %@", [__blink_known_browsers() componentsJoinedByString:@", "]],
                       ] componentsJoinedByString:@"\n"];
  
  if (argc < 2) {
    printf("%s\n", usage.UTF8String);
    return -1;
  }
  
  NSURL *locationURL = [NSURL URLWithString:@(argv[1])];
  if (!locationURL) {
    printf("%s\n", "Invalid URL");
    return -1;
  }

  blink_openurl(locationURL);
  
  
  return 0;
}

