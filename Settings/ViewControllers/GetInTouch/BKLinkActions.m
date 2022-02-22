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

#import <UIKit/UIKit.h>

#import "BKLinkActions.h"
#import "openurl.h"

@implementation BKLinkActions

+ (void)sendToTwitter
{
  NSURL *twitterApp = [NSURL URLWithString:@"twitter:///BlinkShell?screen_name=PAGE"];
  NSURL *twitterURL = [NSURL URLWithString:@"https://twitter.com/BlinkShell"];

  UIApplication *app = [UIApplication sharedApplication];
  if ([app canOpenURL:twitterApp]) {
    [app openURL:twitterApp options:@{} completionHandler:nil];
  } else {
    blink_openurl(twitterURL);
  }
}

+ (void)sendToGitHub:(NSString *)location
{
  NSURL *githubURL = [NSURL URLWithString:@"https://github.com/blinksh"];
  if (location) {
    githubURL = [githubURL URLByAppendingPathComponent:location];
  }
  blink_openurl(githubURL);
}

+ (void)sendToAppStore
{
  NSURL *appStoreLink = [NSURL URLWithString:@"itms-apps://itunes.apple.com/app/id1594898306?action=write-review"];
  [[UIApplication sharedApplication] openURL:appStoreLink options:@{} completionHandler:nil];
}

+ (void)sendToEmailApp
{
  NSURL *mailURL = [NSURL URLWithString:@"mailto:support@blink.sh"];

  [[UIApplication sharedApplication] openURL:mailURL options:@{} completionHandler:nil];
}

+ (void)sendToDiscord {
  NSURL *url = [NSURL URLWithString:@"https://discord.gg/ZTtMfvK"];
  blink_openurl(url);
}

+ (void)sendToReddit {
  NSURL *url = [NSURL URLWithString:@"https://www.reddit.com/r/BlinkShell"];
  blink_openurl(url);
}

+ (void)sendToDiscordSupport {
  NSURL *url = [NSURL URLWithString:@"https://discord.gg/uATT2ad"];
  blink_openurl(url);
}

@end
