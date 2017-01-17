//
//  BKSmartKeysConfigViewController.m
//  Blink
//
//  Created by Atul M on 16/01/17.
//  Copyright © 2017 Carlos Cabañero Projects SL. All rights reserved.
//

#import "BKSmartKeysConfigViewController.h"
#import "BKUserConfigurationManager.h"
@interface BKSmartKeysConfigViewController ()

@property (nonatomic, weak) IBOutlet UISwitch *showWithExternalKeyboard;

@end

@implementation BKSmartKeysConfigViewController

- (void)viewDidLoad {
    [super viewDidLoad];
  [self setupUI];
}

- (void)setupUI
{
  [_showWithExternalKeyboard setOn:[BKUserConfigurationManager userSettingsValueForKey:BKUserConfigShowSmartKeysWithXKeyBoard]];
}

- (IBAction)didToggleSwitch:(id)sender
{
  UISwitch *toggleSwitch = (UISwitch *)sender;
  [BKUserConfigurationManager setUserSettingsValue:toggleSwitch.isOn forKey:BKUserConfigShowSmartKeysWithXKeyBoard];
}
@end
