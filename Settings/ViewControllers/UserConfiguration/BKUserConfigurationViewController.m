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

@import CloudKit;
@import UserNotifications;

#import "BKUserConfigurationViewController.h"

@interface BKUserConfigurationViewController ()

@property (nonatomic, weak) IBOutlet UISwitch *toggleiCloudSync;

@end

@implementation BKUserConfigurationViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self setupUI];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)setupUI
{
  [_toggleiCloudSync setOn:[BKUserConfigurationViewController userSettingsValueForKey:@"iCloudSync"]];
}

#pragma mark - Action Method

- (IBAction)didToggleSwitch:(id)sender
{
  UISwitch *toggleSwitch = (UISwitch *)sender;
  if (toggleSwitch == _toggleiCloudSync) {
    [self checkiCloudStatusAndToggle];
  }
}

- (void)checkiCloudStatusAndToggle
{
  [[CKContainer defaultContainer] accountStatusWithCompletionHandler:
				    ^(CKAccountStatus accountStatus, NSError *error) {
				      if (accountStatus == CKAccountStatusNoAccount) {
					dispatch_async(dispatch_get_main_queue(), ^{
					  UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:@"Please login to your iCloud account to enable Sync" preferredStyle:UIAlertControllerStyleAlert];
					  UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
					  [alertController addAction:ok];
					  [self presentViewController:alertController animated:YES completion:nil];
					  [_toggleiCloudSync setOn:NO];
					});
				      } else {

					if (_toggleiCloudSync.isOn) {
					  [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:(UNAuthorizationOptionAlert)
													      completionHandler:^(BOOL granted, NSError *_Nullable error){

													      }];
					  [[UIApplication sharedApplication] registerForRemoteNotifications];
					}

					[BKUserConfigurationViewController setUserSettingsValue:_toggleiCloudSync.isOn forKey:@"iCloudSync"];
				      }
				    }];
}

+ (void)setUserSettingsValue:(BOOL)value forKey:(NSString *)key
{
  NSMutableDictionary *userSettings = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:@"userSettings"]];
  if (userSettings == nil) {
    userSettings = [NSMutableDictionary dictionary];
  }
  [userSettings setObject:[NSNumber numberWithBool:value] forKey:key];
  [[NSUserDefaults standardUserDefaults] setObject:userSettings forKey:@"userSettings"];
}

+ (BOOL)userSettingsValueForKey:(NSString *)key
{
  NSDictionary *userSettings = [[NSUserDefaults standardUserDefaults] objectForKey:@"userSettings"];
  if (userSettings != nil) {
    if ([userSettings objectForKey:key]) {
      NSNumber *value = [userSettings objectForKey:key];
      return value.boolValue;
    } else {
      return NO;
    }
  } else {
    return NO;
  }
  return NO;
}


@end
