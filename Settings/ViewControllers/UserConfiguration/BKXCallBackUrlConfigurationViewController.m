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


#import "BKXCallBackUrlConfigurationViewController.h"
#import "BKDefaults.h"

#define KTextFieldTag 3001

@interface BKXCallBackUrlConfigurationViewController () <UITextFieldDelegate>

@property (weak) IBOutlet UITextField *xCallbackURLKeyTextField;

@end

@implementation BKXCallBackUrlConfigurationViewController {
  UISwitch *_xCallbackUrlEnabledSwitch;
  NSRegularExpression *_validKeyRegexp;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  NSString *key = [BKDefaults xCallBackURLKey];
  if (key == nil) {
    key = [NSProcessInfo.processInfo.globallyUniqueString substringToIndex:6];
    [BKDefaults setXCallBackURLKey:key];
  }
  
  _validKeyRegexp = [[NSRegularExpression alloc] initWithPattern:@"[^a-zA-Z0-9]" options:kNilOptions error:nil];
  
  _xCallbackUrlEnabledSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
  [_xCallbackUrlEnabledSwitch setOn:[BKDefaults isXCallBackURLEnabled]];
  [_xCallbackUrlEnabledSwitch addTarget:self action:@selector(_onCallBackUrlEnabledChanged) forControlEvents:UIControlEventValueChanged];
  
  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"switch"];
}

- (void)_onCallBackUrlEnabledChanged {
  bool isOn = _xCallbackUrlEnabledSwitch.isOn;
  [BKDefaults setXCallBackURLEnabled:isOn];
  [BKDefaults saveDefaults];
  NSArray * rows = @[[NSIndexPath indexPathForRow:1 inSection:0]];
  if (isOn) {
    [self.tableView insertRowsAtIndexPaths:rows withRowAnimation:UITableViewRowAnimationTop];
  } else {
    [self.tableView deleteRowsAtIndexPaths:rows withRowAnimation:UITableViewRowAnimationTop];
  }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (_xCallbackUrlEnabledSwitch.isOn) {
    return 2;
  } else {
    return 1;
  }
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row == 0) {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"switch" forIndexPath:indexPath];
    cell.accessoryView = _xCallbackUrlEnabledSwitch;
    cell.textLabel.text = NSLocalizedString(@"Allow URL actions", nil);
    return cell;
  } else if (indexPath.row == 1) {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"URLKey" forIndexPath:indexPath];
    _xCallbackURLKeyTextField = [cell viewWithTag:KTextFieldTag];
    _xCallbackURLKeyTextField.text = [BKDefaults xCallBackURLKey];
    return cell;
  }
  
    
  return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"default"];
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
  return NO;
}


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
  if (string.length == 0) {
    return YES;
  }
  
  NSArray *matches = [_validKeyRegexp matchesInString:string options:kNilOptions range:NSMakeRange(0, string.length)];
  
  NSUInteger oldLength = [textField.text length];
  NSUInteger replacementLength = [string length];
  NSUInteger rangeLength = range.length;
  
  NSUInteger newLength = oldLength - rangeLength + replacementLength;
  
  return matches.count == 0 && newLength <= 100;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
  NSString *urlKey = [BKDefaults xCallBackURLKey] ?: @"<URL key>";
  return [NSString stringWithFormat: @"Use x-callback-url for automation and inter-app communication. Your URL key should be kept secret.\n\nExample:\nblinkshell://run?key=%@&cmd=ls", urlKey];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
  [BKDefaults setXCallBackURLKey:textField.text];
  [BKDefaults saveDefaults];
  [self.tableView reloadData];
}

@end
