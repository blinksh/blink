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


#import "SceneDelegate.h"
#import "SpaceController.h"
#import "AppDelegate.h"

@implementation SceneDelegate {
  UIWindow *_window;
}

- (void)scene:(UIScene *)scene
  willConnectToSession:(UISceneSession *)session
               options:(UISceneConnectionOptions *)connectionOptions {
  
  UIWindowScene *winScene = (UIWindowScene *)scene;
  
  UIWindow *window = [[UIWindow alloc] initWithWindowScene:winScene];
  window.rootViewController = [[SpaceController alloc] init];
  [window makeKeyAndVisible];
  _window = window;
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
  AppDelegate *appDelegate = (AppDelegate *)UIApplication.sharedApplication.delegate;
  
  // TODO: check if we are last active scene here
  [appDelegate startMonitoringForSuspending];
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
  
}


- (NSUserActivity *)stateRestorationActivityForScene:(UIScene *)scene {
  return [[NSUserActivity alloc] initWithActivityType:@"state.restoration.activity"];
}

@end
