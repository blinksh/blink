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

#import "UIApplication+Version.h"
#import "BKSettingsViewController.h"
#import "BKDefaults.h"
#import "BKUserConfigurationManager.h"
#import "BKiCloudConfigurationViewController.h"
#import "BKiCloudSyncHandler.h"
#import "Blink-Swift.h"


@interface BKSettingsViewController ()

@property (nonatomic, weak) IBOutlet UILabel *userNameLabel;
@property (nonatomic, weak) IBOutlet UILabel *iCloudSyncStatusLabel;
@property (nonatomic, weak) IBOutlet UILabel *autoLockStatusLabel;
@property (nonatomic, weak) IBOutlet UILabel *xCallbackStatusLabel;
@property (nonatomic, weak) IBOutlet UILabel *versionLabel;

@end

@implementation BKSettingsViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
}

- (void)_closeConfig:(UIKeyCommand *)cmd {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)canBecomeFirstResponder {
  return YES;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  self.userNameLabel.text = [BKDefaults defaultUserName];
  self.iCloudSyncStatusLabel.text = [BKUserConfigurationManager userSettingsValueForKey:BKUserConfigiCloud] ? @"On" : @"Off";
  self.autoLockStatusLabel.text = [BKUserConfigurationManager userSettingsValueForKey:BKUserConfigAutoLock] ? @"On" : @"Off";
  self.xCallbackStatusLabel.text = [BKDefaults isXCallBackURLEnabled] ? @"On" : @"Off";
  self.versionLabel.text = [UIApplication blinkShortVersion];
  
  // Layout tableview so it will place labels correctly
  [self.tableView layoutIfNeeded];
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
  return YES;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 1) {
#if TARGET_OS_MACCATALYST
    return 5;
#else
    return 4;
#endif
  }
  
  return [super tableView:tableView numberOfRowsInSection:section];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == 0 && indexPath.row == 0) {
    UIViewController *vc = [SettingsHostingController createKeysWithNav:self.navigationController];
    [self.navigationController pushViewController:vc animated:YES];
  } else if (indexPath.section == 0 && indexPath.row == 1) {
    UIViewController *vc = [SettingsHostingController createHostsWithNav:self.navigationController];
    [self.navigationController pushViewController:vc animated:YES];
  } else if (indexPath.section == 1 && indexPath.row == 1) {
    UIViewController *vc = [SettingsHostingController createKeyboardControllerWithNav:self.navigationController];
    [self.navigationController pushViewController:vc animated:YES];
  } else if (indexPath.section == 1 && indexPath.row == 3) {
    UIViewController *vc = [SettingsHostingController createNotificationsWithNav:self.navigationController];
    [self.navigationController pushViewController:vc animated:YES];
  } else if (indexPath.section == 1 && indexPath.row == 4) {
    UIViewController *vc = [SettingsHostingController createGesturesWithNav:self.navigationController];
    [self.navigationController pushViewController:vc animated:YES];
  }
}

@end
