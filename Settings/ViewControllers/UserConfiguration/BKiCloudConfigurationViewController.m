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

@import CloudKit;
@import UserNotifications;

#import "BKiCloudConfigurationViewController.h"
#import "BKUserConfigurationManager.h"
#import "Blink-Swift.h"

@interface BKiCloudConfigurationViewController ()

@property (nonatomic, weak) IBOutlet UISwitch *toggleiCloudSync;
@property (nonatomic, weak) IBOutlet UISwitch *toggleiCloudKeysSync;

@end

@implementation BKiCloudConfigurationViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self setupUI];
}

- (void)setupUI
{
  [_toggleiCloudSync setOn:[BKUserConfigurationManager userSettingsValueForKey:@"iCloudSync"]];
  [_toggleiCloudKeysSync setOn:[BKUserConfigurationManager userSettingsValueForKey:@"iCloudKeysSync"]];
}

#pragma mark - Action Method

- (IBAction)didToggleSwitch:(id)sender
{
  UISwitch *toggleSwitch = (UISwitch *)sender;
  if (toggleSwitch == _toggleiCloudSync) {
    [self checkiCloudStatusAndToggle];
    [self.tableView reloadData];
  } else if (toggleSwitch == _toggleiCloudKeysSync) {
    [BKUserConfigurationManager setUserSettingsValue:_toggleiCloudKeysSync.isOn forKey:@"iCloudKeysSync"];
  }
}

- (void)checkiCloudStatusAndToggle
{
  [[CKContainer defaultContainer] accountStatusWithCompletionHandler:
				    ^(CKAccountStatus accountStatus, NSError *error) {
              
    dispatch_async(dispatch_get_main_queue(), ^{

      if (accountStatus == CKAccountStatusNoAccount) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:@"Please login to your iCloud account to enable Sync" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alertController addAction:ok];
        [self presentViewController:alertController animated:YES completion:nil];
        [_toggleiCloudSync setOn:NO];
      } else {
        if (_toggleiCloudSync.isOn) {
          [[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:(UNAuthorizationOptionAlert)
                                                                              completionHandler:^(BOOL granted, NSError *_Nullable error){}];
          [[UIApplication sharedApplication] registerForRemoteNotifications];
        }
        [BKUserConfigurationManager setUserSettingsValue:_toggleiCloudSync.isOn forKey:@"iCloudSync"];
      }
    });
  }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  if (_toggleiCloudSync.isOn) {
    return [super numberOfSectionsInTableView:tableView];
  } else {
    return 1;
  }
}


@end
