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

#import "BKSettingsViewController.h"
#import "BKDefaults.h"
#import "BKTouchIDAuthManager.h"
#import "BKUserConfigurationManager.h"
#import "BKiCloudConfigurationViewController.h"
#import "BKiCloudSyncHandler.h"


@interface BKSettingsViewController ()

@property (nonatomic, weak) IBOutlet UILabel *userNameLabel;
@property (nonatomic, weak) IBOutlet UILabel *iCloudSyncStatusLabel;
@property (nonatomic, weak) IBOutlet UILabel *autoLockStatusLabel;

@end

@implementation BKSettingsViewController
{
  NSArray *_kbCommands;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  UIKeyModifierFlags modifierFlags = [BKUserConfigurationManager shortCutModifierFlags];
  
  _kbCommands = @[
                  [UIKeyCommand keyCommandWithInput: @"w" modifierFlags: modifierFlags
                                             action: @selector(_closeConfig:)
                               discoverabilityTitle: @"Close Settings"]
                  ];
  
  // Uncomment the following line to preserve selection between presentations.
  // self.clearsSelectionOnViewWillAppear = NO;

  // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
  // self.navigationItem.rightBarButtonItem = self.editButtonItem;
  if (@available(iOS 11, *)) {
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
  }
}

- (void)_closeConfig:(UIKeyCommand *)cmd
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSArray<UIKeyCommand *> *)keyCommands
{
  return _kbCommands;
}

- (BOOL)canBecomeFirstResponder
{
  return YES;
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  self.userNameLabel.text = [BKDefaults defaultUserName];
  self.iCloudSyncStatusLabel.text = [BKUserConfigurationManager userSettingsValueForKey:BKUserConfigiCloud] == true ? @"On" : @"Off";
  self.autoLockStatusLabel.text = [BKUserConfigurationManager userSettingsValueForKey:BKUserConfigAutoLock] == true ? @"On" : @"Off";
}

- (IBAction)unwindFromDefaultUser:(UIStoryboardSegue *)sender
{
}
@end
