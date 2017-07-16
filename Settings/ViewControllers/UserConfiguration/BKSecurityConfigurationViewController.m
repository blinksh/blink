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

#import "BKSecurityConfigurationViewController.h"
#import "BKTouchIDAuthManager.h"
#import "BKUserConfigurationManager.h"
#import "Blink-swift.h"

@interface BKSecurityConfigurationViewController () <UINavigationControllerDelegate>

@property (nonatomic, weak) IBOutlet UISwitch *toggleAppLock;

@end

@implementation BKSecurityConfigurationViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  self.navigationController.delegate = self;
}

- (void)setupUI
{
  [_toggleAppLock setOn:[BKUserConfigurationManager userSettingsValueForKey:BKUserConfigAutoLock]];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (IBAction)didToggleSwitch:(id)sender
{
  UISwitch *toggleSwitch = (UISwitch *)sender;
  if (toggleSwitch == _toggleAppLock) {
    NSString *state = nil;
    if ([toggleSwitch isOn]) {
      state = @"SetPasscode";
    } else {
      state = @"RemovePasscode";
    }
    PasscodeLockViewController *lockViewController = [[PasscodeLockViewController alloc] initWithStateString:state];
    lockViewController.completionCallback = ^{
      [BKUserConfigurationManager setUserSettingsValue:!_toggleAppLock.isOn forKey:BKUserConfigAutoLock];
      [[BKTouchIDAuthManager sharedManager] registerforDeviceLockNotif];
      [self setupUI];
    };
    [self.navigationController pushViewController:lockViewController animated:YES];
  }
}


- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
  [self setupUI];
}


@end
