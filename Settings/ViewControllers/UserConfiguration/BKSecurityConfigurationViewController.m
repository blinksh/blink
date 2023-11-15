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

#import "BKSecurityConfigurationViewController.h"
#import "BKUserConfigurationManager.h"
#import "Blink-Swift.h"

//MARK: - Private properties and outlets for the view controller
@interface BKSecurityConfigurationViewController ()

@property (nonatomic, weak) IBOutlet UISwitch *toggleAppLock;
@property (weak, nonatomic) IBOutlet UIButton *customLockButton;
@property (weak, nonatomic) IBOutlet UITableViewCell *customLockTableViewCell;

@end

@implementation BKSecurityConfigurationViewController


//MARK: - Lifecycle
- (void)viewDidLoad {
  [super viewDidLoad];
  
  ///Load the user settings and set the initial state of the toggle switch
  [_toggleAppLock setOn:[BKUserConfigurationManager userSettingsValueForKey:BKUserConfigAutoLock]];
  
  ///Show initial Lock TimeInterval
  [self.customLockButton setTitle:[NSString stringWithFormat:@"%ld minutes", (long)[LocalAuth.shared getMaxMinutesTimeInterval]] forState:UIControlStateNormal];
  
  ///Initially hide the customLockTableViewCell
  _customLockTableViewCell.hidden = YES;
  
  ///Check if auto-lock is enabled, and show the customLockTableViewCell accordingly
  if ([BKUserConfigurationManager userSettingsValueForKey:BKUserConfigAutoLock]) {
    _customLockTableViewCell.hidden = NO;
  }
  
  ///Set up the custom lock menu
  [self setupCustomLockMenu];
}


//MARK: - IBActions
- (IBAction)didToggleSwitch:(UISwitch *)toggleSwitch {
  BOOL isOn = toggleSwitch.isOn;
  
  ///Authenticate using LocalAuth
  [[LocalAuth shared] authenticateWithCallback:^(BOOL success) {
    if (success) {
      
      ///Update the user settings and set the customLockButton title
      [BKUserConfigurationManager setUserSettingsValue:isOn forKey:BKUserConfigAutoLock];
      [_customLockButton setTitle:@"10 minutes" forState:UIControlStateNormal];
    } else {
      
      ///If authentication fails, toggle the switch back to its previous state
      toggleSwitch.on = !isOn;
    }
    
    ///Toggle the visibility of customLockTableViewCell based on the switch state
    _customLockTableViewCell.hidden = !isOn;
    
  } reason: isOn ? @"to turn off auto lock." : @"to turn on auto lock."];
}


//MARK: - Handle the selection of auto-lock time from the menu
- (void)setNewAutoLockTimeUI:(UIAction *)action API_AVAILABLE(ios(13.0)) {
  NSString *title = action.title;
  
  ///Update the customLockButton title based on the selected time
  [_customLockButton setTitle:title forState:UIControlStateNormal];
}


//MARK: - Set up the custom lock menu with actions for different time intervals
- (void)setupCustomLockMenu {
  UIAction *oneMinuteAction = [UIAction actionWithTitle:@"1 minute" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
    [self setNewAutoLockTimeUI:action];
    [[LocalAuth shared] setNewLockTimeIntervalWithMinutes: 1];
  }];
  
  UIAction *fiveMinutesAction = [UIAction actionWithTitle:@"5 minutes" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
    [self setNewAutoLockTimeUI:action];
    [[LocalAuth shared] setNewLockTimeIntervalWithMinutes: 5];
  }];
  
  UIAction *tenMinutesAction = [UIAction actionWithTitle:@"10 minutes" image:nil identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
    [self setNewAutoLockTimeUI:action];
    [[LocalAuth shared] setNewLockTimeIntervalWithMinutes: 10];
  }];
  
  NSArray<UIAction *> *additionalActions = @[oneMinuteAction, fiveMinutesAction, tenMinutesAction];
  
  ///Create a UIMenu with the specified actions and set it to the customLockButton
  UIMenu *customLockMenu = [UIMenu menuWithTitle:@"" children:additionalActions];
  
  [_customLockButton setMenu:customLockMenu];
  [_customLockButton setShowsMenuAsPrimaryAction:YES];
}

@end
