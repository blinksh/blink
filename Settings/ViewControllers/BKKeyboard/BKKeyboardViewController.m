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

#import "BKKeyboardViewController.h"
#import "BKDefaults.h"
#import "BKKeyboardFuncTriggersViewController.h"
#import "BKKeyboardModifierViewController.h"
#import "BKSettingsNotifications.h"

#define KEY_LABEL_TAG 1001
#define VALUE_LABEL_TAG 1002
#define AUTOREPEAT_TAG 1003

NSString *const BKKeyboardConfigChanged = @"BKKeyboardConfigChanged";
NSString *const BKKeyboardFuncTriggerChanged = @"BKKeyboardConfigChanged";

@interface BKKeyboardViewController ()

@property (nonatomic, strong) NSIndexPath *currentSelectionIdx;
@property (nonatomic, strong) NSMutableArray *keyList;
@property (nonatomic, strong) NSMutableDictionary *keyboardMapping;
@property (strong, nonatomic) IBOutlet UISwitch *capsAsEscSwitch;
@property (strong, nonatomic) IBOutlet UISwitch *shiftAsEscSwitch;

@end

@implementation BKKeyboardViewController {
    UISwitch *_autoRepeatSwitch;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self loadData];
  // Uncomment the following line to preserve selection between presentations.
  // self.clearsSelectionOnViewWillAppear = NO;
  
  // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
  // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  [[NSNotificationCenter defaultCenter] postNotificationName:BKKeyboardConfigChanged object:self];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (NSString *)selectedObject
{
  return _keyList[_currentSelectionIdx.row];
}

- (void)loadData
{
  _keyList = [NSMutableArray arrayWithArray:[BKDefaults keyboardKeyList]];
  _keyboardMapping = [NSMutableDictionary dictionaryWithDictionary:[BKDefaults keyboardMapping]];
}

#pragma mark - UICollection View Delegates

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  switch (section) {
    case 0:
      return _keyList.count;
    case 1:
      return 5;
    case 2:
      return 1;
  }
  return 0;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  switch (section) {
    case 0:
      return @"MODIFIER MAPPINGS";
    case 1:
      return @"SPECIAL KEYS";
    case 2:
      return @"BLINK SHORTCUTS";
  }
  return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell *cell;
  switch(indexPath.section) {
    case 0: {
      cell = [tableView dequeueReusableCellWithIdentifier:@"keyMapperCell" forIndexPath:indexPath];
      
      UILabel *keyLabel = [cell viewWithTag:KEY_LABEL_TAG];
      keyLabel.text = [_keyList objectAtIndex:indexPath.row];
      
      UILabel *valueLabel = [cell viewWithTag:VALUE_LABEL_TAG];
      valueLabel.text = [_keyboardMapping objectForKey:keyLabel.text];
      break;
    }
    case 1: {
      switch (indexPath.row) {
        case 0:
          cell = [tableView dequeueReusableCellWithIdentifier:@"capsAsEscCell" forIndexPath:indexPath];
          [_capsAsEscSwitch setOn:[BKDefaults isCapsAsEsc]];
          break;
        case 1:
          cell = [tableView dequeueReusableCellWithIdentifier:@"shiftAsEscCell" forIndexPath:indexPath];
          [_shiftAsEscSwitch setOn:[BKDefaults isShiftAsEsc]];
          break;
        case 2:
          cell = [tableView dequeueReusableCellWithIdentifier:@"autoRepeatCell" forIndexPath:indexPath];
          _autoRepeatSwitch = [cell viewWithTag:AUTOREPEAT_TAG];
          [_autoRepeatSwitch setOn:[BKDefaults autoRepeatKeys]];
        case 3:
          cell = [tableView dequeueReusableCellWithIdentifier:@"multipleModifierCell" forIndexPath:indexPath];
          cell.textLabel.text = (NSString*)BKKeyboardFuncFTriggers;
          cell.detailTextLabel.text = [self detailForKeyboardFunc:BKKeyboardFuncFTriggers];
          break;
        case 4:
          cell = [tableView dequeueReusableCellWithIdentifier:@"multipleModifierCell" forIndexPath:indexPath];
          cell.textLabel.text = (NSString*)BKKeyboardFuncCursorTriggers;
          cell.detailTextLabel.text = [self detailForKeyboardFunc:BKKeyboardFuncCursorTriggers];
          break;
      }
      break;
    }
    case 2: {
      cell = [tableView dequeueReusableCellWithIdentifier:@"multipleModifierCell" forIndexPath:indexPath];
      cell.textLabel.text = (NSString*)BKKeyboardFuncShortcutTriggers;
      cell.detailTextLabel.text = [self detailForKeyboardFunc:BKKeyboardFuncShortcutTriggers];
      break;
    }
  }
  
  return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  _currentSelectionIdx = indexPath;
  return indexPath;
}

- (NSString *)detailForKeyboardFunc:(const NSString *)func
{
  NSString *trigger = [[BKDefaults keyboardFuncTriggers][func] componentsJoinedByString:@" + "];
  
  if ([func isEqualToString:(NSString*)BKKeyboardFuncFTriggers]) {
    return [trigger stringByAppendingString:@" + number"];
  } else if ([func isEqualToString:(NSString*)BKKeyboardFuncCursorTriggers]) {
    return [trigger stringByAppendingString:@" + arrow"];
  } else if ([func  isEqualToString:(NSString*)BKKeyboardFuncShortcutTriggers]) {
    return [trigger stringByAppendingString:@" + key"];
  }
  
  return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
  UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
  if([cell.textLabel.text isEqualToString:(NSString*)BKKeyboardFuncShortcutTriggers]){
    [self performSegueWithIdentifier:@"keyboardShortcutsSegue" sender:self];
  } else if ([cell.textLabel.text isEqualToString:(NSString*)BKKeyboardFuncFTriggers] || [cell.textLabel.text isEqualToString:(NSString*)BKKeyboardFuncCursorTriggers]) {
    [self performSegueWithIdentifier:@"selectTriggersSegue" sender:self];
  }
}

#pragma mark - Actions
- (IBAction)capsAsEscChanged:(UISwitch *)sender
{
  [BKDefaults setCapsAsEsc:[sender isOn]];
  [BKDefaults saveDefaults];
}

- (IBAction)shiftAsEscChanged:(UISwitch *)sender
{
  BOOL what = [sender isOn];
  [BKDefaults setShiftAsEsc:what];
  [BKDefaults saveDefaults];
}
- (IBAction)autoRepeatChanged:(id)sender {
  BOOL what = [sender isOn];
  [BKDefaults setAutoRepeatKeys:what];
  [BKDefaults saveDefaults];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
  if ([segue.identifier isEqualToString:@"keyboardModifier"]) {
    BKKeyboardModifierViewController *modifier = segue.destinationViewController;
    [modifier performInitialSelection:[_keyboardMapping objectForKey:[self selectedObject]]];
  } else if ([segue.identifier isEqualToString:@"selectTriggersSegue"]) {
    BKKeyboardFuncTriggersViewController *vc = segue.destinationViewController;
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:_currentSelectionIdx];
    vc.function = cell.textLabel.text;
    [vc performInitialSelection:[BKDefaults keyboardFuncTriggers][cell.textLabel.text]];
  }
}

- (IBAction)unwindFromKeyboardModifier:(UIStoryboardSegue *)sender
{
  BKKeyboardModifierViewController *modifier = sender.sourceViewController;
  UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:_currentSelectionIdx];
  
  UILabel *valueLabel = [cell viewWithTag:VALUE_LABEL_TAG];
  valueLabel.text = [modifier selectedObject];
  
  [_keyboardMapping setObject:valueLabel.text forKey:[self selectedObject]];
  [BKDefaults setAutoRepeatKeys:_autoRepeatSwitch.on];
  [BKDefaults setModifer:valueLabel.text forKey:[self selectedObject]];
  [BKDefaults saveDefaults];
}

- (IBAction)unwindFromKeyboardFuncTriggers:(UIStoryboardSegue *)sender
{
  UIViewController *vc = sender.sourceViewController;
  UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:_currentSelectionIdx];
  
  NSString *function = cell.textLabel.text;
  NSArray *trigger = [vc valueForKey:@"selectedObjects"];
  
  [BKDefaults setTriggers:trigger forFunction:function];
  [BKDefaults saveDefaults];
  
  cell.detailTextLabel.text = [self detailForKeyboardFunc:function];
  
  [[NSNotificationCenter defaultCenter]
   postNotificationName:BKKeyboardFuncTriggerChanged
   object:vc
   userInfo:@{
              @"func" : function,
              @"trigger" : trigger
              }];
  
}




@end
